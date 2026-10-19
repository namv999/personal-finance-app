# Personal Finance Management App - Database Design

## 1. Entity Relationship Diagram (ERD)

```mermaid
erDiagram
    USERS ||--o{ WALLETS : owns
    USERS ||--o{ CATEGORIES : creates
    USERS ||--o{ TRANSACTIONS : records
    USERS ||--o{ SAVING_GOALS : sets
    USERS ||--o{ TRANSFERS : makes
    USERS ||--o{ MONTHLY_BUDGETS : sets
    USERS ||--|| PETS : has
    USERS ||--|| SAVING_STREAKS : has
    USERS ||--o{ AI_SUGGESTIONS : receives
    USERS ||--o{ PENDING_TRANSACTIONS : reviews
    CATEGORIES ||--o{ PENDING_TRANSACTIONS : "suggested for"

    WALLETS ||--o{ TRANSACTIONS : contains
    WALLETS ||--o{ TRANSFERS : "source of"
    WALLETS ||--o{ TRANSFERS : "destination of"
    WALLETS ||--o| SAVING_GOALS : "linked to"

    CATEGORIES ||--o{ TRANSACTIONS : classifies
    CATEGORIES ||--o{ MONTHLY_BUDGETS : "limited by"

    SAVING_GOALS ||--o{ TRANSFERS : "funded by"

    USERS {
        string id PK
        string full_name
        string email UK
        string password_hash
        int monthly_income "để dành cho tính năng phát triển sau, chưa dùng ở MVP"
        datetime created_at
        datetime updated_at
        bool is_deleted
    }

    WALLETS {
        string id PK
        string user_id FK
        string wallet_name
        string wallet_type "tự do, người dùng đặt tên loại ví"
        int opening_balance "số dư ban đầu, dữ liệu gốc, được đồng bộ"
        int current_balance "cache = opening_balance + thu - chi - chuyển ra + chuyển vào, không đồng bộ"
        string color
        string icon
        datetime updated_at
        bool is_deleted
    }

    CATEGORIES {
        string id PK
        string user_id FK "NULL = danh mục hệ thống (8 UUID cố định, chỉ đọc, không đồng bộ)"
        string category_name
        string type "INCOME hoặc EXPENSE"
        string color
        string icon
        datetime updated_at
        bool is_deleted
    }

    TRANSACTIONS {
        string id PK
        string user_id FK
        string wallet_id FK
        string category_id FK
        string type "INCOME hoặc EXPENSE"
        int amount
        string note
        string source "MANUAL, SMS, IMAGE hoặc TEXT"
        date transaction_date
        datetime created_at
        datetime updated_at
        bool is_deleted
    }

    SAVING_GOALS {
        string id PK
        string user_id FK
        string wallet_id FK "có thể NULL, ví tiết kiệm gắn với mục tiêu"
        string goal_name
        int target_amount
        int saved_amount "giá trị cache, tính lại định kỳ"
        date expected_completion_date
        string status
        datetime updated_at
        bool is_deleted
    }

    TRANSFERS {
        string id PK
        string user_id FK
        string source_wallet_id FK
        string destination_wallet_id FK
        string goal_id FK "có thể NULL"
        int amount
        date transfer_date
        string note
        datetime updated_at
        bool is_deleted
    }

    MONTHLY_BUDGETS {
        string id PK
        string user_id FK
        string category_id FK
        string month "định dạng YYYY-MM"
        int spending_limit
        datetime updated_at
        bool is_deleted
    }

    PETS {
        string id PK
        string user_id FK "unique"
        string pet_name
        int level
        int experience_points
        string shape
        datetime updated_at
    }

    SAVING_STREAKS {
        string id PK
        string user_id FK "unique"
        int current_streak_days
        int longest_streak
        date last_saved_date
        datetime updated_at
    }

    AI_SUGGESTIONS {
        string id PK
        string user_id FK
        string period_type "WEEK hoặc MONTH"
        date period_start
        date period_end
        string suggestion_content
        string suggested_data "JSON số liệu do backend tính"
        datetime created_at
    }

    PENDING_TRANSACTIONS {
        string id PK
        string user_id FK
        string source "SMS, IMAGE hoặc TEXT"
        string masked_content "nội dung đã che số tài khoản, thẻ, điện thoại"
        int amount
        string type "INCOME hoặc EXPENSE"
        date transaction_date
        string note
        string suggested_category_id FK "chỉ giữ nếu thuộc danh mục hợp lệ của user"
        float confidence
        string source_hash "UNIQUE cùng user_id, chống đề xuất trùng"
        string status "NEEDS_AI, PENDING, CONFIRMED hoặc REJECTED"
        datetime updated_at
    }
}
```

