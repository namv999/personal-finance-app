# GUIDE-UI-UX: Tối ưu trải nghiệm người dùng - ĐỢT 1

Dành cho agent thực hiện. Đọc hết trước khi sửa. Làm theo thứ tự các mục, chạy `flutter analyze` và `flutter test` sau MỖI mục, mục nào lỗi thì sửa xong mới sang mục sau.

## 0. Phạm vi và ràng buộc

- Không đổi logic nghiệp vụ, không đổi đồng bộ (`sync_*`), không đổi backend.
- 5 tab của thanh điều hướng dưới (Tổng quan, Giao dịch, Ví, Mục tiêu, Thêm) GIỮ NGUYÊN tên, thứ tự, icon.
- Schema SQLite chỉ đổi đúng 1 chỗ: thêm `users.avatar_path` ở mục 2.2.
- Không thêm quyền `CAMERA` vào AndroidManifest. `image_picker` mở camera bằng intent hệ thống; khai báo CAMERA mà chưa cấp quyền sẽ làm intent chụp ảnh lỗi.
- Không thêm package mới.
- Mọi chữ hiển thị bằng tiếng Việt, ngắn gọn.
- Mỗi FAB trong app đặt `heroTag: null` để tránh hiệu ứng bay FAB khi chuyển route.
- Khi đổi chữ nút, cập nhật các test đang tìm chữ cũ (`pending_screens_test.dart`, `wallet_delete_dialog_test.dart`, `widget_test.dart`).

Đợt 1 (bắt buộc): mục 1.1 đến 1.5. Đợt 2 (làm sau khi đợt 1 chạy ổn): mục 2.1, 2.2.

## 1. ĐỢT 1

### 1.1 Chuẩn hóa nút trong AlertDialog

Tạo `lib/widgets/app_dialog.dart`:

```dart
Future<bool?> showAppConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String cancelLabel,   // tối đa 12 ký tự
  required String confirmLabel,  // tối đa 12 ký tự
  bool danger = false,           // true: nút phải màu AppColors.danger
});
```

Quy tắc layout, áp dụng cho MỌI dialog trong app:
- Đúng 2 nút: đặt trong một `Row`, hai `Expanded` bằng nhau, cách nhau 12px. Nút trái là `OutlinedButton` (hành động hủy hoặc an toàn), nút phải là `FilledButton` (hành động chính). Cùng chiều cao (48).
- Không dùng `TextButton` căn phải, không xếp nút trên dưới khi chỉ có 2 nút.
- 3 nút trở lên: nút chính full-width ở trên, các nút phụ là `TextButton` full-width xếp dưới, không trộn kiểu layout khác.
- Nhãn nút tối đa 2 từ, không viết hoa toàn bộ, không có dấu `&`.

Áp dụng cho các dialog sau (xem `frontend-audit.md` mục 2):

| File | Nút trái | Nút phải |
|---|---|---|
| `widgets/confirm_delete_dialog.dart` | Hủy | Xóa (danger) |
| `widgets/wallet_delete_dialog.dart` | Hủy | Xóa (danger). Khi đếm ngược: `Xóa (6)` rồi `Xóa`, nút phải disabled trong lúc đếm |
| `screens/pet/pet_screen.dart` (đổi tên) | Hủy | Lưu |
| `screens/pending/pending_inbox_screen.dart` (quyền SMS) | Để sau | Cấp quyền |
| `screens/pending/pending_inbox_screen.dart` (đồng ý xử lý ảnh) | Hủy | Tiếp tục |
| `screens/settings/settings_screen.dart` (reset) | Hủy | Đồng ý |
| `screens/scheduled/due_dialog.dart` (xác nhận bỏ qua) | Quay lại | Bỏ qua |

