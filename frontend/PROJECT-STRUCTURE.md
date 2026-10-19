# Project Structure

```text
frontend/
├── lib/                         # Ứng dụng Flutter
│   ├── app.dart
│   ├── main.dart
│   ├── core/
│   │   ├── constants/
│   │   ├── database/
│   │   ├── network/
│   │   ├── theme/
│   │   └── utils/
│   ├── models/                   # User, wallet, transaction, budget, goal, pet...
│   ├── providers/                # Trạng thái và nghiệp vụ ứng dụng
│   ├── repositories/             # Truy cập database và API
│   ├── routes/                   # Điều hướng
│   ├── screens/
│   │   ├── auth/
│   │   ├── budgets/
│   │   ├── categories/
│   │   ├── home/
│   │   ├── saving_goals/
│   │   ├── transactions/
│   │   ├── transfers/
│   │   ├── wallets/
│   │   ├── pet/
│   │   ├── settings/
│   │   └── ai_suggestions/
│   └── widgets/                  # Widget dùng chung
├── test/                         # Kiểm thử chức năng và widget
├── android/...
├── ios/...
├── linux/...
├── macos/...
├── web/...
├── windows/...
├── pubspec.yaml
└── analysis_options.yaml
```

Code chức năng nằm trong `lib/`; kiểm thử nằm trong `test/`. Các thư mục nền tảng được rút gọn vì chủ yếu chứa cấu hình build và mã khởi chạy riêng từng nền tảng.
