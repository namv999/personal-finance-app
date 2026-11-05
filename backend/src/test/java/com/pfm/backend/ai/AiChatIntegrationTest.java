package com.pfm.backend.ai;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.pfm.backend.AbstractIntegrationTest;
import java.time.LocalDate;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.context.annotation.Primary;
import org.springframework.http.MediaType;

@Import(AiChatIntegrationTest.FakeConfig.class)
class AiChatIntegrationTest extends AbstractIntegrationTest {
    static final AtomicInteger CALLS = new AtomicInteger();
    static final AtomicReference<String> LAST_PROMPT = new AtomicReference<>();

    @BeforeEach
    void resetCalls() {
        CALLS.set(0);
        LAST_PROMPT.set(null);
    }

    private org.springframework.test.web.servlet.ResultActions ask(UUID user, String body) throws Exception {
        return mvc.perform(post("/ai/chat").with(as(user)).contentType(MediaType.APPLICATION_JSON).content(body));
    }

    @Test
    void insufficientDataDoesNotCallAi() throws Exception {
        ask(registerUser(), "{\"messages\":[{\"role\":\"USER\",\"content\":\"Tôi chi nhiều nhất vào đâu?\"}]}")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("INSUFFICIENT_DATA"))
                .andExpect(jsonPath("$.reply").doesNotExist());
        assertEquals(0, CALLS.get());
    }

    @Test
    void computesMonthlyTotalsAndSendsOnlySafePromptData() throws Exception {
        UUID user = registerUser(), wallet = UUID.randomUUID();
        LocalDate today = LocalDate.now(VN);
        StringBuilder transactions = new StringBuilder();
        for (int i = 0; i < 5; i++) {
            if (i > 0) transactions.append(',');
            transactions.append(txJson(UUID.randomUUID(), wallet, "EXPENSE", 50000, "PRIVATE_NOTE_SHOULD_NOT_LEAK",
                    today.minusDays(i), CAT_FOOD, false));
        }
        push(user, "{\"wallets\":[" + walletJson(wallet, ts(30), false) + "],\"transactions\":[" + transactions + "]}")
                .andExpect(status().isOk());

        ask(user, "{\"messages\":[{\"role\":\"USER\",\"content\":\"Tháng này tôi chi nhiều nhất vào đâu?\"}]}")
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.status").value("OK"))
                .andExpect(jsonPath("$.reply").value("OK"));

        assertEquals(1, CALLS.get());
        assertTrue(LAST_PROMPT.get().contains("<data>"));
        assertTrue(LAST_PROMPT.get().contains("<history>"));
        assertFalse(LAST_PROMPT.get().contains("PRIVATE_NOTE_SHOULD_NOT_LEAK"));
        assertFalse(LAST_PROMPT.get().contains("wallet_id"));
    }

    @Test
    void lastMessageMustBeUser() throws Exception {
        ask(registerUser(), "{\"messages\":[{\"role\":\"ASSISTANT\",\"content\":\"Hello\"}]}")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));
        assertEquals(0, CALLS.get());
    }

    @Test
    void rejectsMoreThanSixMessages() throws Exception {
        ask(registerUser(), "{\"messages\":["
                + "{\"role\":\"USER\",\"content\":\"1\"},"
                + "{\"role\":\"ASSISTANT\",\"content\":\"2\"},"
                + "{\"role\":\"USER\",\"content\":\"3\"},"
                + "{\"role\":\"ASSISTANT\",\"content\":\"4\"},"
                + "{\"role\":\"USER\",\"content\":\"5\"},"
                + "{\"role\":\"ASSISTANT\",\"content\":\"6\"},"
                + "{\"role\":\"USER\",\"content\":\"7\"}]}")
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));
        assertEquals(0, CALLS.get());
    }

    @TestConfiguration
    static class FakeConfig {
        @Bean
        @Primary
        GeminiClient fakeGemini() {
            return (system, user) -> {
                CALLS.incrementAndGet();
                LAST_PROMPT.set(user);
                return "{\"reply\":\"OK\"}";
            };
        }
    }
}
