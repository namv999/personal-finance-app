# GUIDE-UI-P3.2: dán tin nhắn và hộp thư chờ duyệt

Không sửa logic trong repository/provider. Chỉ gọi các hàm của PendingProvider.
PendingProvider đã gắn với user hiện tại qua ChangeNotifierProxyProvider; UI không truyền userId vào các hàm. Danh sách ví lấy từ WalletProvider.

## Màn 1: PasteMessageScreen

- TextField nhiều dòng, tối đa 1000 ký tự, nút Phân tích.
- Ghi rõ số tài khoản, số điện thoại và số dư được che trước khi gửi.
- Bấm nút gọi submitText(text); trong lúc chờ disable nút và hiện trạng thái đang phân tích.
- Kết quả PasteOutcome:
  - invalid: yêu cầu nhập nội dung không quá 1000 ký tự.
  - duplicate: tin nhắn đã có trong hộp thư.
  - parsed: chuyển sang PendingInboxScreen.
  - queued: đọc provider.lastRun và báo offline, giới hạn lượt, AI tạm lỗi hoặc cần thử lại. Tin vẫn được lưu trên máy.

## Màn 2: PendingInboxScreen

- Khi mở màn, gọi load() rồi retryNeedsAi(). Retry nạp lại danh sách sau khi thử xử lý. Pull-to-refresh gọi retryNeedsAi().
- Mục Đề xuất cần bạn xác nhận (provider.pending) hiển thị số tiền, loại, ngày, ghi chú, danh mục và confidence.
- Mục Đang chờ phân tích (provider.needsAi) chỉ hiển thị maskedContent, có nút thử lại và bỏ.
- Nút Kiểm tra & xác nhận mở bottom sheet sửa số tiền, ví, danh mục cùng loại giao dịch, ngày không ở tương lai và ghi chú.
- Xác nhận gọi provider.confirm(pendingId, walletId, amount, type, date, note, categoryId). Bỏ qua/Bỏ gọi provider.reject(pendingId).
- Sau xác nhận gọi LedgerRefresh.all(context).run() rồi báo giao dịch đã tạo.
- Danh sách trống dùng EmptyState có sẵn. Không hiển thị số dư hoặc số dư dự kiến trong hộp thư.

## Lối vào

- Menu Thêm có mục Hộp thư chờ duyệt với badge pendingCount và mục Dán tin nhắn.
- Routes: AppRoutes.pendingInbox và AppRoutes.pasteMessage.
