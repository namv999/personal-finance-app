# Kiểm kê frontend hiện tại

Phạm vi đọc: `frontend/lib/`, `frontend/android/app/src/main/AndroidManifest.xml`. Đây là mô tả tĩnh những gì đang có trong mã, không suy luận thêm ngoài các callback/route được khai báo.

## 1. Các màn hình trong `lib/screens`

Routes được đối chiếu theo `lib/routes/app_router.dart` và `lib/core/constants/app_routes.dart`. “—” nghĩa là không thấy khai báo tương ứng tại màn đó. Hành động item ghi theo callback trực tiếp.

| File | Route | AppBar actions | FAB | Nội dung chính; kiểu danh sách/item tap |
|---|---|---|---|---|
| `screens/splash_screen.dart` | `/` | — | — | Scaffold splash/loading. |
| `screens/auth/login_screen.dart` | `/login` | — | — | Form đăng nhập; nút đăng ký chuyển `/register`. |
| `screens/auth/register_screen.dart` | `/register` | — | — | Form đăng ký; nút submit. |
| `screens/home/home_shell.dart` | `/home` | — | FAB ở shell: tab Tổng quan/Giao dịch thêm giao dịch, Ví thêm ví, Mục tiêu thêm mục tiêu | `IndexedStack`; NavigationBar 5 tab. Chi tiết ở mục 8, 11. |
| `screens/home/home_screen.dart` | qua `/home` tab 0 | — | Không khai báo trong màn; shell thêm FAB giao dịch | `RefreshIndicator` + `ListView`; thứ tự card ở mục 14. “Ví của tôi” → `/wallets`; thẻ thú cưng → `/pet`; “Xem tất cả” giao dịch → `/transactions`; giao dịch gần đây không có `onTap`. |
| `screens/home/more_menu_screen.dart` | `/home` tab 4 | — | — | `ListView` chứa profile và menu; tap mở route item. Danh sách mục ở mục 4. |
| `screens/wallets/wallet_list_screen.dart` | `/wallets` (tab 2 shell) | Icon add → `/wallets/add` khi dữ liệu rỗng | Màn độc lập có add → `/wallets/add`; embedded thì FAB do shell | `ListView.separated`, `Card`; ví tap → `/wallets/:id`. EmptyState có action add. |
| `screens/wallets/wallet_form_screen.dart` | `/wallets/add`, `/wallets/create-required`, `/wallets/edit/:id` | Khi edit icon delete → xóa ví | — | Form trong `Scaffold`/`SingleChildScrollView`; lưu, chọn icon/màu; không list item. |
| `screens/wallets/wallet_detail_screen.dart` | `/wallets/:id` | edit → `/wallets/edit/:id`; delete → xác nhận/xóa | — | `ListView`, `Card`; giao dịch tap → `/transactions/edit/:id`. |
| `screens/categories/category_list_screen.dart` | `/categories` | — | add → `/categories/add` | `GridView` trong `_CategoryGrid`; danh mục hệ thống không mở; danh mục người dùng tap → `/categories/edit/:id`. |
| `screens/categories/category_form_screen.dart` | `/categories/add`, `/categories/edit/:id` | edit có delete | — | Form; lưu/xóa. |
| `screens/transactions/transaction_list_screen.dart` | `/transactions` (tab 1 shell) | — | màn độc lập có add nếu có ví; embedded thì shell thêm giao dịch | `ListView` dựng cards; giao dịch tap → `/transactions/edit/:id`; EmptyState có action. |
| `screens/transactions/transaction_form_screen.dart` | `/transactions/add`, `/transactions/edit/:id` | edit có delete | — | Form; nếu thiếu ví có nút thêm ví → `/wallets/add`; submit/xóa. |
| `screens/transfers/transfer_list_screen.dart` | `/transfers` | — | add nếu có ít nhất 2 ví → `/transfers/add` | `ListView.separated`, `Card`; long-press mở xử lý xóa/xác nhận (mục 3). Empty action thêm/chọn ví hoặc chuyển khoản. |
| `screens/transfers/transfer_form_screen.dart` | `/transfers/add` (có query `goalId`) | — | — | Form chuyển khoản; nút thêm ví → `/wallets/add`; submit. |
| `screens/saving_goals/saving_goal_list_screen.dart` | `/saving-goals` (tab 3 shell) | add → `/saving-goals/add` khi empty | màn độc lập có add; embedded thì shell thêm mục tiêu | `ListView.separated`, `Card`; mục tiêu tap → `/saving-goals/:id`. Empty action add. |
| `screens/saving_goals/saving_goal_form_screen.dart` | `/saving-goals/add` | — | — | Form; chọn ngày, lưu. |
| `screens/saving_goals/saving_goal_detail_screen.dart` | `/saving-goals/:id` | delete | — | `ListView`, card/progress `Stack`; nút ghi nhận tiền tiết kiệm mở `/transfers/add?goalId=...`; không thấy tap item list. |
| `screens/budgets/budget_list_screen.dart` | `/budgets` | action quản lý/đặt ngân sách theo callback trong appbar | add → `/budgets/add` | danh sách `ListView.separated`, `Card`, kèm tổng quan; item không có callback tap trong list card. Empty action add. |
| `screens/budgets/budget_form_screen.dart` | `/budgets/add` | — | — | Form ngân sách; nút lưu. |
| `screens/pet/pet_screen.dart` | `/pet` | — | — | `ListView`, `Card`; avatar/tên pet tap mở dialog đổi tên. |
| `screens/ai_suggestions/ai_suggestion_screen.dart` | `/ai-suggestions` | không thấy action | — | `ListView`, các `Card` cho dữ liệu/gợi ý; nội dung không có callback tap item. |
| `screens/ai_chat/ai_chat_screen.dart` | `/ai-chat` | có action ở app bar (reset/xóa hội thoại theo callback) | — | Danh sách tin nhắn `ListView`/`ListView.builder`, vùng nhập và gửi. |
| `screens/pending/pending_inbox_screen.dart` | `/pending` | icon action quét SMS/ảnh theo callback | nút extended → `/pending/paste?fromInbox=true` | `ListView`; pending card tap xác nhận; mục cần AI có hành động phân tích; chi tiết mục 9, 13. |
| `screens/pending/paste_message_screen.dart` | `/pending/paste` (fromInbox query tùy chọn) | — | — | `ListView` form dán nội dung; nút phân tích/lưu. |
| `screens/scheduled/scheduled_list_screen.dart` | `/scheduled` | — | add → `/scheduled/add` | `ListView.builder`, `Card`; item tap → `/scheduled/edit/:id`; có nút thao tác trạng thái trong card. |
| `screens/scheduled/scheduled_form_screen.dart` | `/scheduled/add`, `/scheduled/edit/:id` | edit có delete | — | Form; ngày/giờ/kết thúc có picker, nút lưu. |
| `screens/scheduled/due_dialog.dart` | dialog gọi lúc khởi tạo/kiểm tra đến hạn, không phải route | — | — | Dialog nhắc giao dịch đến hạn; action xử lý/bỏ qua và xác nhận. |
| `screens/settings/settings_screen.dart` | `/settings` | — | — | `ListView` các tùy chọn; profile → `/profile`; các action sync/reset và dialog xác nhận. |
| `screens/settings/profile_screen.dart` | `/profile` | — | — | Form; field ở mục 5. |

