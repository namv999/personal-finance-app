package com.pfm.backend.ai;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.pfm.backend.AbstractIntegrationTest;
import java.time.LocalDate;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.context.annotation.Primary;
import org.springframework.http.MediaType;

@Import(AiSuggestionIntegrationTest.FakeConfig.class)
class AiSuggestionIntegrationTest extends AbstractIntegrationTest {
    static final AtomicInteger CALLS = new AtomicInteger();

    @BeforeEach
    void resetCalls() { CALLS.set(0); }

    private org.springframework.test.web.servlet.ResultActions ask(UUID user, String body) throws Exception {
        return mvc.perform(post("/ai/suggestions").with(as(user)).contentType(MediaType.APPLICATION_JSON).content(body));
    }

    @Test
    void insufficientDataDoesNotCallAi() throws Exception {
        ask(registerUser(), "{\"period_type\":\"WEEK\"}").andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("INSUFFICIENT_DATA"))
                .andExpect(jsonPath("$.content").doesNotExist());
        assertEquals(0, CALLS.get());
    }

    @Test
    void backendComputesFigures() throws Exception {
        UUID user = registerUser(), wallet = UUID.randomUUID();
        LocalDate today = LocalDate.now(VN);
        StringBuilder transactions = new StringBuilder();
        for (int i = 0; i < 12; i++) {
            if (i > 0) transactions.append(',');
            transactions.append(txJson(UUID.randomUUID(), wallet, "EXPENSE", 50000, "an pho",
                    today.minusDays(i * 2L), CAT_FOOD, false));
        }
        push(user, "{\"wallets\":[" + walletJson(wallet, ts(30), false) + "],\"transactions\":[" + transactions + "]}")
                .andExpect(status().isOk());
        ask(user, "{\"period_type\":\"WEEK\"}").andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("OK"))
                .andExpect(jsonPath("$.period_type").value("WEEK"))
                .andExpect(jsonPath("$.data.avg_expense").value(182609))
                .andExpect(jsonPath("$.data.top_expense_categories[0].avg_amount").value(182609))
                .andExpect(jsonPath("$.data.top_expense_categories[0].share_percent").value(100))
                .andExpect(jsonPath("$.content").value("- OK"));
        assertEquals(1, CALLS.get());
    }

    @Test
    void invalidPeriodTypeIs400() throws Exception {
        ask(registerUser(), "{\"period_type\":\"YEAR\"}").andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));
    }

    @TestConfiguration
    static class FakeConfig {
        @Bean @Primary
        GeminiClient fakeGemini() {
            return (system, user) -> { CALLS.incrementAndGet(); return "{\"content\":\"- OK\"}"; };
        }
    }
}
