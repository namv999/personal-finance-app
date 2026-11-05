import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/network/api_client.dart';
import 'sync_service.dart';

class AutoSyncService extends ChangeNotifier {
  final SyncService _sync;
  final String? Function() _userId;
  final Future<void> Function() _onDataChanged;

  AutoSyncService(this._sync, this._userId, this._onDataChanged);

  static const _debounce = Duration(seconds: 3);
  static const _resumeGap = Duration(seconds: 30);
  static const _retrySeconds = [30, 60, 120, 300];

  Timer? _debounceTimer;
  Timer? _retryTimer;
  bool _running = false;
  bool _rerun = false;
  Future<SyncOutcome>? _current;
  bool _unauthorized = false;
  bool _disposed = false;
  int _failures = 0;

  DateTime? lastSyncAt;
  String? lastError;

  bool get isRunning => _running;
  bool get needsRelogin => _unauthorized;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Coalesces local writes into one sync after the quiet period.
  void request({bool immediate = false}) {
    if (_disposed || _unauthorized) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(immediate ? Duration.zero : _debounce, _trigger);
  }

  /// Avoids syncing repeatedly when the app resumes shortly after a sync.
  void onResume() {
    final t = lastSyncAt;
    if (t != null && DateTime.now().difference(t) < _resumeGap) return;
    request(immediate: true);
  }

  void markUnauthorized() {
    _unauthorized = true;
    _retryTimer?.cancel();
    _debounceTimer?.cancel();
    _notify();
  }

  void clearUnauthorized() {
    if (!_unauthorized) return;
    _unauthorized = false;
    lastError = null;
    _failures = 0;
    _notify();
  }

  void _trigger() {
    if (_disposed || _unauthorized || _userId() == null) return;
    if (!ApiClient.instance.hasToken) return;
    unawaited(syncNow());
  }

  /// Shared by automatic runs and the Settings "Sync now" action.
  Future<SyncOutcome> syncNow() {
    final uid = _userId();
    if (uid == null) return Future.value(SyncOutcome()..error = 'NO_USER');
    if (_unauthorized) {
      return Future.value(SyncOutcome()
        ..unauthorized = true
        ..error = 'UNAUTHORIZED');
    }
    final running = _current;
    if (running != null) {
      _rerun = true;
      return running;
    }
    return _current = _run(uid).whenComplete(() => _current = null);
  }

  Future<SyncOutcome> _run(String uid) async {
    _running = true;
    _notify();
    var last = SyncOutcome();
    try {
      do {
        _rerun = false;
        try {
          last = await _sync.syncAll(uid);
        } catch (e) {
          last = SyncOutcome()..error = e.toString();
        }
        await _afterSync(last);
      } while (_rerun && last.ok);
    } finally {
      _rerun = false;
      _running = false;
      _notify();
    }
    return last;
  }

  Future<void> _afterSync(SyncOutcome out) async {
    if (out.unauthorized) {
      markUnauthorized();
      return;
    }
    if (out.error == 'NO_TOKEN') return;
    if (out.error == 'BUSY') {
      // Another feature may call SyncService directly (for example scheduled items).
      _retryTimer?.cancel();
      _retryTimer = Timer(const Duration(seconds: 5), _trigger);
      return;
    }
    if (out.error != null) {
      _failures++;
      lastError = out.error;
      _scheduleRetry();
      _notify();
      return;
    }
    _failures = 0;
    lastError = null;
    lastSyncAt = DateTime.now();
    _retryTimer?.cancel();
    _notify();

    final changed = (out.pull?.applied ?? 0) > 0 ||
        (out.push?.rejected.isNotEmpty ?? false);
    if (changed) {
      try {
        await _onDataChanged();
      } catch (e) {
        debugPrint('AutoSync refresh lỗi: $e');
      }
    }
  }

  /// Clears per-session sync state when the current account logs out.
  void reset() {
    _debounceTimer?.cancel();
    _retryTimer?.cancel();
    _unauthorized = false;
    _failures = 0;
    lastError = null;
    lastSyncAt = null;
    _notify();
  }

  void _scheduleRetry() {
    _retryTimer?.cancel();
    final i = (_failures - 1).clamp(0, _retrySeconds.length - 1);
    _retryTimer = Timer(Duration(seconds: _retrySeconds[i]), _trigger);
  }

  @override
  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }
}
