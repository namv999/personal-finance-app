# Personal Finance Management App

Ứng dụng hỗ trợ quản lý thu chi cá nhân — đồ án môn Phát triển ứng dụng di động.

## Giới thiệu

Ứng dụng giúp người dùng ghi nhận thu nhập/chi tiêu theo danh mục, quản lý nhiều ví (ví chi tiêu, ví tiết kiệm...), đặt mục tiêu tiết kiệm, theo dõi chuỗi ngày tiết kiệm, gamification qua hệ thống Pet, và nhận gợi ý tài chính hàng tháng từ AI. Ứng dụng hoạt động offline-first, đồng bộ dữ liệu 2 chiều với server khi có mạng.

## Tech Stack

**Frontend:** Flutter (Dart), Provider, SQLite (sqflite), dio, fl_chart
**Backend:** Spring Boot (Java), Spring Security + JWT, Spring Data JPA, MySQL/PostgreSQL
**Đồng bộ:** REST API `/sync/push`, `/sync/pull`, UUID primary key, Last-Write-Wins
**AI:** OpenAI API / Google Gemini API (gọi từ Backend)

## Cấu trúc thư mục
personal-finance-app/
├── frontend/ # Flutter app
├── backend/ # Spring Boot app
├── docs/ # ERD, sơ đồ, tài liệu, báo cáo tuần
└── .gitignore


## Thành viên nhóm

| Tên | Vai trò |
|---|---|
| A | Kiến trúc hệ thống, sơ đồ thiết kế, tổng hợp báo cáo, lập trình đa số nội dung |
| B | Backend / API (Spring Boot) |
| C | Frontend / UI (Flutter) |

## Hướng dẫn cài đặt

### Frontend
```bash
cd frontend
flutter pub get
flutter run
```

### Backend
```bash
cd backend
./mvnw spring-boot:run
```
Cấu hình kết nối database tại `backend/src/main/resources/application.properties`.

## Tài liệu

- [Thiết kế cơ sở dữ liệu](docs/DB_Flutter_Idea.md)
- [Bảng phân công công việc](docs/PhanCong.md)
- Sơ đồ (ERD, Use case, Sequence, Class, Deployment): `docs/diagrams/`
- Báo cáo tiến độ hàng tuần: `docs/weekly_reports/`

## Quy trình làm việc

- Không code trực tiếp trên nhánh `main`.
- Mỗi tính năng làm trên 1 nhánh riêng: `feature/<tên-tính-năng>` (vd. `feature/auth-api`, `feature/login-ui`).
- Code xong tạo Pull Request vào `main`, cần 1 thành viên khác review trước khi merge.
- Commit message ngắn gọn, rõ ràng (vd. `feat: add login API`, `fix: wallet balance calculation`).