## 2. Dialog, bottom sheet, SnackBar có action

“Thứ tự” là thứ tự khai báo trong `actions` hoặc thứ tự lựa chọn hiển thị.

| File | Tiêu đề/nội dung | Nút/action theo thứ tự |
|---|---|---|
| `widgets/confirm_delete_dialog.dart` | “Xác nhận xóa”; `Bạn có chắc muốn xóa "$itemLabel"? Hành động này không thể hoàn tác.` | 1. Hủy  2. Xóa |
| `widgets/wallet_delete_dialog.dart` | “Xác nhận xóa ví”; nội dung xác nhận tên ví, dữ liệu ảnh hưởng (nếu có) và thời gian chờ 6 giây khi có dữ liệu cascade | 1. Hủy  2. Đồng ý xóa (đếm ngược/disable đến hết) |
| `screens/pet/pet_screen.dart` | Dialog đổi tên thú cưng (title “Đổi tên thú cưng”, input tên hiện tại) | 1. Hủy  2. Lưu |
| `screens/pending/pending_inbox_screen.dart` | Dialog xin phép đọc SMS; nội dung giải thích quyền | 1. Để sau  2. Cấp quyền (mở yêu cầu quyền) |
| `screens/pending/pending_inbox_screen.dart` | Bottom sheet chọn nguồn ảnh | 1. Chụp ảnh (camera)  2. Chọn từ thư viện (gallery) |
| `screens/pending/pending_inbox_screen.dart` | Dialog đồng ý phân tích ảnh/đưa ảnh cho AI; nội dung nêu xử lý ảnh | 1. Hủy  2. Tiếp tục |
| `screens/pending/pending_inbox_screen.dart` | Bottom sheet hành động của một đề xuất (không phải mọi mục có action button) | Các lựa chọn thay đổi theo trạng thái; xem hàm sheet trong file. |
| `screens/pending/pending_inbox_screen.dart` | SnackBar “Đã quét SMS”, có action | “Xem” → mở hộp thư chờ duyệt (`/pending`) |
| `screens/settings/settings_screen.dart` | Dialog xác nhận thao tác reset dữ liệu/cursor; title “Xác nhận” | 1. Hủy  2. Xác nhận |
| `screens/scheduled/due_dialog.dart` | Dialog xác nhận bỏ qua giao dịch đến hạn; nội dung xác nhận | 1. Hủy  2. Bỏ qua |
| `screens/scheduled/due_dialog.dart` | Dialog chính các giao dịch đến hạn, không barrier dismissible; hiển thị các giao dịch | 1. Bỏ qua tất cả  2. Hoãn/xử lý từng mục  3. Hoàn tất (các nút cuối theo dữ liệu) |
| `screens/scheduled/scheduled_list_screen.dart` | SnackBar trạng thái sau thao tác giao dịch hẹn trước; action nếu cần xem trạng thái được khai báo trong SnackBar tại dòng tương ứng | Action hiển thị trong source là theo callback item. |

