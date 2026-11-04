import 'package:flutter/foundation.dart';
import '../core/notifications/notification_service.dart';
import '../core/utils/clock.dart';
import '../core/utils/occurrence.dart';
import '../models/category.dart';
import '../models/scheduled_transaction.dart';
import '../repositories/scheduled_transaction_repository.dart';
import '../repositories/sync_service.dart';

class ScheduledProvider extends ChangeNotifier {
  final ScheduledTransactionRepository _repo;
  final SyncService _sync;
  final String userId;
  bool _disposed = false;

  ScheduledProvider(this._repo, this._sync, this.userId) {
    _sync.pulledTick.addListener(_onPulled);
  }

  List<ScheduledTransaction> items = [];
  List<DueOccurrence> due = [];
  bool isLoading = false;

  void _onPulled() {
    load().catchError((Object e) {
      debugPrint('GDHT refresh sau pull lỗi: $e');
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _sync.pulledTick.removeListener(_onPulled);
    super.dispose();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> start() async {
    if (userId == '_none_') {
      try {
        await NotificationService.instance.cancelAll();
      } catch (e) {
        debugPrint('GDHT cancelAll lỗi: $e');
      }
      return;
    }
    try {
      await load();
    } catch (e) {
      debugPrint('GDHT khởi tạo provider lỗi: $e');
    }
  }

  Future<void> load() async {
    if (userId == '_none_' || _disposed) return;
    isLoading = true;
    _notify();
    try {
      items = await _repo.getAll(userId);
      due = await _repo.getDue(userId);
      try {
        await NotificationService.instance.reschedule(items);
      } catch (e) {
        // Reminder failures must not prevent schedule data from loading.
        debugPrint('GDHT reschedule lỗi: $e');
      }
    } finally {
      isLoading = false;
      _notify();
    }
  }

  /// Returns whether notification and exact-alarm permissions are available.
  Future<bool> add({
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
  }) async {
    await _repo.create(
      userId: userId,
      walletId: walletId,
      categoryId: categoryId,
      type: type,
      amount: amount,
      note: note,
      startDate: startDate,
      timeOfDay: timeOfDay,
      repeatUnit: repeatUnit,
      repeatEvery: repeatEvery,
      endDate: endDate,
    );
    var granted = false;
    try {
      granted = await NotificationService.instance.ensurePermissions();
    } catch (e) {
      debugPrint('GDHT xin quyền thông báo lỗi: $e');
    }
    await load();
    return granted;
  }

  Future<void> edit({
    required String id,
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
  }) async {
    final old = items.firstWhere((s) => s.id == id,
        orElse: () => throw Exception('Giao dịch hẹn trước không tồn tại'));
    await _repo.update(ScheduledTransaction(
      id: id,
      userId: userId,
      walletId: walletId,
      categoryId: categoryId,
      type: type,
      amount: amount,
      note: note,
      startDate: startDate,
      timeOfDay: timeOfDay,
      repeatUnit: repeatUnit,
      repeatEvery: repeatEvery,
      endDate: endDate,
      nextDueDate: old.nextDueDate,
      updatedAt: nowUtc(),
    ));
    await load();
  }

  Future<void> remove(String id) async {
    await _repo.delete(id, userId);
    await load();
  }

  /// Caller should refresh ledger providers after confirming an occurrence.
  Future<void> confirm(DueOccurrence occurrence, {int? amount}) async {
    await _repo.confirm(
      userId: userId,
      id: occurrence.item.id,
      occurrenceDate: occurrence.date,
      amount: amount,
    );
    await load();
  }

  Future<void> cancel(DueOccurrence occurrence) async {
    await _repo.cancel(
      userId: userId,
      id: occurrence.item.id,
      occurrenceDate: occurrence.date,
    );
    await load();
  }

  /// Returns the number of due occurrences skipped.
  Future<int> skipAllDue() async {
    final count = await _repo.skipAllDue(userId);
    await load();
    return count;
  }

  static DateTime _asBusiness(String date, String time) {
    final d = date.split('-');
    final t = time.split(':');
    return DateTime.utc(int.parse(d[0]), int.parse(d[1]), int.parse(d[2]),
        int.parse(t[0]), int.parse(t[1]));
  }

  /// Duration until the next future due time, zero if an occurrence is due,
  /// or null if there are no remaining occurrences.
  Duration? timeUntilNextDue() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 7));
    Duration? best;
    for (final item in items) {
      final date = item.nextDueDate;
      if (date == null) continue;
      final diff = _asBusiness(date, item.timeOfDay).difference(now);
      if (diff <= Duration.zero) return Duration.zero;
      if (best == null || diff < best) best = diff;
    }
    return best;
  }
}
