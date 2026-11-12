package com.pfm.backend;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.UUID;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.MediaType;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.mail.MailSendException;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.ResultActions;

class PasswordResetIntegrationTest extends AbstractIntegrationTest {
    // Mail giả: test không gửi email thật
    @MockitoBean
    JavaMailSender mail;

    @Autowired
    JdbcTemplate jdbc;

    private ResultActions forgot(String email) throws Exception {
        return mvc.perform(post("/auth/forgot-password").contentType(MediaType.APPLICATION_JSON)
                .content("{\"email\":\"%s\"}".formatted(email)));
    }

    private ResultActions reset(String email, String otp, String newPassword) throws Exception {
        return mvc.perform(post("/auth/reset-password").contentType(MediaType.APPLICATION_JSON).content("""
                {"email":"%s","otp":"%s","new_password":"%s"}
                """.formatted(email, otp, newPassword)));
    }

    private ResultActions login(String email, String password) throws Exception {
        return mvc.perform(post("/auth/login").contentType(MediaType.APPLICATION_JSON).content("""
                {"email":"%s","password":"%s"}
                """.formatted(email, password)));
    }

    // Tạo user rồi yêu cầu OTP, trả về email của user
    private String newUserWithOtpRequested() throws Exception {
        UUID id = registerUser();
        String email = "u" + id + "@test.com";
        forgot(email).andExpect(status().isOk());
        return email;
    }

    // Lấy OTP từ nội dung mail đã "gửi"
    private String capturedOtp() {
        ArgumentCaptor<SimpleMailMessage> cap = ArgumentCaptor.forClass(SimpleMailMessage.class);
        verify(mail).send(cap.capture());
        Matcher m = Pattern.compile("\\b(\\d{6})\\b").matcher(cap.getValue().getText());
        assertTrue(m.find(), "Không thấy OTP trong nội dung mail");
        return m.group(1);
    }

    // OTP 6 số chắc chắn khác OTP thật
    private String wrongOtp(String realOtp) {
        return realOtp.equals("111111") ? "222222" : "111111";
    }

    @Test
    void resetWithCorrectOtpChangesPassword() throws Exception {
        String email = newUserWithOtpRequested();
        String otp = capturedOtp();
        reset(email, otp, "matkhau-moi").andExpect(status().isOk());
        login(email, "matkhau-moi").andExpect(status().isOk());
        login(email, "123456").andExpect(status().isUnauthorized());
    }

    @Test
    void unknownEmailReturns200AndSendsNothing() throws Exception {
        forgot("khong-ton-tai-" + UUID.randomUUID() + "@test.com").andExpect(status().isOk());
        verify(mail, never()).send(any(SimpleMailMessage.class));
    }

    @Test
    void wrongOtpIsRejected() throws Exception {
        String email = newUserWithOtpRequested();
        String bad = wrongOtp(capturedOtp());
        reset(email, bad, "matkhau-moi")
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value("INVALID_OTP"));
        login(email, "123456").andExpect(status().isOk());
    }

    @Test
    void otpLockedAfterFiveWrongAttempts() throws Exception {
        String email = newUserWithOtpRequested();
        String otp = capturedOtp();
        String bad = wrongOtp(otp);
        for (int i = 0; i < 5; i++) {
            reset(email, bad, "matkhau-moi").andExpect(status().isBadRequest());
        }
        // Kiểm tra luôn noRollbackFor: nếu attempts không được lưu thì OTP đúng vẫn qua
        reset(email, otp, "matkhau-moi")
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value("INVALID_OTP"));
    }

    @Test
    void expiredOtpIsRejected() throws Exception {
        String email = newUserWithOtpRequested();
        String otp = capturedOtp();
        int rows = jdbc.update(
                "UPDATE users SET reset_otp_expires_at = DATEADD(MINUTE, -1, SYSUTCDATETIME()) WHERE email = ?",
                email);
        assertEquals(1, rows);
        reset(email, otp, "matkhau-moi")
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value("INVALID_OTP"));
    }

    @Test
    void otpCannotBeReused() throws Exception {
        String email = newUserWithOtpRequested();
        String otp = capturedOtp();
        reset(email, otp, "matkhau-moi").andExpect(status().isOk());
        reset(email, otp, "matkhau-khac")
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value("INVALID_OTP"));
        login(email, "matkhau-moi").andExpect(status().isOk());
    }

    @Test
    void secondRequestWithin60SecondsIsRejected() throws Exception {
        String email = newUserWithOtpRequested();
        forgot(email).andExpect(status().isTooManyRequests())
                .andExpect(jsonPath("$.code").value("OTP_TOO_SOON"));
    }

    @Test
    void mailFailureReturns503AndAllowsImmediateRetry() throws Exception {
        UUID id = registerUser();
        String email = "u" + id + "@test.com";
        doThrow(new MailSendException("smtp down")).when(mail).send(any(SimpleMailMessage.class));
        forgot(email).andExpect(status().isServiceUnavailable())
                .andExpect(jsonPath("$.code").value("MAIL_UNAVAILABLE"));
        // OTP đã bị xóa nên không dính cooldown
        org.mockito.Mockito.reset(mail);
        forgot(email).andExpect(status().isOk());
    }

    @Test
    void invalidOtpFormatIsValidationError() throws Exception {
        reset("a@test.com", "12ab", "matkhau-moi")
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));
    }
}
