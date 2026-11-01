package com.pfm.backend.ai;

import java.util.Map;

public interface GeminiClient {
    String generateJson(String systemPrompt, String userPrompt);

    default String generateJson(String systemPrompt, String userPrompt, Map<String, Object> schema) {
        return generateJson(systemPrompt, userPrompt);
    }
}
