import 'package:sqflite/sqflite.dart';
import '../core/database/db_helper.dart';
import '../core/utils/id_generator.dart';
import '../models/sync_queue_item.dart';

/// Implements the sync flow described in the design doc (§4):
/// 1. Every local write also enqueues a row here.
/// 2. When online, [pushPending] POSTs the queue to `/sync/push`.
/// 3. [pull] fetches remote changes since a timestamp via `/sync/pull`.
///
/// Other repositories call [enqueue] after every local write; they never
/// need to know whether the app is online.
class SyncRepository {
  final Database _db;
  SyncRepository(this._db);

  Future<void> enqueue({
    required String tableName,
    required String recordId,
    required SyncAction action,
  }) async {
    final item = SyncQueueItem(
      id: IdGenerator.next(),
      tableName: tableName,
      recordId: recordId,
      action: action,
      isSynced: false,
      createdAt: DateTime.now(),
    );
    await _db.insert(Tables.syncQueue, item.toMap());
  }

  Future<List<SyncQueueItem>> getPending() async {
    final rows = await _db.query(Tables.syncQueue, where: 'is_synced = 0');
    return rows.map(SyncQueueItem.fromMap).toList();
  }

  /// Pushes everything pending to the backend. No-op stub until the Spring
  /// Boot backend exists — safe to call any time (e.g. on connectivity
  /// regained, or a pull-to-refresh) once implemented.
  Future<void> pushPending() async {
    final pending = await getPending();
    if (pending.isEmpty) return;

    // TODO(backend): once Spring Boot is live, uncomment:
    // await ApiClient.instance.post(ApiEndpoints.syncPush, body: {
    //   'items': pending.map((e) => e.toMap()).toList(),
    // });
    // Then mark each as synced:
    // for (final item in pending) {
    //   await _db.update(Tables.syncQueue, {'is_synced': 1},
    //       where: 'id = ?', whereArgs: [item.id]);
    // }
  }

  /// Pulls remote changes since [since] and merges them locally.
  /// TODO(backend): implement once `/sync/pull` exists; apply
  /// Last-Write-Wins by comparing `updated_at` before overwriting local rows.
  Future<void> pull({DateTime? since}) async {
    // final response = await ApiClient.instance.get(
    //   ApiEndpoints.syncPull,
    //   query: {if (since != null) 'since': since.toIso8601String()},
    // );
    // ... merge response into local tables here.
  }
}
