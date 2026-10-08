import 'package:sqflite/sqflite.dart';
import '../core/database/db_helper.dart';
import '../core/utils/id_generator.dart';
import '../models/category.dart';
import '../models/sync_queue_item.dart';
import '../models/transaction.dart';
import 'sync_repository.dart';
import 'wallet_repository.dart';

class TransactionRepository {
  final Database _db;
  late final SyncRepository _sync = SyncRepository(_db);
  late final WalletRepository _wallets = WalletRepository(_db);
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
      args.add(from.toIso8601String().split('T').first);
    }
    if (to != null) {
      where.write(' AND transaction_date <= ?');
      args.add(to.toIso8601String().split('T').first);
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
    final tx = FinanceTransaction(
      id: IdGenerator.next(),
      userId: userId,
      walletId: walletId,
      categoryId: categoryId,
      type: type,
      amount: amount,
      note: note,
      transactionDate: transactionDate,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await _db.insert(Tables.transactions, tx.toMap());
    await _sync.enqueue(tableName: Tables.transactions, recordId: tx.id, action: SyncAction.create);
    await _wallets.recomputeBalance(walletId);
    return tx;
  }

  Future<void> update(FinanceTransaction tx) async {
    await _db.update(Tables.transactions, tx.toMap(), where: 'id = ?', whereArgs: [tx.id]);
    await _sync.enqueue(tableName: Tables.transactions, recordId: tx.id, action: SyncAction.update);
    await _wallets.recomputeBalance(tx.walletId);
  }

  Future<void> delete(String id, String walletId) async {
    await _db.update(Tables.transactions, {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [id]);
    await _sync.enqueue(tableName: Tables.transactions, recordId: id, action: SyncAction.delete);
    await _wallets.recomputeBalance(walletId);
  }

  /// Sum of income/expense for a user within [from, to], grouped by type.
  Future<Map<CategoryType, int>> getTotalsByType(
      String userId, DateTime from, DateTime to) async {
    final rows = await _db.rawQuery('''
      SELECT type, COALESCE(SUM(amount), 0) as total FROM ${Tables.transactions}
      WHERE user_id = ? AND is_deleted = 0 AND transaction_date BETWEEN ? AND ?
      GROUP BY type
    ''', [userId, from.toIso8601String().split('T').first, to.toIso8601String().split('T').first]);

    final result = {CategoryType.income: 0, CategoryType.expense: 0};
    for (final row in rows) {
      result[CategoryTypeX.fromValue(row['type'] as String)] = row['total'] as int;
    }
    return result;
  }

  /// Spending grouped by category for a month — powers the dashboard chart
  /// and budget screens.
  Future<Map<String, int>> getExpenseByCategory(String userId, String yyyyMM) async {
    final rows = await _db.rawQuery('''
      SELECT category_id, COALESCE(SUM(amount), 0) as total FROM ${Tables.transactions}
      WHERE user_id = ? AND is_deleted = 0 AND type = 'EXPENSE'
        AND transaction_date LIKE ?
      GROUP BY category_id
    ''', [userId, '$yyyyMM%']);

    return {for (final row in rows) (row['category_id'] as String? ?? 'uncategorized'): row['total'] as int};
  }
}