Các SnackBar không có `SnackBarAction` cũng xuất hiện để báo lỗi/thành công tại các form, settings, profile, pending inbox, paste message, AI suggestion, transfer và category. Chúng không có nhãn nút.

## 3. Long press, dismiss, popup menu, swipe

- `screens/transfers/transfer_list_screen.dart`: `onLongPress` trên card chuyển khoản; gọi xử lý xóa/xác nhận chuyển khoản.
- Toàn bộ `lib/`: không thấy `Dismissible`, `PopupMenuButton`, `Slidable` hoặc widget swipe action.

## 4. Menu “Thêm”

`lib/screens/home/more_menu_screen.dart` xây danh sách theo thứ tự:

1. Chuyển khoản — `/transfers`
2. Danh mục — `/categories`
3. Ngân sách — `/budgets`
4. Giao dịch hẹn trước — `/scheduled`
5. Thú cưng — `/pet`
6. Gợi ý AI — `/ai-suggestions`
7. Hỏi đáp AI — `/ai-chat`
8. Hộp thư chờ duyệt — `/pending` (badge số pending)
9. Dán tin nhắn — `/pending/paste`
10. Cài đặt — `/settings`

Đầu danh sách còn có tile hồ sơ, tap → `/profile`. Tất cả item dùng `ListTile.onTap` và `context.push(item.route)`.

## 5. Hồ sơ, model User và bảng users

