package com.pfm.backend.auth;

import com.pfm.backend.auth.dto.AuthResponse;
import com.pfm.backend.auth.dto.LoginRequest;
import com.pfm.backend.auth.dto.RegisterRequest;
import com.pfm.backend.auth.dto.ResetPasswordRequest;
import com.pfm.backend.auth.dto.UserInfo;
import com.pfm.backend.common.ApiException;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import java.security.SecureRandom;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.mail.MailException;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.Locale;

@Service
public class AuthService {
    private static final Logger log = LoggerFactory.getLogger(AuthService.class);
    private static final SecureRandom RANDOM = new SecureRandom();
    private static final int OTP_TTL_MIN = 10;
    private static final int OTP_MAX_ATTEMPTS = 5;
    private static final int OTP_COOLDOWN_SEC = 60;

    private final UserRepository users;
    private final PasswordEncoder encoder;
    private final JwtService jwt;
    private final JavaMailSender mail;

    public AuthService(UserRepository users, PasswordEncoder encoder, JwtService jwt, JavaMailSender mail) {
        this.users = users;
        this.encoder = encoder;
        this.jwt = jwt;
        this.mail = mail;
    }

    @Transactional
    public AuthResponse register(RegisterRequest req) {
        String email = req.email().trim().toLowerCase(java.util.Locale.ROOT);
        if (users.existsByEmail(email)) {
            throw new ApiException(HttpStatus.CONFLICT, "EMAIL_ALREADY_EXISTS", "Email đã được sử dụng");
        }
        if (users.existsById(req.id())) {
            throw new ApiException(HttpStatus.CONFLICT, "ID_ALREADY_EXISTS", "ID đã tồn tại");
        }
        Instant now = Instant.now().truncatedTo(ChronoUnit.MILLIS);
        User user = users.save(new User(req.id(), req.fullName().trim(), email,
                encoder.encode(req.password()), now));
        return toResponse(user);
    }

    public AuthResponse login(LoginRequest req) {
        String email = req.email().trim().toLowerCase(java.util.Locale.ROOT);
        User user = users.findByEmailAndDeletedFalse(email).orElseThrow(this::invalid);
        if (!encoder.matches(req.password(), user.getPasswordHash()))
            throw invalid();
        return toResponse(user);
    }

    public void forgotPassword(String rawEmail) {
        String email = rawEmail.trim().toLowerCase(Locale.ROOT);
        User user = users.findByEmailAndDeletedFalse(email).orElse(null);
        if (user == null) return;

        Instant now = Instant.now().truncatedTo(ChronoUnit.MILLIS);
        if (user.isOtpCoolingDown(now, OTP_COOLDOWN_SEC)) {
            throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "OTP_TOO_SOON",
                    "Vui lòng đợi 60 giây trước khi gửi lại mã");
        }
        String otp = String.format(Locale.ROOT, "%06d", RANDOM.nextInt(1_000_000));
        user.setResetOtp(encoder.encode(otp), now.plus(OTP_TTL_MIN, ChronoUnit.MINUTES), now);
        users.save(user);

        SimpleMailMessage msg = new SimpleMailMessage();
        msg.setTo(email);
        msg.setSubject("Mã đặt lại mật khẩu");
        msg.setText("Mã xác nhận của bạn là: " + otp + "\nMã có hiệu lực " + OTP_TTL_MIN
                + " phút. Nếu bạn không yêu cầu, hãy bỏ qua email này.");
        try {
            mail.send(msg);
        } catch (MailException ex) {
            log.error("Gửi OTP thất bại: {}", ex.getMessage());
            user.clearResetOtp();
            users.save(user);
            throw new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "MAIL_UNAVAILABLE",
                    "Không gửi được email, thử lại sau");
        }
    }

    @Transactional(noRollbackFor = ApiException.class)
    public void resetPassword(ResetPasswordRequest req) {
        String email = req.email().trim().toLowerCase(Locale.ROOT);
        User user = users.findByEmailAndDeletedFalse(email).orElseThrow(this::invalidOtp);
        Instant now = Instant.now().truncatedTo(ChronoUnit.MILLIS);
        if (!user.hasActiveOtp(now, OTP_MAX_ATTEMPTS)) throw invalidOtp();
        if (!encoder.matches(req.otp(), user.getResetOtpHash())) {
            user.registerOtpFailure();
            throw invalidOtp();
        }
        user.changePassword(encoder.encode(req.newPassword()), now);
    }

    private ApiException invalidOtp() {
        return new ApiException(HttpStatus.BAD_REQUEST, "INVALID_OTP", "Mã không đúng hoặc đã hết hạn");
    }

    private ApiException invalid() {
        return new ApiException(HttpStatus.UNAUTHORIZED, "INVALID_CREDENTIALS", "Sai email hoặc mật khẩu");
    }

    private AuthResponse toResponse(User user) {
        return new AuthResponse(jwt.issue(user.getId()),
                new UserInfo(user.getId(), user.getFullName(), user.getEmail()));
    }
}