`screens/scheduled/due_dialog.dart` dialog chính "Giao dịch hẹn trước đến hạn":
- Với mỗi kỳ đến hạn: nút trái `Bỏ qua kỳ này` (thay cho "Hủy", vì "Hủy" dễ bị hiểu là hủy cả lịch), nút phải `Xác nhận`.
- Nếu có nhiều kỳ đến hạn và đang có nút "Bỏ qua tất cả": đặt thành `TextButton` riêng ở cuối dialog, không chen vào hàng 2 nút.
- Câu mô tả "Chỉ bỏ qua kỳ này, chuỗi lặp vẫn chạy tiếp." giữ nguyên.
- Đọc code hiện tại và giữ nguyên hành vi từng nút, chỉ đổi nhãn và bố cục.

Thẻ đề xuất trong Hộp thư chờ duyệt (`pending_inbox_screen.dart`): hai nút bằng nhau, `Bỏ qua` | `Kiểm tra` (thay cho "Kiểm tra & xác nhận"). Màn kiểm tra đã có nút xác nhận nên không lặp lại ở đây.

Nghiệm thu: không còn dialog nào có nút `TextButton` lệch phải đi kèm nút full-width; hai nút bằng nhau về chiều rộng; mọi nhãn nút từ 12 ký tự trở xuống; test đã cập nhật chữ mới.

### 1.2 FAB: animation, nút Chat, bong bóng nhắc, khoảng đệm đáy

Hiện trạng (từ audit): `HomeShell._buildFab` trả FAB trực tiếp. Tab 0 và 1 dùng chung `ValueKey('fab_transaction')` nên chuyển giữa hai tab này không có animation, còn tab Ví và Mục tiêu đổi key nên có.

Sửa trong `lib/screens/home/home_shell.dart`:

1. Bọc nhóm FAB trong `AnimatedSwitcher` (duration 200ms, transition = `ScaleTransition` + `FadeTransition`). Key của nhóm theo CHỈ SỐ TAB: `ValueKey('fab_group_$index')`, để mọi lần chuyển tab đều animate, kể cả 0 và 1.
2. Nhóm FAB là một `Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.end)` gồm, từ trên xuống:
   - Hàng chat: `Row` gồm bong bóng (nếu đang hiện) + FAB chat.
   - Khoảng cách 12px.
   - FAB Add hiện có (giữ nguyên hành động theo từng tab).
3. FAB chat: `FloatingActionButton.small`, `heroTag: null`, icon `Icons.auto_awesome`, nền `AppColors.secondary`, chữ/icon trắng, `tooltip: 'Chat với Bot'`, bấm thì `context.push(AppRoutes.aiChat)`.
4. Hiển thị:
   - Tab 0, 1, 2, 3: hiện nhóm FAB. Tab 4 (Thêm): không hiện gì.
   - FAB Add giữ điều kiện cũ (tab 0/1 ẩn nếu chưa có ví).
   - Danh sách rỗng thì ẩn FAB Add (xem 1.3), FAB chat vẫn hiện.
5. Bong bóng "Chat với Bot!":
   - Hiện mỗi lần mở app (mỗi lần tiến trình khởi động), KHÔNG hiện lại khi chuyển tab hoặc quay lại từ màn khác. Dùng cờ `static bool _chatHintShown` ở cấp file, đặt `true` ngay khi hiện.
   - Hiện sau khi `HomeShell` dựng xong khung hình đầu (delay 600ms), tự ẩn sau 3 giây (fade 200ms). Hủy `Timer` trong `dispose`.
   - Hình dạng: khối bo tròn 12, nền `AppColors.surface`, viền `AppColors.divider`, đổ bóng nhẹ, chữ 13px. Nằm bên TRÁI FAB chat, không che FAB Add.
   - Có dấu `x` nhỏ (icon 14px) ở góc trên phải bong bóng. Vùng chạm tối thiểu 32x32. Bấm `x` thì ẩn ngay.
   - Bấm vào bong bóng thì mở chat luôn (giống FAB chat).
   - Bong bóng không được chặn thao tác của danh sách bên dưới.
