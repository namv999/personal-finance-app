package com.pfm.backend.auth;

import com.pfm.backend.auth.dto.AuthResponse;
import com.pfm.backend.auth.dto.LoginRequest;
import com.pfm.backend.auth.dto.RegisterRequest;
import com.pfm.backend.auth.dto.UserInfo;
import com.pfm.backend.common.ApiException;
import java.time.Instant;
import java.time.temporal.ChronoUnit;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class AuthService {
    private final UserRepository users;
    private final PasswordEncoder encoder;
    private final JwtService jwt;

    public AuthService(UserRepository users, PasswordEncoder encoder, JwtService jwt) {
        this.users = users;
        this.encoder = encoder;
        this.jwt = jwt;
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
        if (!encoder.matches(req.password(), user.getPasswordHash())) throw invalid();
        return toResponse(user);
    }

    private ApiException invalid() {
        return new ApiException(HttpStatus.UNAUTHORIZED, "INVALID_CREDENTIALS", "Sai email hoặc mật khẩu");
    }

    private AuthResponse toResponse(User user) {
        return new AuthResponse(jwt.issue(user.getId()),
            new UserInfo(user.getId(), user.getFullName(), user.getEmail()));
    }
}
