package com.pfm.backend.sync.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.databind.PropertyNamingStrategies;
import com.fasterxml.jackson.databind.annotation.JsonNaming;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;

@JsonNaming(PropertyNamingStrategies.SnakeCaseStrategy.class)
public record ScheduledTransactionDto(UUID id, UUID userId, UUID walletId, UUID categoryId, String type,
                Long amount, String note, LocalDate startDate, String timeOfDay, String repeatUnit,
                Integer repeatEvery, LocalDate endDate, LocalDate nextDueDate, Instant updatedAt,
                @JsonProperty("is_deleted") boolean isDeleted, Long serverVersion) implements SyncDto {
}
