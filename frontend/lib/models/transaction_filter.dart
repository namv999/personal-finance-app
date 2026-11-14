import 'category.dart';

/// Bộ lọc giao dịch. Bất biến, dùng copyWith để đổi.
class TransactionFilter {
  final String query;
  final CategoryType? type;
  final String? walletId;
  final String? categoryId;
  final DateTime? from;
  final DateTime? to;

  const TransactionFilter({
    this.query = '',
    this.type,
    this.walletId,
    this.categoryId,
    this.from,
    this.to,
  });

  bool get isActive =>
      query.trim().isNotEmpty ||
      type != null ||
      walletId != null ||
      categoryId != null ||
      from != null ||
      to != null;

  /// Số điều kiện đang bật, dùng hiển thị trên badge nếu cần.
  int get activeCount => [
        query.trim().isNotEmpty,
        type != null,
        walletId != null,
        categoryId != null,
        from != null || to != null,
      ].where((e) => e).length;

  /// clearX = true để đặt field về null (copyWith thường không gán null được).
  TransactionFilter copyWith({
    String? query,
    CategoryType? type,
    String? walletId,
    String? categoryId,
    DateTime? from,
    DateTime? to,
    bool clearType = false,
    bool clearWallet = false,
    bool clearCategory = false,
    bool clearDates = false,
  }) =>
      TransactionFilter(
        query: query ?? this.query,
        type: clearType ? null : (type ?? this.type),
        walletId: clearWallet ? null : (walletId ?? this.walletId),
        categoryId: clearCategory ? null : (categoryId ?? this.categoryId),
        from: clearDates ? null : (from ?? this.from),
        to: clearDates ? null : (to ?? this.to),
      );
}
