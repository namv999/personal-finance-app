import 'package:sqflite/sqflite.dart';
import '../core/database/db_helper.dart';
import '../core/database/txn_ext.dart';
import '../core/utils/clock.dart';
import '../core/utils/id_generator.dart';
import '../core/utils/occurrence.dart';
import '../models/category.dart';
import '../models/scheduled_transaction.dart';
import '../models/sync_queue_item.dart';
import 'sync_repository.dart';
import 'transaction_repository.dart';

class DueOccurrence {
  final ScheduledTransaction item;
  final String date;
  const DueOccurrence(this.item, this.date);
  String get key => '$date ${item.timeOfDay}';
}

class ScheduledTransactionRepository {
  static const maxDuePerItem = 100;
  static final _timeRe = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');
  static final _dateRe = RegExp(r'^\d{4}-\d{2}-\d{2}$');

  final DatabaseExecutor _db;
  ScheduledTransactionRepository(this._db);

  Future<List<ScheduledTransaction>> _active(
      DatabaseExecutor e, String userId) async {
    final rows = await e.query(Tables.scheduledTransactions,
        where: 'user_id = ? AND is_deleted = 0',
        whereArgs: [userId],
        orderBy: 'next_due_date IS NULL, next_due_date, time_of_day');
    return rows.map(ScheduledTransaction.fromMap).toList();
  }

  Future<List<ScheduledTransaction>> getAll(String userId) =>
      _active(_db, userId);

