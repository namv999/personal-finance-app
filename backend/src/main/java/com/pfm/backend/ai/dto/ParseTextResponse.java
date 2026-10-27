package com.pfm.backend.ai.dto;

import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record ParseTextResponse(List<Result> results) {
    public enum Status {
        PARSED, NOT_A_TRANSACTION, FAILED
    }

    public record Result(UUID ref, Status status, Suggestion suggestion) {
    }

    public record Suggestion(long amount, String type, LocalDate transactionDate, String note, UUID categoryId,
            double confidence) {
    }
}
