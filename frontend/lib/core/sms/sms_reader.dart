import 'package:flutter_sms_inbox/flutter_sms_inbox.dart';
import 'package:permission_handler/permission_handler.dart';

enum SmsPermission { granted, denied, permanentlyDenied }

class RawSms {
  final String body;
  final DateTime? date;

  const RawSms(this.body, this.date);
}

class SmsReader {
  SmsReader._();

  static SmsPermission _map(PermissionStatus status) => status.isGranted
      ? SmsPermission.granted
      : status.isPermanentlyDenied
          ? SmsPermission.permanentlyDenied
          : SmsPermission.denied;

  static Future<SmsPermission> status() async =>
      _map(await Permission.sms.status);

  static Future<SmsPermission> request() async =>
      _map(await Permission.sms.request());

  /// Reads only recent inbox messages, newest first. Message bodies are never logged.
  static Future<List<RawSms>> readInbox({
    int count = 300,
    Duration within = const Duration(days: 30),
  }) async {
    final messages = await SmsQuery().querySms(
      kinds: [SmsQueryKind.inbox],
      count: count,
    );
    final since = DateTime.now().subtract(within);
    final output = <RawSms>[];
    for (final message in messages) {
      final body = message.body;
      final date = message.date;
      if (body == null || body.trim().isEmpty) continue;
      if (date != null && date.isBefore(since)) continue;
      output.add(RawSms(body, date));
    }
    output.sort((a, b) => (b.date ?? DateTime(1970))
        .compareTo(a.date ?? DateTime(1970)));
    return output;
  }
}