6. Tạo `lib/core/constants/app_spacing.dart`:
   ```dart
   class AppSpacing {
     AppSpacing._();
     static const double fabClearanceDouble = 150; // 2 FAB (Add + Chat)
     static const double fabClearanceSingle = 88;  // 1 FAB
   }
   ```
   Áp dụng làm padding đáy để FAB không che nội dung cuối:
   - `home_screen.dart`: thay spacer cuối `SizedBox(height: 24)` bằng `SizedBox(height: AppSpacing.fabClearanceDouble)`.
   - Danh sách embedded của Giao dịch, Ví, Mục tiêu: `fabClearanceDouble`.
   - Màn độc lập có 1 FAB (Danh mục, Ngân sách, Giao dịch hẹn trước, Chuyển khoản): `fabClearanceSingle`.

Nghiệm thu:
- Chuyển Tổng quan sang Giao dịch sang Ví sang Mục tiêu: nhóm FAB scale/fade mỗi lần, không tab nào "đứng yên".
- Tab Thêm không có FAB. Cuộn hết danh sách ở 4 tab đầu: mục cuối không bị che.
- Mở app: bong bóng hiện, 3 giây tự tắt, bấm `x` tắt ngay. Chuyển tab và quay lại thì không hiện lại. Đóng hẳn app, mở lại thì hiện lại.
- Không có cảnh báo "multiple heroes" trong console.

### 1.3 Không trùng nút trên cùng một màn hình

Quy tắc chung: danh sách CÓ dữ liệu thì chỉ có FAB để thêm. Danh sách RỖNG thì chỉ có nút trong `EmptyState`, ẩn FAB. AppBar không đặt nút "thêm".

| Màn | Việc cần làm |
|---|---|
| Ví (`wallet_list_screen.dart`) | Bỏ icon add trên AppBar khi rỗng. Rỗng: chỉ EmptyState CTA, ẩn FAB shell |
| Mục tiêu (`saving_goal_list_screen.dart`) | Như Ví |
| Giao dịch (`transaction_list_screen.dart` + shell) | Rỗng: chỉ EmptyState CTA, ẩn FAB Add |
| Ngân sách (`budget_list_screen.dart`) | Đọc action AppBar: nếu mở form thêm thì bỏ; nếu là chức năng khác thì giữ và thêm nhãn chữ. Rỗng: ẩn FAB |
| Giao dịch hẹn trước (`scheduled_list_screen.dart`) | Rỗng: ẩn FAB, chỉ EmptyState CTA |
| Chuyển khoản (`transfer_list_screen.dart`) | Rỗng: ẩn FAB, chỉ EmptyState CTA |
| Danh mục (`category_list_screen.dart`) | Chỉ FAB. Không đổi |
| Hộp thư chờ duyệt (`pending_inbox_screen.dart`) | Bỏ FAB "Dán tin nhắn" và 2 icon AppBar (camera, tin nhắn). Thay bằng thanh 3 nút có chữ ở đầu body (xem 1.5) |

Cách ẩn FAB theo trạng thái rỗng cho tab trong shell: `HomeShell` đọc `context.watch<TransactionProvider>()` và `SavingGoalProvider` để biết rỗng. Ví không cần xử lý vì app đã chuyển hướng sang `walletCreateRequired` khi không có ví.

Nghiệm thu: với từng màn ở bảng trên, ở cả hai trạng thái (rỗng, có dữ liệu), mỗi chức năng "thêm" chỉ xuất hiện ĐÚNG MỘT nút.

### 1.4 Sắp xếp lại tab "Thêm"

File: `lib/screens/home/more_menu_screen.dart`. Giữ tile hồ sơ ở đầu. Dưới đó chia 4 nhóm, mỗi nhóm có tiêu đề (chữ 13px, đậm, màu `AppColors.textSecondary`, padding trái 16, trên 16, dưới 4), các mục trong nhóm là `ListTile` như hiện tại.

