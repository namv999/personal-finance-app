package com.pfm.backend.ai;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;
import com.pfm.backend.AbstractIntegrationTest;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;

@Import(AiParseIntegrationTest.FakeGeminiConfig.class)
class AiParseIntegrationTest extends AbstractIntegrationTest {
    @Test
    void requiresAuthentication() throws Exception {
        mvc.perform(post("/ai/parse-text").contentType(MediaType.APPLICATION_JSON)
                .content("{\"items\":[],\"categories\":[]}"))
                .andExpect(status().isUnauthorized()).andExpect(jsonPath("$.code").value("UNAUTHORIZED"));
    }

    @Test
    void validatesRequestBeforeCallingAi() throws Exception {
        StringBuilder items = new StringBuilder("[");
        for (int i = 0; i < 11; i++) {
            if (i > 0)
                items.append(',');
            items.append("{\"ref\":\"00000000-0000-4000-8000-000000000001\",\"source\":\"SMS\",\"content\":\"test\"}");
        }
        items.append(']');
        mvc.perform(post("/ai/parse-text").with(as(registerUser())).contentType(MediaType.APPLICATION_JSON)
                .content("{\"items\":" + items + ",\"categories\":[]}"))
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));
    }

    @Test
    void returnsParsedResultWithFakeGemini() throws Exception {
        String request = """
                {"items":[{"ref":"00000000-0000-4000-8000-000000000010","source":"TEXT","content":"-50,000 VND"}],
                 "categories":[{"id":"00000000-0000-4000-8000-000000000003","category_name":"Ăn uống","type":"EXPENSE"}]}
                """;
        mvc.perform(post("/ai/parse-text").with(as(registerUser())).contentType(MediaType.APPLICATION_JSON)
                .content(request))
                .andExpect(status().isOk()).andExpect(jsonPath("$.results[0].status").value("PARSED"))
                .andExpect(jsonPath("$.results[0].suggestion.amount").value(50000))
                .andExpect(
                        jsonPath("$.results[0].suggestion.category_id").value("00000000-0000-4000-8000-000000000003"));
    }

    @TestConfiguration
    static class FakeGeminiConfig {
        @Bean
        @Primary
        GeminiClient fakeGeminiClient() {
            return (system,
                    user) -> "[{\"index\":0,\"is_transaction\":true,\"amount\":50000,\"type\":\"EXPENSE\",\"transaction_date\":\"2026-10-26\",\"category_id\":\"00000000-0000-4000-8000-000000000003\",\"confidence\":0.92}]";
        }
    }
}
