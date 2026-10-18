# Handoff đồ án Personal Finance App cho Claude Agent

> Tài liệu tổng hợp trạng thái mã nguồn tại nhánh `fix/logic-transfer`, cập nhật ngày 2026-10-18. Nội dung được chuyển từ repo `DoAnFlutter` sang monorepo `personal-finance-app`; các đường dẫn `lib/...`, `pubspec.yaml` và `pubspec.lock` bên dưới tính từ thư mục `frontend/`. Đây là mô tả theo mã nguồn/config tại thời điểm đồng bộ, không phải xác nhận rằng mọi luồng đã chạy đúng. Cần đọc mã trước khi sửa và cập nhật tài liệu khi kiến trúc thay đổi.

## 1. Mục tiêu và trạng thái tổng quan

Ứng dụng Flutter quản lý thu chi cá nhân, hiện thiết kế theo hướng **offline-first**: SQLite là nguồn dữ liệu chạy thực tế; Provider quản lý trạng thái; GoRouter điều hướng. Có khung chuẩn bị cho Spring Boot REST và đồng bộ, nhưng backend chưa được nối vào các luồng chính. Gợi ý AI hiện là placeholder lưu cục bộ.

Repo nguồn: `D:\Flutter\app\DoAnFlutter`  
Workspace đích: `D:\Flutter\personal-finance-app\frontend` (frontend package)  
Nhánh nguồn: `fix/logic-transfer`  
Working tree: có thay đổi chưa commit. Các thay đổi này là một phần trạng thái hiện tại và không được xóa/ghi đè nếu chưa kiểm tra với tác giả.

Các file đang sửa theo `git status`:

- `lib/core/database/db_helper.dart`
- `lib/core/utils/validators.dart`
- `lib/models/wallet.dart`
- `lib/repositories/budget_repository.dart`
- `lib/repositories/saving_streak_repository.dart`
- `lib/repositories/transaction_repository.dart`
- `lib/repositories/transfer_repository.dart`
- `lib/repositories/wallet_repository.dart`
- `lib/screens/budgets/budget_form_screen.dart`
- `lib/screens/saving_goals/saving_goal_form_screen.dart`
- `lib/screens/transactions/transaction_form_screen.dart`
- `lib/screens/wallets/wallet_form_screen.dart`
- Plugin registration sinh tự động đã thay đổi: `linux/flutter/*`, `macos/Flutter/GeneratedPluginRegistrant.swift`, `windows/flutter/*`.
- Chưa track: `.vscode/`, `PROJECT-STRUCTURE.md` (file cấu trúc do người dùng/phiên làm việc tạo ra; giữ nguyên).

Tại thời điểm ghi nhận, `git diff --stat` cho 12 file code đang sửa là 136 dòng thêm, 55 dòng xóa; thống kê này không gồm file generated/untracked. Không có backend Spring Boot hoặc tài liệu `DB_Flutter_Idea.md` trong danh sách file repo quan sát được. README vẫn là README mẫu Flutter, không mô tả đồ án.

## 2. Công nghệ và phụ thuộc

SDK constraint từ `pubspec.yaml`: Dart `>=3.3.0 <4.0.0`. Tên package: `personal_finance_app`, version `1.0.0+1`.

| Package | Khai báo | Mục đích trong app |
|---|---:|---|
| `provider` | ^6.1.2 | DI đơn giản và state management bằng Provider/ChangeNotifier |
| `go_router` | ^14.2.0 | Route table, redirect theo trạng thái đăng nhập |
| `sqflite` | ^2.3.3 | SQLite local |
| `path` | ^1.9.0 | Tạo đường dẫn database |
| `path_provider` | ^2.1.3 | Dependency tiện ích đường dẫn nền tảng |
| `uuid` | ^4.4.0 | ID client-side (xem `lib/core/utils/id_generator.dart`) |
| `intl` | ^0.19.0 | Format tiền/ngày tháng |
| `http` | ^1.2.1 | HTTP client khung cho backend |
| `crypto` | ^3.0.5 | SHA-256 password local hiện tại |
| `shared_preferences` | ^2.2.3 | Lưu session user id và token API |
| `fl_chart` | ^0.68.0 | Biểu đồ dashboard |
| `cupertino_icons` | ^1.0.6 | Icon |
| `flutter_test` | SDK | Dev dependency test |
| `flutter_lints` | ^4.0.0 | Dev lint |

