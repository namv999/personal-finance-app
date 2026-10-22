import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../core/database/db_helper.dart';
import '../core/database/txn_ext.dart';
import '../core/utils/clock.dart';
import '../core/utils/id_generator.dart';
import '../models/sync_queue_item.dart';

const syncTableOrder = [
  Tables.wallets, Tables.categories, Tables.savingGoals,
  Tables.transactions, Tables.transfers, Tables.monthlyBudgets,
];

const syncColumns = <String, List<String>>{
  Tables.wallets: ['id', 'user_id', 'wallet_name', 'wallet_type', 'opening_balance', 'color', 'icon', 'updated_at', 'is_deleted'],
  Tables.categories: ['id', 'user_id', 'category_name', 'type', 'color', 'icon', 'updated_at', 'is_deleted'],
  Tables.savingGoals: ['id', 'user_id', 'wallet_id', 'goal_name', 'target_amount', 'expected_completion_date', 'status', 'updated_at', 'is_deleted'],
  Tables.transactions: ['id', 'user_id', 'wallet_id', 'category_id', 'type', 'amount', 'note', 'transaction_date', 'source', 'updated_at', 'is_deleted'],
  Tables.transfers: ['id', 'user_id', 'source_wallet_id', 'destination_wallet_id', 'goal_id', 'amount', 'transfer_date', 'note', 'updated_at', 'is_deleted'],
  Tables.monthlyBudgets: ['id', 'user_id', 'category_id', 'month', 'spending_limit', 'updated_at', 'is_deleted'],
};

class SyncBatch {
  final Map<String, List<Map<String, Object?>>> records;
  final Map<String, List<String>> queueIdsByRecord;
  SyncBatch(this.records, this.queueIdsByRecord);
}

DateTime _ts(Object? v) => v == null
    ? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
    : DateTime.parse(v as String);

class SyncRepository {
  final DatabaseExecutor _db;
  SyncRepository(this._db);

  Future<void> enqueue({required String tableName, required String recordId, required SyncAction action}) async {
    await _db.insert(Tables.syncQueue, SyncQueueItem(id: IdGenerator.next(), tableName: tableName, recordId: recordId, action: action, isSynced: false, createdAt: nowUtc()).toMap());
  }

  Future<List<SyncQueueItem>> getPending() async {
    final rows = await _db.query(Tables.syncQueue, where: 'is_synced = 0', orderBy: 'created_at ASC');
    return rows.map(SyncQueueItem.fromMap).toList();
  }

