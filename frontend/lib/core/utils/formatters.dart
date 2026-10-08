import 'package:intl/intl.dart';

/// Currency/date formatting helpers, centralized so every screen displays
/// numbers and dates identically.
class Formatters {
  Formatters._();

  static final NumberFormat _currency =
      NumberFormat.currency(locale: 'vi_VN', symbol: 'đ', decimalDigits: 0);
  static final DateFormat _date = DateFormat('dd/MM/yyyy');
  static final DateFormat _monthYear = DateFormat('MM/yyyy');

  static String currency(num amount) => _currency.format(amount);
  static String date(DateTime date) => _date.format(date);
  static String monthYear(DateTime date) => _monthYear.format(date);

  /// e.g. 2026-09 for monthly_budgets.month / ai_suggestions.month
  static String yyyyMM(DateTime date) => DateFormat('yyyy-MM').format(date);
}
