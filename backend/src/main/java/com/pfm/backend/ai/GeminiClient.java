package com.pfm.backend.ai;

import java.util.Map;

public interface GeminiClient {
    String generateJson(String systemPrompt, String userPrompt);

    default String generateJson(String systemPrompt, String userPrompt, Map<String, Object> schema) {
        return generateJson(systemPrompt, userPrompt);
    }

    default String generateJson(String systemPrompt, String userPrompt,
            Map<String, Object> schema, byte[] image, String mimeType) {
        throw new UnsupportedOperationException("GeminiClient này không hỗ trợ ảnh");
    }
}