- `screens/settings/profile_screen.dart`: hiển thị avatar chữ cái đầu tên, Họ và tên (có thể sửa; validate bắt buộc), Email (read-only), Thu nhập hàng tháng (tùy chọn, nhập số), nút “Lưu thay đổi”. Không có field mật khẩu trong form.
- `models/user.dart` (`AppUser`): `id`, `fullName`, `email?`, `passwordHash`, `monthlyIncome?`, `createdAt`, `updatedAt?`, `isDeleted`; có map/JSON và `copyWith` cho tên/email/thu nhập.
- `core/database/db_helper.dart`: DB version hiện tại **6**; có callback `onUpgrade`. Các nhánh: `<2` thêm `wallets.opening_balance` và phục hồi giá trị; `<3` chuẩn hóa/khử trùng lặp ngân sách; `<4` thêm `transactions.source`, tạo bảng pending, chuẩn hóa email; `<5` tạo lại bảng AI suggestions; `<6` tạo bảng scheduled transactions. Mỗi lần upgrade cuối cùng tạo index.
- `users` khi tạo mới: `id TEXT PRIMARY KEY`, `full_name TEXT NOT NULL`, `email TEXT UNIQUE`, `password_hash TEXT NOT NULL`, `monthly_income INTEGER`, `created_at TEXT DEFAULT CURRENT_TIMESTAMP`, `updated_at TEXT`, `is_deleted INTEGER DEFAULT 0`.

## 6. Widgets dùng chung

| File | Mục đích |
|---|---|
| `widgets/app_text_field.dart` | TextFormField chuẩn có label, controller, validator, keyboard, prefix, readOnly/onTap. |
| `widgets/budget_status_bar.dart` | Thanh tiến độ ngân sách, màu trạng thái và nhãn số tiền/phần trăm. |
| `widgets/confirm_delete_dialog.dart` | Hàm dialog xác nhận xóa dùng chung. |
| `widgets/empty_state.dart` | Trạng thái danh sách trống, icon/title/subtitle và action tùy chọn. |
| `widgets/icon_color_picker.dart` | Chọn icon và màu cho ví/danh mục; kèm chuyển đổi tên icon/hex. |
| `widgets/loading_view.dart` | Vòng loading căn giữa. |
| `widgets/wallet_delete_dialog.dart` | Xem trước dữ liệu bị ảnh hưởng khi xóa ví, dialog cascade và phối hợp xóa/làm mới dữ liệu. |

Có dialog dùng chung xác nhận xóa và dialog riêng cho xóa ví. Không thấy widget menu dùng chung; menu “Thêm” nằm trong screen riêng.

## 7. Theme, màu và spacing

- `core/theme/app_theme.dart`: Material 3; `AppBarTheme` nền background, foreground textPrimary, elevation 0, title 20px bold; `CardThemeData` surface, elevation 0, bo 16, viền divider, margin zero; `InputDecorationTheme` filled, padding ngang 16/dọc 14, bo 12, focused border primary 1.5; `ElevatedButtonThemeData`: primary nền, trắng chữ, min height 50, bo 12, elevation 0; `FloatingActionButtonThemeData`: primary/trắng; `BottomNavigationBarThemeData` surface/primary/textSecondary, fixed; divider/text theme.
- `DialogTheme`: không được định nghĩa trong app theme.
- `app_colors.dart`: primary `#2E7D6B`, primaryDark `#1E5548`, secondary `#F2A65A`, background `#F7F8FA`, surface trắng; income `#2E9E5B`, expense/danger `#E0554F`, transfer `#4C7DF0`, text primary `#1B1E23`, secondary `#6B7280`, divider `#E5E7EB`, warning `#F2B84B`, success `#2E9E5B`; palette picker có 8 màu.
- Không có bộ hằng spacing tập trung trong `app_theme.dart`/`app_colors.dart`; khoảng cách được khai báo trực tiếp bằng `SizedBox`/`EdgeInsets` tại widget (ví dụ padding trang 16, card 14–20).

## 8. Bottom navigation và FAB chồng danh sách

`home_shell.dart` khai 5 tab: Tổng quan (0), Giao dịch (1), Ví (2), Mục tiêu (3), Thêm (4). Bốn tab đầu nạp màn hình con bằng `IndexedStack`; tab “Thêm” là `MoreMenuScreen`.

