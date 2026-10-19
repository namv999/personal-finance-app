import 'package:sqflite/sqflite.dart';
import '../core/database/db_helper.dart';
import '../core/database/txn_ext.dart';
import '../core/utils/clock.dart';
import '../core/utils/id_generator.dart';
import '../models/category.dart';
import '../models/sync_queue_item.dart';
import '../models/transaction.dart';
import 'sync_repository.dart';
import 'wallet_repository.dart';
import 'saving_streak_repository.dart';

class TransactionRepository {
  final DatabaseExecutor _db;
  TransactionRepository(this._db);

  Future<List<FinanceTransaction>> getAll(
    String userId, {
    String? walletId,
    DateTime? from,
    DateTime? to,
    int? limit,
  }) async {
    final where = StringBuffer('user_id = ? AND is_deleted = 0');
    final args = <dynamic>[userId];
    if (walletId != null) {
      where.write(' AND wallet_id = ?');
      args.add(walletId);
    }
    if (from != null) {
      where.write(' AND transaction_date >= ?');
      args.add(dateOnly(from));
    }
    if (to != null) {
      where.write(' AND transaction_date <= ?');
      args.add(dateOnly(to));
    }
    final rows = await _db.query(
      Tables.transactions,
      where: where.toString(),
      whereArgs: args,
      orderBy: 'transaction_date DESC, created_at DESC',
      limit: limit,
    );
    return rows.map(FinanceTransaction.fromMap).toList();
  }

  Future<FinanceTransaction> create({
    required String userId,
    required String walletId,
    String? categoryId,
    required CategoryType type,
    required int amount,
    String? note,
    required DateTime transactionDate,
  }) async {
    if (amount <= 0) throw Exception('Số tiền phải lớn hơn 0');
    ensureNotFuture(transactionDate);
    return _db.inTxn((e) async {
      await _validateRefs(e,
          userId: userId,
          walletId: walletId,
          categoryId: categoryId,
          type: type);
    final tx = FinanceTransaction(
      id: IdGenerator.next(),
      userId: userId,
      walletId: walletId,
      categoryId: categoryId,
      type: type,
      amount: amount,
      note: note,
      transactionDate: transactionDate,
      createdAt: nowUtc(),
      updatedAt: nowUtc(),
    );
    await e.insert(Tables.transactions, tx.toMap());
    await SyncRepository(e).enqueue(
        tableName: Tables.transactions,
        recordId: tx.id,
        action: SyncAction.create);
      await WalletRepository(e).recomputeBalance(walletId);
      await SavingStreakRepository(e).recompute(userId);
      return tx;
    });
  }

  Future<void> _validateRefs(DatabaseExecutor e,
      {required String userId,
      required String walletId,
      String? categoryId,
      required CategoryType type}) async {
    final wallets = await e.query(Tables.wallets,
        columns: ['id'],
        where: 'id = ? AND user_id = ? AND is_deleted = 0',
        whereArgs: [walletId, userId],
        limit: 1);
    if (wallets.isEmpty) throw Exception('Ví không hợp lệ');
    if (categoryId == null) return;
    final categories = await e.query(Tables.categories,
        columns: ['type'],
        where: 'id = ? AND is_deleted = 0 AND (user_id IS NULL OR user_id = ?)',
        whereArgs: [categoryId, userId],
        limit: 1);
    if (categories.isEmpty) throw Exception('Danh mục không hợp lệ');
    if (categories.first['type'] != type.value) {
      throw Exception('Loại danh mục không khớp loại giao dịch');
    }
  }

  Future<void> update(FinanceTransaction tx) async {
    if (tx.amount <= 0) throw Exception('Số tiền phải lớn hơn 0');
    ensureNotFuture(tx.transactionDate);
    await _db.inTxn((e) async {
      final existingRows = await e.query(Tables.transactions,
          columns: ['wallet_id'],
          where: 'id = ? AND user_id = ? AND is_deleted = 0',
          whereArgs: [tx.id, tx.userId],
          limit: 1);
      if (existingRows.isEmpty) throw Exception('Giao dịch không tồn tại');
      final oldWalletId = existingRows.first['wallet_id'] as String;
      await _validateRefs(e,
          userId: tx.userId,
          walletId: tx.walletId,
          categoryId: tx.categoryId,
          type: tx.type);
      await e.update(Tables.transactions, {
        'wallet_id': tx.walletId,
        'category_id': tx.categoryId,
        'type': tx.type.value,
        'amount': tx.amount,
        'note': tx.note,
        'transaction_date': dateOnly(tx.transactionDate),
        'updated_at': nowUtcIso(),
      }, where: 'id = ?', whereArgs: [tx.id]);
    await SyncRepository(e).enqueue(
        tableName: Tables.transactions,
        recordId: tx.id,
        action: SyncAction.update);
      final wallets = WalletRepository(e);
      if (oldWalletId != tx.walletId) {
        await wallets.recomputeBalance(oldWalletId);
      }
      await wallets.recomputeBalance(tx.walletId);
      await SavingStreakRepository(e).recompute(tx.userId);
    });
  }

  Future<void> delete(String id, String walletId) => _db.inTxn((e) async {
    final rows = await e.query(Tables.transactions,
        columns: ['wallet_id', 'user_id'],
        where: 'id = ? AND is_deleted = 0',
        whereArgs: [id],
        limit: 1);
    if (rows.isEmpty) return;
    await e.update(Tables.transactions,
        {'is_deleted': 1, 'updated_at': nowUtcIso()},
        where: 'id = ?', whereArgs: [id]);
    await SyncRepository(e).enqueue(
        tableName: Tables.transactions,
        recordId: id,
        action: SyncAction.delete);
    await WalletRepository(e)
        .recomputeBalance(rows.first['wallet_id'] as String);
    await SavingStreakRepository(e)
        .recompute(rows.first['user_id'] as String);
  });

  /// Sum of income/expense for a user within [from, to], grouped by type.
  Future<Map<CategoryType, int>> getTotalsByType(
      String userId, DateTime from, DateTime to) async {
    final rows = await _db.rawQuery('''
      SELECT type, COALESCE(SUM(amount), 0) as total FROM ${Tables.transactions}
      WHERE user_id = ? AND is_deleted = 0 AND transaction_date BETWEEN ? AND ?
      GROUP BY type
    ''', [
      userId,
      dateOnly(from),
      dateOnly(to)
    ]);

    final result = {CategoryType.income: 0, CategoryType.expense: 0};
    for (final row in rows) {
      result[CategoryTypeX.fromValue(row['type'] as String)] =
          row['total'] as int;
    }
    return result;
  }

  /// Spending grouped by category for a month — powers the dashboard chart
  /// and budget screens.
  Future<Map<String, int>> getExpenseByCategory(
      String userId, String yyyyMM) async {
    final rows = await _db.rawQuery('''
      SELECT category_id, COALESCE(SUM(amount), 0) as total FROM ${Tables.transactions}
      WHERE user_id = ? AND is_deleted = 0 AND type = 'EXPENSE'
        AND transaction_date LIKE ?
      GROUP BY category_id
    ''', [userId, '$yyyyMM%']);

    return {
      for (final row in rows)
        (row['category_id'] as String? ?? 'uncategorized'): row['total'] as int
    };
  }
}