| Nhóm | Mục (theo thứ tự) |
|---|---|
| Nhập nhanh AI | Quét SMS, Chụp hóa đơn, Dán tin nhắn, Hộp thư chờ duyệt (giữ badge số đề xuất) |
| Trợ lý AI | Gợi ý AI, Hỏi đáp AI |
| Tiền bạc | Chuyển khoản, Giao dịch hẹn trước, Danh mục, Ngân sách |
| Khác | Thú cưng, Cài đặt |

Chi tiết:
- Nhóm "Nhập nhanh AI" nổi bật: nền `AppColors.primary` alpha 0.06, bo 16, margin ngang 12, icon trong vòng tròn nền `AppColors.primary` alpha 0.12. Các nhóm còn lại nền thường.
- Subtitle mỗi mục ngắn, một dòng:
  - Quét SMS: `Đọc tin nhắn ngân hàng`
  - Chụp hóa đơn: `Đọc hóa đơn bằng AI`
  - Dán tin nhắn: `Dán nội dung để AI phân tích`
  - Hộp thư chờ duyệt: `Đề xuất chờ bạn kiểm tra`
  - Gợi ý AI: `Dự kiến thu chi tuần/tháng tới`
  - Hỏi đáp AI: `Hỏi về chi tiêu của bạn`
- Route của "Quét SMS": `/pending?action=sms`. Của "Chụp hóa đơn": `/pending?action=image`. Xem cơ chế ở 1.5.
- Đổi tên "Gợi ý AI" subtitle cũ ("Lời khuyên tài chính hàng tháng") vì gợi ý có cả tuần.

Nghiệm thu: tab Thêm có đúng 4 nhóm theo bảng; badge vẫn hiện ở Hộp thư chờ duyệt; không mục nào bị mất; mọi route cũ vẫn mở đúng.

### 1.5 Làm nổi bật tính năng thông minh (SMS, ảnh, dán tin nhắn)

Cơ chế chung: `/pending` nhận tham số `action` = `sms` hoặc `image`. Sửa `app_router.dart` để truyền `s.uri.queryParameters['action']` vào `PendingInboxScreen(autoAction: ...)`. Trong `initState` của màn này, sau khung hình đầu, nếu `autoAction != null` thì chạy ĐÚNG MỘT LẦN hàm quét SMS (`sms`) hoặc luồng chọn ảnh (`image`) đang có sẵn. Không viết lại logic quét, chỉ gọi lại hàm hiện có (gồm xin quyền, hộp thoại đồng ý ảnh). Không chạy lại khi rebuild hoặc khi quay về từ màn khác.

Khi quét SMS từ bên trong Hộp thư, SnackBar kết quả không cần nút "Xem" (đang ở đúng chỗ). Từ nơi khác thì kết quả đã hiển thị ngay vì người dùng đã được chuyển vào Hộp thư, nên cũng không cần.

**A. Thẻ "Nhập nhanh bằng AI" ở Tổng quan** (`home_screen.dart`)
- Đặt ngay sau `_MonthSummaryRow`, trước `_PetStreakRow`.
- Khung nền `AppColors.primary` alpha 0.06, viền `AppColors.primary` alpha 0.25, bo 16, padding 16.
- Tiêu đề `Nhập nhanh bằng AI` (icon `auto_awesome` màu `AppColors.secondary` bên trái), dòng phụ `AI đọc tin nhắn và hóa đơn giúp bạn`.
- Hàng 3 nút bằng nhau (mỗi nút: icon trên, chữ dưới, bo 12): `Quét SMS` (`Icons.sms_outlined`, mở `/pending?action=sms`), `Chụp hóa đơn` (`Icons.receipt_long_outlined`, mở `/pending?action=image`), `Dán tin nhắn` (`Icons.content_paste`, mở `/pending/paste`).
- Dòng dưới cùng, chỉ hiện khi `pendingCount > 0`: `Có N đề xuất chờ duyệt` kèm mũi tên, bấm mở `/pending`.
- Thẻ này KHÔNG thay đổi hành vi FAB Add.

