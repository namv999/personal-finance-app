package com.pfm.backend.sync.dto;
import com.fasterxml.jackson.annotation.JsonProperty;
import com.fasterxml.jackson.databind.PropertyNamingStrategies;
import com.fasterxml.jackson.databind.annotation.JsonNaming;
import java.time.Instant;
import java.util.UUID;
@JsonNaming(PropertyNamingStrategies.SnakeCaseStrategy.class)
public record CategoryDto(UUID id, UUID userId, String categoryName, String type, String color, String icon,
        Instant updatedAt, @JsonProperty("is_deleted") boolean isDeleted, Long serverVersion) implements SyncDto {}
