package com.pfm.backend.ai.dto;

import com.pfm.backend.ai.dto.SuggestionRequest.PeriodType;
import java.time.LocalDate;
import java.util.Map;

public record SuggestionResponse(Status status, PeriodType periodType, LocalDate periodStart, LocalDate periodEnd,
        String content, Map<String, Object> data, String message) {
    public enum Status { OK, INSUFFICIENT_DATA }
}
