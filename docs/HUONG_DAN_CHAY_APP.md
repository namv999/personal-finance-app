# Hướng dẫn cài đặt và chạy ứng dụng

Tài liệu dành cho thành viên mới cài dự án trên Windows/PowerShell. Dự án có hai phần chạy độc lập: backend Spring Boot và ứng dụng Flutter. Flutter hiện lưu dữ liệu offline trên SQLite; backend dùng SQL Server.

## 1. Công cụ cần cài

- **JDK 17** (không chỉ JRE). Kiểm tra bằng `java -version`.
- **Flutter SDK** phiên bản tương thích với Dart `>=3.3.0 <4.0.0`. Kiểm tra `flutter --version` và `flutter doctor`.
- **Android Studio** (Android SDK và emulator) hoặc thiết bị Android đã bật USB debugging. Chạy `flutter devices` để kiểm tra.
- **SQL Server** và một công cụ quản lý như SQL Server Management Studio (SSMS) hoặc Azure Data Studio. SQL Server cần chạy cục bộ và chấp nhận kết nối TCP/IP cổng `1433` (hoặc cập nhật port trong JDBC URL).
- Maven Wrapper đã có trong `backend/`, nên không cần cài Maven riêng.

Nếu dùng Android emulator, API base URL mặc định `http://10.0.2.2:8080` trỏ tới máy host. Với thiết bị thật, dùng địa chỉ IP LAN của máy chạy backend thay cho `10.0.2.2`; máy tính và điện thoại cần cùng mạng và firewall phải cho phép kết nối cổng 8080.

## 2. Chuẩn bị SQL Server và database

Tạo **hai database riêng** trên SQL Server: `pfm` để chạy ứng dụng và `pfm_test` để chạy integration test. Không dùng database có dữ liệu cần giữ làm database test.

Ví dụ chạy trong SSMS bằng tài khoản có quyền tạo database:

```sql
CREATE DATABASE pfm;
CREATE DATABASE pfm_test;
```

Backend dùng Flyway để tạo/cập nhật schema tự động khi khởi động. Các migration nằm trong `backend/src/main/resources/db/migration/`; không cần tự tạo bảng bằng tay. Tài khoản kết nối cần quyền đọc/ghi và quyền tạo, sửa bảng trên cả hai database.

`backend/env-local.ps1` hiện cấu hình SQL Server local với Windows Integrated Authentication và đặt URL của cả `DB_URL` và `TEST_DB_URL` vào `pfm_test`. Trước khi chạy backend, sửa `DB_URL` thành `databaseName=pfm`. Giữ `TEST_DB_URL` trỏ tới `databaseName=pfm_test`. Không để app chạy thường ngày vào database test.

Nếu dùng SQL Server Authentication thay cho Windows Authentication, sửa URL để bỏ `integratedSecurity=true` và điền `DB_USER`, `DB_PASSWORD` tương ứng. Ví dụ:

```powershell
$env:DB_URL = "jdbc:sqlserver://localhost:1433;databaseName=pfm;encrypt=true;trustServerCertificate=true"
$env:DB_USER = "pfm_app"
$env:DB_PASSWORD = "mat-khau-local"
$env:TEST_DB_URL = "jdbc:sqlserver://localhost:1433;databaseName=pfm_test;encrypt=true;trustServerCertificate=true"
```

Tạo login/user SQL Server riêng có quyền phù hợp cho hai database. Không dùng hoặc gửi mật khẩu thật trong tài liệu, ảnh chụp màn hình hay commit. Nếu chọn Windows Integrated Authentication thì có thể để trống user/password như cấu hình mẫu; máy phải đăng nhập bằng Windows account được cấp quyền trên SQL Server và JDBC driver phải hỗ trợ Integrated Authentication.

## 3. Thiết lập biến môi trường `env-local.ps1`

File `backend/env-local.ps1` bị Git bỏ qua vì chứa cấu hình riêng trên máy. Mỗi thành viên cần tự tạo file này từ mẫu được chia sẻ an toàn hoặc điền các biến cần thiết theo cấu hình local; không chép API key hay mật khẩu của người khác. File hiện có trên máy phát triển là cấu hình tham khảo, hãy kiểm tra database và thông tin đăng nhập trước khi dùng.

Các biến backend đọc từ môi trường:

| Biến | Dùng cho |
|---|---|
| `DB_URL`, `DB_USER`, `DB_PASSWORD` | Kết nối database khi chạy ứng dụng bình thường |
| `TEST_DB_URL` | Kết nối database riêng khi chạy integration test với profile `test` |
| `JWT_SECRET` | Ký JWT; đặt chuỗi bí mật đủ dài cho môi trường local |
| `GEMINI_API_KEY` | Tùy chọn cho tính năng gọi Gemini; để rỗng nếu không kiểm tra tính năng AI |
| `GEMINI_MODEL` | Tùy chọn, tên model Gemini; có giá trị mặc định trong cấu hình |

Mở PowerShell tại thư mục gốc repo rồi nạp biến vào **chính cửa sổ PowerShell đó**:

```powershell
. .\backend\env-local.ps1
```

