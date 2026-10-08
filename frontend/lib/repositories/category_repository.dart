import 'package:sqflite/sqflite.dart';
import '../core/database/db_helper.dart';
import '../core/utils/id_generator.dart';
import '../models/category.dart';
import '../models/sync_queue_item.dart';
import 'sync_repository.dart';

class CategoryRepository {
  final Database _db;
  late final SyncRepository _sync = SyncRepository(_db);
  CategoryRepository(this._db);

  /// Returns system default categories (user_id NULL) plus this user's own.
  Future<List<TransactionCategory>> getAll(String userId, {CategoryType? type}) async {
    final where = StringBuffer('(user_id IS NULL OR user_id = ?) AND is_deleted = 0');
    final args = <dynamic>[userId];
    if (type != null) {
      where.write(' AND type = ?');
      args.add(type.value);
    }
    final rows = await _db.query(Tables.categories,
        where: where.toString(), whereArgs: args, orderBy: 'category_name');
    return rows.map(TransactionCategory.fromMap).toList();
  }

  Future<TransactionCategory?> getById(String id) async {
    final rows = await _db.query(Tables.categories, where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : TransactionCategory.fromMap(rows.first);
  }

  Future<TransactionCategory> create({
    required String userId,
    required String categoryName,
    required CategoryType type,
    String? color,
    String? icon,
  }) async {
    final category = TransactionCategory(
      id: IdGenerator.next(),
      userId: userId,
      categoryName: categoryName,
      type: type,
      color: color,
      icon: icon,
      updatedAt: DateTime.now(),
    );
    await _db.insert(Tables.categories, category.toMap());
    await _sync.enqueue(tableName: Tables.categories, recordId: category.id, action: SyncAction.create);
    return category;
  }

  Future<void> update(TransactionCategory category) async {
    await _db.update(Tables.categories, category.toMap(), where: 'id = ?', whereArgs: [category.id]);
    await _sync.enqueue(tableName: Tables.categories, recordId: category.id, action: SyncAction.update);
  }

  Future<void> delete(String id) async {
    await _db.update(Tables.categories, {'is_deleted': 1, 'updated_at': DateTime.now().toIso8601String()},
        where: 'id = ?', whereArgs: [id]);
    await _sync.enqueue(tableName: Tables.categories, recordId: id, action: SyncAction.delete);
  }
}
