# GUIDE-UI-budget-status.md

Mục tiêu: thanh trạng thái ngân sách 3 màu Xanh, Vàng, Đỏ và thẻ tổng quan. Không viết logic tính toán trong UI.

## Đọc trước
- lib/core/constants/app_colors.dart. Đã có: primary, danger, divider, textSecondary.
  Nếu thiếu thì thêm `success` (gợi ý 0xFF2E9E5B) và `warning` (gợi ý 0xFFF2B84B). Màu đỏ dùng lại AppColors.danger.
- lib/core/utils/budget_status.dart: BudgetStatus (level, ratio, barFill, remaining) và budgetStatusOf.

## Dữ liệu (đã có, không sửa)
- `BudgetLine.status` cho từng dòng.
- `BudgetProvider.totalLimit`, `totalSpent`, `overallStatus` cho thẻ tổng quan
  (chỉ gồm các danh mục đã đặt ngân sách; nhãn ghi rõ "Các danh mục đã đặt ngân sách").
- Cấm tự so sánh ngưỡng hay tính % trong widget; chỉ đọc từ BudgetStatus.

## Widget dùng chung: lib/widgets/budget_status_bar.dart
- Input: `BudgetStatus status`, `bool showLabel = true`.
- Thanh: LinearProgressIndicator(value: status.barFill), minHeight 10, ClipRRect bo 6px.
  backgroundColor = màu trạng thái với alpha 0.15 (`color.withValues(alpha: 0.15)`).
- Màu: safe -> AppColors.success, warning -> AppColors.warning, exceeded -> AppColors.danger.
- Không dùng màu làm tín hiệu duy nhất. Dòng chữ dưới thanh:
  - safe: "Còn {remaining}"
  - warning: "Sắp hết, còn {remaining}"
  - exceeded: "Vượt {-remaining}" kèm icon cảnh báo, chữ AppColors.danger, đậm
- Bên phải hiện % thực = (ratio * 100).round(), vượt thì vẫn hiện (ví dụ 150%); chỉ thanh bị chặn đầy 100%.
- Tiền định dạng bằng Formatters.currency.

## Sửa budget_list_screen.dart
- Thay khối ClipRRect(LinearProgressIndicator ...) và Row hiển thị "spent / limit" (khoảng dòng 98-125)
  bằng BudgetStatusBar(status: line.status), giữ lại dòng "spent / limit" nhỏ phía trên thanh.
- Thêm thẻ tổng quan ở đầu danh sách (Card, tiêu đề "Tổng ngân sách tháng"):
  BudgetStatusBar(status: provider.overallStatus) + dòng "{totalSpent} / {totalLimit}".
  Chỉ hiện khi provider.lines không rỗng. Chọn cách ít thay đổi cấu trúc nhất
  (ví dụ Column với thẻ tổng quan rồi Expanded(ListView)).
- Sau khi chuyển hết sang `status`, xóa getter `progress` ở BudgetLine và các chỗ import AppColors không còn dùng.

## Hành vi
- Widget chỉ context.watch<BudgetProvider>. Không thêm nút làm mới và không gọi load() trong build.
  Việc nạp lại sau khi đổi giao dịch do LedgerRefresh (tầng logic) lo.
- Animate đổi màu 250ms bằng TweenAnimationBuilder (tùy chọn).

## Nghiệm thu (danh mục Ăn uống, hạn mức 1.000.000)
1. Chi 600.000: xanh, 60%, "Còn 400.000".
2. Thêm 150.000 (750.000): vàng, 75%.
3. Thêm 250.000 (đúng 1.000.000): vẫn vàng, 100%, "Còn 0".
4. Thêm 1: đỏ, thanh đầy, "Vượt 1".
5. Xóa khoản vừa thêm: về vàng ngay khi quay lại màn Ngân sách, không cần thoát app.
6. Sửa giao dịch sang danh mục khác: cả hai ngân sách cập nhật.
7. Xóa ví chứa giao dịch: ngân sách giảm tương ứng.
8. Thẻ tổng quan khớp tổng các dòng ở mọi bước trên.