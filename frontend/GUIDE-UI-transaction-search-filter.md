# GUIDE-UI-transaction-search-filter

Mục tiêu: thêm tìm kiếm và lọc cho tab Giao dịch bằng icon trên AppBar mở bottom sheet.
Dữ liệu lấy từ SQLite local (offline-first). Không gọi backend.

## 0. Ràng buộc (đọc trước khi code)

- Dự án đã qua mốc đóng băng tính năng. Chỉ làm đúng phạm vi bên dưới.
- KHÔNG sửa: schema SQLite, migration, backend, `docs/openapi.yaml`, sync, `home_shell.dart`.
- KHÔNG thêm package mới. Không thêm localization delegate mới.
- `TransactionProvider.transactions` dùng chung với màn Tổng quan. KHÔNG ghi kết quả lọc vào đó.
- Chỉ viết đoạn code cần thêm/sửa, đánh dấu rõ chỗ chèn. Không viết lại cả file.
- Chỉ đọc tên field của `Wallet` (`wallet.dart`) và `TransactionCategory` (`category.dart`) trước khi dùng.
  Trong code hiện có: category có `id`, `categoryName`, `type`, `isDeleted`; wallet nhiều khả năng có `id`, `walletName`.

## 1. Phạm vi

Có:
- Tìm theo `note` (không phân biệt hoa/thường, có phân biệt dấu).
- Lọc: loại (Tất cả/Thu/Chi), ví, danh mục, khoảng ngày.

Không làm:
- Lọc theo số tiền, tìm theo tên danh mục, tìm không dấu, lọc "Không phân loại", lọc theo `source`.

## 2. Vì sao lọc note bằng Dart, không dùng SQL LIKE

`LIKE` của SQLite chỉ bỏ phân biệt hoa/thường với ký tự ASCII. Gõ "phở" sẽ không khớp "Phở".
Cách làm: SQL lọc các điều kiện chính xác (loại, ví, danh mục, ngày), sau đó lọc `note` trong Dart
bằng `toLowerCase().contains(...)`. Dart xử lý đúng hoa/thường tiếng Việt.

## 3. File mới: `lib/models/transaction_filter.dart`

```dart
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
```

## 4. Sửa `transaction_repository.dart`: mở rộng `getAll`

Chỉ thêm 2 tham số và 2 điều kiện, giữ nguyên phần còn lại.

```dart
Future<List<FinanceTransaction>> getAll(
  String userId, {
  String? walletId,
  DateTime? from,
  DateTime? to,
  int? limit,
  CategoryType? type,      // THÊM
  String? categoryId,      // THÊM
}) async {
  final where = StringBuffer('user_id = ? AND is_deleted = 0');
  final args = <dynamic>[userId];
  // ... các điều kiện walletId, from, to giữ nguyên ...

  // THÊM, đặt trước câu query:
  if (type != null) {
    where.write(' AND type = ?');
    args.add(type.value);
  }
  if (categoryId != null) {
    where.write(' AND category_id = ?');
    args.add(categoryId);
  }
  // ... phần _db.query giữ nguyên ...
}
```

Các nơi đang gọi `getAll` không bị ảnh hưởng vì tham số mới là tùy chọn.

## 5. Sửa `transaction_provider.dart`

Thêm import `../models/transaction_filter.dart`.

Thêm state (đặt cạnh `transactions`):

```dart
TransactionFilter filter = const TransactionFilter();
List<FinanceTransaction> searchResults = [];   // riêng, KHÔNG dùng chung với `transactions`
bool get isFiltering => filter.isActive;
```

Thêm các hàm:

```dart
Future<void> applyFilter(TransactionFilter f) async {
  filter = f;
  await _runSearch();
  notifyListeners();
}

Future<void> clearFilter() => applyFilter(const TransactionFilter());

Future<void> _runSearch() async {
  if (!filter.isActive) {
    searchResults = [];
    return;
  }
  // Không limit: người dùng cần thấy mọi kết quả khớp, không chỉ 200 giao dịch gần nhất.
  final rows = await _repo.getAll(
    userId,
    walletId: filter.walletId,
    categoryId: filter.categoryId,
    type: filter.type,
    from: filter.from,
    to: filter.to,
  );
  final q = filter.query.trim().toLowerCase();
  searchResults = q.isEmpty
      ? rows
      : rows.where((t) => (t.note ?? '').toLowerCase().contains(q)).toList();
}
```