`pubspec.lock` đã commit/hiện diện và khóa phiên bản cụ thể. Một số ví dụ đang khóa mới hơn constraint: `go_router 14.8.1`, `http 1.6.0`, `crypto 3.0.7`, `cupertino_icons 1.0.9`. Cần tham khảo cả `pubspec.yaml` lẫn `pubspec.lock` khi tái tạo môi trường. `flutter pub get` là lệnh cài/khôi phục dependencies; lockfile không phải nơi triển khai tính năng. Các file `GeneratedPluginRegistrant` được Flutter sinh từ plugin cấu hình, không sửa tay trừ khi xử lý lỗi build nền tảng.

Chưa thấy khai báo asset/font trong `pubspec.yaml`. App bật Material icons. Có scaffold Android, iOS, Web, Linux, macOS, Windows; việc có scaffold không đảm bảo mọi plugin chạy trên mọi target (đặc biệt `sqflite` phụ thuộc nền tảng).

## 3. Kiến trúc và luồng khởi động

```text
main.dart
  -> mở SQLite qua DbHelper
  -> App(database)
       -> MultiProvider: repositories + AuthProvider + providers theo user
       -> MaterialApp.router / buildRouter
  -> splash / login / register hoặc home
```

- `lib/main.dart`: entry point, khởi tạo DB và chạy app.
- `lib/app.dart`: tạo repository dùng chung DB, đăng ký Provider; các feature provider phụ thuộc `AuthProvider` và gọi `load()` khi user thay đổi.
- `lib/routes/app_router.dart`: route table, redirect khi auth `unknown`, `unauthenticated`, `authenticated`.
- `lib/core/database/db_helper.dart`: singleton `DbHelper`, database `personal_finance.db`, foreign keys bật, schema hiện ở version 2; migration v1→v2 bổ sung `wallets.opening_balance` và khôi phục số dư từ ledger. Tạo mới sẽ seed danh mục hệ thống.
- Mẫu feature thường là `screens -> providers -> repositories -> models -> SQLite`. UI gọi provider; repository chịu trách nhiệm truy vấn/ghi dữ liệu và một số quy tắc nghiệp vụ.
- Hầu hết thao tác xóa là soft delete (`is_deleted=1`) để giữ dữ liệu cho sync. Nhiều thao tác ghi enqueue vào `sync_queue`.
- `lib/core/network/` và sync repository là khung tích hợp tương lai, không nên hiểu nhầm là đồng bộ đang hoạt động.

## 4. Chức năng hiện có và đường dẫn mã

### 4.1 Đăng nhập, đăng ký, hồ sơ

- UI: `lib/screens/auth/login_screen.dart`, `register_screen.dart`; `lib/screens/settings/profile_screen.dart`, `settings_screen.dart`.
- Trạng thái/nghiệp vụ: `lib/providers/auth_provider.dart`, `lib/repositories/auth_repository.dart`, `lib/models/user.dart`.
- Đăng ký tạo user local, tạo pet và saving streak mặc định; đăng nhập xác minh hash; `current_user_id` lưu bằng SharedPreferences.
- Hash hiện dùng SHA-256 thuần trong app; đây là cơ chế hiện tại, chưa phải auth backend/JWT. TODO backend trong repository.
- Route guard ở `lib/routes/app_router.dart`; constants tại `lib/core/constants/app_routes.dart`.

### 4.2 Ví và số dư

- UI: `lib/screens/wallets/wallet_list_screen.dart`, `wallet_form_screen.dart`, `wallet_detail_screen.dart`.
- Logic: `lib/providers/wallet_provider.dart`, `lib/repositories/wallet_repository.dart`, `lib/models/wallet.dart`.
- Ví có `opening_balance` và `current_balance` cache. Công thức đang được repository dùng: `opening_balance + income - expense - transfer_out + transfer_in`.
- Chi tiết ví có liên kết xem giao dịch. Sửa ví và ảnh hưởng lên số dư cần kiểm tra cùng transaction/transfer và migration.

