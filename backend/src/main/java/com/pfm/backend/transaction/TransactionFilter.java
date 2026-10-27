package com.pfm.backend.transaction;

import java.time.LocalDate;
import java.util.UUID;

public record TransactionFilter(String q, String type, UUID walletId, UUID categoryId,
                LocalDate from, LocalDate to, Long minAmount, Long maxAmount) {
}