FAB tại shell: Tổng quan/Giao dịch → `/transactions/add` (ẩn nếu chưa có ví); Ví → `/wallets/add`; Mục tiêu → `/saving-goals/add`; tab Thêm không có. Embedded list của Giao dịch có `ListView` với padding dọc `top:12, bottom:6`, Ví và Mục tiêu dùng `ListView.separated` padding mặc định/không có padding đáy riêng. Home dashboard `ListView(padding: EdgeInsets.all(16))`, không có phần bù đáy riêng cho FAB. Vì vậy source không đặt padding đáy chuyên dụng để né FAB ở các list tab.

## 9. Phân tích ảnh, quyền và manifest

- `screens/pending/pending_inbox_screen.dart` import `image_picker` và `permission_handler`; bottom sheet cho chọn camera hoặc gallery; `ImagePicker().pickImage(source: ..., imageQuality: ...)` lấy file ảnh; sau đó dialog xin xác nhận trước xử lý ảnh.
- `permission_handler` trong luồng này được dùng với `Permission.sms` thông qua `core/sms/sms_reader.dart`; không thấy xin permission camera/gallery trong Dart flow. Picker mở UI camera/gallery của hệ thống.
- `core/sms/sms_reader.dart` đọc status/request SMS; `providers/pending_provider.dart` kiểm tra quyền trước khi gọi reader/quét.
- `android/app/src/main/AndroidManifest.xml` khai báo `INTERNET`, `READ_SMS`, `POST_NOTIFICATIONS`, `RECEIVE_BOOT_COMPLETED`, `VIBRATE`, `USE_EXACT_ALARM`, `SCHEDULE_EXACT_ALARM` (maxSdkVersion 32). Queries có `IMAGE_CAPTURE`; không khai báo quyền CAMERA hoặc quyền đọc media/storage trong manifest main.

## 10. Màn có FAB và thêm ở AppBar/body cùng chức năng

- Danh mục: FAB add; thêm chủ yếu qua FAB (empty action cũng add).
- Ngân sách: FAB add và action đặt ngân sách trong AppBar/empty state cùng mở form thêm.
- Ví: màn standalone có FAB add và AppBar add ở trạng thái danh sách rỗng; empty action add. Embedded tab: FAB shell, empty action trong body.
- Mục tiêu: FAB add và AppBar add khi empty; empty action cũng add. Embedded tab: FAB shell, empty action trong body.
- Giao dịch: FAB add khi có ví, empty state body action thêm giao dịch; embedded FAB thuộc shell.
- Giao dịch hẹn trước: FAB add và empty state action add.
- Hộp thư chờ duyệt có FAB dán tin nhắn và action AppBar quét, nhưng đây là tác vụ khác nhau, không tính cùng chức năng thêm.

## 11. FAB của bốn tab và animation

- Tổng quan: `HomeScreen` không có FAB riêng; `HomeShell._buildFab` trả `FloatingActionButton` giao dịch.
- Giao dịch: `TransactionListScreen(embedded:true)` không tự dựng FAB; `HomeShell._buildFab` trả cùng FAB giao dịch.
- Ví: `WalletListScreen(embedded:true)` bỏ FAB riêng; shell dựng FAB ví.
- Mục tiêu: `SavingGoalListScreen(embedded:true)` bỏ FAB riêng; shell dựng FAB mục tiêu.
- Cả bốn tab con đều trả `Scaffold` (có nested Scaffold trong Scaffold shell). Shell sử dụng `IndexedStack`.
- Mã gọi trực tiếp `_buildFab` làm thay đổi child FAB theo tab; không bọc bằng `AnimatedSwitcher`, không khai `Hero`/`heroTag` tùy chỉnh, không có animation riêng. `FloatingActionButton` mặc định Flutter có hero mặc định, nhưng ở đây FAB giao dịch tại tab 0 và 1 có cùng `ValueKey('fab_transaction')`, nên child/key ổn định khi chuyển giữa Tổng quan và Giao dịch; vì vậy không đổi FAB để kích hoạt chuyển đổi. Ví và Mục tiêu dùng key khác (`fab_wallet`, `fab_saving_goal`) và hành động/child khác nên FAB đổi khi chuyển tab, Flutter có thể animate sự thay thế mặc định. Không có `AnimatedSwitcher` explicit trong source.