### 4.3 Giao dịch thu/chi

- UI: `lib/screens/transactions/transaction_list_screen.dart`, `transaction_form_screen.dart`.
- Logic: `lib/providers/transaction_provider.dart`, `lib/repositories/transaction_repository.dart`, `lib/models/transaction.dart`, `lib/models/category.dart`.
- Transaction type chỉ có `INCOME`/`EXPENSE`; amount phải dương theo schema. Ghi/sửa/xóa giao dịch tính lại số dư ví. Báo cáo tổng và chi theo category phục vụ dashboard/ngân sách.
- Form có phụ thuộc danh mục và ví; kiểm tra nhất quán type của category với type giao dịch, chọn ngày, sửa giao dịch, validation và trạng thái loading/error khi chỉnh sửa.

### 4.4 Chuyển tiền giữa các ví / liên kết mục tiêu tiết kiệm

- UI: `lib/screens/transfers/transfer_list_screen.dart`, `transfer_form_screen.dart`; CTA liên quan ở `lib/screens/saving_goals/saving_goal_detail_screen.dart`.
- Logic: `lib/providers/transfer_provider.dart`, `lib/repositories/transfer_repository.dart`, `lib/models/transfer.dart`.
- Transfer là ledger riêng, **không phải expense transaction**, tránh tính nhầm chi tiêu. Repository từ chối ví nguồn và đích trùng nhau, ghi transfer, tính lại số dư hai ví và saved amount mục tiêu nếu `goalId` có giá trị.
- Transfer vào ví được xem là hoạt động tiết kiệm cho streak. Cần kiểm tra tính nguyên tử của nhiều bước ghi, kiểm tra số dư đủ, chủ sở hữu ví nguồn/đích, liên kết goal, xóa transfer và cập nhật streak đối xứng. Mã hiện quan sát thấy không có route/screen sửa transfer; thao tác UI chính là thêm và xóa.
- Đây là vùng trọng tâm nhánh `fix/logic-transfer`; trước khi thay đổi cần đọc cả form, provider, repository, wallet, saving goal/streak, schema và diff đang có.

### 4.5 Mục tiêu tiết kiệm

- UI: `lib/screens/saving_goals/saving_goal_list_screen.dart`, `saving_goal_form_screen.dart`, `saving_goal_detail_screen.dart`.
- Logic: `lib/providers/saving_goal_provider.dart`, `lib/repositories/saving_goal_repository.dart`, `lib/models/saving_goal.dart`.
- `saved_amount` được tính từ tổng transfer còn hoạt động gắn với goal; status chuyển `COMPLETED` khi đạt target (cần xem cách reset nếu goal giảm target hoặc transfer bị xóa). Goal có thể gắn wallet tùy chọn.

### 4.6 Ngân sách tháng

- UI: `lib/screens/budgets/budget_list_screen.dart`, `budget_form_screen.dart`.
- Logic: `lib/providers/budget_provider.dart`, `lib/repositories/budget_repository.dart`, `lib/models/monthly_budget.dart`, kết hợp `TransactionRepository`.
- Hạn mức theo category/tháng; repository upsert để một category có một budget active trong tháng. Mức đã chi lấy từ expense transactions.

### 4.7 Danh mục

- UI: `lib/screens/categories/category_list_screen.dart`, `category_form_screen.dart`.
- Logic: `lib/providers/category_provider.dart`, `lib/repositories/category_repository.dart`, `lib/models/category.dart`.
- Danh mục hệ thống có `user_id = NULL`, user nhìn thấy mặc định cộng danh mục riêng. DB seed danh mục Thu/Chi khi tạo database.

### 4.8 Dashboard, điều hướng phụ, thú cưng, gợi ý

