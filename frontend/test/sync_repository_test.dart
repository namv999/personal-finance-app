import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:personal_finance_app/core/database/db_helper.dart';
import 'package:personal_finance_app/models/sync_queue_item.dart';
import 'package:personal_finance_app/repositories/sync_repository.dart';

void main() {
  late Database db;
  late SyncRepository sync;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await DbHelper.instance.database;
    for (final table in [
      Tables.syncQueue,
      Tables.transfers,
      Tables.transactions,
      Tables.monthlyBudgets,
      Tables.savingGoals,
      Tables.wallets,
    ]) {
      await db.delete(table);
    }
    await db.delete(Tables.categories, where: 'user_id IS NOT NULL');
    await db.delete(Tables.pets);
    await db.delete(Tables.savingStreaks);
    await db.delete(Tables.users);
    await db.insert(Tables.users, {
      'id': 'u1',
      'full_name': 'T',
      'email': 't@x.com',
      'password_hash': 'h',
      'created_at': '2026-10-01T00:00:00.000Z',
    });
    sync = SyncRepository(db);
  });

  Map<String, Object?> wallet(String id, String name, String at,
          {String user = 'u1'}) =>
      {
        'id': id,
        'user_id': user,
        'wallet_name': name,
        'wallet_type': 'SPENDING',
        'opening_balance': 0,
        'updated_at': at,
        'is_deleted': false,
      };

  test('LWW preserves newer local rows and applies newer remote rows', () async {
    await db.insert(Tables.wallets, {
      'id': 'w1',
      'user_id': 'u1',
      'wallet_name': 'Local',
      'wallet_type': 'SPENDING',
      'updated_at': '2026-10-05T00:00:00.000Z',
    });
    await db.insert(Tables.wallets, {
      'id': 'w2',
      'user_id': 'u1',
      'wallet_name': 'Old',
      'wallet_type': 'SPENDING',
      'updated_at': '2026-10-01T00:00:00.000Z',
    });
    await sync.applyPulled('u1', {
      Tables.wallets: [
        wallet('w1', 'Remote', '2026-10-01T00:00:00.000Z'),
        wallet('w2', 'New', '2026-10-09T00:00:00.000Z'),
      ],
    });
    final w1 = await db.query(Tables.wallets, where: 'id = ?', whereArgs: ['w1']);
    final w2 = await db.query(Tables.wallets, where: 'id = ?', whereArgs: ['w2']);
    expect(w1.first['wallet_name'], 'Local');
    expect(w2.first['wallet_name'], 'New');
  });

  test('ignores records belonging to another user', () async {
    await sync.applyPulled('u1', {
      Tables.wallets: [wallet('w9', 'Other', '2026-10-01T00:00:00.000Z', user: 'other')],
    });
    expect(await db.query(Tables.wallets), isEmpty);
  });

  test('newer natural-key budget wins and queues the displaced row', () async {
    await db.insert(Tables.categories, {
      'id': 'c1',
      'user_id': 'u1',
      'category_name': 'Ăn',
      'type': 'EXPENSE',
      'updated_at': '2026-10-01T00:00:00.000Z',
    });
    await db.insert(Tables.monthlyBudgets, {
      'id': 'b-local',
      'user_id': 'u1',
      'category_id': 'c1',
      'month': '2026-10',
      'spending_limit': 100,
      'updated_at': '2026-10-01T00:00:00.000Z',
    });
    await sync.applyPulled('u1', {
      Tables.monthlyBudgets: [
        {
          'id': 'b-remote',
          'user_id': 'u1',
          'category_id': 'c1',
          'month': '2026-10',
          'spending_limit': 200,
          'updated_at': '2026-10-02T00:00:00.000Z',
          'is_deleted': false,
        },
      ],
    });
    final active = await db.query(Tables.monthlyBudgets, where: 'is_deleted = 0');
    expect(active, hasLength(1));
    expect(active.first['id'], 'b-remote');
    final queued = await db.query(Tables.syncQueue,
        where: 'record_id = ?', whereArgs: ['b-local']);
    expect(queued, isNotEmpty);
  });

  test('push sends current snapshot and leaves queue rows added after snapshot', () async {
    await db.insert(Tables.wallets, {
      'id': 'w1',
      'user_id': 'u1',
      'wallet_name': 'A',
      'wallet_type': 'SPENDING',
      'updated_at': '2026-10-01T00:00:00.000Z',
    });
    await sync.enqueue(tableName: Tables.wallets, recordId: 'w1', action: SyncAction.create);
    await db.update(Tables.wallets, {'wallet_name': 'B'},
        where: 'id = ?', whereArgs: ['w1']);
    await sync.enqueue(tableName: Tables.wallets, recordId: 'w1', action: SyncAction.update);

    final batch = await sync.buildPushBatch('u1');
    expect(batch.records[Tables.wallets]!.single['wallet_name'], 'B');
    expect(batch.queueIdsByRecord['${Tables.wallets}|w1'], hasLength(2));

    await sync.enqueue(tableName: Tables.wallets, recordId: 'w1', action: SyncAction.update);
    await sync.markSynced(batch, ['${Tables.wallets}|w1']);
    expect(await db.query(Tables.syncQueue), hasLength(1));
  });
}
