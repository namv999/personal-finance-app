import 'package:sqflite/sqflite.dart';
import '../core/database/db_helper.dart';
import '../core/database/txn_ext.dart';
import '../core/utils/clock.dart';
import '../core/utils/id_generator.dart';
import '../models/sync_queue_item.dart';
import '../models/wallet.dart';
import 'sync_repository.dart';
import 'saving_goal_repository.dart';
import 'saving_streak_repository.dart';

class WalletRepository {
  final DatabaseExecutor _db;
  WalletRepository(this._db);

  Future<List<Wallet>> getAll(String userId) async {
    final rows = await _db.query(Tables.wallets,
        where: 'user_id = ? AND is_deleted = 0',
        whereArgs: [userId],
        orderBy: 'wallet_name');
    return rows.map(Wallet.fromMap).toList();
  }

  Future<Wallet?> getById(String id) async {
    final rows =
        await _db.query(Tables.wallets, where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : Wallet.fromMap(rows.first);
  }

  Future<Wallet?> getOwned(String id, String userId) async {
    final rows = await _db.query(Tables.wallets,
        where: 'id = ? AND user_id = ? AND is_deleted = 0',
        whereArgs: [id, userId]);
    return rows.isEmpty ? null : Wallet.fromMap(rows.first);
  }

  Future<Wallet> create({
    required String userId,
    required String walletName,
    required String walletType,
    int initialBalance = 0,
    String? color,
    String? icon,
  }) => _db.inTxn((e) async {
    if (walletName.trim().isEmpty) {
      throw Exception('Tên ví không được để trống');
    }
    final wallet = Wallet(
      id: IdGenerator.next(),
      userId: userId,
      walletName: walletName.trim(),
      walletType: walletType,
      currentBalance: initialBalance,
      openingBalance: initialBalance,
      color: color,
      icon: icon,
      updatedAt: nowUtc(),
    );
    await e.insert(Tables.wallets, wallet.toMap());
    await SyncRepository(e).enqueue(
        tableName: Tables.wallets,
        recordId: wallet.id,
        action: SyncAction.create);
    return wallet;
  });

  Future<void> update(Wallet wallet) => _db.inTxn((e) async {
    final n = await e.update(
      Tables.wallets,
      {
        'wallet_name': wallet.walletName.trim(),
        'wallet_type': wallet.walletType,
        'opening_balance': wallet.openingBalance,
        'color': wallet.color,
        'icon': wallet.icon,
        'updated_at': nowUtcIso(),
      },
      where: 'id = ? AND user_id = ? AND is_deleted = 0',
      whereArgs: [wallet.id, wallet.userId],
    );
    if (n == 0) throw Exception('Ví không tồn tại');
    await SyncRepository(e).enqueue(
        tableName: Tables.wallets,
        recordId: wallet.id,
        action: SyncAction.update);
    await WalletRepository(e).recomputeBalance(wallet.id);
  });

  /// Soft delete, per design doc (hard delete would break sync tracking).
  Future<void> delete(String id) => _db.inTxn((e) async {
        final rows = await e.query(Tables.wallets,
            where: 'id = ? AND is_deleted = 0', whereArgs: [id], limit: 1);
        if (rows.isEmpty) return;
        final userId = rows.first['user_id'] as String;
        final del = {'is_deleted': 1, 'updated_at': nowUtcIso()};
        final txIds = (await e.query(Tables.transactions,
                columns: ['id'],
                where: 'wallet_id = ? AND is_deleted = 0',
                whereArgs: [id]))
            .map((r) => r['id'] as String)
            .toList();
        final tfRows = await e.query(Tables.transfers,
            columns: ['id', 'source_wallet_id', 'destination_wallet_id', 'goal_id'],
            where:
                'is_deleted = 0 AND (source_wallet_id = ? OR destination_wallet_id = ?)',
            whereArgs: [id, id]);
        final goalIds = (await e.query(Tables.savingGoals,
                columns: ['id'],
                where: 'wallet_id = ? AND is_deleted = 0',
                whereArgs: [id]))
            .map((r) => r['id'] as String)
            .toList();
        await e.update(Tables.transactions, del,
            where: 'wallet_id = ? AND is_deleted = 0', whereArgs: [id]);
        await e.update(Tables.transfers, del,
            where:
                'is_deleted = 0 AND (source_wallet_id = ? OR destination_wallet_id = ?)',
            whereArgs: [id, id]);
        await e.update(Tables.savingGoals, del,
            where: 'wallet_id = ? AND is_deleted = 0', whereArgs: [id]);
        await e.update(Tables.wallets, del, where: 'id = ?', whereArgs: [id]);

        final sync = SyncRepository(e);
        await sync.enqueueMany(
            tableName: Tables.transactions,
            recordIds: txIds,
            action: SyncAction.delete);
        await sync.enqueueMany(
            tableName: Tables.transfers,
            recordIds: tfRows.map((r) => r['id'] as String),
            action: SyncAction.delete);
        await sync.enqueueMany(
            tableName: Tables.savingGoals,
            recordIds: goalIds,
            action: SyncAction.delete);
        await sync.enqueueMany(
            tableName: Tables.wallets,
            recordIds: [id],
            action: SyncAction.delete);

        final others = <String>{};
        final goals = <String>{};
        for (final t in tfRows) {
          others
            ..add(t['source_wallet_id'] as String)
            ..add(t['destination_wallet_id'] as String);
          final goalId = t['goal_id'] as String?;
          if (goalId != null && !goalIds.contains(goalId)) goals.add(goalId);
        }
        others.remove(id);
        final wallets = WalletRepository(e);
        for (final walletId in others) {
          await wallets.recomputeBalance(walletId);
        }
        final goalRepo = SavingGoalRepository(e);
        for (final goalId in goals) {
          await goalRepo.recomputeSavedAmount(goalId);
        }
        await SavingStreakRepository(e).recompute(userId);
      });

  /// Recomputes `current_balance` from transactions + transfers, as the
  /// design doc recommends, instead of incrementing/decrementing ad hoc.
  Future<int> recomputeBalance(String walletId) async {
    await _db.rawUpdate('''
      UPDATE ${Tables.wallets} SET current_balance = opening_balance
        + COALESCE((SELECT SUM(amount) FROM ${Tables.transactions}
            WHERE wallet_id = ? AND type = 'INCOME' AND is_deleted = 0), 0)
        - COALESCE((SELECT SUM(amount) FROM ${Tables.transactions}
            WHERE wallet_id = ? AND type = 'EXPENSE' AND is_deleted = 0), 0)
        - COALESCE((SELECT SUM(amount) FROM ${Tables.transfers}
            WHERE source_wallet_id = ? AND is_deleted = 0), 0)
        + COALESCE((SELECT SUM(amount) FROM ${Tables.transfers}
            WHERE destination_wallet_id = ? AND is_deleted = 0), 0)
      WHERE id = ?
    ''', [walletId, walletId, walletId, walletId, walletId]);
    final rows = await _db.query(Tables.wallets,
        columns: ['current_balance'], where: 'id = ?', whereArgs: [walletId]);
    return rows.isEmpty ? 0 : (rows.first['current_balance'] as int?) ?? 0;
  }

  Future<WalletDeletePreview> previewDelete(String walletId) async {
    final tx = await _db.rawQuery('''
      SELECT type, COUNT(*) AS c, COALESCE(SUM(amount), 0) AS s
      FROM ${Tables.transactions} WHERE wallet_id = ? AND is_deleted = 0 GROUP BY type
    ''', [walletId]);
    var txCount = 0, income = 0, expense = 0;
    for (final row in tx) {
      txCount += row['c'] as int;
      if (row['type'] == 'INCOME') {
        income = row['s'] as int;
      } else {
        expense = row['s'] as int;
      }
    }
    final transferCount = Sqflite.firstIntValue(await _db.rawQuery('''
      SELECT COUNT(*) FROM ${Tables.transfers}
      WHERE is_deleted = 0 AND (source_wallet_id = ? OR destination_wallet_id = ?)
    ''', [walletId, walletId])) ?? 0;
    final counterparts = await _db.rawQuery('''
      SELECT w.id AS id, w.wallet_name AS name,
        SUM(CASE WHEN t.destination_wallet_id = w.id THEN -t.amount ELSE t.amount END) AS delta
      FROM ${Tables.transfers} t
      JOIN ${Tables.wallets} w ON w.is_deleted = 0 AND w.id =
        CASE WHEN t.source_wallet_id = ? THEN t.destination_wallet_id ELSE t.source_wallet_id END
      WHERE t.is_deleted = 0 AND (t.source_wallet_id = ? OR t.destination_wallet_id = ?)
      GROUP BY w.id, w.wallet_name
    ''', [walletId, walletId, walletId]);
    final deletedGoals = await _db.rawQuery(
        'SELECT goal_name FROM ${Tables.savingGoals} WHERE wallet_id = ? AND is_deleted = 0',
        [walletId]);
    final affectedGoals = await _db.rawQuery('''
      SELECT DISTINCT g.goal_name FROM ${Tables.transfers} t
      JOIN ${Tables.savingGoals} g ON g.id = t.goal_id AND g.is_deleted = 0
      WHERE t.is_deleted = 0 AND (t.source_wallet_id = ? OR t.destination_wallet_id = ?)
        AND (g.wallet_id IS NULL OR g.wallet_id <> ?)
    ''', [walletId, walletId, walletId]);
    return WalletDeletePreview(
      transactionCount: txCount,
      incomeTotal: income,
      expenseTotal: expense,
      transferCount: transferCount,
      counterparts: counterparts
          .map((r) => WalletDeleteImpact(
                walletId: r['id'] as String,
                walletName: r['name'] as String,
                balanceDelta: r['delta'] as int,
              ))
          .toList(),
      deletedGoals: deletedGoals.map((r) => r['goal_name'] as String).toList(),
      affectedGoals: affectedGoals.map((r) => r['goal_name'] as String).toList(),
    );
  }

  Future<int> getTotalBalance(String userId) async {
    final result = await _db.rawQuery('''
      SELECT COALESCE(SUM(current_balance), 0) as total FROM ${Tables.wallets}
      WHERE user_id = ? AND is_deleted = 0
    ''', [userId]);
    return (result.first['total'] as int?) ?? 0;
  }
}

class WalletDeleteImpact {
  final String walletId;
  final String walletName;
  final int balanceDelta;
  const WalletDeleteImpact({
    required this.walletId,
    required this.walletName,
    required this.balanceDelta,
  });
}

class WalletDeletePreview {
  final int transactionCount;
  final int incomeTotal;
  final int expenseTotal;
  final int transferCount;
  final List<WalletDeleteImpact> counterparts;
  final List<String> deletedGoals;
  final List<String> affectedGoals;

  const WalletDeletePreview({
    required this.transactionCount,
    required this.incomeTotal,
    required this.expenseTotal,
    required this.transferCount,
    required this.counterparts,
    required this.deletedGoals,
    required this.affectedGoals,
  });
}
