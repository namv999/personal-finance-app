import 'package:sqflite/sqflite.dart';
import '../core/database/db_helper.dart';
import '../core/database/txn_ext.dart';
import '../core/utils/clock.dart';
import '../core/utils/id_generator.dart';
import '../models/saving_goal.dart';
import '../models/sync_queue_item.dart';
import 'sync_repository.dart';
import 'saving_streak_repository.dart';

class SavingGoalRepository {
  final DatabaseExecutor _db;
  SavingGoalRepository(this._db);

  Future<List<SavingGoal>> getAll(String userId) async {
    final rows = await _db.query(Tables.savingGoals,
        where: 'user_id = ? AND is_deleted = 0',
        whereArgs: [userId],
        orderBy: 'updated_at DESC');
    return rows.map(SavingGoal.fromMap).toList();
  }

  Future<SavingGoal?> getById(String id) async {
    final rows =
        await _db.query(Tables.savingGoals, where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : SavingGoal.fromMap(rows.first);
  }

  Future<SavingGoal> create({
    required String userId,
    String? walletId,
    required String goalName,
    required int targetAmount,
    DateTime? expectedCompletionDate,
  }) =>
      _db.inTxn((e) async {
        if (goalName.trim().isEmpty) {
          throw Exception('Tên mục tiêu không được để trống');
        }
        if (targetAmount <= 0) {
          throw Exception('Số tiền mục tiêu phải lớn hơn 0');
        }
        if (walletId != null) await _ensureWalletOwned(e, walletId, userId);
        final goal = SavingGoal(
          id: IdGenerator.next(),
          userId: userId,
          walletId: walletId,
          goalName: goalName.trim(),
          targetAmount: targetAmount,
          expectedCompletionDate: expectedCompletionDate,
          updatedAt: nowUtc(),
        );
        await e.insert(Tables.savingGoals, goal.toMap());
        await SyncRepository(e).enqueue(
            tableName: Tables.savingGoals,
            recordId: goal.id,
            action: SyncAction.create);
        return goal;
      });

  static Future<void> _ensureWalletOwned(
      DatabaseExecutor e, String walletId, String userId) async {
    final rows = await e.query(Tables.wallets,
        columns: ['id'],
        where: 'id = ? AND user_id = ? AND is_deleted = 0',
        whereArgs: [walletId, userId],
        limit: 1);
    if (rows.isEmpty) throw Exception('Ví không hợp lệ');
  }

  Future<void> update(SavingGoal goal) => _db.inTxn((e) async {
        if (goal.goalName.trim().isEmpty) {
          throw Exception('Tên mục tiêu không được để trống');
        }
        if (goal.targetAmount <= 0) {
          throw Exception('Số tiền mục tiêu phải lớn hơn 0');
        }
        final old = await e.query(Tables.savingGoals,
            where: 'id = ? AND user_id = ? AND is_deleted = 0',
            whereArgs: [goal.id, goal.userId],
            limit: 1);
        if (old.isEmpty) throw Exception('Mục tiêu không tồn tại');
        if (goal.walletId != null) {
          await _ensureWalletOwned(e, goal.walletId!, goal.userId);
        }
        if (goal.walletId != old.first['wallet_id']) {
          final count = Sqflite.firstIntValue(await e.rawQuery(
                  'SELECT COUNT(*) FROM ${Tables.transfers} WHERE goal_id = ? AND is_deleted = 0',
                  [goal.id])) ??
              0;
          if (count > 0) {
            throw Exception(
                'Mục tiêu đã có giao dịch chuyển tiền, không thể đổi ví gắn kèm');
          }
        }
        await e.update(
          Tables.savingGoals,
          {
            'goal_name': goal.goalName.trim(),
            'target_amount': goal.targetAmount,
            'wallet_id': goal.walletId,
            'expected_completion_date': goal.expectedCompletionDate == null
                ? null
                : dateOnly(goal.expectedCompletionDate!),
            'updated_at': nowUtcIso(),
          },
          where: 'id = ?',
          whereArgs: [goal.id],
        );
        await SyncRepository(e).enqueue(
            tableName: Tables.savingGoals,
            recordId: goal.id,
            action: SyncAction.update);
        await SavingGoalRepository(e).recomputeSavedAmount(goal.id);
      });

  Future<void> delete(String id) => _db.inTxn((e) async {
        final rows = await e.query(Tables.savingGoals,
            columns: ['user_id'],
            where: 'id = ? AND is_deleted = 0',
            whereArgs: [id],
            limit: 1);
        if (rows.isEmpty) return;
        await e.update(
            Tables.savingGoals, {'is_deleted': 1, 'updated_at': nowUtcIso()},
            where: 'id = ?', whereArgs: [id]);
        await SyncRepository(e).enqueue(
            tableName: Tables.savingGoals,
            recordId: id,
            action: SyncAction.delete);
        await SavingStreakRepository(e)
            .recompute(rows.first['user_id'] as String);
      });

  /// Recomputes `saved_amount` from transfers linked to this goal.
  Future<void> recomputeSavedAmount(String goalId) async {
    final goals = await _db.query(Tables.savingGoals,
        where: 'id = ?', whereArgs: [goalId], limit: 1);
    if (goals.isEmpty) return;
    final walletId = goals.first['wallet_id'] as String?;
    final target = goals.first['target_amount'] as int;
    final status = goals.first['status'] as String? ?? 'IN_PROGRESS';
    final result = walletId == null
        ? await _db.rawQuery(
            'SELECT COALESCE(SUM(amount), 0) AS total FROM ${Tables.transfers} WHERE goal_id = ? AND is_deleted = 0',
            [goalId])
        : await _db.rawQuery('''
            SELECT COALESCE(SUM(CASE WHEN destination_wallet_id = ? THEN amount
                                     WHEN source_wallet_id = ? THEN -amount ELSE 0 END), 0) AS total
            FROM ${Tables.transfers} WHERE goal_id = ? AND is_deleted = 0
          ''', [walletId, walletId, goalId]);
    var saved = (result.first['total'] as int?) ?? 0;
    if (saved < 0) saved = 0;
    var newStatus = status;
    if (status != 'CANCELLED') {
      newStatus = saved >= target ? 'COMPLETED' : 'IN_PROGRESS';
    }
    await _db.update(
        Tables.savingGoals, {'saved_amount': saved, 'status': newStatus},
        where: 'id = ?', whereArgs: [goalId]);
  }
}
