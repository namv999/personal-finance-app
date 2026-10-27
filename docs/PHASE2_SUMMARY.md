# PHASE2_SUMMARY: Backend và tích hợp Flutter-Backend

Cập nhật: 26/10/2026. Trạng thái: **Phase 2 hoàn thành (P2.1 đến P2.7)**.

## 1. Đã làm được gì

| Mã | Nội dung | Kết quả |
|---|---|---|
| P2.1 | Chốt contract | `docs/openapi.yaml`, `docs/SYNC_RULES.md` |
| P2.2 | Nền backend | Spring Boot, SQL Server, Flyway V1 |
| P2.3 | Auth | JWT, `/auth/register`, `/auth/login` |
| P2.4 | Sync push | LWW, kiểm tra bản ghi cha, hợp nhất budget |
| P2.5 | Sync pull | Cursor `server_version`, phân trang |
| P2.6 | Flutter-Backend | Auth online, push/pull client, xử lý conflict, pull sau login |
| P2.7 | Search và test | `GET /transactions`, 26 test tự động |

## 2. Kiến trúc tóm tắt

- App Flutter **offline-first**: mọi thao tác ghi vào SQLite trước, đồng thời ghi `sync_queue` trong cùng một transaction.
- Khi đồng bộ, `SyncService.syncAll(userId)` làm theo thứ tự: push các bản ghi bẩn, xử lý kết quả `REJECTED`, rồi pull. Push lỗi thì không pull.
- Xung đột giải quyết bằng Last-Write-Wins theo `updated_at` (UTC). Xóa là xóa mềm (`is_deleted`).
- Server gán `server_version` (SEQUENCE dùng chung 6 bảng). Client dùng nó làm cursor khi pull, không dùng timestamp.
- Các giá trị suy ra (`current_balance`, `saved_amount`, streak, XP của pet) không đồng bộ. Client tính lại sau mỗi lần pull hoặc xử lý từ chối.
- Backend lấy `userId` từ JWT, không nhận từ body.

## 3. Backend

Package gốc `com.pfm.backend`:
- `auth/`: đăng ký, đăng nhập, JWT
- `common/`: `ApiException`, `GlobalExceptionHandler`
- `config/`: `SecurityConfig`, `JwtConfig`
- `sync/`: push, pull, entity, repository
- `transaction/`: `GET /transactions` (P2.7)

Endpoint:

| Method | Đường dẫn | Mô tả |
|---|---|---|
| POST | `/auth/register` | Đăng ký, `id` do client sinh, trả 201 `{token, user}` |
| POST | `/auth/login` | Đăng nhập, trả `{token, user}` |
| POST | `/sync/push` | Đẩy snapshot bản ghi bẩn, tối đa 500 bản ghi mỗi request |
| GET | `/sync/pull?cursor=&limit=` | Kéo thay đổi sau cursor, limit 1 đến 500 |
| GET | `/transactions` | Danh sách giao dịch đã đồng bộ, có tìm kiếm, lọc, phân trang |

Kết quả push từng bản ghi: `APPLIED`, `SKIPPED_NEWER`, hoặc `REJECTED` kèm lý do `PARENT_DELETED`, `FUTURE_DATE`, `INVALID`.

`GET /transactions` nhận: `q` (tìm trong `note`, không phân biệt hoa thường, có phân biệt dấu), `type`, `wallet_id`, `category_id`, `from`, `to`, `min_amount`, `max_amount`, `page` (từ 0), `size` (1 đến 100, mặc định 20). Sắp xếp theo `transaction_date` giảm dần. Tham số sai trả 400 `VALIDATION_FAILED`.

Contract đầy đủ nằm trong `docs/openapi.yaml`, quy tắc đồng bộ trong `docs/SYNC_RULES.md`.

## 4. Cài đặt môi trường

### Công cụ cần có
- JDK 17 (Eclipse Temurin). Kiểm tra bằng `java -version`, nếu hiện Java khác thì trỏ `JAVA_HOME` về JDK 17.
- Maven (lệnh `mvn` chạy được trong terminal).
- SQL Server (cổng 1433, bật mixed mode authentication) và SSMS.
- Flutter 3.47.2 stable (đi kèm Dart 3.13.2), Android SDK, Postman.