## 2. Lược đồ quan hệ (Relational Schema Overview)

| Bảng | Khóa chính | Khóa ngoại | Đồng bộ | Ghi chú |
|---|---|---|---|---|
| `users` | id | - | Không | Đi qua `/auth/*`, không qua `/sync`. Email lưu lowercase. `password_hash` chỉ dùng đăng nhập offline, không bao giờ gửi lên hoặc kéo về |
| `wallets` | id | user_id → users | Có | Ví tự do. `opening_balance` là dữ liệu gốc, `current_balance` là cache |
| `categories` | id | user_id → users (nullable) | Có (chỉ dòng `user_id NOT NULL`) | `user_id NULL` = danh mục hệ thống, hai phía tự seed cùng UUID, chỉ đọc |
| `transactions` | id | user_id, wallet_id, category_id | Có | Giao dịch thu/chi. `source` cho biết nguồn tạo |
| `saving_goals` | id | user_id, wallet_id (nullable) | Có | `saved_amount` là cache, không đồng bộ |
| `transfers` | id | user_id, source_wallet_id, destination_wallet_id, goal_id (nullable) | Có | Chuyển nội bộ, KHÔNG tính vào thu/chi |
| `monthly_budgets` | id | user_id, category_id | Có | Hợp nhất theo khóa tự nhiên (user_id, category_id, month) khi còn hiệu lực |
| `pets` | id | user_id (unique) | Không | XP, level, shape suy ra từ dữ liệu. `pet_name` chỉ lưu local |
| `saving_streaks` | id | user_id (unique) | Không | Suy ra từ transfers hợp lệ, mỗi máy tự tính lại |
| `ai_suggestions` | id | user_id | Không | Cache local kết quả backend trả về. Unique (user_id, period_type, period_start) |
| `pending_transactions` | id | user_id, suggested_category_id | Không | Hộp thư chờ duyệt, chỉ ở local. Chỉ khi người dùng xác nhận mới tạo `transactions` (source ≠ MANUAL) |
| `sync_queue` | id | - | Không | Chỉ ở local, ghi nhận bản ghi bẩn chưa đẩy lên |

### Các quyết định thiết kế quan trọng
- **Khóa chính là UUID (TEXT, lowercase)** do client sinh, để bản ghi tạo offline không trùng ID. Danh mục hệ thống dùng 8 UUID cố định (xem mục 3.1), không dùng ID kiểu `default-...`.
- **`updated_at` (UTC, ISO-8601, mili-giây, hậu tố Z) + `is_deleted`** có ở mọi bảng đồng bộ, phục vụ Last-Write-Wins và xóa mềm.
- **Transfers tách khỏi transactions.** Chuyển tiền nội bộ không làm thay đổi số liệu "tổng đã chi".
- **Cache:** `wallets.current_balance` và `saving_goals.saved_amount` luôn tính lại từ `opening_balance`, `transactions`, `transfers`, không cộng trừ rải rác, và không đồng bộ. Sau mỗi lần pull, client tính lại.
- **Số dư ví** = `opening_balance` + thu − chi + chuyển vào − chuyển ra. Có thể âm sau khi hợp nhất dữ liệu từ nhiều thiết bị; app chỉ cảnh báo, không chặn.
- **Đề xuất AI không ảnh hưởng số dư.** Chỉ tạo giao dịch chính thức sau khi người dùng xác nhận.
- **Ngày nghiệp vụ** (`transaction_date`, `transfer_date`) là `yyyy-MM-dd`, không đổi múi giờ, không được ở tương lai theo Asia/Ho_Chi_Minh (UTC+7). `updated_at` luôn UTC.
## 3. Định nghĩa đầy đủ các bảng (SQL)

