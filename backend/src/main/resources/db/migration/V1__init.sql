CREATE SEQUENCE seq_server_version AS BIGINT START WITH 1 INCREMENT BY 1;

CREATE TABLE users (
    id UNIQUEIDENTIFIER PRIMARY KEY,
    full_name NVARCHAR(100) NOT NULL,
    email NVARCHAR(255) NOT NULL UNIQUE,         -- lowercase, kiểm soát ở code
    password_hash NVARCHAR(100) NOT NULL,
    monthly_income BIGINT NULL,
    created_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    is_deleted BIT NOT NULL DEFAULT 0
);

CREATE TABLE wallets (
    id UNIQUEIDENTIFIER PRIMARY KEY,
    user_id UNIQUEIDENTIFIER NOT NULL REFERENCES users(id),
    wallet_name NVARCHAR(100) NOT NULL,
    wallet_type NVARCHAR(50) NOT NULL,
    opening_balance BIGINT NOT NULL DEFAULT 0,
    color NVARCHAR(20) NULL,
    icon NVARCHAR(50) NULL,
    updated_at DATETIME2(3) NOT NULL,
    is_deleted BIT NOT NULL DEFAULT 0,
    server_version BIGINT NOT NULL
);

CREATE TABLE categories (
    id UNIQUEIDENTIFIER PRIMARY KEY,
    user_id UNIQUEIDENTIFIER NULL REFERENCES users(id),   -- NULL = danh mục hệ thống
    category_name NVARCHAR(100) NOT NULL,
    type VARCHAR(10) NOT NULL CHECK (type IN ('INCOME','EXPENSE')),
    color NVARCHAR(20) NULL,
    icon NVARCHAR(50) NULL,
    updated_at DATETIME2(3) NOT NULL,
    is_deleted BIT NOT NULL DEFAULT 0,
    server_version BIGINT NOT NULL
);

CREATE TABLE saving_goals (
    id UNIQUEIDENTIFIER PRIMARY KEY,
    user_id UNIQUEIDENTIFIER NOT NULL REFERENCES users(id),
    wallet_id UNIQUEIDENTIFIER NULL REFERENCES wallets(id),
    goal_name NVARCHAR(100) NOT NULL,
    target_amount BIGINT NOT NULL CHECK (target_amount > 0),
    expected_completion_date DATE NULL,
    status VARCHAR(20) NOT NULL DEFAULT 'IN_PROGRESS',
    updated_at DATETIME2(3) NOT NULL,
    is_deleted BIT NOT NULL DEFAULT 0,
    server_version BIGINT NOT NULL
);

CREATE TABLE transactions (
    id UNIQUEIDENTIFIER PRIMARY KEY,
    user_id UNIQUEIDENTIFIER NOT NULL REFERENCES users(id),
    wallet_id UNIQUEIDENTIFIER NOT NULL REFERENCES wallets(id),
    category_id UNIQUEIDENTIFIER NULL REFERENCES categories(id),
    type VARCHAR(10) NOT NULL CHECK (type IN ('INCOME','EXPENSE')),
    amount BIGINT NOT NULL CHECK (amount > 0),
    note NVARCHAR(500) NULL,
    source VARCHAR(10) NOT NULL DEFAULT 'MANUAL' CHECK (source IN ('MANUAL','SMS','IMAGE','TEXT')),
    transaction_date DATE NOT NULL,
    created_at DATETIME2(3) NOT NULL DEFAULT SYSUTCDATETIME(),
    updated_at DATETIME2(3) NOT NULL,
    is_deleted BIT NOT NULL DEFAULT 0,
    server_version BIGINT NOT NULL
);

CREATE TABLE transfers (
    id UNIQUEIDENTIFIER PRIMARY KEY,
    user_id UNIQUEIDENTIFIER NOT NULL REFERENCES users(id),
    source_wallet_id UNIQUEIDENTIFIER NOT NULL REFERENCES wallets(id),
    destination_wallet_id UNIQUEIDENTIFIER NOT NULL REFERENCES wallets(id),
    goal_id UNIQUEIDENTIFIER NULL REFERENCES saving_goals(id),
    amount BIGINT NOT NULL CHECK (amount > 0),
    transfer_date DATE NOT NULL,
    note NVARCHAR(500) NULL,
    updated_at DATETIME2(3) NOT NULL,
    is_deleted BIT NOT NULL DEFAULT 0,
    server_version BIGINT NOT NULL
);

CREATE TABLE monthly_budgets (
    id UNIQUEIDENTIFIER PRIMARY KEY,
    user_id UNIQUEIDENTIFIER NOT NULL REFERENCES users(id),
    category_id UNIQUEIDENTIFIER NOT NULL REFERENCES categories(id),
    month CHAR(7) NOT NULL,                      -- YYYY-MM
    spending_limit BIGINT NOT NULL CHECK (spending_limit > 0),
    updated_at DATETIME2(3) NOT NULL,
    is_deleted BIT NOT NULL DEFAULT 0,
    server_version BIGINT NOT NULL
);

-- Chỉ mục phục vụ pull theo cursor và gộp budget
CREATE INDEX ix_wallets_pull ON wallets(user_id, server_version);
CREATE INDEX ix_categories_pull ON categories(user_id, server_version);
CREATE INDEX ix_goals_pull ON saving_goals(user_id, server_version);
CREATE INDEX ix_tx_pull ON transactions(user_id, server_version);
CREATE INDEX ix_tf_pull ON transfers(user_id, server_version);
CREATE INDEX ix_budgets_pull ON monthly_budgets(user_id, server_version);
CREATE UNIQUE INDEX ux_budget_active
    ON monthly_budgets(user_id, category_id, month) WHERE is_deleted = 0;

-- 8 danh mục hệ thống, UUID khớp DB_Flutter_Idea.md mục 3.1
INSERT INTO categories (id, user_id, category_name, type, updated_at, is_deleted, server_version) VALUES
('00000000-0000-4000-8000-000000000001', NULL, N'Lương',     'INCOME',  '2026-01-01T00:00:00.000', 0, 0),
('00000000-0000-4000-8000-000000000002', NULL, N'Thưởng',    'INCOME',  '2026-01-01T00:00:00.000', 0, 0),
('00000000-0000-4000-8000-000000000003', NULL, N'Ăn uống',   'EXPENSE', '2026-01-01T00:00:00.000', 0, 0),
('00000000-0000-4000-8000-000000000004', NULL, N'Di chuyển', 'EXPENSE', '2026-01-01T00:00:00.000', 0, 0),
('00000000-0000-4000-8000-000000000005', NULL, N'Mua sắm',   'EXPENSE', '2026-01-01T00:00:00.000', 0, 0),
('00000000-0000-4000-8000-000000000006', NULL, N'Hóa đơn',   'EXPENSE', '2026-01-01T00:00:00.000', 0, 0),
('00000000-0000-4000-8000-000000000007', NULL, N'Giải trí',  'EXPENSE', '2026-01-01T00:00:00.000', 0, 0),
('00000000-0000-4000-8000-000000000008', NULL, N'Sức khỏe',  'EXPENSE', '2026-01-01T00:00:00.000', 0, 0);
