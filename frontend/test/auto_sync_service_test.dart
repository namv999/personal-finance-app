import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:personal_finance_app/core/network/api_client.dart';
import 'package:personal_finance_app/repositories/auto_sync_service.dart';
import 'package:personal_finance_app/repositories/sync_pull_repository.dart';
import 'package:personal_finance_app/repositories/sync_push_repository.dart';
import 'package:personal_finance_app/repositories/sync_service.dart';

class _FakeSync implements SyncService {
  final Future<SyncOutcome> Function(String userId) run;
  int calls = 0;

  _FakeSync(this.run);

  @override
  final ValueNotifier<int> pulledTick = ValueNotifier(0);

  @override
  Future<SyncOutcome> syncAll(String userId) {
    calls++;
    return run(userId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await ApiClient.instance.saveToken('test-token');
  });

  tearDown(() async {
    await ApiClient.instance.clearToken();
  });

  test('successful changed sync records time and refreshes data', () async {
    final sync = _FakeSync((_) async => SyncOutcome()
      ..push = PushResult()
      ..pull = (PullResult()
        ..received = 1
        ..applied = 1));
    var refreshes = 0;
    final service = AutoSyncService(sync, () => 'u1', () async {
      refreshes++;
    });
    addTearDown(service.dispose);

    final out = await service.syncNow();

    expect(out.ok, isTrue);
    expect(sync.calls, 1);
    expect(service.lastSyncAt, isNotNull);
    expect(service.lastError, isNull);
    expect(refreshes, 1);
  });

  test('received but unapplied records do not refresh data', () async {
    final sync = _FakeSync((_) async => SyncOutcome()
      ..push = PushResult()
      ..pull = (PullResult()..received = 1));
    var refreshes = 0;
    final service = AutoSyncService(sync, () => 'u1', () async {
      refreshes++;
    });
    addTearDown(service.dispose);

    final out = await service.syncNow();

    expect(out.ok, isTrue);
    expect(refreshes, 0);
  });

  test('unauthorized sync pauses future auto requests', () async {
    final sync = _FakeSync((_) async => SyncOutcome()
      ..unauthorized = true
      ..error = 'UNAUTHORIZED');
    final service = AutoSyncService(sync, () => 'u1', () async {});
    addTearDown(service.dispose);

    final out = await service.syncNow();
    service.request(immediate: true);

    expect(out.unauthorized, isTrue);
    expect(service.needsRelogin, isTrue);
    expect(sync.calls, 1);
  });
}