```sql
CREATE TABLE users (
    id TEXT PRIMARY KEY,
    full_name TEXT NOT NULL,
    email TEXT UNIQUE,
    password_hash TEXT NOT NULL,
    monthly_income INTEGER,              -- để dành cho tính năng tương lai, chưa dùng ở MVP
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT,
    is_deleted INTEGER DEFAULT 0
);

CREATE TABLE wallets (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    wallet_name TEXT NOT NULL,
    wallet_type TEXT NOT NULL,           -- tự do: SPENDING, SAVINGS, hoặc tên tự đặt
    opening_balance INTEGER NOT NULL DEFAULT 0,  -- số dư ban đầu, dữ liệu gốc
    current_balance INTEGER DEFAULT 0,           -- cache = opening + thu - chi - chuyển ra + chuyển vào
    color TEXT,
    icon TEXT,
    updated_at TEXT,
    is_deleted INTEGER DEFAULT 0,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE categories (
    id TEXT PRIMARY KEY,
    user_id TEXT,                        -- NULL = danh mục mặc định hệ thống
    category_name TEXT NOT NULL,
    type TEXT NOT NULL CHECK (type IN ('INCOME','EXPENSE')),
    color TEXT,
    icon TEXT,
    updated_at TEXT,
    is_deleted INTEGER DEFAULT 0,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE transactions (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    wallet_id TEXT NOT NULL,
    category_id TEXT,
    type TEXT NOT NULL CHECK (type IN ('INCOME','EXPENSE')),
    amount INTEGER NOT NULL CHECK (amount > 0),
    note TEXT,
    source TEXT NOT NULL DEFAULT 'MANUAL' CHECK (source IN ('MANUAL','SMS','IMAGE','TEXT')),
    transaction_date TEXT NOT NULL,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT,
    is_deleted INTEGER DEFAULT 0,
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (wallet_id) REFERENCES wallets(id),
    FOREIGN KEY (category_id) REFERENCES categories(id)
);

CREATE TABLE saving_goals (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    wallet_id TEXT,                      -- ví tiết kiệm gắn với mục tiêu này, nếu có
    goal_name TEXT NOT NULL,
    target_amount INTEGER NOT NULL,
    saved_amount INTEGER DEFAULT 0,      -- giá trị cache, tính lại định kỳ
    expected_completion_date TEXT,
    status TEXT DEFAULT 'IN_PROGRESS',
    updated_at TEXT,
    is_deleted INTEGER DEFAULT 0,
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (wallet_id) REFERENCES wallets(id)
);

CREATE TABLE transfers (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    source_wallet_id TEXT NOT NULL,
    destination_wallet_id TEXT NOT NULL,
    goal_id TEXT,                        -- liên kết tùy chọn đến 1 mục tiêu tiết kiệm
    amount INTEGER NOT NULL CHECK (amount > 0),
    transfer_date TEXT NOT NULL,
    note TEXT,
    updated_at TEXT,
    is_deleted INTEGER DEFAULT 0,
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (source_wallet_id) REFERENCES wallets(id),
    FOREIGN KEY (destination_wallet_id) REFERENCES wallets(id),
    FOREIGN KEY (goal_id) REFERENCES saving_goals(id)
);

CREATE TABLE monthly_budgets (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    category_id TEXT NOT NULL,
    month TEXT NOT NULL,                 -- định dạng: YYYY-MM
    spending_limit INTEGER NOT NULL,
    updated_at TEXT,
    is_deleted INTEGER DEFAULT 0,
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (category_id) REFERENCES categories(id)
);

CREATE TABLE pets (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL UNIQUE,
    pet_name TEXT DEFAULT 'Mam Nho',
    level INTEGER DEFAULT 1,
    experience_points INTEGER DEFAULT 0,
    shape TEXT DEFAULT 'MEDIUM',
    updated_at TEXT,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE saving_streaks (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL UNIQUE,
    current_streak_days INTEGER DEFAULT 0,
    longest_streak INTEGER DEFAULT 0,
    last_saved_date TEXT,
    updated_at TEXT,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

CREATE TABLE ai_suggestions (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    period_type TEXT NOT NULL CHECK (period_type IN ('WEEK','MONTH')),
    period_start TEXT NOT NULL,          -- yyyy-MM-dd
    period_end TEXT NOT NULL,            -- yyyy-MM-dd
    suggestion_content TEXT NOT NULL,
    suggested_data TEXT,                 -- JSON, số liệu do backend tính
    created_at TEXT DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

-- Hộp thư chờ duyệt, chỉ tồn tại ở local, không đồng bộ
CREATE TABLE pending_transactions (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    source TEXT NOT NULL CHECK (source IN ('SMS','IMAGE','TEXT')),
    masked_content TEXT,                 -- đã che số tài khoản, thẻ, điện thoại
    amount INTEGER,
    type TEXT CHECK (type IN ('INCOME','EXPENSE')),
    transaction_date TEXT,
    note TEXT,
    suggested_category_id TEXT,          -- NULL nếu AI trả danh mục không hợp lệ
    confidence REAL,
    source_hash TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'NEEDS_AI'
        CHECK (status IN ('NEEDS_AI','PENDING','CONFIRMED','REJECTED')),
    updated_at TEXT,
    UNIQUE (user_id, source_hash),       -- 2 tài khoản trên cùng máy có thể nhận cùng 1 SMS
    FOREIGN KEY (user_id) REFERENCES users(id),
    FOREIGN KEY (suggested_category_id) REFERENCES categories(id)
);

-- Bảng chỉ tồn tại local (SQLite), dùng cho cơ chế đồng bộ offline, bản thân bảng này không đồng bộ lên server
CREATE TABLE sync_queue (
    id TEXT PRIMARY KEY,
    table_name TEXT NOT NULL,
    record_id TEXT NOT NULL,
    action TEXT NOT NULL CHECK (action IN ('CREATE','UPDATE','DELETE')),
    is_synced INTEGER DEFAULT 0,
    created_at TEXT DEFAULT CURRENT_TIMESTAMP
);
```