- Trang chủ và shell: `lib/screens/home/home_shell.dart`, `home_screen.dart`, `more_menu_screen.dart`; biểu đồ dùng `fl_chart`.
- Pet/streak: `lib/screens/pet/pet_screen.dart`, `lib/providers/pet_streak_provider.dart`, `lib/repositories/pet_repository.dart`, `saving_streak_repository.dart`, `lib/models/pet.dart`, `saving_streak.dart`.
- Gợi ý: `lib/screens/ai_suggestions/ai_suggestion_screen.dart`, `lib/providers/ai_suggestion_provider.dart`, `lib/repositories/ai_suggestion_repository.dart`, `lib/models/ai_suggestion.dart`. Hiện tạo chuỗi placeholder local, chưa gọi AI/backend.
- Tiện ích UI chung: `lib/widgets/` (loading, empty state, form field, icon/color picker, confirm delete); format/validation/id/theme/constants ở `lib/core/`.

## 5. Database và mô hình dữ liệu

Database file local: `personal_finance.db`. Các bảng do `DbHelper` khai báo:

| Bảng | Vai trò |
|---|---|
| `users` | Tài khoản local, profile, password hash |
| `wallets` | Ví, loại ví, opening/current balance, soft delete |
| `categories` | Danh mục thu/chi hệ thống hoặc của user |
| `transactions` | Thu/chi, ví, category, ngày, note |
| `saving_goals` | Mục tiêu, target/saved, trạng thái, ví tùy chọn |
| `transfers` | Dòng tiền giữa hai ví, liên kết goal tùy chọn |
| `monthly_budgets` | Budget theo category và tháng |
| `pets` | Pet 1:1 user, level/xp/shape |
| `saving_streaks` | Streak 1:1 user |
| `ai_suggestions` | Cache gợi ý theo tháng |
| `sync_queue` | Local queue cho thao tác CREATE/UPDATE/DELETE |

ID được tạo ở client. Tiền lưu `INTEGER` (đơn vị tiền chưa được quy định rõ trong schema/UI; cần xác minh quy ước VND khi làm nghiệp vụ). Ngày nhiều model serialize thành `yyyy-MM-dd`; thời điểm cập nhật thường ISO-8601. FK bật khi mở DB; cần đánh giá migration và thao tác multi-table trong transaction, vì soft delete không tự cascade.

## 6. Backend và đồng bộ: hiện trạng chính xác

- `lib/core/network/api_client.dart`: wrapper `http`, JSON, Bearer token tùy chọn, lỗi thành `ApiException`.
- `lib/core/network/api_endpoints.dart`: URL mặc định placeholder `https://api.your-domain.com/api/v1`, override `--dart-define=API_BASE_URL=...`.
- `lib/repositories/sync_repository.dart`: enqueue thực sự; `pushPending()` chưa gửi/đánh dấu synced, `pull()` là stub.
- `AuthRepository`: TODO gọi API login/register; thực tế hiện xác thực local.
- `AiSuggestionRepository`: nội dung placeholder, chưa gọi API.
- `ApiClient.loadToken()` có định nghĩa nhưng cần kiểm tra nơi bootstrap gọi; không được giả định token tự động phục hồi.
- Không thấy backend source/config hoặc endpoint server thật trong repo. Không gửi thông tin nhạy cảm hay tự tạo endpoint giả.

## 7. Các điểm cần Claude điều tra khi tiếp nhận

Đây là các điểm cần kiểm tra bằng code và luồng chạy, chưa khẳng định tất cả đều là bug:

