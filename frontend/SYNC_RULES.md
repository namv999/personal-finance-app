# SYNC_RULES

## Phạm vi
- Đồng bộ: wallets, categories (user_id NOT NULL), saving_goals, transactions, transfers, monthly_budgets.
- Không đồng bộ: users (qua /auth/*), pets, saving_streaks, ai_suggestions (cache local kết quả backend trả về), pending_transactions, sync_queue.
- Danh mục hệ thống (user_id NULL): hai phía tự seed cùng UUID, read-only, không push/pull.
- Không gửi cache: wallets.current_balance, saving_goals.saved_amount. Client tính lại sau pull. Số dư ví = opening_balance + thu - chi + chuyển vào - chuyển ra.

## Định dạng
- Tên field JSON = tên cột (snake_case). is_deleted là boolean. Tiền là long (VND).
- transaction_date/transfer_date: yyyy-MM-dd. updated_at: ISO-8601 UTC, mili-giây, hậu tố Z.
- created_at do server tự gán.
- `user_id` khi push là tùy chọn: nếu gửi thì phải khớp user trong token, nếu không server tự gán từ JWT; pull luôn trả `user_id`.

## Auth
- POST /auth/register {id, full_name, email, password} -> 201 {token, user}; trùng email -> 409.
  id là UUID do client sinh (ngoại lệ duy nhất của quy tắc "không nhận id từ body").
- POST /auth/login {email, password} -> {token, user}; sai -> 401 (thông báo chung).
- Email lưu lowercase, unique. Server không bao giờ trả password hash.

## POST /sync/push
- Req: {records: {wallets: [...], categories: [...], ...}} - mỗi bản ghi là snapshot hiện tại (gồm is_deleted).
- Res: {results: [{table, id, status, reason?}]}, status: APPLIED | SKIPPED_NEWER | REJECTED.
- Mỗi item xử lý độc lập; xử lý bảng cha trước con.
- Tối đa 500 bản ghi tổng cộng mỗi request.
- LWW theo updated_at của client; updated_at > now + 5 phút thì ép về now.
- Mỗi lần ghi, server gán server_version (SEQUENCE).
- Chỉ validate cấu trúc: user_id khớp token, bản ghi cha tồn tại cùng user, amount > 0,
  ngày không tương lai theo Asia/Ho_Chi_Minh, goal.wallet_id khớp destination_wallet_id.
- KHÔNG validate đủ số dư (hai máy offline có thể làm ví âm sau khi hợp nhất; client chỉ cảnh báo).
- REJECTED reason: PARENT_DELETED (client soft-delete bản ghi mồ côi, tính lại số dư),
  FUTURE_DATE, INVALID.
- monthly_budgets: hợp nhất theo (user_id, category_id, month) đang active; giữ updated_at mới hơn,
  bản còn lại is_deleted = true.

## GET /sync/pull?cursor=<int64>&limit=500
- Res: {changes: {wallets: [...], categories: [...], saving_goals: [...], transactions: [...], transfers: [...], monthly_budgets: [...]}, next_cursor, has_more}. Lọc server_version > cursor, theo user từ token.
- Cursor là số do server cấp, không phải timestamp. Lần đầu cursor = 0.
- Client gộp mọi trang, áp dụng trong 1 transaction, lưu cursor sau khi thành công.
- Tham số cursor thay cho since.
