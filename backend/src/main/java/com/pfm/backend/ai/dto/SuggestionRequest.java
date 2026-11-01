package com.pfm.backend.ai.dto;

import jakarta.validation.constraints.NotNull;

public record SuggestionRequest(@NotNull PeriodType periodType) {
    public enum PeriodType { WEEK, MONTH }
}