Dấu chấm, dấu cách rồi đến đường dẫn là cú pháp dot-source, giúp biến môi trường còn hiệu lực trong terminal hiện tại. Mỗi terminal mới cần nạp lại file. Kiểm tra các biến không nhạy cảm:

```powershell
$env:DB_URL
$env:TEST_DB_URL
```

Không in hoặc chia sẻ `DB_PASSWORD`, `JWT_SECRET`, `GEMINI_API_KEY`. Nếu PowerShell chặn chạy script, chỉ áp dụng policy tạm thời cho terminal hiện tại rồi nạp lại:

```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
. .\backend\env-local.ps1
```

## 4. Cài dependencies

Mở terminal ở thư mục gốc repo.

Backend (PowerShell):

```powershell
cd backend
./mvnw.cmd -version
```

Frontend:

```powershell
cd frontend
flutter pub get
```

Nếu chạy `flutter doctor` báo thiếu Android licenses, làm theo hướng dẫn trong output, thường là `flutter doctor --android-licenses`.

## 5. Chạy backend

Đảm bảo SQL Server đang chạy và `DB_URL` trỏ tới `pfm`. Từ thư mục gốc, nạp env rồi chạy:

```powershell
. .\backend\env-local.ps1
cd backend
./mvnw.cmd spring-boot:run
```

Lần chạy đầu, Flyway áp dụng các migration để tạo schema và có thể mất thêm thời gian. Khi log báo ứng dụng đã khởi động, backend phục vụ tại `http://localhost:8080`. Có thể mở Swagger UI tại `http://localhost:8080/swagger-ui/index.html` để xem API. Dừng bằng `Ctrl+C`.

## 6. Chạy Flutter app

Mở **terminal thứ hai** để giữ backend đang chạy. Từ thư mục gốc:

```powershell
cd frontend
flutter pub get
flutter devices
flutter run
```

Nếu có nhiều thiết bị, chọn một thiết bị cụ thể bằng `flutter run -d <device-id>`. Với Android emulator, URL backend mặc định đã dùng địa chỉ host phù hợp. Nếu chạy trên điện thoại thật, truyền địa chỉ IP máy tính:

```powershell
flutter run --dart-define=API_BASE_URL=http://192.168.1.10:8080
```

Thay `192.168.1.10` bằng IP LAN thật của máy đang chạy backend. App được thiết kế offline-first và nhiều repository/API flow vẫn đang phát triển; vì vậy một số màn hình có thể hoạt động với SQLite local dù backend chưa được tích hợp đầy đủ.

## 7. Chạy kiểm tra

### Backend

Integration test dùng profile `test` và `TEST_DB_URL`. Nạp `env-local.ps1`, xác nhận URL test là `pfm_test`, SQL Server đang chạy, rồi từ thư mục gốc:

```powershell
. .\backend\env-local.ps1
cd backend
./mvnw.cmd test
```

Các integration test tạo dữ liệu trong database test. Không đặt `TEST_DB_URL` thành database phát triển hoặc database có dữ liệu cần giữ. Nếu chỉ muốn biên dịch/đóng gói mà chưa chạy test:

```powershell
./mvnw.cmd -DskipTests package
```

### Flutter

Từ thư mục gốc:

```powershell
cd frontend
flutter test
```

Lệnh chạy toàn bộ unit/widget tests trong `frontend/test/`. Một test cụ thể có thể chạy bằng `flutter test test/ten_file_test.dart` khi đang ở thư mục `frontend`.

## 8. Sự cố thường gặp

- **`java` không nhận diện hoặc sai phiên bản:** cài JDK 17, cấu hình `JAVA_HOME`/`PATH`, mở terminal mới và kiểm tra lại `java -version`.
- **Không kết nối được SQL Server / connection refused:** xác nhận dịch vụ SQL Server đang chạy, TCP/IP được bật, port trong `DB_URL` đúng và tường lửa không chặn.
- **Login failed / lỗi Integrated Authentication:** xác nhận Windows account được cấp quyền, hoặc dùng SQL Authentication và kiểm tra `DB_USER`/`DB_PASSWORD`. Nếu driver báo thiếu native authentication library, cấu hình Microsoft JDBC integrated auth phù hợp hoặc chuyển sang SQL Authentication.
- **Thiếu biến môi trường:** nạp lại `. .\backend\env-local.ps1` trong đúng terminal đang chạy Maven; mở terminal mới thì cần nạp lại.
- **Flyway báo migration/schema error:** kiểm tra đang kết nối đúng database và không chỉnh sửa migration cũ đã được áp dụng. Với database local thử nghiệm có thể tạo lại database sau khi chắc chắn không cần dữ liệu; không làm vậy với dữ liệu cần giữ.
- **Flutter không tìm thấy thiết bị:** mở emulator hoặc kết nối điện thoại, chấp nhận USB debugging, rồi kiểm tra `flutter devices` và `flutter doctor`.
- **Điện thoại không gọi được backend:** dùng IP LAN thay cho `localhost`/`10.0.2.2`, đảm bảo cùng mạng và cho phép cổng 8080 qua firewall.
- **Backend chạy nhưng AI không hoạt động:** `GEMINI_API_KEY` là tùy chọn cho khởi động thông thường; tính năng AI cần key hợp lệ và kết nối Internet.
