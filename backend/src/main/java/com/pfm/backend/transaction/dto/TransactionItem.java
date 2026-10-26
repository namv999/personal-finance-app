package com.pfm.backend.transaction.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import java.util.UUID;

public record TransactionItem(UUID id, UUID userId, String updatedAt,
        @JsonProperty("is_deleted") boolean isDeleted,
        UUID walletId, UUID categoryId, String type, long amount, String note, String source,
        String transactionDate, String createdAt) {}