Sửa `load()`: thêm 1 dòng trong `try`, ngay sau khi tính `monthTotals`.
Lý do: add/edit/delete đều gọi `load()`, cần chạy lại bộ lọc đang bật.

```dart
monthTotals = await _repo.getTotalsByType(userId, from, to);
await _runSearch();   // THÊM
```

## 6. File mới: `lib/screens/transactions/transaction_filter_sheet.dart`

Một StatefulWidget giữ bản nháp bộ lọc. Chỉ trả kết quả khi bấm "Áp dụng".

Hàm mở sheet (đặt trong file này, gọi từ màn danh sách):

```dart
Future<TransactionFilter?> showTransactionFilterSheet(
  BuildContext context, {
  required TransactionFilter initial,
  required List<Wallet> wallets,
  required List<TransactionCategory> categories,
}) {
  return showModalBottomSheet<TransactionFilter>(
    context: context,
    isScrollControlled: true,   // để sheet đẩy lên theo bàn phím
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => _FilterSheet(
        initial: initial, wallets: wallets, categories: categories),
  );
}
```

Nội dung `_FilterSheet` (từ trên xuống), bọc trong `SingleChildScrollView` và
`Padding(bottom: MediaQuery.of(context).viewInsets.bottom + 16)`:

1. Hàng tiêu đề: "Tìm kiếm và lọc" bên trái, `TextButton('Đặt lại')` bên phải.
   "Đặt lại" chỉ reset bản nháp về `TransactionFilter()`, chưa áp dụng.
2. `TextField` "Tìm trong ghi chú", prefix icon search, có nút xóa nội dung (`TextEditingController` nội bộ, nhớ dispose).
3. Loại: ba `ChoiceChip` "Tất cả" / "Thu" / "Chi". Chọn "Tất cả" thì `clearType`.
   Khi đổi loại, nếu `categoryId` đang chọn không cùng loại mới thì `clearCategory` (tránh lọc ra rỗng khó hiểu).
4. Ví: `DropdownButtonFormField<String?>`, mục đầu `null` = "Tất cả ví", các mục sau là `wallets`.
5. Danh mục: `DropdownButtonFormField<String?>`, mục đầu `null` = "Tất cả danh mục".
   Nếu đã chọn loại thì chỉ liệt kê danh mục cùng loại; chưa chọn thì liệt kê tất cả (đã loại `isDeleted`).
6. Khoảng ngày: một `ListTile` bấm vào mở `showDateRangePicker`
   (`firstDate: DateTime(2020)`, `lastDate: DateTime.parse(businessToday())`, vì không có giao dịch tương lai).
   Subtitle hiển thị `Formatters.date(from) - Formatters.date(to)` hoặc "Tất cả thời gian".
   Có icon xóa (`clearDates`) khi đã chọn.
7. `FilledButton` full width "Áp dụng": `Navigator.pop(context, draft)` với `query` lấy từ controller.

Dùng `AppColors`, `AppSpacing`, `Formatters` có sẵn, không hardcode màu mới.

## 7. Sửa `transaction_list_screen.dart`

Thêm import `../../models/transaction_filter.dart` và `transaction_filter_sheet.dart`.

### 7.1 Chọn nguồn dữ liệu hiển thị

Đầu `build`, sau khi có `provider`:

```dart
final isFiltering = provider.isFiltering;
final list = isFiltering ? provider.searchResults : provider.transactions;
```

### 7.2 Sửa điều kiện body

- `provider.isLoading` giữ `LoadingView`.
- Điều kiện EmptyState đổi từ `provider.transactions.isEmpty` thành
  `provider.transactions.isEmpty && !isFiltering` (không có dữ liệu thật và không đang lọc).
- Nhánh còn lại giữ `RefreshIndicator` + `ListView`, nhưng `children` đổi thành:

```dart
children: [
  if (isFiltering) _buildFilterHeader(context, provider, list.length),
  if (isFiltering && list.isEmpty)
    const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(child: Text('Không tìm thấy giao dịch phù hợp')),
    ),
  ..._groupByDate(list, categories, context),
],
```

`ListView` giữ nguyên `padding` hiện có (đã tính khoảng trống cho FAB).

### 7.3 Header kết quả