## 12. Tất cả FAB / Location / Hero tag

Khai báo `floatingActionButton` hoặc `FloatingActionButton`:

- `screens/home/home_shell.dart`: FAB tab-dependent; key `fab_transaction`, `fab_wallet`, `fab_saving_goal`.
- `screens/categories/category_list_screen.dart`: add category.
- `screens/budgets/budget_list_screen.dart`: add budget.
- `screens/wallets/wallet_list_screen.dart`: add wallet (khi non-embedded).
- `screens/transactions/transaction_list_screen.dart`: add transaction (khi non-embedded, có ví).
- `screens/transfers/transfer_list_screen.dart`: add transfer (từ 2 ví).
- `screens/saving_goals/saving_goal_list_screen.dart`: add goal (khi non-embedded).
- `screens/scheduled/scheduled_list_screen.dart`: add scheduled transaction.
- `screens/pending/pending_inbox_screen.dart`: FAB.extended mở paste message.

Không thấy `floatingActionButtonLocation` tùy chỉnh hay `heroTag` được truyền tường minh. FAB ở home shell chỉ có `ValueKey`, đây không phải heroTag.

## 13. Luồng SMS, ảnh, dán tin nhắn

- Quét SMS: action ở AppBar hộp thư chờ duyệt `/pending` → `PendingProvider` (provider `lib/providers/pending_provider.dart`) kiểm tra SMS permission và gọi `SmsReader` (`lib/core/sms/sms_reader.dart`; lọc ở `lib/core/sms/bank_sms_filter.dart`) → lưu pending → hiện SnackBar action “Xem”/ở lại hộp thư. Route kết quả là `AppRoutes.pendingInbox` (`/pending`), UI kết quả `screens/pending/pending_inbox_screen.dart`.
- Ảnh: action AppBar trong `/pending` → bottom sheet camera/gallery → ImagePicker → xác nhận → phân tích/tạo pending trong inbox.
- Dán tin nhắn: menu “Thêm” → `/pending/paste`; ngoài ra FAB extended trên `/pending` mở `/pending/paste?fromInbox=true`. Màn xử lý là `screens/pending/paste_message_screen.dart`; khi mở từ inbox có thể quay lại inbox sau khi xử lý.

## 14. Dashboard `home_screen.dart`

Từ trên xuống: `Scaffold` → `AppBar` lời chào → `RefreshIndicator` → loading hoặc `ListView` padding 16:

1. `_BalanceCard` tổng số dư + nút “Ví của tôi”.
2. `_MonthSummaryRow`: hai thẻ thu nhập tháng / chi tiêu tháng.
3. `_PetStreakRow`: tên/level thú cưng và chuỗi tiết kiệm.
4. `_SpendingByCategoryCard`: biểu đồ chi tiêu theo danh mục + legend list.
5. `_RecentTransactionsCard`: tối đa 5 giao dịch gần đây + nút “Xem tất cả”.
6. `SizedBox(height:24)` kết thúc list.

Padding đáy hiện có là padding tổng thể 16 và spacer cuối 24; không có bottom inset/phần đệm bổ sung riêng theo chiều cao FAB.

## 15. SharedPreferences và cờ lần đầu/gợi ý

Trong `lib/` không thấy key SharedPreferences dùng để lưu cờ lần đầu hoặc trạng thái đã hiện gợi ý. Các key đọc/ghi được thấy dùng cho `current_user_id`, token và `sync_cursor_$userId` (phục vụ đăng nhập/đồng bộ), không phải cờ onboarding/gợi ý.

## 16. Overlay, Tooltip, OverlayEntry, Stack

- Không thấy gọi trực tiếp `Overlay`, `OverlayEntry` hoặc `Tooltip` trong `lib/`.
- `screens/saving_goals/saving_goal_detail_screen.dart` dùng `Stack` để xếp lớp nội dung/progress.
- `screens/home/home_shell.dart` dùng `IndexedStack` để giữ các tab.
- `Badge` trong menu pending tạo nhãn số trên item; không phải mã Overlay thủ công.