  Future<void> enqueueMany({required String tableName, required Iterable<String> recordIds, required SyncAction action}) async {
    if (recordIds.isEmpty) return;
    final batch = _db.batch();
    for (final id in recordIds) {
      batch.insert(Tables.syncQueue, SyncQueueItem(id: IdGenerator.next(), tableName: tableName, recordId: id, action: action, isSynced: false, createdAt: nowUtc()).toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<SyncBatch> buildPushBatch(String userId) async {
    final queue = await _db.query(Tables.syncQueue, where: 'is_synced = 0');
    final recordIds = <String, Set<String>>{};
    final queueIds = <String, List<String>>{};
    for (final q in queue) {
      final table = q['table_name'] as String;
      if (!syncColumns.containsKey(table)) continue;
      final rid = q['record_id'] as String;
      recordIds.putIfAbsent(table, () => <String>{}).add(rid);
      queueIds.putIfAbsent('$table|$rid', () => []).add(q['id'] as String);
    }
    final records = <String, List<Map<String, Object?>>>{};
    for (final table in syncTableOrder) {
      final ids = (recordIds[table] ?? <String>{}).toList();
      for (var i = 0; i < ids.length; i += 400) {
        final chunk = ids.sublist(i, i + 400 < ids.length ? i + 400 : ids.length);
        final rows = await _db.query(table, columns: syncColumns[table], where: 'user_id = ? AND id IN (${List.filled(chunk.length, '?').join(',')})', whereArgs: [userId, ...chunk]);
        records.putIfAbsent(table, () => []).addAll(rows.map((r) => {...r, 'is_deleted': r['is_deleted'] == 1}));
      }
    }
    return SyncBatch(records, queueIds);
  }

  /// Split pending records into requests of at most [max] records, preserving
  /// table order so parent records are sent before their children.
  List<Map<String, List<Map<String, Object?>>>> splitBatch(SyncBatch batch,
      {int max = 500}) {
    if (max <= 0) throw ArgumentError.value(max, 'max', 'Must be positive');
    final chunks = <Map<String, List<Map<String, Object?>>>>[];
    var current = <String, List<Map<String, Object?>>>{};
    var count = 0;
    for (final table in syncTableOrder) {
      for (final record
          in batch.records[table] ?? const <Map<String, Object?>>[]) {
        if (count == max) {
          chunks.add(current);
          current = <String, List<Map<String, Object?>>>{};
          count = 0;
        }
        current.putIfAbsent(table, () => <Map<String, Object?>>[]).add(record);
        count++;
      }
    }
    if (count > 0) chunks.add(current);
    return chunks;
  }

  Future<void> markSynced(SyncBatch batch, Iterable<String> recordKeys) async {
    final ids = [for (final k in recordKeys) ...?batch.queueIdsByRecord[k]];
    for (var i = 0; i < ids.length; i += 400) {
      final chunk = ids.sublist(i, i + 400 < ids.length ? i + 400 : ids.length);
      await _db.update(Tables.syncQueue, {'is_synced': 1}, where: 'id IN (${List.filled(chunk.length, '?').join(',')})', whereArgs: chunk);
    }
    await _db.delete(Tables.syncQueue, where: 'is_synced = 1');
  }

  Future<String?> getCursor(String userId) async => (await SharedPreferences.getInstance()).getString('sync_cursor_$userId');
  Future<void> saveCursor(String userId, String cursor) async => (await SharedPreferences.getInstance()).setString('sync_cursor_$userId', cursor);

  Future<void> applyPulled(String userId, Map<String, List<Map<String, dynamic>>> changes) => _db.inTxn((e) async {
    await e.execute('PRAGMA defer_foreign_keys = ON');
    for (final table in syncTableOrder) {
      for (final raw in changes[table] ?? const <Map<String, dynamic>>[]) {
        final remote = <String, Object?>{for (final c in syncColumns[table]!) if (raw.containsKey(c)) c: raw[c]};
        if (remote['user_id'] != userId) continue;
        remote['is_deleted'] = (remote['is_deleted'] == true || remote['is_deleted'] == 1) ? 1 : 0;
        final remoteAt = _ts(remote['updated_at']);
        final local = await e.query(table, columns: ['updated_at'], where: 'id = ?', whereArgs: [remote['id']], limit: 1);
        if (local.isNotEmpty && !_ts(local.first['updated_at']).isBefore(remoteAt)) continue;
        if (table == Tables.monthlyBudgets && remote['is_deleted'] == 0) {
          final dup = await e.query(table, columns: ['id', 'updated_at'], where: 'user_id = ? AND category_id = ? AND month = ? AND is_deleted = 0 AND id <> ?', whereArgs: [userId, remote['category_id'], remote['month'], remote['id']], limit: 1);
          if (dup.isNotEmpty) {
            if (_ts(dup.first['updated_at']).isAfter(remoteAt)) {
              remote['is_deleted'] = 1;
            } else {
              final dupId = dup.first['id'] as String;
              await e.update(table, {'is_deleted': 1, 'updated_at': nowUtcIso()}, where: 'id = ?', whereArgs: [dupId]);
              await SyncRepository(e).enqueue(tableName: table, recordId: dupId, action: SyncAction.update);
            }
          }
        }
        if (local.isEmpty) { await e.insert(table, remote); }
        else { await e.update(table, remote, where: 'id = ?', whereArgs: [remote['id']]); }
      }
    }
  });
}
