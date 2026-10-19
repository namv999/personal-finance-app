import 'package:sqflite/sqflite.dart';
import '../core/database/db_helper.dart';
import '../core/database/txn_ext.dart';
import '../core/utils/clock.dart';
import '../core/utils/id_generator.dart';
import '../models/monthly_budget.dart';
import '../models/sync_queue_item.dart';
import 'sync_repository.dart';

class BudgetRepository {
  final DatabaseExecutor _db;
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
    if (spendingLimit <= 0) throw Exception('Hạn mức phải lớn hơn 0');
    if (!RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(month)) {
      throw Exception('Tháng không hợp lệ');
    }
    return _db.inTxn((e) async {
      final categories = await e.query(Tables.categories,
          columns: ['type'],
          where:
              'id = ? AND is_deleted = 0 AND (user_id IS NULL OR user_id = ?)',
          whereArgs: [categoryId, userId],
          limit: 1);
      if (categories.isEmpty) throw Exception('Danh mục không hợp lệ');
      if (categories.first['type'] != 'EXPENSE') {
        throw Exception('Chỉ đặt ngân sách cho danh mục chi tiêu');
      }
      final holders = await e.query(Tables.monthlyBudgets,
          columns: ['id'],
          where:
              'user_id = ? AND category_id = ? AND month = ? AND is_deleted = 0',
          whereArgs: [userId, categoryId, month],
          limit: 1);
      final holderId = holders.isEmpty ? null : holders.first['id'] as String;
      if (id != null && holderId != null && holderId != id) {
        throw Exception('Danh mục này đã có ngân sách trong tháng đó');
      }
      final existingId = id ?? holderId;
      final budgetId = existingId ?? IdGenerator.next();
      final now = nowUtcIso();
      if (existingId == null) {
        await e.insert(Tables.monthlyBudgets, {
          'id': budgetId,
          'user_id': userId,
          'category_id': categoryId,
          'month': month,
          'spending_limit': spendingLimit,
          'updated_at': now,
          'is_deleted': 0,
        });
        await SyncRepository(e).enqueue(
            tableName: Tables.monthlyBudgets,
            recordId: budgetId,
            action: SyncAction.create);
      } else {
        final count = await e.update(
          Tables.monthlyBudgets,
          {
            'category_id': categoryId,
            'month': month,
            'spending_limit': spendingLimit,
            'updated_at': now,
          },
          where: 'id = ? AND user_id = ? AND is_deleted = 0',
          whereArgs: [existingId, userId],
        );
        if (count == 0) throw Exception('Ngân sách không tồn tại');
        await SyncRepository(e).enqueue(
            tableName: Tables.monthlyBudgets,
            recordId: budgetId,
            action: SyncAction.update);
      }
      return MonthlyBudget(
        id: budgetId,
        userId: userId,
        categoryId: categoryId,
        month: month,
        spendingLimit: spendingLimit,
        updatedAt: DateTime.parse(now),
      );
    });
  }

  Future<void> delete(String id) => _db.inTxn((e) async {
        final count = await e.update(
          Tables.monthlyBudgets,
          {'is_deleted': 1, 'updated_at': nowUtcIso()},
          where: 'id = ? AND is_deleted = 0',
          whereArgs: [id],
        );
        if (count > 0) {
          await SyncRepository(e).enqueue(
              tableName: Tables.monthlyBudgets,
              recordId: id,
              action: SyncAction.delete);
        }
      });
}