**B. Hộp thư chờ duyệt**: thay 2 icon AppBar và FAB bằng một thanh 3 nút có chữ ở đầu body (cùng kiểu với thẻ A: `Quét SMS`, `Chụp hóa đơn`, `Dán tin nhắn`), danh sách đề xuất nằm bên dưới. Nút "Dán tin nhắn" vẫn mở `/pending/paste?fromInbox=true`. Khi danh sách rỗng, EmptyState nói rõ: `Chưa có đề xuất. Hãy quét SMS, chụp hóa đơn hoặc dán tin nhắn ở trên.`, không thêm nút trùng.

**C. Tab Thêm**: nhóm "Nhập nhanh AI" ở đầu danh sách và có nền nhấn (mục 1.4).

Nghiệm thu:
- Từ Tổng quan bấm `Quét SMS`: vào Hộp thư, hiện hộp xin quyền (lần đầu) rồi quét, kết quả hiện ngay trong danh sách. Quay lại rồi bấm lần nữa thì chạy lại bình thường (mỗi lần mở là một lần chạy, không tự chạy khi chỉ rebuild).
- `Chụp hóa đơn` mở hộp chọn Camera/Thư viện rồi hộp đồng ý xử lý ảnh như cũ.
- Thẻ A hiện đúng số đề xuất chờ duyệt, cập nhật khi xác nhận hoặc bỏ qua một đề xuất.
- Hộp thư không còn icon camera/tin nhắn trên AppBar và không còn FAB.

## 2. ĐỢT 2 (làm sau khi đợt 1 ổn định)

### 2.1 Nhấn giữ mở menu chức năng, kèm nút `⋮`

Mục tiêu: nhấn giữ là cử chỉ ẩn, nên luôn đi kèm một dấu hiệu nhìn thấy được.

Tạo `lib/widgets/item_action_sheet.dart`:

```dart
class ItemAction {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  const ItemAction(this.icon, this.label, this.onTap, {this.danger = false});
}

Future<void> showItemActionSheet(BuildContext context,
    {required String title, required List<ItemAction> actions});
```

`showModalBottomSheet`: tiêu đề là tên mục, các hành động là `ListTile`, hành động `danger` màu `AppColors.danger`. Xóa luôn đi qua `showAppConfirm` (1.1) trước khi thực hiện.

Áp dụng: gắn `onLongPress` VÀ một `IconButton(Icons.more_vert)` ở cuối item, cùng mở một sheet.

| Danh sách | Hành động trong sheet |
|---|---|
| Giao dịch | Sửa, Xóa |
| Ví | Xem chi tiết, Sửa, Xóa (dùng lại `wallet_delete_dialog`) |
| Mục tiêu | Xem chi tiết, Ghi nhận tiết kiệm, Xóa |
| Ngân sách | Các hành động hiện có của item (agent đọc code và liệt kê) |
| Chuyển khoản | Xóa (thay cho `onLongPress` cũ, dùng chung sheet) |
| Giao dịch hẹn trước | Sửa, Xóa |
| Đề xuất trong Hộp thư | Kiểm tra, Bỏ qua |
| Danh mục (lưới) | Chỉ dùng nhấn giữ, không thêm `⋮` vì ô nhỏ. Dưới tiêu đề màn ghi dòng nhỏ `Nhấn giữ để sửa hoặc xóa`. Danh mục hệ thống không có menu |

Không áp dụng cho "Giao dịch gần đây" ở Tổng quan (đang không có tương tác).

Nghiệm thu: mọi danh sách ở bảng có thể mở sheet bằng nhấn giữ hoặc bấm `⋮`, hai cách cho cùng kết quả; xóa luôn có hộp xác nhận; tap thường trên item vẫn giữ hành vi cũ.

### 2.2 Avatar từ Camera hoặc Thư viện (chỉ lưu local)

Đây là mục DUY NHẤT đổi schema.

