# Frontend: cấu trúc và file Dart

```text
frontend/
├── lib/
│   ├── main.dart
│   ├── app.dart
│   ├── routes/
│   │   └── app_router.dart
│   ├── core/
│   │   ├── constants/
│   │   │   ├── app_colors.dart
│   │   │   └── app_routes.dart
│   │   ├── database/
│   │   │   ├── db_helper.dart
│   │   │   └── txn_ext.dart
│   │   ├── network/
│   │   │   ├── api_client.dart
│   │   │   └── api_endpoints.dart
│   │   ├── theme/
│   │   │   └── app_theme.dart
│   │   └── utils/
│   │       ├── budget_status.dart
│   │       ├── clock.dart
│   │       ├── formatters.dart
│   │       ├── id_generator.dart
│   │       ├── ledger_refresh.dart
│   │       └── validators.dart
│   ├── models/
│   │   ├── ai_suggestion.dart
│   │   ├── category.dart
│   │   ├── monthly_budget.dart
│   │   ├── pet.dart
│   │   ├── saving_goal.dart
│   │   ├── saving_streak.dart
│   │   ├── sync_queue_item.dart
│   │   ├── transaction.dart
│   │   ├── transfer.dart
│   │   ├── user.dart
│   │   └── wallet.dart
│   ├── repositories/
│   │   ├── ai_suggestion_repository.dart
│   │   ├── auth_repository.dart
│   │   ├── budget_repository.dart
│   │   ├── category_repository.dart
│   │   ├── pet_repository.dart
│   │   ├── saving_goal_repository.dart
│   │   ├── saving_streak_repository.dart
│   │   ├── sync_push_repository.dart
│   │   ├── sync_repository.dart
│   │   ├── transaction_repository.dart
│   │   ├── transfer_repository.dart
│   │   └── wallet_repository.dart
│   ├── providers/
│   │   ├── ai_suggestion_provider.dart
│   │   ├── auth_provider.dart
│   │   ├── budget_provider.dart
│   │   ├── category_provider.dart
│   │   ├── pet_streak_provider.dart
│   │   ├── saving_goal_provider.dart
│   │   ├── transaction_provider.dart
│   │   ├── transfer_provider.dart
│   │   └── wallet_provider.dart
│   ├── screens/
│   │   ├── ai_suggestions/ai_suggestion_screen.dart
│   │   ├── auth/{login_screen.dart, register_screen.dart}
│   │   ├── budgets/{budget_form_screen.dart, budget_list_screen.dart}
│   │   ├── categories/{category_form_screen.dart, category_list_screen.dart}
│   │   ├── home/{home_screen.dart, home_shell.dart, more_menu_screen.dart}
│   │   ├── pet/pet_screen.dart
│   │   ├── saving_goals/{saving_goal_detail_screen.dart, saving_goal_form_screen.dart, saving_goal_list_screen.dart}
│   │   ├── settings/{profile_screen.dart, settings_screen.dart}
│   │   ├── transactions/{transaction_form_screen.dart, transaction_list_screen.dart}
│   │   ├── transfers/{transfer_form_screen.dart, transfer_list_screen.dart}
│   │   ├── wallets/{wallet_detail_screen.dart, wallet_form_screen.dart, wallet_list_screen.dart}
│   │   └── splash_screen.dart
│   └── widgets/
│       ├── app_text_field.dart
│       ├── budget_status_bar.dart
│       ├── confirm_delete_dialog.dart
│       ├── empty_state.dart
│       ├── icon_color_picker.dart
│       ├── loading_view.dart
│       └── wallet_delete_dialog.dart
├── test/...
├── pubspec.yaml
└── analysis_options.yaml
```

Danh sách trên liệt kê các file Dart trong `lib/`, bao gồm toàn bộ file trong `core/` và `widgets/`. Chỉ lược các thư mục nền tảng (`android/`, `ios/`, `web/`...) và các file cấu hình tự tạo ít dùng đến khỏi cây tổng quan; không lược file mã nguồn thông thường.
