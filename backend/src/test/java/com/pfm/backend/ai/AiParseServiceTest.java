package com.pfm.backend.ai;

import static org.junit.jupiter.api.Assertions.*;
import tools.jackson.databind.PropertyNamingStrategies;
import tools.jackson.databind.json.JsonMapper;
import com.pfm.backend.ai.dto.ParseTextRequest;
import com.pfm.backend.ai.dto.ParseTextRequest.*;
import com.pfm.backend.ai.dto.ParseTextResponse.Status;
import com.pfm.backend.common.ApiException;
import java.time.*;
import java.util.*;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

class AiParseServiceTest {
    static final UUID FOOD = UUID.fromString("00000000-0000-4000-8000-000000000003");
    static final UUID SALARY = UUID.fromString("00000000-0000-4000-8000-000000000001");
    static final LocalDate TODAY = LocalDate.now(ZoneId.of("Asia/Ho_Chi_Minh"));
    final JsonMapper mapper = JsonMapper.builder().propertyNamingStrategy(PropertyNamingStrategies.SNAKE_CASE).build();

    ParseTextRequest req(int n) {
        List<Item> items = new ArrayList<>();
        for (int i = 0; i < n; i++)
            items.add(new Item(UUID.randomUUID(), Source.SMS, "TK ****1234 -50,000 VND"));
        return new ParseTextRequest(items,
                List.of(new Cat(FOOD, "Ăn uống", "EXPENSE"), new Cat(SALARY, "Lương", "INCOME")));
    }

    private com.pfm.backend.ai.dto.ParseTextResponse run(String json, int n) {
        return new AiParseService((sys, user) -> json, mapper).parse(req(n));
    }

    private String ok(int index, String type, String date, String cat) {
        return """
                {"index":%d,"is_transaction":true,"amount":50000,"type":"%s","transaction_date":%s,"note":"Highlands","category_id":%s,"confidence":0.92}
                """
                .formatted(index, type, date == null ? "null" : "\"" + date + "\"",
                        cat == null ? "null" : "\"" + cat + "\"");
    }

    @Test
    void parsedAndDateFallback() {
        var parsed = run("[" + ok(0, "EXPENSE", TODAY.minusDays(1).toString(), FOOD.toString()) + "]", 1).results()
                .get(0);
        assertEquals(Status.PARSED, parsed.status());
        assertEquals(FOOD, parsed.suggestion().categoryId());
        var future = run("[" + ok(0, "EXPENSE", TODAY.plusDays(2).toString(), null) + "]", 1).results().get(0);
        assertEquals(TODAY, future.suggestion().transactionDate());
    }

    @Test
    void rejectsInvalidJsonAmountTypeAndMissingIndexAsFailed() {
        assertEquals(Status.FAILED, run("not json", 1).results().get(0).status());
        assertEquals(Status.FAILED, run("[{\"index\":0,\"is_transaction\":true,\"amount\":-1,\"type\":\"EXPENSE\"}]", 1)
                .results().get(0).status());
        assertEquals(Status.FAILED, run("[" + ok(2, "EXPENSE", null, null) + "]", 1).results().get(0).status());
    }

    @Test
    void notTransactionAndInvalidCategory() {
        assertEquals(Status.NOT_A_TRANSACTION,
                run("[{\"index\":0,\"is_transaction\":false}]", 1).results().get(0).status());
        var result = run("[" + ok(0, "EXPENSE", null, SALARY.toString()) + "]", 1).results().get(0);
        assertEquals(Status.PARSED, result.status());
        assertNull(result.suggestion().categoryId());
    }

    @Test
    void propagatesRateLimit() {
        var service = new AiParseService((sys, user) -> {
            throw new ApiException(HttpStatus.TOO_MANY_REQUESTS, "AI_RATE_LIMITED", "x");
        }, mapper);
        assertEquals("AI_RATE_LIMITED", assertThrows(ApiException.class, () -> service.parse(req(1))).getCode());
    }

    @Test
    void masksSensitiveDataAndLeavesAmounts() {
        assertFalse(SensitiveMasker.mask("gọi 0912345678 nhé").contains("0912345678"));
        assertFalse(SensitiveMasker.mask("thẻ 1234 5678 9012 3456").contains("5678"));
        assertFalse(SensitiveMasker.mask("STK 1234567890123").contains("1234567890123"));
        assertTrue(SensitiveMasker.mask("-50,000 VND").contains("50,000"));
    }
}
