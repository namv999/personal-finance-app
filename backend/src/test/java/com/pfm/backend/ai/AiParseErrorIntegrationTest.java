package com.pfm.backend.ai;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.pfm.backend.AbstractIntegrationTest;
import com.pfm.backend.common.ApiException;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.context.annotation.Primary;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;

@Import(AiParseErrorIntegrationTest.ThrowingConfig.class)
class AiParseErrorIntegrationTest extends AbstractIntegrationTest {
    @Test
    void rateLimitReturns429() throws Exception {
        String request = """
                {"items":[{"ref":"00000000-0000-4000-8000-000000000010","source":"TEXT","content":"-50,000 VND"}],
                 "categories":[]}
                """;
        mvc.perform(post("/ai/parse-text").with(as(registerUser()))
                .contentType(MediaType.APPLICATION_JSON).content(request))
                .andExpect(status().isTooManyRequests())
                .andExpect(jsonPath("$.code").value("AI_RATE_LIMITED"));
    }

    @TestConfiguration
    static class ThrowingConfig {
        @Bean
        @Primary
        GeminiClient throwingGemini() {
            return (systemPrompt, userPrompt) -> {
                throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "AI_RATE_LIMITED", "x");
            };
        }
    }
}