1. Transfer có tạo dữ liệu atomically không; lỗi ở bước enqueue/recompute/streak có thể để lại trạng thái một phần?
2. Có chặn amount <= 0 và số dư không đủ ở mọi tầng không? Schema chỉ enforce amount > 0, nhưng logic chuyển không thấy kiểm tra số dư trong phần repository đã đọc.
3. Có đảm bảo wallet/goal thuộc đúng user khi ghi transaction/transfer/budget không? FK hiện chỉ đảm bảo tồn tại, không đảm bảo cùng user.
4. Xóa transfer có rollback/recompute streak không? Transfer tạo cập nhật streak nhưng delete hiện tính lại wallet/goal; cần quyết định nghiệp vụ streak cho dữ liệu quá khứ.
5. Khi sửa transaction chuyển sang wallet khác, tính lại số dư cả wallet cũ và mới; khi xóa phải dùng wallet ID thực của bản ghi để tránh stale ID.
6. Cập nhật opening balance có giữ quan hệ đúng với ledger/current balance không; migration v2 chỉ thực hiện một lần trên database cũ.
7. Budget unique/upsert có race/duplicate khi nhiều lần submit không; schema hiện không có unique constraint rõ ràng.
8. Các screen load có cập nhật provider đúng sau khi pop form; xử lý lỗi repository có dừng spinner và báo user không?
9. Ngày giao dịch, timezone, khoảng ngày lọc (inclusive), streak khi nhập giao dịch/chuyển tiền quá khứ và ngày tương lai cần thống nhất.
10. Provider Proxy hiện tạo provider mới khi auth thay đổi; kiểm tra vòng đời/listener và tránh tải lặp không cần thiết.
11. Login/hash, session, profile, logout và bảo vệ dữ liệu nhiều user cần được đánh giá cho mục tiêu sản phẩm.
12. Chưa có bằng chứng từ lượt rà soát này về test bao phủ nghiệp vụ. Có `test/widget_test.dart`; đọc nội dung trước khi kết luận chất lượng test.

Hướng làm phù hợp: vẽ luồng người dùng hiện tại; ghi rõ invariant và quy tắc nghiệp vụ; lần theo màn hình → provider → repository → DB; sau đó mới sửa và bổ sung kiểm chứng theo yêu cầu của chủ đồ án. Không đại tu nhiều feature cùng lúc nếu chưa khoanh rõ lỗi.

## 8. Cây thư mục mã nguồn

```text
lib/
  main.dart, app.dart
  core/
    constants/ (routes, colors)
    database/ (SQLite schema, migrations)
    network/ (API client, endpoint config)
    theme/
    utils/ (formatters, validators, id generation)
  models/ (user, wallet, category, transaction, transfer, goals, budget, pet, streak, AI, sync queue)
  providers/ (auth + feature state)
  repositories/ (local persistence + nghiệp vụ feature + sync)
  routes/
  screens/
    auth/, home/, wallets/, categories/, transactions/, transfers/,
    saving_goals/, budgets/, pet/, ai_suggestions/, settings/
  widgets/ (shared UI)
test/widget_test.dart
pubspec.yaml, pubspec.lock
android/, ios/, web/, linux/, macos/, windows/ (platform runners/config)
```

File đầy đủ trong `lib/` tại thời điểm ghi nhận:

```text
lib/main.dart
lib/app.dart
lib/core/constants/app_colors.dart
lib/core/constants/app_routes.dart
lib/core/database/db_helper.dart
lib/core/network/api_client.dart
lib/core/network/api_endpoints.dart
lib/core/theme/app_theme.dart
lib/core/utils/formatters.dart
lib/core/utils/id_generator.dart
lib/core/utils/validators.dart
lib/models/ai_suggestion.dart
lib/models/category.dart
lib/models/monthly_budget.dart
lib/models/pet.dart
lib/models/saving_goal.dart
lib/models/saving_streak.dart
lib/models/sync_queue_item.dart
lib/models/transaction.dart
lib/models/transfer.dart
lib/models/user.dart
lib/models/wallet.dart
lib/providers/ai_suggestion_provider.dart
lib/providers/auth_provider.dart
lib/providers/budget_provider.dart
lib/providers/category_provider.dart
lib/providers/pet_streak_provider.dart
lib/providers/saving_goal_provider.dart
lib/providers/transaction_provider.dart
lib/providers/transfer_provider.dart
lib/providers/wallet_provider.dart
lib/repositories/ai_suggestion_repository.dart
lib/repositories/auth_repository.dart
lib/repositories/budget_repository.dart
lib/repositories/category_repository.dart
lib/repositories/pet_repository.dart
lib/repositories/saving_goal_repository.dart
lib/repositories/saving_streak_repository.dart
lib/repositories/sync_repository.dart
lib/repositories/transaction_repository.dart
lib/repositories/transfer_repository.dart
lib/repositories/wallet_repository.dart
lib/routes/app_router.dart
lib/screens/ai_suggestions/ai_suggestion_screen.dart
lib/screens/auth/login_screen.dart
lib/screens/auth/register_screen.dart
lib/screens/budgets/budget_form_screen.dart
lib/screens/budgets/budget_list_screen.dart
lib/screens/categories/category_form_screen.dart
lib/screens/categories/category_list_screen.dart
lib/screens/home/home_screen.dart
lib/screens/home/home_shell.dart
lib/screens/home/more_menu_screen.dart
lib/screens/pet/pet_screen.dart
lib/screens/saving_goals/saving_goal_detail_screen.dart
lib/screens/saving_goals/saving_goal_form_screen.dart
lib/screens/saving_goals/saving_goal_list_screen.dart
lib/screens/settings/profile_screen.dart
lib/screens/settings/settings_screen.dart
lib/screens/splash_screen.dart
lib/screens/transactions/transaction_form_screen.dart
lib/screens/transactions/transaction_list_screen.dart
lib/screens/transfers/transfer_form_screen.dart
lib/screens/transfers/transfer_list_screen.dart
lib/screens/wallets/wallet_detail_screen.dart
lib/screens/wallets/wallet_form_screen.dart
lib/screens/wallets/wallet_list_screen.dart
lib/widgets/app_text_field.dart
lib/widgets/confirm_delete_dialog.dart
lib/widgets/empty_state.dart
lib/widgets/icon_color_picker.dart
lib/widgets/loading_view.dart
```

## 9. Hướng dẫn gửi file cho Claude Agent theo nhóm chức năng

### Khi mới giao việc / cần hiểu toàn dự án

Gửi tối thiểu:

1. `CLAUDE_AGENT_HANDOFF.md` (file này).
2. `pubspec.yaml`, `pubspec.lock`.
3. Toàn bộ `lib/` (nếu công cụ cho phép; đây là nguồn sự thật của app).
4. `analysis_options.yaml`, `test/widget_test.dart`.
5. `git status --short` và `git diff` của nhánh hiện tại; cần báo rõ nhánh `fix/logic-transfer` và các file chưa commit.
6. Log lỗi đầy đủ, các bước tái hiện, kết quả mong đợi/thực tế, ảnh/video UI nếu vấn đề là giao diện.

Không cần gửi thư mục build/cache (`build/`, `.dart_tool/`, `.pub-cache/`) để Claude hiểu logic. Gửi platform config chỉ khi vấn đề liên quan build, quyền, plugin hoặc target cụ thể.

### Chỉ sửa chuyển tiền / logic số dư (nhóm trọng tâm)

Gửi:

- `lib/screens/transfers/transfer_form_screen.dart`, `transfer_list_screen.dart`
- `lib/providers/transfer_provider.dart`, `lib/repositories/transfer_repository.dart`, `lib/models/transfer.dart`
- `lib/repositories/wallet_repository.dart`, `lib/models/wallet.dart`, `lib/providers/wallet_provider.dart`
- `lib/repositories/transaction_repository.dart`, `lib/models/transaction.dart`
- Nếu transfer gắn mục tiêu/streak: `lib/repositories/saving_goal_repository.dart`, `lib/models/saving_goal.dart`, `lib/repositories/saving_streak_repository.dart`, `lib/repositories/pet_repository.dart`, models/provider tương ứng
- `lib/core/database/db_helper.dart`, validators/formatters, route constants/router
- Diff hiện có của tất cả các file này; mẫu DB hoặc mô tả dữ liệu tái hiện (ẩn thông tin cá nhân).

### Đăng nhập / tài khoản

`login_screen.dart`, `register_screen.dart`, `profile_screen.dart`, `settings_screen.dart`, `auth_provider.dart`, `auth_repository.dart`, `user.dart`, `db_helper.dart`, `app.dart`, `app_router.dart`, `app_routes.dart`; thêm Android/iOS config nếu lỗi lưu trữ/plugin theo nền tảng.