1. `core/database/db_helper.dart`: tăng version lên 7. Trong `onUpgrade` thêm `if (oldVersion < 7) { ALTER TABLE users ADD COLUMN avatar_path TEXT }`. Thêm cột `avatar_path TEXT` vào `CREATE TABLE users` của `onCreate`. Không đụng nhánh upgrade cũ.
2. `models/user.dart`: thêm `avatarPath` (nullable) vào field, `fromMap`, `toMap`, `copyWith` (cần phân biệt "không đổi" và "xóa ảnh"; dùng tham số riêng `clearAvatar`).
3. Không thêm `avatar_path` vào đồng bộ. Bảng `users` không nằm trong sync, và `password_hash`, avatar không được gửi lên server.
4. `AuthRepository.updateProfile` ghi toàn bộ `user.toMap()` nên phải đảm bảo `avatarPath` đi theo; kiểm tra `_upsertLocalUser` (đăng nhập online) không làm mất `avatar_path` của dòng đã có.
5. Lưu ảnh: sau khi `ImagePicker().pickImage(source: ..., imageQuality: 80, maxWidth: 512, maxHeight: 512)`, copy vào `getApplicationDocumentsDirectory()/avatars/<userId>.jpg` (ghi đè ảnh cũ), lưu đường dẫn vào `users.avatar_path`. Gọi `FileImage(file).evict()` để ảnh mới hiện ngay vì tên file không đổi.
6. `profile_screen.dart`: avatar tròn ở đầu form, có biểu tượng máy ảnh nhỏ ở góc. Bấm vào mở bottom sheet 3 mục: `Chụp ảnh`, `Chọn từ thư viện`, `Xóa ảnh` (chỉ hiện khi đã có ảnh; danger). Không xin quyền camera trong Dart (giữ cách làm như luồng phân tích ảnh).
7. Tạo widget dùng chung `lib/widgets/user_avatar.dart` (tham số: `AppUser?`, `radius`): hiện ảnh nếu `avatarPath` tồn tại và file còn; nếu không thì hiện chữ cái đầu của tên như hiện tại. Dùng ở màn hồ sơ và tile hồ sơ ở đầu tab Thêm.
8. Khi đăng xuất hoặc đổi tài khoản, avatar luôn theo `userId`, không dùng chung giữa hai tài khoản.

Nghiệm thu:
- Cài đè bản mới lên bản cũ (không gỡ app): app mở bình thường, dữ liệu cũ còn nguyên, không crash vì thiếu cột.
- Chọn ảnh từ Camera và Thư viện đều đổi avatar ở hồ sơ và tab Thêm ngay lập tức.
- Thoát hẳn app và mở lại: avatar còn. Xóa ảnh thì quay về chữ cái đầu.
- File ảnh bị xóa tay thì app không crash mà hiện chữ cái đầu.

## 3. Danh sách kiểm tra cuối

- [ ] `flutter analyze` sạch, `flutter test` xanh (đã cập nhật chữ trong test).
- [ ] 5 tab dưới không đổi; tab Thêm có 4 nhóm đúng bảng 1.4.
- [ ] Mọi dialog 2 nút đều cân xứng, nhãn ngắn (1.1).
- [ ] FAB có animation ở cả 4 tab; chat FAB và bong bóng đúng quy tắc 1.2.
- [ ] Mỗi màn chỉ có một nút "thêm" (1.3).
- [ ] Thẻ "Nhập nhanh bằng AI" ở Tổng quan, thanh 3 nút ở Hộp thư, nhóm nổi bật ở Thêm (1.5).
- [ ] (Đợt 2) Menu nhấn giữ và `⋮`; avatar; cài đè không mất dữ liệu.
- [ ] Không có thay đổi ngoài phạm vi: không đổi sync, backend, các màn form.

## 4. Báo cáo lại cho người giao việc

Sau mỗi mục, ghi ngắn: file đã sửa, file mới, điểm chưa chắc, và các test đã cập nhật. Nếu phát hiện code thực tế khác với mô tả trong guide (ví dụ action AppBar của Ngân sách, các nút của `due_dialog`), nêu rõ chỗ khác và cách đã xử lý, không tự đoán.