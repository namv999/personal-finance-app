package com.pfm.backend;

import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.security.test.web.servlet.setup.SecurityMockMvcConfigurers.springSecurity;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.UUID;
import org.junit.jupiter.api.BeforeEach;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.ResultActions;
import org.springframework.test.web.servlet.request.RequestPostProcessor;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;
import org.springframework.web.context.WebApplicationContext;

@SpringBootTest
@ActiveProfiles("test")
public abstract class AbstractIntegrationTest {
    protected static final ZoneId VN = ZoneId.of("Asia/Ho_Chi_Minh");
    protected static final String CAT_FOOD = "00000000-0000-4000-8000-000000000003";
    private static final DateTimeFormatter TS =
            DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'").withZone(ZoneOffset.UTC);

    @Autowired WebApplicationContext ctx;
    @Value("${spring.datasource.url}") String dbUrl;
    protected MockMvc mvc;

    @BeforeEach
    void setUpMvc() {
        assertTrue(dbUrl.contains("_test"), "Test phải chạy trên database pfm_test, hiện tại: " + dbUrl);
        mvc = MockMvcBuilders.webAppContextSetup(ctx).apply(springSecurity()).build();
    }

    protected UUID registerUser() throws Exception {
        UUID id = UUID.randomUUID();
        mvc.perform(post("/auth/register").contentType(MediaType.APPLICATION_JSON).content("""
                {"id":"%s","full_name":"Test","email":"u%s@test.com","password":"123456"}
                """.formatted(id, id))).andExpect(status().isCreated());
        return id;
    }

    protected RequestPostProcessor as(UUID userId) {
        return jwt().jwt(j -> j.subject(userId.toString()));
    }

    protected String ts(long secondsAgo) {
        return TS.format(Instant.now().minusSeconds(secondsAgo));
    }

    protected ResultActions push(UUID user, String recordsJson) throws Exception {
        return mvc.perform(post("/sync/push").with(as(user)).contentType(MediaType.APPLICATION_JSON)
                .characterEncoding("UTF-8").content("{\"records\":" + recordsJson + "}"));
    }

    protected String walletJson(UUID id, String updatedAt, boolean deleted) {
        return """
                {"id":"%s","updated_at":"%s","is_deleted":%s,"wallet_name":"Ví test","wallet_type":"SPENDING","opening_balance":0}
                """.formatted(id, updatedAt, deleted);
    }

    protected String txJson(UUID id, UUID walletId, String type, long amount, String note,
            LocalDate date, String categoryId, boolean deleted) {
        String cat = categoryId == null ? "null" : "\"" + categoryId + "\"";
        return """
                {"id":"%s","updated_at":"%s","is_deleted":%s,"wallet_id":"%s","category_id":%s,"type":"%s","amount":%d,"note":"%s","source":"MANUAL","transaction_date":"%s"}
                """.formatted(id, ts(30), deleted, walletId, cat, type, amount, note, date);
    }
}
