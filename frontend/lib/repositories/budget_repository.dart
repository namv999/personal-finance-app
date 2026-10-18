import 'package:sqflite/sqflite.dart';
import '../core/database/db_helper.dart';
import '../core/utils/id_generator.dart';
import '../models/monthly_budget.dart';
import '../models/sync_queue_item.dart';
import 'sync_repository.dart';

class BudgetRepository {
  final Database _db;
  late final SyncRepository _sync = SyncRepository(_db);
  BudgetRepository(this._db);

  Future<List<MonthlyBudget>> getForMonth(String userId, String yyyyMM) async {
    final rows = await _db.query(Tables.monthlyBudgets,
        where: 'user_id = ? AND month = ? AND is_deleted = 0',
        whereArgs: [userId, yyyyMM]);
    return rows.map(MonthlyBudget.fromMap).toList();
  }

  Future<MonthlyBudget> upsert({
    String? id,
    required String userId,
    required String categoryId,
    required String month,
    required int spendingLimit,
  }) async {
    // A category can have only one active budget per month. Update it when
    // the user submits that category again instead of creating a duplicate.
    if (id == null) {
      final existing = await _db.query(
        Tables.monthlyBudgets,
        columns: ['id'],
        where: 'user_id = ? AND category_id = ? AND month = ? AND is_deleted = 0',
        whereArgs: [userId, categoryId, month],
        limit: 1,
      );
      if (existing.isNotEmpty) id = existing.first['id'] as String;
    }
    final budget = MonthlyBudget(
      id: id ?? IdGenerator.next(),
      userId: userId,
      categoryId: categoryId,
      month: month,
      spendingLimit: spendingLimit,
      updatedAt: DateTime.now(),
    );
    if (id == null) {
      await _db.insert(Tables.monthlyBudgets, budget.toMap());
      await _sync.enqueue(tableName: Tables.monthlyBudgets, recordId: budget.id, action: SyncAction.create);
    } else {
      await _db.update(Tables.monthlyBudgets, budget.toMap(), where: 'id = ?', whereArgs: [id]);
      await _sync.enqueue(tableName: Tables.monthlyBudgets, recordId: budget.id, action: SyncAction.update);
    }
    return budget;
  }

  Future<void> delete(String id) async {
    await _db.update(Tables.monthlyBudgets, {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [id]);
    await _sync.enqueue(tableName: Tables.monthlyBudgets, recordId: id, action: SyncAction.delete);
  }
}
