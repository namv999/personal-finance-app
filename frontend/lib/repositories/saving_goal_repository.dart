import 'package:sqflite/sqflite.dart';
import '../core/database/db_helper.dart';
import '../core/utils/id_generator.dart';
import '../models/saving_goal.dart';
import '../models/sync_queue_item.dart';
import 'sync_repository.dart';

class SavingGoalRepository {
  final Database _db;
  late final SyncRepository _sync = SyncRepository(_db);
  SavingGoalRepository(this._db);

  Future<List<SavingGoal>> getAll(String userId) async {
    final rows = await _db.query(Tables.savingGoals,
        where: 'user_id = ? AND is_deleted = 0', whereArgs: [userId], orderBy: 'updated_at DESC');
    return rows.map(SavingGoal.fromMap).toList();
  }

  Future<SavingGoal?> getById(String id) async {
    final rows = await _db.query(Tables.savingGoals, where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : SavingGoal.fromMap(rows.first);
  }

  Future<SavingGoal> create({
    required String userId,
    String? walletId,
    required String goalName,
    required int targetAmount,
    DateTime? expectedCompletionDate,
  }) async {
    final goal = SavingGoal(
      id: IdGenerator.next(),
      userId: userId,
      walletId: walletId,
      goalName: goalName,
      targetAmount: targetAmount,
      expectedCompletionDate: expectedCompletionDate,
      updatedAt: DateTime.now(),
    );
    await _db.insert(Tables.savingGoals, goal.toMap());
    await _sync.enqueue(tableName: Tables.savingGoals, recordId: goal.id, action: SyncAction.create);
    return goal;
  }

  Future<void> update(SavingGoal goal) async {
    await _db.update(Tables.savingGoals, goal.toMap(), where: 'id = ?', whereArgs: [goal.id]);
    await _sync.enqueue(tableName: Tables.savingGoals, recordId: goal.id, action: SyncAction.update);
  }

  Future<void> delete(String id) async {
    await _db.update(Tables.savingGoals, {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [id]);
    await _sync.enqueue(tableName: Tables.savingGoals, recordId: id, action: SyncAction.delete);
  }

  /// Recomputes `saved_amount` from transfers linked to this goal.
  Future<void> recomputeSavedAmount(String goalId) async {
    final result = await _db.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) as total FROM ${Tables.transfers}
      WHERE goal_id = ? AND is_deleted = 0
    ''', [goalId]);
    final saved = (result.first['total'] as int?) ?? 0;

    final goal = await getById(goalId);
    String status = goal?.status.value ?? 'IN_PROGRESS';
    if (goal != null && saved >= goal.targetAmount) status = 'COMPLETED';

    await _db.update(
      Tables.savingGoals,
      {'saved_amount': saved, 'status': status, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [goalId],
    );
  }
}