### Thư viện
Backend: Maven tự tải theo `pom.xml` ở lần chạy đầu, không cài tay. Các thư viện chính: Spring Boot 4.1.1 (webmvc, security, oauth2-resource-server cho JWT, data-jpa, validation), Flyway (kèm `flyway-sqlserver`), `mssql-jdbc`, springdoc-openapi (Swagger UI), Lombok.

Frontend: chạy một lần trong thư mục `frontend/`:
```powershell
flutter pub get
```
Các package chính: `provider`, `go_router`, `fl_chart`, `sqflite`, `shared_preferences`, `dio`, `uuid`. Phiên bản được khóa trong `pubspec.lock`, không tự nâng cấp.

### Tạo database (chạy trong SSMS, thay các giá trị trong `<>`)
```sql
CREATE DATABASE <ten_db_dev>;
GO
CREATE LOGIN pfm_app WITH PASSWORD = '<mat_khau>';   -- bỏ qua nếu login đã có
GO
USE <ten_db_dev>;
CREATE USER pfm_app FOR LOGIN pfm_app;
ALTER ROLE db_owner ADD MEMBER pfm_app;
GO
CREATE DATABASE pfm_test;
GO
USE pfm_test;
CREATE USER pfm_app FOR LOGIN pfm_app;
ALTER ROLE db_owner ADD MEMBER pfm_app;
```
Bảng và dữ liệu danh mục hệ thống do Flyway tự tạo khi backend chạy lần đầu.

### Biến môi trường
Tạo file `backend/env-local.ps1` (đã nằm trong `.gitignore`, **không commit**):
```powershell
$env:DB_URL = "jdbc:sqlserver://localhost:1433;databaseName=<ten_db_dev>;encrypt=true;trustServerCertificate=true"
$env:DB_USER = "pfm_app"
$env:DB_PASSWORD = "<mat_khau>"
$env:JWT_SECRET = "<chuoi_ngau_nhien_tu_32_ky_tu_tro_len>"
$env:TEST_DB_URL = "jdbc:sqlserver://localhost:1433;databaseName=pfm_test;encrypt=true;trustServerCertificate=true"
```
Đổi `JWT_SECRET` thì mọi token cũ mất hiệu lực, phải đăng nhập lại.

## 5. Cách chạy

Backend (mỗi terminal mới):
```powershell
cd D:\Flutter\personal-finance-app\backend
. .\env-local.ps1
mvn spring-boot:run
```
Swagger UI: `http://localhost:8080/swagger-ui.html`.

Flutter (thư mục `frontend/`):
```powershell
# Emulator Android
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
# Điện thoại thật (cùng Wi-Fi với máy tính)
flutter run --dart-define=API_BASE_URL=http://<IP_may_tinh>:8080
```
Nếu điện thoại không kết nối được, kiểm tra tường lửa Windows có chặn cổng 8080 không.

## 6. Cách chạy test

Backend (cần database `pfm_test` và `TEST_DB_URL`):
```powershell
cd D:\Flutter\personal-finance-app\backend
. .\env-local.ps1
mvn test
```
Kết quả hiện tại: **26 test, 0 lỗi**.

| Lớp test | Số test | Nội dung |
|---|---|---|
| `BackendApplicationTests` | 1 | Context khởi động được |
| `AuthIntegrationTest` | 5 | Đăng ký, đăng nhập, trùng email, trùng id, mật khẩu ngắn |
| `SyncIntegrationTest` | 8 | LWW, `FUTURE_DATE`, `INVALID`, `PARENT_DELETED`, phân trang cursor, cách ly user, 400, 401 |
| `TransactionSearchIntegrationTest` | 12 | Lọc, tìm kiếm, ký tự đặc biệt của LIKE, phân trang, tham số sai, cách ly user |

Lưu ý:
- Test chạy trên SQL Server thật (`pfm_test`), không dùng H2 vì H2 không có `SEQUENCE` và hành vi kiểu dữ liệu khác SQL Server.
- Mỗi test tự tạo user và id ngẫu nhiên nên không cần dọn database. Test sẽ báo lỗi nếu URL không chứa `_test`, để tránh chạy nhầm lên database dev.

Flutter (thư mục `frontend/`):
```powershell
flutter analyze
flutter test
```

## 7. Thử nhanh bằng Postman

Base URL `http://localhost:8080`. Id và email phải mới mỗi lần thử, đổi nếu đã dùng.

