package com.pfm.backend.transaction.dto;

import java.util.List;

public record TransactionPageResponse(List<TransactionItem> items, int page, int size,
        long totalElements, int totalPages) {}
