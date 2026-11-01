package com.pfm.backend.ai;

import com.pfm.backend.common.ApiException;
import java.time.Duration;
import java.util.List;
import java.util.Map;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.client.SimpleClientHttpRequestFactory;
import org.springframework.stereotype.Component;
import org.springframework.web.client.*;

@Component
public class GeminiHttpClient implements GeminiClient {
  private static final Logger log = LoggerFactory.getLogger(GeminiHttpClient.class);
  private static final Map<String, Object> SCHEMA = Map.of("type", "ARRAY", "items", Map.of("type", "OBJECT",
      "properties", Map.of("index", Map.of("type", "INTEGER"), "is_transaction", Map.of("type", "BOOLEAN"),
          "amount", Map.of("type", "NUMBER", "nullable", true), "type",
          Map.of("type", "STRING", "enum", List.of("INCOME", "EXPENSE"), "nullable", true),
          "transaction_date", Map.of("type", "STRING", "nullable", true), "note",
          Map.of("type", "STRING", "nullable", true),
          "category_id", Map.of("type", "STRING", "nullable", true), "confidence",
          Map.of("type", "NUMBER", "nullable", true)),
      "required", List.of("index", "is_transaction")));
  private final RestClient http;
  private final String apiKey, model, fallbackModel;

  public GeminiHttpClient(@Value("${app.gemini.api-key:}") String apiKey,
      @Value("${app.gemini.model}") String model, @Value("${app.gemini.base-url}") String baseUrl,
      @Value("${app.gemini.fallback-model:}") String fallbackModel,
      @Value("${app.gemini.timeout-seconds:15}") int timeoutSeconds) {
    var factory = new SimpleClientHttpRequestFactory();
    factory.setConnectTimeout(Duration.ofSeconds(5));
    factory.setReadTimeout(Duration.ofSeconds(timeoutSeconds));
    http = RestClient.builder().baseUrl(baseUrl).requestFactory(factory).build();
    this.apiKey = apiKey;
    this.model = model;
    this.fallbackModel = fallbackModel == null ? "" : fallbackModel.trim();
  }

  public String generateJson(String systemPrompt, String userPrompt) {
    return generateJson(systemPrompt, userPrompt, SCHEMA);
  }

  @Override
  public String generateJson(String systemPrompt, String userPrompt, Map<String, Object> schema) {
    if (apiKey == null || apiKey.isBlank()) {
      log.error("Thiếu GEMINI_API_KEY");
      throw unavailable();
    }
    String[] models = fallbackModel.isBlank()
        ? new String[] { model, model }
        : new String[] { model, model, fallbackModel };
    ApiException last = null;
    for (int i = 0; i < models.length; i++) {
      try {
        return callOnce(models[i], systemPrompt, userPrompt, schema);
      } catch (ApiException e) {
        if (!"AI_UNAVAILABLE".equals(e.getCode()))
          throw e;
        last = e;
        if (i < models.length - 1) {
          try {
            Thread.sleep(1000);
          } catch (InterruptedException interrupted) {
            Thread.currentThread().interrupt();
            throw e;
          }
        }
      }
    }
    throw last == null ? unavailable() : last;
  }

  private String callOnce(String modelName, String systemPrompt, String userPrompt, Map<String, Object> schema) {
    Map<String, Object> body = Map.of("systemInstruction", Map.of("parts", List.of(Map.of("text", systemPrompt))),
        "contents", List.of(Map.of("role", "user", "parts", List.of(Map.of("text", userPrompt)))),
        "generationConfig", Map.of("temperature", 0, "responseMimeType", "application/json", "responseSchema", schema));
    try {
      Map<?, ?> response = http.post().uri("/models/{model}:generateContent", modelName)
          .header("x-goog-api-key", apiKey)
          .contentType(MediaType.APPLICATION_JSON).body(body).retrieve().body(Map.class);
      return extractText(response);
    } catch (RestClientResponseException e) {
      int status = e.getStatusCode().value();
      log.warn("Gemini model {} trả HTTP {}", modelName, status);
      if (status == 429)
        throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "AI_RATE_LIMITED", "Dịch vụ AI đang quá tải, thử lại sau");
      throw unavailable();
    } catch (RestClientException e) {
      log.warn("Không gọi được Gemini model {}: {}", modelName, e.getMessage());
      throw unavailable();
    }
  }

  private static String extractText(Map<?, ?> r) {
    if (r != null && r.get("candidates") instanceof List<?> c && !c.isEmpty() && c.get(0) instanceof Map<?, ?> ca
        && ca.get("content") instanceof Map<?, ?> co && co.get("parts") instanceof List<?> p && !p.isEmpty()
        && p.get(0) instanceof Map<?, ?> part && part.get("text") instanceof String t)
      return t;
    return "";
  }

  private static ApiException unavailable() {
    return new ApiException(HttpStatus.SERVICE_UNAVAILABLE, "AI_UNAVAILABLE", "Dịch vụ AI tạm thời không khả dụng");
  }
}
