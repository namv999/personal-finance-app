import 'sync_pull_repository.dart';
import 'sync_push_repository.dart';

class SyncOutcome {
  PushResult? push;
  PullResult? pull;
  String? error;
  bool unauthorized = false;
  bool get ok => error == null && !unauthorized;
}

class SyncService {
  final SyncPushRepository _push;
  final SyncPullRepository _pull;
  bool _running = false;
  SyncService(this._push, this._pull);

  /// Thứ tự cố định: push (đã xử lý REJECTED) -> pull
  Future<SyncOutcome> syncAll(String userId) async {
    final out = SyncOutcome();
    if (_running) {
      out.error = 'BUSY';
      return out;
    }
    _running = true;
    try {
      var push = await _push.push(userId);
      // FUTURE_DATE đã được sửa và enqueue lại, gửi thêm 1 lượt
      if (push.ok &&
          !push.skippedNoToken &&
          push.rejected.any((r) => r.reason == 'FUTURE_DATE')) {
        push = await _push.push(userId);
      }
      out.push = push;
      if (push.skippedNoToken) {
        out.error = 'NO_TOKEN';
        return out;
      }
      if (!push.ok) {
        out.unauthorized = push.unauthorized;
        out.error = push.error;
        return out; // push lỗi thì không pull
      }
      final pull = await _pull.pull(userId);
      out.pull = pull;
      out.unauthorized = pull.unauthorized;
      out.error = pull.error;
    } finally {
      _running = false;
    }
    return out;
  }
}