  static bool _validDate(String s) {
    if (!_dateRe.hasMatch(s)) return false;
    final p = s.split('-');
    final d = DateTime.utc(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
    return dateOnly(d) == s;
  }

  static void _checkRule({
    required String startDate,
    required String timeOfDay,
    RepeatUnit? unit,
    int? every,
    String? endDate,
    required bool mustBeFuture,
  }) {
    if (!_validDate(startDate) || !_timeRe.hasMatch(timeOfDay)) {
      throw Exception('Ngày hoặc giờ không hợp lệ');
    }
    if ((unit == null) != (every == null)) {
      throw Exception('Chu kỳ lặp không hợp lệ');
    }
    if (every != null && (every < 1 || every > 365)) {
      throw Exception('Chu kỳ lặp phải từ 1 đến 365');
    }
    if (unit == null && endDate != null) {
      throw Exception('Giao dịch một lần không có ngày kết thúc');
    }
    if (endDate != null &&
        (!_validDate(endDate) || endDate.compareTo(startDate) < 0)) {
      throw Exception('Ngày kết thúc không được trước ngày bắt đầu');
    }
    if (mustBeFuture &&
        '$startDate $timeOfDay'.compareTo(businessNowKey()) <= 0) {
      throw Exception('Thời điểm hẹn phải ở tương lai');
    }
  }

  Future<ScheduledTransaction> create({
    required String userId,
    required String walletId,
    String? categoryId,
    required CategoryType type,
    required int amount,
    String? note,
    required String startDate,
    required String timeOfDay,
    RepeatUnit? repeatUnit,
    int? repeatEvery,
    String? endDate,
  }) =>
      _db.inTxn((e) async {
        if (amount <= 0) throw Exception('Số tiền phải lớn hơn 0');
        _checkRule(
            startDate: startDate,
            timeOfDay: timeOfDay,
            unit: repeatUnit,
            every: repeatEvery,
            endDate: endDate,
            mustBeFuture: true);
        await TransactionRepository(e).validateRefs(e,
            userId: userId,
            walletId: walletId,
            categoryId: categoryId,
            type: type);
        final trimmed = note?.trim();
        final s = ScheduledTransaction(
          id: IdGenerator.next(),
          userId: userId,
          walletId: walletId,
          categoryId: categoryId,
          type: type,
          amount: amount,
          note: (trimmed == null || trimmed.isEmpty) ? null : trimmed,
          startDate: startDate,
          timeOfDay: timeOfDay,
          repeatUnit: repeatUnit,
          repeatEvery: repeatEvery,
          endDate: endDate,
          nextDueDate: startDate,
          updatedAt: nowUtc(),
        );
        await e.insert(Tables.scheduledTransactions, s.toMap());
        await SyncRepository(e).enqueue(
            tableName: Tables.scheduledTransactions,
            recordId: s.id,
            action: SyncAction.create);
        return s;
      });

  /// Rule changes restart the schedule at startDate; value-only changes keep the pending date.
  Future<void> update(ScheduledTransaction s) => _db.inTxn((e) async {
        if (s.amount <= 0) throw Exception('Số tiền phải lớn hơn 0');
        final rows = await e.query(Tables.scheduledTransactions,
            where: 'id = ? AND user_id = ? AND is_deleted = 0',
            whereArgs: [s.id, s.userId],
            limit: 1);
        if (rows.isEmpty) throw Exception('Giao dịch hẹn trước không tồn tại');
        final old = ScheduledTransaction.fromMap(rows.first);
        final ruleChanged = old.startDate != s.startDate ||
            old.timeOfDay != s.timeOfDay ||
            old.repeatUnit != s.repeatUnit ||
            old.repeatEvery != s.repeatEvery ||
            old.endDate != s.endDate;
        _checkRule(
            startDate: s.startDate,
            timeOfDay: s.timeOfDay,
            unit: s.repeatUnit,
            every: s.repeatEvery,
            endDate: s.endDate,
            mustBeFuture: ruleChanged);
        await TransactionRepository(e).validateRefs(e,
            userId: s.userId,
            walletId: s.walletId,
            categoryId: s.categoryId,
            type: s.type);
        final trimmed = s.note?.trim();
        await e.update(
            Tables.scheduledTransactions,
            {
              'wallet_id': s.walletId,
              'category_id': s.categoryId,
              'type': s.type.value,
              'amount': s.amount,
              'note': (trimmed == null || trimmed.isEmpty) ? null : trimmed,
              'start_date': s.startDate,
              'time_of_day': s.timeOfDay,
              'repeat_unit': s.repeatUnit?.value,
              'repeat_every': s.repeatEvery,
              'end_date': s.endDate,
              'next_due_date': ruleChanged ? s.startDate : old.nextDueDate,
              'updated_at': nowUtcIso(),
            },
            where: 'id = ?',
            whereArgs: [s.id]);
        await SyncRepository(e).enqueue(
            tableName: Tables.scheduledTransactions,
            recordId: s.id,
            action: SyncAction.update);
      });

  Future<void> delete(String id, String userId) => _db.inTxn((e) async {
        final n = await e.update(Tables.scheduledTransactions,
            {'is_deleted': 1, 'updated_at': nowUtcIso()},
            where: 'id = ? AND user_id = ? AND is_deleted = 0',
            whereArgs: [id, userId]);
        if (n == 0) return;
        await SyncRepository(e).enqueue(
            tableName: Tables.scheduledTransactions,
            recordId: id,
            action: SyncAction.delete);
      });

  Future<List<DueOccurrence>> getDue(String userId, {String? nowKey}) async {
    final now = nowKey ?? businessNowKey();
    final out = <DueOccurrence>[];
    for (final s in await _active(_db, userId)) {
      var d = s.nextDueDate;
      var n = 0;
      while (d != null &&
          '$d ${s.timeOfDay}'.compareTo(now) <= 0 &&
          n++ < maxDuePerItem) {
        out.add(DueOccurrence(s, d));
        d = s.rule.nextAfter(d);
      }
    }
    out.sort((a, b) => a.key.compareTo(b.key));
    return out;
  }

  Future<ScheduledTransaction> _loadForOccurrence(
      DatabaseExecutor e, String userId, String id, String date) async {
    final rows = await e.query(Tables.scheduledTransactions,
        where: 'id = ? AND user_id = ? AND is_deleted = 0',
        whereArgs: [id, userId],
        limit: 1);
    if (rows.isEmpty) throw Exception('Giao dịch hẹn trước không tồn tại');
    final s = ScheduledTransaction.fromMap(rows.first);
    if (s.nextDueDate != date) throw Exception('Kỳ này đã được xử lý');
    return s;
  }

  Future<void> _setNext(DatabaseExecutor e, String id, String? next) async {
    await e.update(Tables.scheduledTransactions,
        {'next_due_date': next, 'updated_at': nowUtcIso()},
        where: 'id = ?', whereArgs: [id]);
    await SyncRepository(e).enqueue(
        tableName: Tables.scheduledTransactions,
        recordId: id,
        action: SyncAction.update);
  }

  Future<String?> _usableCategory(
      DatabaseExecutor e, String userId, ScheduledTransaction s) async {
    if (s.categoryId == null) return null;
    final rows = await e.query(Tables.categories,
        columns: ['id'],
        where:
            'id = ? AND type = ? AND is_deleted = 0 AND (user_id IS NULL OR user_id = ?)',
        whereArgs: [s.categoryId, s.type.value, userId],
        limit: 1);
    return rows.isEmpty ? null : s.categoryId;
  }

  Future<void> confirm({
    required String userId,
    required String id,
    required String occurrenceDate,
    int? amount,
  }) =>
      _db.inTxn((e) async {
        final s = await _loadForOccurrence(e, userId, id, occurrenceDate);
        final value = amount ?? s.amount;
        if (value <= 0) throw Exception('Số tiền phải lớn hơn 0');
        final txId = IdGenerator.forOccurrence(id, occurrenceDate);
        final exists = await e.query(Tables.transactions,
            columns: ['id'], where: 'id = ?', whereArgs: [txId], limit: 1);
        if (exists.isEmpty) {
          await TransactionRepository(e).create(
            id: txId,
            userId: userId,
            walletId: s.walletId,
            categoryId: await _usableCategory(e, userId, s),
            type: s.type,
            amount: value,
            note: s.note,
            transactionDate: DateTime.parse(occurrenceDate),
          );
        }
        await _setNext(e, id, s.rule.nextAfter(occurrenceDate));
      });

  Future<void> cancel({
    required String userId,
    required String id,
    required String occurrenceDate,
  }) =>
      _db.inTxn((e) async {
        final s = await _loadForOccurrence(e, userId, id, occurrenceDate);
        await _setNext(e, id, s.rule.nextAfter(occurrenceDate));
      });

  Future<int> skipAllDue(String userId) => _db.inTxn((e) async {
        final now = businessNowKey();
        var skipped = 0;
        for (final s in await _active(e, userId)) {
          final start = s.nextDueDate;
          var d = start;
          while (d != null && '$d ${s.timeOfDay}'.compareTo(now) <= 0) {
            d = s.rule.nextAfter(d);
            skipped++;
          }
          if (d != start) await _setNext(e, s.id, d);
        }
        return skipped;
      });

  /// Call from the pull transaction to advance past occurrences confirmed elsewhere.
  Future<void> reconcileAfterPull(String userId) => _db.inTxn((e) async {
        for (final s in await _active(e, userId)) {
          final start = s.nextDueDate;
          var d = start;
          while (d != null) {
            final hit = await e.query(Tables.transactions,
                columns: ['id'],
                where: 'id = ?',
                whereArgs: [IdGenerator.forOccurrence(s.id, d)],
                limit: 1);
            if (hit.isEmpty) break;
            d = s.rule.nextAfter(d);
          }
          if (d != start) await _setNext(e, s.id, d);
        }
      });
}
