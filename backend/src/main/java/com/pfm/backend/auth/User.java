package com.pfm.backend.auth;

import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import java.time.Instant;
import java.util.UUID;

@Entity
@Table(name = "users")
public class User {
    @Id
    private UUID id;

    @Column(name = "full_name", nullable = false)
    private String fullName;

    @Column(nullable = false, unique = true)
    private String email;

    @Column(name = "password_hash", nullable = false)
    private String passwordHash;

    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;

    @Column(name = "updated_at", nullable = false)
    private Instant updatedAt;

    @Column(name = "is_deleted", nullable = false)
    private boolean deleted;

    @Column(name = "reset_otp_hash")
    private String resetOtpHash;

    @Column(name = "reset_otp_expires_at")
    private Instant resetOtpExpiresAt;

    @Column(name = "reset_otp_attempts", nullable = false)
    private int resetOtpAttempts;

    @Column(name = "reset_otp_sent_at")
    private Instant resetOtpSentAt;

    protected User() {
    }

    public User(UUID id, String fullName, String email, String passwordHash, Instant now) {
        this.id = id;
        this.fullName = fullName;
        this.email = email;
        this.passwordHash = passwordHash;
        this.createdAt = now;
        this.updatedAt = now;
    }

    public UUID getId() {
        return id;
    }

    public String getFullName() {
        return fullName;
    }

    public String getEmail() {
        return email;
    }

    public String getPasswordHash() {
        return passwordHash;
    }

    public String getResetOtpHash() { return resetOtpHash; }

    public boolean isOtpCoolingDown(Instant now, int cooldownSec) {
        return resetOtpSentAt != null && now.isBefore(resetOtpSentAt.plusSeconds(cooldownSec));
    }

    public boolean hasActiveOtp(Instant now, int maxAttempts) {
        return resetOtpHash != null && resetOtpExpiresAt != null
                && now.isBefore(resetOtpExpiresAt) && resetOtpAttempts < maxAttempts;
    }

    public void setResetOtp(String hash, Instant expiresAt, Instant now) {
        this.resetOtpHash = hash;
        this.resetOtpExpiresAt = expiresAt;
        this.resetOtpSentAt = now;
        this.resetOtpAttempts = 0;
    }

    public void registerOtpFailure() { this.resetOtpAttempts++; }

    public void clearResetOtp() {
        this.resetOtpHash = null;
        this.resetOtpExpiresAt = null;
        this.resetOtpSentAt = null;
        this.resetOtpAttempts = 0;
    }

    public void changePassword(String newHash, Instant now) {
        this.passwordHash = newHash;
        this.updatedAt = now;
        clearResetOtp();
    }
}