## 3.1 Index và seed

```sql
CREATE UNIQUE INDEX ux_budget_active ON monthly_budgets(user_id, category_id, month) WHERE is_deleted = 0;
CREATE INDEX ix_tx_wallet ON transactions(wallet_id, is_deleted);
CREATE INDEX ix_tx_user_date ON transactions(user_id, transaction_date);
CREATE INDEX ix_tf_src ON transfers(source_wallet_id, is_deleted);
CREATE INDEX ix_tf_dst ON transfers(destination_wallet_id, is_deleted);
CREATE INDEX ix_tf_goal ON transfers(goal_id, is_deleted);
CREATE INDEX ix_pending_user_status ON pending_transactions(user_id, status);
CREATE UNIQUE INDEX ux_ai_period ON ai_suggestions(user_id, period_type, period_start);

-- Danh mục hệ thống: ID cố định, SQLite và SQL Server seed giống hệt nhau
-- (user_id NULL, is_deleted 0, updated_at '2026-01-01T00:00:00.000Z')
-- 00000000-0000-4000-8000-000000000001  Lương      INCOME
-- 00000000-0000-4000-8000-000000000002  Thưởng     INCOME
-- 00000000-0000-4000-8000-000000000003  Ăn uống    EXPENSE
-- 00000000-0000-4000-8000-000000000004  Di chuyển  EXPENSE
-- 00000000-0000-4000-8000-000000000005  Mua sắm    EXPENSE
-- 00000000-0000-4000-8000-000000000006  Hóa đơn    EXPENSE
-- 00000000-0000-4000-8000-000000000007  Giải trí   EXPENSE
-- 00000000-0000-4000-8000-000000000008  Sức khỏe   EXPENSE
```
## 4. Tóm tắt luồng đồng bộ (Sync Flow)

