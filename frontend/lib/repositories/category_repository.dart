import 'package:sqflite/sqflite.dart';
import '../core/database/db_helper.dart';
import '../core/database/txn_ext.dart';
import '../core/utils/clock.dart';
import '../core/utils/id_generator.dart';
import '../models/category.dart';
import '../models/sync_queue_item.dart';
import 'sync_repository.dart';

class CategoryRepository {
  final DatabaseExecutor _db;
  CategoryRepository(this._db);

  /// Returns system default categories (user_id NULL) plus this user's own.
  Future<List<TransactionCategory>> getAll(String userId,
      {CategoryType? type}) async {
    final where =
        StringBuffer('(user_id IS NULL OR user_id = ?) AND is_deleted = 0');
    final args = <dynamic>[userId];
    if (type != null) {
      where.write(' AND type = ?');
      args.add(type.value);
    }
    final rows = await _db.query(Tables.categories,
        where: where.toString(), whereArgs: args, orderBy: 'category_name');
    return rows.map(TransactionCategory.fromMap).toList();
  }

  /// Active and deleted categories, for displaying historical transactions.
  Future<List<TransactionCategory>> getAllForDisplay(String userId) async {
    final rows = await _db.query(
      Tables.categories,
      where: '(user_id IS NULL OR user_id = ?)',
      whereArgs: [userId],
      orderBy: 'category_name',
    );
    return rows.map(TransactionCategory.fromMap).toList();
  }

  Future<TransactionCategory?> getById(String id) async {
    final rows =
        await _db.query(Tables.categories, where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : TransactionCategory.fromMap(rows.first);
  }

  Future<TransactionCategory> create({
    required String userId,
    required String categoryName,
    required CategoryType type,
    String? color,
    String? icon,
  }) async {
    if (categoryName.trim().isEmpty) {
      throw Exception('Tên danh mục không được để trống');
    }
    return _db.inTxn((e) async {
      final category = TransactionCategory(
        id: IdGenerator.next(),
        userId: userId,
        categoryName: categoryName.trim(),
        type: type,
        color: color,
        icon: icon,
        updatedAt: nowUtc(),
      );
      await e.insert(Tables.categories, category.toMap());
      await SyncRepository(e).enqueue(
          tableName: Tables.categories,
          recordId: category.id,
          action: SyncAction.create);
      return category;
    });
  }

  Future<void> update(TransactionCategory category) => _db.inTxn((e) async {
        if (category.categoryName.trim().isEmpty) {
          throw Exception('Tên danh mục không được để trống');
        }
        final old = await e.query(Tables.categories,
            where: 'id = ? AND user_id = ? AND is_deleted = 0',
            whereArgs: [category.id, category.userId],
            limit: 1);
        if (old.isEmpty) throw Exception('Không thể sửa danh mục này');
        if (old.first['type'] != category.type.value) {
          final transactions = Sqflite.firstIntValue(await e.rawQuery(
                  'SELECT COUNT(*) FROM ${Tables.transactions} WHERE category_id = ? AND is_deleted = 0',
                  [category.id])) ??
              0;
          final budgets = Sqflite.firstIntValue(await e.rawQuery(
                  'SELECT COUNT(*) FROM ${Tables.monthlyBudgets} WHERE category_id = ? AND is_deleted = 0',
                  [category.id])) ??
              0;
          if (transactions + budgets > 0) {
            throw Exception('Danh mục đã có dữ liệu, không thể đổi loại');
          }
        }
        await e.update(
            Tables.categories,
            {
              'category_name': category.categoryName.trim(),
              'type': category.type.value,
              'color': category.color,
              'icon': category.icon,
              'updated_at': nowUtcIso(),
            },
            where: 'id = ?',
            whereArgs: [category.id]);
        await SyncRepository(e).enqueue(
            tableName: Tables.categories,
            recordId: category.id,
            action: SyncAction.update);
      });

  Future<void> delete(String id) => _db.inTxn((e) async {
        final rows = await e.query(Tables.categories,
            where: 'id = ? AND is_deleted = 0', whereArgs: [id], limit: 1);
        if (rows.isEmpty) return;
        if (rows.first['user_id'] == null) {
          throw Exception('Không thể xóa danh mục hệ thống');
        }
        final now = nowUtcIso();
        final budgetIds = (await e.query(Tables.monthlyBudgets,
                columns: ['id'],
                where: 'category_id = ? AND is_deleted = 0',
                whereArgs: [id]))
            .map((r) => r['id'] as String)
            .toList();
        await e.update(
            Tables.monthlyBudgets, {'is_deleted': 1, 'updated_at': now},
            where: 'category_id = ? AND is_deleted = 0', whereArgs: [id]);
        await e.update(Tables.categories, {'is_deleted': 1, 'updated_at': now},
            where: 'id = ?', whereArgs: [id]);
        final sync = SyncRepository(e);
        await sync.enqueueMany(
            tableName: Tables.monthlyBudgets,
            recordIds: budgetIds,
            action: SyncAction.delete);
        await sync.enqueueMany(
            tableName: Tables.categories,
            recordIds: [id],
            action: SyncAction.delete);
      });
}
