import '../core/network/api_client.dart';
import 'sync_repository.dart';

class PushRejection {
  final String table;
  final String id;
  final String reason;
  final String? message;

  PushRejection(this.table, this.id, this.reason, this.message);
}

class PushResult {
  int applied = 0;
  int skippedNewer = 0;
  final List<PushRejection> rejected = [];
  bool unauthorized = false;
  bool skippedNoToken = false;
  String? error;

  bool get ok => error == null && !unauthorized;
}

typedef PostJson = Future<Map<String, dynamic>> Function(
    Map<String, dynamic> body);

class SyncPushRepository {
  final SyncRepository _sync;
  final PostJson _post;
  bool _running = false;

  SyncPushRepository(this._sync, this._post);

  Future<PushResult> push(String userId) async {
    final result = PushResult();
    if (_running) {
      result.error = 'BUSY';
      return result;
    }
    if (!ApiClient.instance.hasToken) {
      result.skippedNoToken = true;
      return result;
    }

    _running = true;
    try {
      final batch = await _sync.buildPushBatch(userId);
      for (final chunk in _sync.splitBatch(batch)) {
        final body = {
          'records': {for (final table in syncTableOrder) table: chunk[table] ?? const []},
        };
        final Map<String, dynamic> response;
        try {
          response = await _post(body);
        } on ApiException catch (e) {
          if (e.statusCode == 401 && e.code == 'UNAUTHORIZED') {
            result.unauthorized = true;
          } else {
            result.error = e.code ?? 'HTTP_${e.statusCode}';
          }
          break;
        } on NetworkException catch (e) {
          result.error = e.message;
          break;
        }

        final synced = <String>[];
        final results = (response['results'] as List).cast<Map>();
        for (final raw in results) {
          final record = Map<String, dynamic>.from(raw);
          final table = '${record['table']}';
          final id = '${record['id']}';
          final key = '$table|$id';
          switch (record['status']) {
            case 'APPLIED':
              result.applied++;
              synced.add(key);
              break;
            case 'SKIPPED_NEWER':
              result.skippedNewer++;
              synced.add(key);
              break;
            default:
              result.rejected.add(PushRejection(
                  table,
                  id,
                  '${record['reason']}',
                  record['message'] as String?));
              break;
          }
        }
        // Persist progress after every successful chunk. If a later chunk
        // fails, its parents have already been sent before its children.
        await _sync.markSynced(batch, synced);
      }
    } finally {
      _running = false;
    }
    return result;
  }
}
