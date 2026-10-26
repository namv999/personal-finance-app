CREATE INDEX ix_tx_user_date ON transactions(user_id, is_deleted, transaction_date DESC);
