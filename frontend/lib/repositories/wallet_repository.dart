import 'package:sqflite/sqflite.dart';
import '../core/database/db_helper.dart';
import '../core/utils/id_generator.dart';
import '../models/sync_queue_item.dart';
import '../models/wallet.dart';
import 'sync_repository.dart';

class WalletRepository {
  final Database _db;
  late final SyncRepository _sync = SyncRepository(_db);
  WalletRepository(this._db);

  Future<List<Wallet>> getAll(String userId) async {
    final rows = await _db.query(Tables.wallets,
        where: 'user_id = ? AND is_deleted = 0', whereArgs: [userId], orderBy: 'wallet_name');
    return rows.map(Wallet.fromMap).toList();
  }

  Future<Wallet?> getById(String id) async {
    final rows = await _db.query(Tables.wallets, where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Wallet.fromMap(rows.first);
  }

  Future<Wallet> create({
    required String userId,
    required String walletName,
    required String walletType,
    int initialBalance = 0,
    String? color,
    String? icon,
  }) async {
    final wallet = Wallet(
      id: IdGenerator.next(),
      userId: userId,
      walletName: walletName,
      walletType: walletType,
      currentBalance: initialBalance,
      color: color,
      icon: icon,
      updatedAt: DateTime.now(),
    );
    await _db.insert(Tables.wallets, wallet.toMap());
    await _sync.enqueue(tableName: Tables.wallets, recordId: wallet.id, action: SyncAction.create);
    return wallet;
  }

  Future<void> update(Wallet wallet) async {
    await _db.update(Tables.wallets, wallet.toMap(), where: 'id = ?', whereArgs: [wallet.id]);
    await _sync.enqueue(tableName: Tables.wallets, recordId: wallet.id, action: SyncAction.update);
  }

  /// Soft delete, per design doc (hard delete would break sync tracking).
  Future<void> delete(String id) async {
    await _db.update(Tables.wallets, {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [id]);
    await _sync.enqueue(tableName: Tables.wallets, recordId: id, action: SyncAction.delete);
  }

  /// Recomputes `current_balance` from transactions + transfers, as the
  /// design doc recommends, instead of incrementing/decrementing ad hoc.
  Future<int> recomputeBalance(String walletId) async {
    final incomeResult = await _db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total FROM ${Tables.transactions}
      WHERE wallet_id = ? AND type = 'INCOME' AND is_deleted = 0
    ''', [walletId]);
    final expenseResult = await _db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total FROM ${Tables.transactions}
      WHERE wallet_id = ? AND type = 'EXPENSE' AND is_deleted = 0
    ''', [walletId]);
    final transferOutResult = await _db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total FROM ${Tables.transfers}
      WHERE source_wallet_id = ? AND is_deleted = 0
    ''', [walletId]);
    final transferInResult = await _db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total FROM ${Tables.transfers}
      WHERE destination_wallet_id = ? AND is_deleted = 0
    ''', [walletId]);

    final income = (incomeResult.first['total'] as int?) ?? 0;
    final expense = (expenseResult.first['total'] as int?) ?? 0;
    final transferOut = (transferOutResult.first['total'] as int?) ?? 0;
    final transferIn = (transferInResult.first['total'] as int?) ?? 0;

    final balance = income - expense - transferOut + transferIn;
    await _db.update(Tables.wallets, {'current_balance': balance, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [walletId]);
    return balance;
  }

  Future<int> getTotalBalance(String userId) async {
    final result = await _db.rawQuery('''
      SELECT COALESCE(SUM(current_balance), 0) as total FROM ${Tables.wallets}
      WHERE user_id = ? AND is_deleted = 0
    ''', [userId]);
    return (result.first['total'] as int?) ?? 0;
  }
}
