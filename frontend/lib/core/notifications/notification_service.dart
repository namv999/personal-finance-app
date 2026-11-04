import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../../models/scheduled_transaction.dart';
import '../utils/occurrence.dart';

/// Bọc plugin thông báo. Múi giờ cố định Asia/Ho_Chi_Minh, khớp businessToday().
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  static const _channelId = 'scheduled_tx';
  static const _testId = 999001;
  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      _channelId,
      'Giao dịch hẹn trước',
      channelDescription: 'Nhắc các giao dịch đến hạn',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );
  static const _perItem = 5;
  static const _maxTotal = 100;

  final _plugin = FlutterLocalNotificationsPlugin();
  final tapTick = ValueNotifier<int>(0);
  bool _ready = false;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (r) {
        debugPrint('Bấm thông báo, payload: ${r.payload}');
        tapTick.value++;
      },
    );
    _ready = true;
  }

  /// true khi đã có cả quyền thông báo lẫn quyền báo thức chính xác.
  Future<bool> ensurePermissions() async {
    final a = _android;
    if (a == null) return false;
    final notif = await a.requestNotificationsPermission() ?? false;
    if (!notif) return false;
    var exact = await a.canScheduleExactNotifications() ?? false;
    if (!exact) {
      await a.requestExactAlarmsPermission();
      exact = await a.canScheduleExactNotifications() ?? false;
    }
    return exact;
  }

  /// Hẹn một thông báo thử sau [delay], trả về giờ hẹn dạng HH:mm:ss.
  Future<String> scheduleTest(Duration delay) async {
    final at = tz.TZDateTime.now(tz.local).add(delay);
    await _plugin.zonedSchedule(
      id: _testId + delay.inMinutes,
      title: 'Giao dịch hẹn trước (thử)',
      body: 'Bạn có 1 giao dịch hẹn trước. Xác nhận ngay',
      scheduledDate: at,
      notificationDetails: _details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: 'gdht-test',
    );
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(at.hour)}:${two(at.minute)}:${two(at.second)}';
  }

  Future<int> pendingCount() async =>
      (await _plugin.pendingNotificationRequests()).length;

  Future<void> cancelAll() async {
    if (!_ready) return;
    await _plugin.cancelAllPendingNotifications();
  }

  /// Rebuild pending reminders from active schedules. Schedules that are
  /// already due are left to the in-app due gate instead of a late alert.
  Future<void> reschedule(List<ScheduledTransaction> items) async {
    if (!_ready) return;
    final now = businessNowKey();
    final groups = <String, int>{};
    for (final item in items) {
      var date = item.nextDueDate;
      var scheduled = 0;
      var guard = 0;
      while (date != null && scheduled < _perItem && guard++ < 200) {
        final key = '$date ${item.timeOfDay}';
        if (key.compareTo(now) > 0) {
          groups[key] = (groups[key] ?? 0) + 1;
          scheduled++;
        }
        date = item.rule.nextAfter(date);
      }
    }

    await _plugin.cancelAllPendingNotifications();
    final keys = groups.keys.toList()..sort();
    final scheduledKeys = keys.take(_maxTotal).toList();
    var id = 1;
    for (final key in scheduledKeys) {
      final count = groups[key]!;
      final p = key.split(RegExp(r'[- :]'));
      final at = tz.TZDateTime(tz.local, int.parse(p[0]), int.parse(p[1]),
          int.parse(p[2]), int.parse(p[3]), int.parse(p[4]));
      await _plugin.zonedSchedule(
        id: id++,
        title: 'Giao dịch hẹn trước',
        body:
            'Bạn có $count giao dịch hẹn trước vào ${p[2]}/${p[1]}/${p[0]}. Mở ứng dụng để xử lý.',
        scheduledDate: at,
        notificationDetails: _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        payload: 'gdht',
      );
    }
    debugPrint('GDHT: đã hẹn ${scheduledKeys.length} thông báo');
  }
}