### Thu/chi / danh mục / báo cáo

`transaction_form_screen.dart`, `transaction_list_screen.dart`, `category_form_screen.dart`, `category_list_screen.dart`, `home_screen.dart`, `transaction_provider.dart`, `category_provider.dart`, `transaction_repository.dart`, `category_repository.dart`, `transaction.dart`, `category.dart`, `wallet_repository.dart`, `db_helper.dart`, validators/formatters.

### Ví / chi tiết ví

Ba screen trong `screens/wallets/`, `wallet_provider.dart`, `wallet_repository.dart`, `wallet.dart`, `transaction_repository.dart`, `transfer_repository.dart`, `db_helper.dart`, cùng log hoặc ảnh số dư sai.

### Mục tiêu tiết kiệm / streak / pet

Ba screen `screens/saving_goals/`, `screens/pet/pet_screen.dart`, `saving_goal_provider.dart`, `pet_streak_provider.dart`, `saving_goal_repository.dart`, `saving_streak_repository.dart`, `pet_repository.dart`, `transfer_repository.dart`, các model goal/streak/pet, `db_helper.dart`.

### Ngân sách

`budget_list_screen.dart`, `budget_form_screen.dart`, `budget_provider.dart`, `budget_repository.dart`, `monthly_budget.dart`, `transaction_repository.dart`, `transaction.dart`, `category.dart`, `db_helper.dart`.

### Điều hướng / luồng tổng thể / giao diện

`app.dart`, `app_router.dart`, `app_routes.dart`, `home_shell.dart`, `home_screen.dart`, `more_menu_screen.dart`, và các screen của luồng bị lỗi; kèm ảnh/video hoặc thao tác chính xác.

### Backend / đồng bộ / AI

`api_client.dart`, `api_endpoints.dart`, `sync_repository.dart`, các repository của resource, model serialize, cấu hình base URL (che secret), contract OpenAPI/JSON của backend và log HTTP đã loại token/PII. Với AI bổ sung `ai_suggestion_*` screen/provider/repository/model. Backend code không nằm trong repo hiện tại nên cần gửi từ repo backend nếu muốn Claude sửa hai phía.

### Lỗi cài dependencies / build theo nền tảng

`pubspec.yaml`, `pubspec.lock`, output lệnh lỗi đầy đủ, Flutter/Dart version và target. Gửi thêm `android/` (Gradle/Manifest), `ios/` (Pod/Xcode), `web/`, `windows/`, `linux/`, hoặc `macos/` tùy nền tảng. Không gửi cache; không chỉnh tay generated registrant nếu chưa xác định nguyên nhân.

## 10. Quy ước làm việc đề xuất cho Agent

- Giữ nguyên các thay đổi chưa commit và xem `git diff` trước khi đụng file đang sửa.
- Trước khi code, diễn giải luồng hiện tại và invariant (ví dụ tổng tài sản, expense, transfer, goal saved amount) để phát hiện cập nhật thiếu hoặc trùng.
- Tách việc tái cấu trúc điều hướng khỏi sửa phép tính nghiệp vụ, trừ khi cùng một bug yêu cầu cả hai.
- Cẩn thận với schema migration: không sửa schema `onCreate` mà quên nâng version/migration cho DB đã cài.
- Dùng soft delete nhất quán; kiểm tra mọi phép tổng hợp đều lọc `is_deleted=0`.
- Khi đổi model/map, rà soát cả `fromMap/toMap`, `fromJson/toJson`, schema và mọi caller.
- Không khẳng định backend, sync, AI hoặc test đã hoạt động chỉ từ tên file/comment.
- Báo lại file đổi, quy tắc nghiệp vụ đã chọn, tình huống chưa giải quyết và kiểm chứng đã chạy (hoặc chưa chạy).

## 11. Lệnh môi trường thường dùng

Chạy từ thư mục repo:

```powershell
flutter pub get
flutter run
flutter analyze
flutter test
```

Các lệnh này là hướng dẫn cho phiên làm việc sau; lượt tạo handoff này không chạy analyze/test và không thay đổi dependency.
