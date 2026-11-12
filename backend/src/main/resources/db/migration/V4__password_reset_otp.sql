-- OTP đặt lại mật khẩu, lưu trực tiếp trên users
ALTER TABLE users ADD
    reset_otp_hash NVARCHAR(100) NULL,
    reset_otp_expires_at DATETIME2(3) NULL,
    reset_otp_attempts INT NOT NULL CONSTRAINT df_users_otp_attempts DEFAULT 0,
    reset_otp_sent_at DATETIME2(3) NULL;
