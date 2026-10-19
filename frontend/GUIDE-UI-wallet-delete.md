# GUIDE-UI-wallet-delete.md

Mục tiêu: UI cho quyết định "xóa ví có cascade". Không đổi logic repository.

## Dữ liệu
- `WalletRepository.previewDelete(walletId)` trả `WalletDeletePreview`
  (transactionCount, incomeTotal, expenseTotal, transferCount,
  counterparts[walletName, balanceDelta], deletedGoals[], affectedGoals[]).
- `WalletRepository.delete(walletId)` thực hiện cascade (đã atomic).
- Thêm vào `WalletProvider`: `previewDelete(id)` gọi repo. `deleteWallet(id)` giữ nguyên.

## Hộp thoại xác nhận xóa (thay confirmDelete trong wallet_form_screen::_delete)
1. Gọi previewDelete, hiển thị loading ngắn, rồi mở dialog.
2. Nội dung (chỉ hiện dòng có dữ liệu):
   - "{n} giao dịch thu/chi sẽ bị xóa (tổng thu X, tổng chi Y), số liệu thống kê sẽ thay đổi"
   - "{m} lượt chuyển tiền sẽ bị xóa"
   - Mỗi ví đối ứng: "Ví {tên}: số dư thay đổi {+/-} đ" (đỏ nếu âm, xanh nếu dương)
   - "Mục tiêu sẽ bị xóa: ..." và "Tiến độ mục tiêu thay đổi: ..."
3. Nút "Đồng ý xóa" bị vô hiệu và hiển thị đếm ngược "Đồng ý xóa (6)" giảm mỗi giây
   (Timer.periodic, hủy timer trong dispose). Hết 6 giây mới bật nút. Luôn áp dụng.
4. Nút "Hủy", chạm ngoài dialog, hoặc nút Back: trả false, KHÔNG gọi deleteWallet.
5. Khi đồng ý: gọi deleteWallet(id), rồi reload WalletProvider, TransactionProvider,
   TransferProvider, SavingGoalProvider, PetStreakProvider.
   Sau đó: nếu không còn ví nào -> context.go(walletCreateRequired), ngược lại -> AppRoutes.wallets.

## Bắt buộc tạo ví khi không còn ví
- Route mới `/wallets/create-required` dùng lại form tạo ví, ẩn nút Back và nút xóa.
- GoRouter redirect: user đã đăng nhập, danh sách ví đã tải xong (có cờ loaded để tránh nháy)
  và rỗng -> chuyển về route này, trừ khi đang ở route này hoặc màn hình đăng xuất.
- Tạo ví xong -> về Home. Chặn các nút thêm thu/chi/chuyển khoản khi chưa có ví.

## Form thu/chi và chuyển khoản
- Date picker: lastDate = businessToday() (UTC+7), initialDate không lớn hơn lastDate.
- Hiển thị lỗi từ repository bằng SnackBar (đã có sẵn, chỉ bỏ tiền tố "Exception: ").

## Form chuyển khoản và mục tiêu
- Dropdown goal chỉ hiện goal tương thích: goal.walletId == null, hoặc bằng ví nguồn, hoặc bằng ví đích.
- Khi chọn ví nguồn/đích trùng ví của đúng một goal, tự chọn goal đó (người dùng đổi sang "Không liên kết" được).
- Nhãn gợi ý: ví đích = ví goal -> "Nạp vào mục tiêu"; ví nguồn = ví goal -> "Rút khỏi mục tiêu".
- Ghi chú dưới dropdown: "Chuyển tiền không gắn mục tiêu không tính vào tiến độ và chuỗi tiết kiệm".

## Màn hình mục tiêu / pet
- Hiển thị saved_amount và status như repository trả về (tiến độ >= 0, tự quay về đang thực hiện khi rút).
- Streak hiển thị current_streak_days trực tiếp (đã về 0 khi hết hạn).