**1. Đăng ký** `POST /auth/register` (không cần token)
```json
{
  "id": "3f6c1a52-8b7e-4d21-9c4a-5e2d7b9a1f30",
  "full_name": "Nguyen Van C",
  "email": "c@test.com",
  "password": "123456"
}
```
Copy `token` trong kết quả, dán vào Authorization (Bearer Token) cho các request sau.

**2. Đẩy dữ liệu** `POST /sync/push`
```json
{
  "records": {
    "wallets": [
      {
        "id": "c1a2b3d4-0001-4a11-8b22-000000000001",
        "updated_at": "2026-10-26T11:00:00.000Z",
        "is_deleted": false,
        "wallet_name": "Ví chính",
        "wallet_type": "SPENDING",
        "opening_balance": 1000000
      }
    ],
    "transactions": [
      {
        "id": "c1a2b3d4-0002-4a11-8b22-000000000001",
        "updated_at": "2026-10-26T11:00:00.000Z",
        "is_deleted": false,
        "wallet_id": "c1a2b3d4-0001-4a11-8b22-000000000001",
        "category_id": "00000000-0000-4000-8000-000000000003",
        "type": "EXPENSE",
        "amount": 50000,
        "note": "Ăn phở",
        "source": "MANUAL",
        "transaction_date": "2026-10-25"
      }
    ]
  }
}
```
Kỳ vọng: mọi kết quả là `APPLIED`. Gửi lại lần hai sẽ là `SKIPPED_NEWER`.

**3. Kéo dữ liệu** `GET /sync/pull?cursor=0&limit=500`

**4. Tìm kiếm** `GET /transactions?q=phở&type=EXPENSE&size=10`. Kỳ vọng 1 giao dịch.

## 8. Hạn chế đã biết (ghi vào báo cáo)

- Hai thiết bị của cùng một user push đồng thời có thể làm một bản ghi bị bỏ sót đến lần sửa kế tiếp, vì `server_version` nhỏ có thể commit sau khi thiết bị kia đã pull qua mốc đó.
- Số dư ví có thể âm sau khi hợp nhất dữ liệu nhiều máy, app chỉ cảnh báo.
- Bản ghi `INVALID` chỉ được ghi log và nằm lại ở local, không tự sửa, máy khác không thấy.
- Đăng nhập online nhưng pull lỗi vẫn cho vào app, người dùng có thể bị yêu cầu tạo ví trước khi dữ liệu server về.
- Chưa tự động đồng bộ khi mở app hoặc sau mỗi lần ghi, hiện chỉ có nút "Đồng bộ ngay" và pull sau đăng nhập.
- `ApiClient.onUnauthorized` chưa được gán, nên token hết hạn chưa dẫn đến thông báo "đăng nhập lại để đồng bộ".
- `GET /transactions` phân trang theo offset (dữ liệu đổi giữa hai lần gọi có thể lệch trang), tìm kiếm có phân biệt dấu, và chỉ đọc dữ liệu đã đồng bộ. Tìm kiếm trong app dùng SQLite local.
- `GlobalExceptionHandler` gán mọi `DataIntegrityViolationException` thành `EMAIL_ALREADY_EXISTS`. Chỉ xảy ra khi hai request đăng ký trùng nhau đến cùng lúc.

## 9. Việc còn tồn đọng (cần từng người xác nhận)

- [ ] PR `feature/be-search-tests` đã merge vào `develop`, commit P2.5 trên `feature/be-auth-sync` đã được merge
- [ ] FE: `ledger_refresh.dart` (làm mới budget khi xóa category), `wallet_delete_dialog.dart`, đường dữ liệu wallet detail
- [ ] Gỡ `package:http` khỏi `pubspec.yaml` khi không còn file nào import
- [ ] Gỡ tile test 600 giao dịch trong Settings
- [ ] Sửa tài liệu và báo cáo: `GET /sync/pull?since=...` thành `GET /sync/pull?cursor=<int64>&limit=500`
- [ ] `DB_Flutter_Idea.md`: xóa dấu `}` thừa ở cuối khối ERD (đang làm Mermaid không hiển thị)

## 10. Quy ước

- Tên bảng và trường bằng tiếng Anh, comment bằng tiếng Việt.
- Git: `main`, `develop`, `feature/*`, tích hợp qua Pull Request.
- OpenAPI là contract duy nhất giữa frontend và backend: thêm hoặc đổi endpoint thì sửa `docs/openapi.yaml` trước khi viết code.
- Không commit API key, mật khẩu, JWT secret.