```dart
Widget _buildFilterHeader(
    BuildContext context, TransactionProvider provider, int count) {
  return Row(
    children: [
      Expanded(child: Text('Tìm thấy $count giao dịch')),
      TextButton(
        onPressed: () => provider.clearFilter(),
        child: const Text('Xóa lọc'),
      ),
    ],
  );
}
```

### 7.4 Icon lọc trên AppBar (cả hai nhánh `Scaffold`: embedded và không embedded)

Thêm `actions` vào cả hai `AppBar`. Ẩn icon khi chưa có giao dịch nào và không đang lọc.

```dart
actions: [
  if (provider.transactions.isNotEmpty || isFiltering)
    IconButton(
      tooltip: 'Tìm kiếm và lọc',
      icon: Badge(
        isLabelVisible: isFiltering,
        child: const Icon(Icons.filter_list),
      ),
      onPressed: () => _openFilter(context, provider),
    ),
],
```

```dart
Future<void> _openFilter(
    BuildContext context, TransactionProvider provider) async {
  final result = await showTransactionFilterSheet(
    context,
    initial: provider.filter,
    wallets: context.read<WalletProvider>().wallets,
    categories: context.read<CategoryProvider>().categories,
  );
  if (result != null) await provider.applyFilter(result);
}
```

`categories` ở đây là getter đã lọc `isDeleted`. Danh mục hệ thống nằm trong đó nên dropdown vẫn có đủ.

## 8. Kiểm thử

Thêm vào `test/` theo đúng pattern của `transaction_flow_test.dart` (đọc file đó trước để dùng cùng cách khởi tạo DB):

- Repository: tạo vài giao dịch khác loại/ví/danh mục/ngày, kiểm tra `getAll` với `type`, `categoryId`, `from`/`to` trả đúng tập.
- Provider: tạo giao dịch có note "Ăn Phở", gọi `applyFilter(TransactionFilter(query: 'phở'))` phải ra 1 kết quả;
  `query: 'PHỞ'` cũng ra 1; `query: 'pho'` ra 0 (có phân biệt dấu, đúng như thiết kế).
- Sau khi `applyFilter` xong, `provider.transactions` KHÔNG bị thay đổi.
- Xóa một giao dịch khi đang lọc: `searchResults` cập nhật theo (nhờ `load()` gọi `_runSearch()`).
- Chạy `flutter analyze` và `flutter test`, cả hai phải sạch.

## 9. Nghiệm thu thủ công

1. Tab Giao dịch có icon lọc; chưa lọc thì không có badge.
2. Gõ "phở" mở khớp cả "Phở" và "phở". Danh sách chỉ hiện giao dịch khớp, có badge và dòng "Tìm thấy N giao dịch".
3. Chọn "Chi" thì dropdown danh mục chỉ còn danh mục chi; đổi sang "Thu" mà danh mục cũ là loại chi thì danh mục bị reset.
4. Lọc khoảng ngày chỉ ra giao dịch trong khoảng (gồm cả hai đầu mút).
5. Không có kết quả thì hiện "Không tìm thấy giao dịch phù hợp", có nút "Xóa lọc".
6. Đang lọc, xóa một giao dịch thì danh sách cập nhật ngay, bộ lọc vẫn giữ.
7. Kéo để refresh khi đang lọc vẫn giữ bộ lọc.
8. Chuyển sang tab Tổng quan: số liệu và giao dịch gần đây không bị ảnh hưởng bởi bộ lọc.
9. Bàn phím mở thì sheet đẩy lên, nút "Áp dụng" vẫn thấy được.
10. Tắt mạng vẫn tìm/lọc được.

## 10. Hạn chế đã biết (ghi vào báo cáo nếu cần)

- Bộ lọc nằm trong `TransactionProvider` nên mất khi đăng xuất hoặc khởi động lại app.
- Tìm kiếm phân biệt dấu ("pho" không ra "Phở").
- Khi lọc, app đọc toàn bộ giao dịch khớp điều kiện SQL, rồi lọc `note` trong bộ nhớ. Với vài nghìn giao dịch thì ổn.

## 11. Fix bổ sung

- Khi tạo hoàn tất tạo Mục tiêu, màn hình đôi khi bị đứng ở màn hình tạo Mục tiêu, không tự động quay lại màn hình list mục tiêu.
- Và sau khi nạp tiền vào mục tiêu, cũng đứng ở màn hình nạp Mục tiêu, không tự động quay lại màn hình tiến độ.