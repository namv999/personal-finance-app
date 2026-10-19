DateTime nowUtc() => DateTime.fromMillisecondsSinceEpoch(
    DateTime.now().millisecondsSinceEpoch, isUtc: true);

String toUtcIso(DateTime d) => DateTime.fromMillisecondsSinceEpoch(
    d.millisecondsSinceEpoch, isUtc: true).toIso8601String();

String? toUtcIsoN(DateTime? d) => d == null ? null : toUtcIso(d);

String nowUtcIso() => nowUtc().toIso8601String();

String dateOnly(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Hôm nay theo múi giờ nghiệp vụ Asia/Ho_Chi_Minh (UTC+7 cố định).
String businessToday() =>
    dateOnly(DateTime.now().toUtc().add(const Duration(hours: 7)));

/// Chặn ngày tương lai cho transactions và transfers.
void ensureNotFuture(DateTime d) {
  if (dateOnly(d).compareTo(businessToday()) > 0) {
    throw Exception('Ngày không được ở tương lai');
  }
}
