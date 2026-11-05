# Frontend: cấu trúc và file Dart

Cập nhật theo code Flutter hiện có. App offline-first dùng SQLite, Provider và Dio; có auth, đồng bộ hai chiều, phân tích giao dịch từ tin nhắn dán/ảnh, luồng duyệt đề xuất trước khi tạo transaction, màn gợi ý thu chi AI và chat tài chính theo phiên không lưu lịch sử. Hộp thư chờ duyệt cho phép chụp/chọn ảnh, nén, xin đồng ý trước khi gửi tới backend/Gemini và chỉ lưu đề xuất cùng hash byte ảnh (không lưu ảnh). Ảnh cần mạng, giới hạn 3 MB; hash ảnh giúp phát hiện ảnh trùng theo user. Màn gợi ý giải thích kỳ dự kiến và khoảng ngày dữ liệu. Phần đọc SMS inbox có các tiện ích xin quyền, đọc tin gần đây và lọc sơ bộ tin có khả năng là giao dịch.

```text
frontend/
├── pubspec.yaml
├── analysis_options.yaml
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
│   │   ├── sms/
│   │   │   ├── bank_sms_filter.dart
│   │   │   └── sms_reader.dart
│   │   ├── theme/app_theme.dart
│   │   └── utils/
│   │       ├── budget_status.dart
│   │       ├── clock.dart
│   │       ├── formatters.dart
│   │       ├── id_generator.dart
│   │       ├── ledger_refresh.dart
│   │       ├── text_masker.dart
│   │       └── validators.dart
│   ├── models/
│   │   ├── ai_suggestion.dart
│   │   ├── category.dart
│   │   ├── monthly_budget.dart
│   │   ├── pet.dart
│   │   ├── pending_transaction.dart
│   │   ├── saving_goal.dart
│   │   ├── saving_streak.dart
│   │   ├── sync_queue_item.dart
│   │   ├── transaction.dart
│   │   ├── transfer.dart
│   │   ├── user.dart
│   │   └── wallet.dart
│   ├── providers/
│   │   ├── ai_chat_provider.dart
│   │   ├── ai_suggestion_provider.dart
│   │   ├── auth_provider.dart
│   │   ├── budget_provider.dart
│   │   ├── category_provider.dart
│   │   ├── pet_streak_provider.dart
│   │   ├── pending_provider.dart
│   │   ├── saving_goal_provider.dart
│   │   ├── transaction_provider.dart
│   │   ├── transfer_provider.dart
│   │   └── wallet_provider.dart
│   ├── repositories/
│   │   ├── ai_chat_repository.dart
│   │   ├── ai_suggestion_repository.dart
│   │   ├── auth_repository.dart
│   │   ├── budget_repository.dart
│   │   ├── category_repository.dart
│   │   ├── derived_recompute.dart
│   │   ├── pet_repository.dart
│   │   ├── pending_transaction_repository.dart
│   │   ├── saving_goal_repository.dart
│   │   ├── saving_streak_repository.dart
│   │   ├── sync_pull_repository.dart
│   │   ├── sync_push_repository.dart
│   │   ├── sync_repository.dart
│   │   ├── sync_service.dart
│   │   ├── transaction_repository.dart
│   │   ├── transfer_repository.dart
│   │   └── wallet_repository.dart
│   ├── screens/
│   │   ├── ai_chat/ai_chat_screen.dart
│   │   ├── splash_screen.dart
│   │   ├── ai_suggestions/ai_suggestion_screen.dart
│   │   ├── auth/
│   │   │   ├── login_screen.dart
│   │   │   └── register_screen.dart
│   │   ├── budgets/
│   │   │   ├── budget_form_screen.dart
│   │   │   └── budget_list_screen.dart
│   │   ├── categories/
│   │   │   ├── category_form_screen.dart
│   │   │   └── category_list_screen.dart
│   │   ├── home/
│   │   │   ├── home_screen.dart
│   │   │   ├── home_shell.dart
│   │   │   └── more_menu_screen.dart
│   │   ├── pet/
│   │   │   └── pet_screen.dart
│   │   ├── pending/
│   │   │   ├── paste_message_screen.dart
│   │   │   └── pending_inbox_screen.dart
│   │   ├── saving_goals/
│   │   │   ├── saving_goal_detail_screen.dart
│   │   │   ├── saving_goal_form_screen.dart
│   │   │   └── saving_goal_list_screen.dart
│   │   ├── settings/
│   │   │   ├── profile_screen.dart
│   │   │   └── settings_screen.dart
│   │   ├── transactions/
│   │   │   ├── transaction_form_screen.dart
│   │   │   └── transaction_list_screen.dart
│   │   ├── transfers/
│   │   │   ├── transfer_form_screen.dart
│   │   │   └── transfer_list_screen.dart
│   │   └── wallets/
│   │       ├── wallet_detail_screen.dart
│   │       ├── wallet_form_screen.dart
│   │       └── wallet_list_screen.dart
│   └── widgets/
│       ├── app_text_field.dart
│       ├── budget_status_bar.dart
│       ├── confirm_delete_dialog.dart
│       ├── empty_state.dart
│       ├── icon_color_picker.dart
│       ├── loading_view.dart
│       └── wallet_delete_dialog.dart
└── test/
    ├── ai_suggestion_screen_test.dart
    ├── budget_status_bar_test.dart
    ├── image_helpers_test.dart
    ├── pending_screens_test.dart
    ├── sync_repository_test.dart
    ├── text_masker_test.dart
    ├── wallet_delete_dialog_test.dart
    └── widget_test.dart
```

Cây trên liệt kê các file `.dart` hiện có trong `lib/` và `test/`. Test `TextMasker` được đặt trong `test/` cùng các test khác, không nằm trong mã ứng dụng `lib/`. Các file Dart sinh trong `.dart_tool/` hoặc thư mục build, cùng mã nền tảng Android/iOS/Web/Desktop, không nằm trong cây mã nguồn ứng dụng.

`image_picker` được khai báo trong `pubspec.yaml`. Android manifest khai báo intent camera để image picker mở camera hệ thống; app không yêu cầu quyền `CAMERA` riêng.
