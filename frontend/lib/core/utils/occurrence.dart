import 'clock.dart';

enum RepeatUnit { day, week, month, year }

extension RepeatUnitX on RepeatUnit {
  String get value => name.toUpperCase();
  static RepeatUnit? fromValue(String? v) {
    for (final u in RepeatUnit.values) {
      if (u.value == v) return u;
    }
    return null;
  }
}

/// yyyy-MM-dd HH:mm in the fixed Asia/Ho_Chi_Minh business timezone.
String businessNowKey() {
  final n = DateTime.now().toUtc().add(const Duration(hours: 7));
  String two(int v) => v.toString().padLeft(2, '0');
  return '${dateOnly(n)} ${two(n.hour)}:${two(n.minute)}';
}

/// Each occurrence is derived from the original start date, avoiding month drift.
class RecurrenceRule {
  final String startDate;
  final RepeatUnit? unit;
  final int? every;
  final String? endDate;

  const RecurrenceRule(
      {required this.startDate, this.unit, this.every, this.endDate});

  static DateTime _utc(String s) {
    final p = s.split('-');
    return DateTime.utc(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
  }

  static String _addMonths(DateTime s, int months) {
    final total = s.year * 12 + (s.month - 1) + months;
    final y = total ~/ 12;
    final m = total % 12 + 1;
    final last = DateTime.utc(y, m + 1, 0).day;
    return dateOnly(DateTime.utc(y, m, s.day < last ? s.day : last));
  }

  String dateAt(int k) {
    final u = unit;
    if (u == null) return startDate;
    final s = _utc(startDate);
    final n = k * every!;
    switch (u) {
      case RepeatUnit.day:
        return dateOnly(s.add(Duration(days: n)));
      case RepeatUnit.week:
        return dateOnly(s.add(Duration(days: 7 * n)));
      case RepeatUnit.month:
        return _addMonths(s, n);
      case RepeatUnit.year:
        return _addMonths(s, 12 * n);
    }
  }

  int _estimate(String from) {
    final s = _utc(startDate), f = _utc(from);
    final days = f.difference(s).inDays;
    final months = (f.year - s.year) * 12 + f.month - s.month;
    final raw = switch (unit!) {
      RepeatUnit.day => days ~/ every!,
      RepeatUnit.week => days ~/ (7 * every!),
      RepeatUnit.month => months ~/ every!,
      RepeatUnit.year => months ~/ (12 * every!),
    };
    return raw < 0 ? 0 : raw;
  }

  /// The first occurrence strictly after [date], or null when the rule ends.
  String? nextAfter(String date) {
    if (unit == null) return startDate.compareTo(date) > 0 ? startDate : null;
    final from = dateOnly(_utc(date).add(const Duration(days: 1)));
    var k = _estimate(from);
    while (k > 0 && dateAt(k - 1).compareTo(from) >= 0) {
      k--;
    }
    while (dateAt(k).compareTo(from) < 0) {
      k++;
    }
    final d = dateAt(k);
    if (endDate != null && d.compareTo(endDate!) > 0) return null;
    return d;
  }
}