1. App luôn ghi SQLite local trước (chạy được khi offline). Mỗi lần ghi, đồng thời thêm một dòng vào `sync_queue` trong cùng transaction.
2. Khi push, client gộp `sync_queue` thành các bản ghi bẩn (theo bảng + id) và đọc **trạng thái hiện tại** của từng bản ghi (gồm `is_deleted`) để gửi lên, không phát lại từng thao tác. Chỉ gửi bản ghi thuộc user hiện tại.
3. Thứ tự bảng khi push và pull: wallets → categories → saving_goals → transactions và transfers → monthly_budgets (bảng cha trước bảng con).
4. `POST /sync/push`: server xử lý độc lập từng bản ghi và trả kết quả riêng: `APPLIED`, `SKIPPED_NEWER` (server đang có bản mới hơn, LWW theo `updated_at`), hoặc `REJECTED` kèm lý do. Client chỉ đánh dấu `is_synced = 1` cho `APPLIED` và `SKIPPED_NEWER`, các dòng đã đồng bộ sẽ được dọn khỏi queue.
5. Mỗi lần server ghi bản ghi, nó gán `server_version` (số nguyên tăng dần). Con trỏ pull dùng `server_version`, không dùng `updated_at` của client, để thiết bị offline đẩy dữ liệu muộn không làm các thiết bị khác bỏ sót thay đổi.
6. `GET /sync/pull?cursor=<int64>`: client gộp mọi trang, áp dụng toàn bộ trong một transaction (LWW theo `updated_at`, `monthly_budgets` hợp nhất theo khóa tự nhiên), rồi mới lưu cursor theo từng user.
7. Sau pull, client tính lại `current_balance`, `saved_amount`, streak và XP của pet, vì đây là các giá trị suy ra.
8. Server không kiểm tra "đủ số dư" khi nhận transfer (ví có thể âm sau khi hợp nhất). Server chỉ kiểm tra cấu trúc: ownership, khóa cha còn tồn tại, `amount > 0`, ngày không tương lai, `goal.wallet_id` khớp ví đích.
9. Bản ghi mà cha đã bị xóa ở máy khác bị `REJECTED (PARENT_DELETED)`; client xóa mềm bản ghi đó và tính lại số dư.

## 5. Ánh xạ SQLite ↔ SQL Server

| SQLite | SQL Server | Ghi chú |
|---|---|---|
| TEXT (UUID) | UNIQUEIDENTIFIER | JSON luôn dùng chữ thường (`java.util.UUID`); client so sánh ID dạng chuỗi |
| TEXT (updated_at) | DATETIME2(3) | UTC, mili-giây; so sánh bằng thời gian, không so chuỗi |
| TEXT (yyyy-MM-dd) | DATE | Ngày nghiệp vụ, không đổi múi giờ |
| INTEGER (is_deleted) | BIT | JSON dùng boolean |
| INTEGER (tiền) | BIGINT | VND, không có phần lẻ |
| - | `server_version BIGINT` (SEQUENCE) | Chỉ có ở server, dùng làm cursor pull |
| UNIQUE INDEX ... WHERE is_deleted = 0 | Filtered unique index | Hợp nhất budget ở server theo khóa tự nhiên |