import 'package:sqflite/sqflite.dart';
import '../core/database/db_helper.dart';
import '../core/database/txn_ext.dart';
import '../core/network/api_client.dart';
import 'saving_goal_repository.dart';
import 'saving_streak_repository.dart';
import 'sync_repository.dart';
import 'wallet_repository.dart';

class PullResult {
  int pages = 0;
  int received = 0;
  int cursor = 0;
  bool unauthorized = false;
  bool skippedNoToken = false;
  String? error;

  bool get ok => error == null && !unauthorized;
}

typedef GetJson = Future<Map<String, dynamic>> Function(
    Map<String, dynamic> query);

class SyncPullRepository {
  static const pageSize = 500;
  final SyncRepository _sync;
  final Database _db;
  final GetJson _get;
  bool _running = false;

  SyncPullRepository(this._sync, this._db, this._get);

  Future<void> resetCursor(String userId) => _sync.saveCursor(userId, '0');

  Future<PullResult> pull(String userId) async {
    final result = PullResult();
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
      var cursor = int.tryParse(await _sync.getCursor(userId) ?? '') ?? 0;
      final merged = <String, List<Map<String, dynamic>>>{
        for (final t in syncTableOrder) t: <Map<String, dynamic>>[],
      };

      // Gộp mọi trang vào bộ nhớ, chưa ghi DB và chưa lưu cursor
      while (true) {
        final res = await _get({'cursor': cursor, 'limit': pageSize});
        final changes = (res['changes'] as Map?) ?? const {};
        for (final t in syncTableOrder) {
          for (final item in (changes[t] as List?) ?? const []) {
            merged[t]!.add(Map<String, dynamic>.from(item as Map));
            result.received++;
          }
        }
        result.pages++;
        final next = (res['next_cursor'] as num).toInt();
        final hasMore = res['has_more'] == true;
        // Chống vòng lặp vô hạn nếu server trả cursor không tiến
        if (hasMore && next <= cursor) {
          result.error = 'CURSOR_STUCK';
          return result;
        }
        if (next > cursor) cursor = next;
        if (!hasMore) break;
      }

      // Áp dụng và tính lại giá trị suy ra trong CÙNG một transaction
      await _db.inTxn((e) async {
        await SyncRepository(e).applyPulled(userId, merged);
        await _recomputeDerived(e, userId);
      });

      // Cursor chỉ lưu sau khi transaction commit thành công
      await _sync.saveCursor(userId, '$cursor');
      result.cursor = cursor;
    } on ApiException catch (e) {
      if (e.statusCode == 401 && e.code == 'UNAUTHORIZED') {
        result.unauthorized = true;
      } else {
        result.error = e.code ?? 'HTTP_${e.statusCode}';
      }
    } on NetworkException catch (e) {
      result.error = e.message;
    } catch (e) {
      result.error = '$e';
    } finally {
      _running = false;
    }
    return result;
  }

  Future<void> _recomputeDerived(DatabaseExecutor e, String userId) async {
    final wallets = WalletRepository(e);
    final walletRows = await e.query(Tables.wallets,
        columns: ['id'],
        where: 'user_id = ? AND is_deleted = 0',
        whereArgs: [userId]);
    for (final r in walletRows) {
      await wallets.recomputeBalance(r['id'] as String);
    }

    final goals = SavingGoalRepository(e);
    final goalRows = await e.query(Tables.savingGoals,
        columns: ['id'],
        where: 'user_id = ? AND is_deleted = 0',
        whereArgs: [userId]);
    for (final r in goalRows) {
      await goals.recomputeSavedAmount(r['id'] as String);
    }

    // Streak và XP của pet được tính lại trong cùng hàm này
    await SavingStreakRepository(e).recompute(userId);
  }
}
