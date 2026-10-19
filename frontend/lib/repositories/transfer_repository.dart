import 'package:sqflite/sqflite.dart';
import '../core/database/db_helper.dart';
import '../core/database/txn_ext.dart';
import '../core/utils/clock.dart';
import '../core/utils/id_generator.dart';
import '../models/sync_queue_item.dart';
import '../models/transfer.dart';
import 'saving_goal_repository.dart';
import 'saving_streak_repository.dart';
import 'sync_repository.dart';
import 'wallet_repository.dart';

class TransferRepository {
  final DatabaseExecutor _db;
  TransferRepository(this._db);

  Future<List<Transfer>> getAll(String userId, {int? limit}) async {
    final rows = await _db.query(Tables.transfers,
        where: 'user_id = ? AND is_deleted = 0',
        whereArgs: [userId],
        orderBy: 'transfer_date DESC, updated_at DESC',
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
    if (amount <= 0) throw Exception('Số tiền phải lớn hơn 0');
    if (sourceWalletId == destinationWalletId) {
      throw Exception('Ví nguồn và ví đích phải khác nhau');
    }
    ensureNotFuture(transferDate);
    return _db.inTxn((e) async {
      final wallets = WalletRepository(e);
      if (await wallets.getOwned(sourceWalletId, userId) == null ||
          await wallets.getOwned(destinationWalletId, userId) == null) {
        throw Exception('Ví không hợp lệ');
      }
      final balance = await wallets.recomputeBalance(sourceWalletId);
      if (balance < amount) throw Exception('Số dư ví nguồn không đủ');

      if (goalId != null) {
        final goals = await e.query(Tables.savingGoals,
            where: 'id = ? AND user_id = ? AND is_deleted = 0',
            whereArgs: [goalId, userId],
            limit: 1);
        if (goals.isEmpty) throw Exception('Mục tiêu không hợp lệ');
        final goalWalletId = goals.first['wallet_id'] as String?;
        final isDeposit = goalWalletId == null || destinationWalletId == goalWalletId;
        final isWithdraw = goalWalletId != null && sourceWalletId == goalWalletId;
        if (!isDeposit && !isWithdraw) {
          throw Exception('Chuyển tiền phải vào hoặc ra khỏi ví của mục tiêu');
        }
        if (isWithdraw) {
          await SavingGoalRepository(e).recomputeSavedAmount(goalId);
          final savedRows = await e.query(Tables.savingGoals,
              columns: ['saved_amount'], where: 'id = ?', whereArgs: [goalId]);
          if (amount > ((savedRows.first['saved_amount'] as int?) ?? 0)) {
            throw Exception('Số tiền rút vượt quá tiến độ mục tiêu');
          }
        }
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
      updatedAt: nowUtc(),
    );
    await e.insert(Tables.transfers, transfer.toMap());
    await SyncRepository(e).enqueue(
        tableName: Tables.transfers,
        recordId: transfer.id,
        action: SyncAction.create);

      await wallets.recomputeBalance(sourceWalletId);
      await wallets.recomputeBalance(destinationWalletId);
      if (goalId != null) {
        await SavingGoalRepository(e).recomputeSavedAmount(goalId);
      }
      await SavingStreakRepository(e).recompute(userId);
      return transfer;
    });
  }

  Future<void> delete(Transfer transfer) => _db.inTxn((e) async {
    final rows = await e.query(Tables.transfers,
        where: 'id = ? AND is_deleted = 0',
        whereArgs: [transfer.id],
        limit: 1);
    if (rows.isEmpty) return;
    final current = Transfer.fromMap(rows.first);
    await e.update(Tables.transfers,
        {'is_deleted': 1, 'updated_at': nowUtcIso()},
        where: 'id = ?', whereArgs: [current.id]);
    await SyncRepository(e).enqueue(
        tableName: Tables.transfers,
        recordId: current.id,
        action: SyncAction.delete);
    final wallets = WalletRepository(e);
    await wallets.recomputeBalance(current.sourceWalletId);
    await wallets.recomputeBalance(current.destinationWalletId);
    if (current.goalId != null) {
      await SavingGoalRepository(e).recomputeSavedAmount(current.goalId!);
    }
    await SavingStreakRepository(e).recompute(current.userId);
  });
}
