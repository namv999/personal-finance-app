import 'package:sqflite/sqflite.dart';
import '../core/database/db_helper.dart';
import '../core/utils/id_generator.dart';
import '../models/sync_queue_item.dart';
import '../models/transfer.dart';
import 'saving_goal_repository.dart';
import 'saving_streak_repository.dart';
import 'sync_repository.dart';
import 'wallet_repository.dart';

class TransferRepository {
  final Database _db;
  late final SyncRepository _sync = SyncRepository(_db);
  late final WalletRepository _wallets = WalletRepository(_db);
  late final SavingGoalRepository _goals = SavingGoalRepository(_db);
  late final SavingStreakRepository _streaks = SavingStreakRepository(_db);
  TransferRepository(this._db);

  Future<List<Transfer>> getAll(String userId, {int? limit}) async {
    final rows = await _db.query(Tables.transfers,
        where: 'user_id = ? AND is_deleted = 0',
        whereArgs: [userId],
        orderBy: 'transfer_date DESC',
        limit: limit);
    return rows.map(Transfer.fromMap).toList();
  }

  Future<Transfer> create({
    required String userId,
    required String sourceWalletId,
    required String destinationWalletId,
    String? goalId,
    required int amount,
    required DateTime transferDate,
    String? note,
  }) async {
    if (sourceWalletId == destinationWalletId) {
      throw Exception('Ví nguồn và ví đích phải khác nhau');
    }
    final transfer = Transfer(
      id: IdGenerator.next(),
      userId: userId,
      sourceWalletId: sourceWalletId,
      destinationWalletId: destinationWalletId,
      goalId: goalId,
      amount: amount,
      transferDate: transferDate,
      note: note,
      updatedAt: DateTime.now(),
    );
    await _db.insert(Tables.transfers, transfer.toMap());
    await _sync.enqueue(tableName: Tables.transfers, recordId: transfer.id, action: SyncAction.create);

    await _wallets.recomputeBalance(sourceWalletId);
    await _wallets.recomputeBalance(destinationWalletId);
    if (goalId != null) await _goals.recomputeSavedAmount(goalId);

    // Transferring money into a savings wallet counts as "saving today".
    await _streaks.markSavedToday(userId);

    return transfer;
  }

  Future<void> delete(Transfer transfer) async {
    await _db.update(Tables.transfers, {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [transfer.id]);
    await _sync.enqueue(tableName: Tables.transfers, recordId: transfer.id, action: SyncAction.delete);
    await _wallets.recomputeBalance(transfer.sourceWalletId);
    await _wallets.recomputeBalance(transfer.destinationWalletId);
    if (transfer.goalId != null) await _goals.recomputeSavedAmount(transfer.goalId!);
  }
}
