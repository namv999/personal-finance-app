package com.pfm.backend.ai;

public interface GeminiClient {
    String generateJson(String systemPrompt, String userPrompt);
}
