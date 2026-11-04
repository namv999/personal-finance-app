CREATE TABLE scheduled_transactions (
    id UNIQUEIDENTIFIER PRIMARY KEY,
    user_id UNIQUEIDENTIFIER NOT NULL REFERENCES users(id),
    wallet_id UNIQUEIDENTIFIER NOT NULL REFERENCES wallets(id),
    category_id UNIQUEIDENTIFIER NULL REFERENCES categories(id),
    type VARCHAR(10) NOT NULL CHECK (type IN ('INCOME','EXPENSE')),
    amount BIGINT NOT NULL CHECK (amount > 0),
    note NVARCHAR(500) NULL,
    start_date DATE NOT NULL,
    time_of_day CHAR(5) NOT NULL,
    repeat_unit VARCHAR(10) NULL CHECK (repeat_unit IN ('DAY','WEEK','MONTH','YEAR')),
    repeat_every INT NULL CHECK (repeat_every >= 1),
    end_date DATE NULL,
    next_due_date DATE NULL,
    updated_at DATETIME2(3) NOT NULL,
    is_deleted BIT NOT NULL DEFAULT 0,
    server_version BIGINT NOT NULL,
    CONSTRAINT ck_sched_repeat CHECK (
        (repeat_unit IS NULL AND repeat_every IS NULL)
        OR (repeat_unit IS NOT NULL AND repeat_every IS NOT NULL))
);
CREATE INDEX ix_sched_pull ON scheduled_transactions(user_id, server_version);
