import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:personal_finance_app/core/database/db_helper.dart';
import 'package:personal_finance_app/models/sync_queue_item.dart';
import 'package:personal_finance_app/core/utils/id_generator.dart';
import 'package:personal_finance_app/repositories/scheduled_transaction_repository.dart';
import 'package:personal_finance_app/repositories/sync_repository.dart';
import 'package:personal_finance_app/repositories/wallet_repository.dart';

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
      Tables.scheduledTransactions,
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
    await db.insert(Tables.pets, {'id': 'p1', 'user_id': 'u1'});
    await db.insert(Tables.savingStreaks, {'id': 'ss1', 'user_id': 'u1'});
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

  test('LWW preserves newer local rows and applies newer remote rows',
      () async {
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
    final w1 =
        await db.query(Tables.wallets, where: 'id = ?', whereArgs: ['w1']);
    final w2 =
        await db.query(Tables.wallets, where: 'id = ?', whereArgs: ['w2']);
    expect(w1.first['wallet_name'], 'Local');
    expect(w2.first['wallet_name'], 'New');
  });

  test('ignores records belonging to another user', () async {
    await sync.applyPulled('u1', {
      Tables.wallets: [
        wallet('w9', 'Other', '2026-10-01T00:00:00.000Z', user: 'other')
      ],
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
    final active =
        await db.query(Tables.monthlyBudgets, where: 'is_deleted = 0');
    expect(active, hasLength(1));
    expect(active.first['id'], 'b-remote');
    final queued = await db.query(Tables.syncQueue,
        where: 'record_id = ?', whereArgs: ['b-local']);
    expect(queued, isNotEmpty);
  });

  test('push sends current snapshot and leaves queue rows added after snapshot',
      () async {
    await db.insert(Tables.wallets, {
      'id': 'w1',
      'user_id': 'u1',
      'wallet_name': 'A',
      'wallet_type': 'SPENDING',
      'updated_at': '2026-10-01T00:00:00.000Z',
    });
    await sync.enqueue(
        tableName: Tables.wallets, recordId: 'w1', action: SyncAction.create);
    await db.update(Tables.wallets, {'wallet_name': 'B'},
        where: 'id = ?', whereArgs: ['w1']);
    await sync.enqueue(
        tableName: Tables.wallets, recordId: 'w1', action: SyncAction.update);

    final batch = await sync.buildPushBatch('u1');
    expect(batch.records[Tables.wallets]!.single['wallet_name'], 'B');
    expect(batch.queueIdsByRecord['${Tables.wallets}|w1'], hasLength(2));

    await sync.enqueue(
        tableName: Tables.wallets, recordId: 'w1', action: SyncAction.update);
    await sync.markSynced(batch, ['${Tables.wallets}|w1']);
    expect(await db.query(Tables.syncQueue), hasLength(1));
  });

  Future<void> insertWallet() => db.insert(Tables.wallets, {
        'id': 'w1',
        'user_id': 'u1',
        'wallet_name': 'A',
        'wallet_type': 'SPENDING',
        'updated_at': '2026-10-01T00:00:00.000Z',
      });

  Map<String, Object?> sched(String id, String at,
          {String? next = '2026-11-10',
          String? unit = 'MONTH',
          int? every = 1}) =>
      {
        'id': id,
        'user_id': 'u1',
        'wallet_id': 'w1',
        'category_id': null,
        'type': 'EXPENSE',
        'amount': 50000,
        'note': 'Tiền nhà',
        'start_date': '2026-11-10',
        'time_of_day': '08:00',
        'repeat_unit': unit,
        'repeat_every': every,
        'end_date': null,
        'next_due_date': next,
        'updated_at': at,
        'is_deleted': false,
      };

  test('GDHT: pull áp dụng bản mới, giữ bản local mới hơn', () async {
    await insertWallet();
    await sync.applyPulled('u1', {
      Tables.scheduledTransactions: [
        sched('s1', '2026-10-05T00:00:00.000Z'),
        sched('s2', '2026-10-05T00:00:00.000Z'),
      ],
    });
    await sync.applyPulled('u1', {
      Tables.scheduledTransactions: [
        sched('s1', '2026-10-01T00:00:00.000Z', next: '2026-12-10'),
        sched('s2', '2026-10-09T00:00:00.000Z', next: '2026-12-10'),
      ],
    });
    final rows = await db.query(Tables.scheduledTransactions, orderBy: 'id');
    expect(rows[0]['next_due_date'], '2026-11-10');
    expect(rows[1]['next_due_date'], '2026-12-10');
  });

  test('GDHT: push batch có bảng scheduled_transactions', () async {
    await insertWallet();
    await db.insert(Tables.scheduledTransactions,
        {...sched('s1', '2026-10-05T00:00:00.000Z'), 'is_deleted': 0});
    await sync.enqueue(
        tableName: Tables.scheduledTransactions,
        recordId: 's1',
        action: SyncAction.create);
    final batch = await sync.buildPushBatch('u1');
    final row = batch.records[Tables.scheduledTransactions]!.single;
    expect(row['repeat_unit'], 'MONTH');
    expect(row['is_deleted'], false);
  });

  test('GDHT: xác nhận tạo giao dịch id xác định, đẩy kỳ sau, tính lại số dư',
      () async {
    await insertWallet();
    await db.insert(Tables.scheduledTransactions, {
      ...sched('s1', '2026-10-05T00:00:00.000Z', next: '2026-11-01'),
      'is_deleted': 0,
    });
    final repo = ScheduledTransactionRepository(db);
    await repo.confirm(
        userId: 'u1', id: 's1', occurrenceDate: '2026-11-01', amount: 70000);
    final txId = IdGenerator.forOccurrence('s1', '2026-11-01');
    final tx =
        await db.query(Tables.transactions, where: 'id = ?', whereArgs: [txId]);
    expect(tx.single['amount'], 70000);
    expect(tx.single['transaction_date'], '2026-11-01');
    final s = await db.query(Tables.scheduledTransactions);
    expect(s.single['next_due_date'], '2026-11-10');
    final w = await db.query(Tables.wallets);
    expect(w.single['current_balance'], -70000);
    await expectLater(
        repo.confirm(userId: 'u1', id: 's1', occurrenceDate: '2026-11-01'),
        throwsException);
  });

  test('GDHT: kỳ đã có giao dịch (kể cả đã xóa) không bị tạo lại', () async {
    await insertWallet();
    await db.insert(Tables.scheduledTransactions, {
      ...sched('s1', '2026-10-05T00:00:00.000Z', next: '2026-11-10'),
      'is_deleted': 0,
    });
    final txId = IdGenerator.forOccurrence('s1', '2026-11-10');
    await db.insert(Tables.transactions, {
      'id': txId,
      'user_id': 'u1',
      'wallet_id': 'w1',
      'type': 'EXPENSE',
      'amount': 50000,
      'transaction_date': '2026-11-10',
      'is_deleted': 1,
      'updated_at': '2026-11-10T02:00:00.000Z',
    });
    final repo = ScheduledTransactionRepository(db);
    await repo.reconcileAfterPull('u1');
    var s = await db.query(Tables.scheduledTransactions);
    expect(s.single['next_due_date'], '2026-12-10');
    final queued = await db
        .query(Tables.syncQueue, where: 'record_id = ?', whereArgs: ['s1']);
    expect(queued, isNotEmpty);

    await db
        .update(Tables.scheduledTransactions, {'next_due_date': '2026-11-10'});
    await repo.confirm(userId: 'u1', id: 's1', occurrenceDate: '2026-11-10');
    final txs =
        await db.query(Tables.transactions, where: 'id = ?', whereArgs: [txId]);
    expect(txs, hasLength(1));
    expect(txs.single['is_deleted'], 1);
    s = await db.query(Tables.scheduledTransactions);
    expect(s.single['next_due_date'], '2026-12-10');
  });

  test('GDHT: getDue gom các kỳ đã lỡ, cũ nhất trước', () async {
    await insertWallet();
    await db.insert(Tables.scheduledTransactions, {
      ...sched('s1', '2026-10-05T00:00:00.000Z',
          next: '2026-11-01', unit: 'DAY', every: 1),
      'start_date': '2026-11-01',
      'is_deleted': 0,
    });
    final due = await ScheduledTransactionRepository(db)
        .getDue('u1', nowKey: '2026-11-03 10:00');
    expect(due.map((d) => d.date), ['2026-11-01', '2026-11-02', '2026-11-03']);
  });

  test('G5: xóa ví xóa mềm GDHT của ví đó, ghi queue, không đụng ví khác',
      () async {
    await insertWallet();
    await db.insert(Tables.wallets, {
      'id': 'w2',
      'user_id': 'u1',
      'wallet_name': 'B',
      'wallet_type': 'SPENDING',
      'updated_at': '2026-10-01T00:00:00.000Z',
    });
    await db.insert(Tables.scheduledTransactions,
        {...sched('s1', '2026-10-05T00:00:00.000Z'), 'is_deleted': 0});
    await db.insert(Tables.scheduledTransactions, {
      ...sched('s2', '2026-10-05T00:00:00.000Z'),
      'wallet_id': 'w2',
      'is_deleted': 0
    });

    final repo = WalletRepository(db);
    final preview = await repo.previewDelete('w1');
    expect(preview.scheduledCount, 1);

    await repo.delete('w1');
    final rows = await db.query(Tables.scheduledTransactions, orderBy: 'id');
    expect(rows[0]['is_deleted'], 1);
    expect(rows[1]['is_deleted'], 0);

    final queued = await db.query(Tables.syncQueue,
        where: 'table_name = ?', whereArgs: [Tables.scheduledTransactions]);
    expect(queued.map((q) => q['record_id']), ['s1']);
    expect(queued.single['action'], 'DELETE');
  });
}
