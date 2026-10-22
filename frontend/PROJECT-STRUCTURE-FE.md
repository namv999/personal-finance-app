# Frontend: cấu trúc và file Dart quan trọng

```text
frontend/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── routes/
│   │   └── app_router.dart
│   ├── core/
│   │   ├── constants/
│   │   │   ├── app_routes.dart
│   │   │   └── app_colors.dart
│   │   ├── database/
│   │   │   ├── db_helper.dart
│   │   │   └── txn_ext.dart
│   │   ├── network/
│   │   │   ├── api_client.dart
│   │   │   └── api_endpoints.dart
│   │   ├── theme/app_theme.dart
│   │   └── utils/...
│   ├── models/...
│   ├── repositories/
│   │   ├── auth_repository.dart
│   │   ├── sync_repository.dart
│   │   ├── wallet_repository.dart
│   │   ├── category_repository.dart
│   │   ├── transaction_repository.dart
│   │   ├── transfer_repository.dart
│   │   ├── budget_repository.dart
│   │   ├── saving_goal_repository.dart
│   │   ├── pet_repository.dart
│   │   ├── saving_streak_repository.dart
│   │   └── ai_suggestion_repository.dart
│   ├── providers/
│   │   ├── auth_provider.dart
│   │   ├── wallet_provider.dart
│   │   ├── category_provider.dart
│   │   ├── transaction_provider.dart
│   │   ├── transfer_provider.dart
│   │   ├── budget_provider.dart
│   │   ├── saving_goal_provider.dart
│   │   ├── pet_streak_provider.dart
│   │   └── ai_suggestion_provider.dart
│   ├── screens/
│   │   ├── auth/{login_screen.dart, register_screen.dart}
│   │   ├── home/{home_shell.dart, home_screen.dart, more_menu_screen.dart}
│   │   ├── wallets/{wallet_list_screen.dart, wallet_form_screen.dart, wallet_detail_screen.dart}
│   │   ├── transactions/{transaction_list_screen.dart, transaction_form_screen.dart}
│   │   ├── transfers/{transfer_list_screen.dart, transfer_form_screen.dart}
│   │   ├── categories/{category_list_screen.dart, category_form_screen.dart}
│   │   ├── budgets/{budget_list_screen.dart, budget_form_screen.dart}
│   │   ├── saving_goals/{saving_goal_list_screen.dart, saving_goal_form_screen.dart, saving_goal_detail_screen.dart}
│   │   ├── settings/{settings_screen.dart, profile_screen.dart}
│   │   ├── ai_suggestions/ai_suggestion_screen.dart
│   │   ├── pet/pet_screen.dart
│   │   └── splash_screen.dart
│   └── widgets/...
├── test/...
├── pubspec.yaml
└── analysis_options.yaml
```

`models/...`, `core/utils/...` và `widgets/...` đại diện cho các file Dart trong folder tương ứng. Thư mục nền tảng (`android/`, `ios/`, `web/`...) được lược khỏi cây này vì chủ yếu chứa cấu hình build riêng từng nền tảng.
