# DB_Flutter_Idea

## Đồng bộ và dữ liệu cục bộ
- `users`: email lưu lowercase; không đồng bộ, xác thực qua `/auth/*`.
- `wallets`: `opening_balance` là dữ liệu gốc; `current_balance` là cache tính lại từ ledger.
- `categories`: tám danh mục hệ thống dùng UUID cố định theo `_systemCategoryIds`; danh mục hệ thống có `user_id = NULL`.
- `transactions`: có `source` (`MANUAL`, `SMS`, `IMAGE`, `TEXT`).
- `pending_transactions`: local-only, unique theo `(user_id, source_hash)`; giữ dòng `CONFIRMED` và `REJECTED` để chống đề xuất lặp.
- `ai_suggestions`: schema local hiện tại được giữ cho đến khi model/repository/provider được nâng cấp an toàn.
- `pets`, `saving_streaks`: local-only; XP/level/shape và streak là giá trị suy ra, tính lại sau pull.
- `sync_queue`: local-only, không thêm `user_id`; queue được lọc theo owner của snapshot khi push.
- Index: `ux_budget_active` (chỉ active), index ledger v3, `ix_pending_user_status`.

## Luồng đồng bộ
Push snapshot hiện tại theo thứ tự `wallets`, `categories`, `saving_goals`, `transactions`, `transfers`, `monthly_budgets`. Không gửi cache (`current_balance`, `saved_amount`) hoặc `created_at`. Pull dùng cursor số nguyên `server_version`, gộp mọi trang rồi áp dụng trong một transaction theo LWW `updated_at`. Lưu cursor chỉ sau khi transaction thành công; sau đó tính lại cache và dữ liệu suy ra.
