package com.pfm.backend.ai;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.*;

import com.pfm.backend.AbstractIntegrationTest;
import java.util.Base64;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.context.annotation.Primary;
import org.springframework.http.MediaType;

@Import(AiParseImageIntegrationTest.FakeConfig.class)
class AiParseImageIntegrationTest extends AbstractIntegrationTest {
    private static byte[] jpeg(int marker) {
        byte[] bytes = new byte[32];
        bytes[0] = (byte) 0xFF;
        bytes[1] = (byte) 0xD8;
        bytes[2] = (byte) 0xFF;
        bytes[4] = (byte) marker;
        return bytes;
    }

    private static String body(byte[] image, String mime) {
        return "{\"image_base64\":\"" + Base64.getEncoder().encodeToString(image) + "\",\"mime_type\":\"" + mime
                + "\",\"categories\":[{\"id\":\"00000000-0000-4000-8000-000000000003\",\"category_name\":\"Ăn uống\",\"type\":\"EXPENSE\"}]}";
    }

    @Test
    void requiresAuthentication() throws Exception {
        mvc.perform(post("/ai/parse-image").contentType(MediaType.APPLICATION_JSON).content(body(jpeg(0), "image/jpeg")))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void parsesImageAndMasksNote() throws Exception {
        mvc.perform(post("/ai/parse-image").with(as(registerUser())).contentType(MediaType.APPLICATION_JSON)
                .content(body(jpeg(0), "image/jpeg")))
                .andExpect(status().isOk()).andExpect(jsonPath("$.status").value("PARSED"))
                .andExpect(jsonPath("$.suggestion.amount").value(10000))
                .andExpect(jsonPath("$.suggestion.note").value("Chuyen den [SO]"))
                .andExpect(jsonPath("$.suggestion.category_id").value("00000000-0000-4000-8000-000000000003"));
    }

    @Test
    void notATransaction() throws Exception {
        mvc.perform(post("/ai/parse-image").with(as(registerUser())).contentType(MediaType.APPLICATION_JSON)
                .content(body(jpeg(1), "image/jpeg")))
                .andExpect(status().isOk()).andExpect(jsonPath("$.status").value("NOT_A_TRANSACTION"));
    }

    @Test
    void rejectsMimeMismatch() throws Exception {
        mvc.perform(post("/ai/parse-image").with(as(registerUser())).contentType(MediaType.APPLICATION_JSON)
                .content(body(jpeg(0), "image/png")))
                .andExpect(status().isBadRequest()).andExpect(jsonPath("$.code").value("VALIDATION_FAILED"));
    }

    @TestConfiguration
    static class FakeConfig {
        @Bean
        @Primary
        GeminiClient fakeGeminiClient() {
            return new GeminiClient() {
                @Override
                public String generateJson(String systemPrompt, String userPrompt) {
                    throw new UnsupportedOperationException();
                }

                @Override
                public String generateJson(String systemPrompt, String userPrompt, Map<String, Object> schema,
                        byte[] image, String mimeType) {
                    if (image[4] == 1)
                        return "{\"is_transaction\":false}";
                    return "{\"is_transaction\":true,\"amount\":10000,\"type\":\"EXPENSE\",\"transaction_date\":\"2026-10-26\","
                            + "\"note\":\"Chuyen den 0123456789012\",\"category_id\":\"00000000-0000-4000-8000-000000000003\",\"confidence\":0.9}";
                }
            };
        }
    }
}
