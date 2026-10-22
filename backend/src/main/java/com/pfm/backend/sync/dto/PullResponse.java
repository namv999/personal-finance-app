package com.pfm.backend.sync.dto;

import com.fasterxml.jackson.annotation.JsonProperty;
import java.time.LocalDate;
import java.util.List;
import java.util.UUID;

public record PullResponse(Changes changes, long nextCursor, boolean hasMore) {
    public record Changes(List<WalletRow> wallets, List<CategoryRow> categories,
            List<GoalRow> savingGoals, List<TransactionRow> transactions,
            List<TransferRow> transfers, List<BudgetRow> monthlyBudgets) {}

    public record WalletRow(UUID id, UUID userId, String walletName, String walletType, long openingBalance,
            String color, String icon, String updatedAt, @JsonProperty("is_deleted") boolean isDeleted, long serverVersion) {}

    public record CategoryRow(UUID id, UUID userId, String categoryName, String type, String color, String icon,
            String updatedAt, @JsonProperty("is_deleted") boolean isDeleted, long serverVersion) {}

    public record GoalRow(UUID id, UUID userId, UUID walletId, String goalName, long targetAmount,
            LocalDate expectedCompletionDate, String status,
            String updatedAt, @JsonProperty("is_deleted") boolean isDeleted, long serverVersion) {}

    public record TransactionRow(UUID id, UUID userId, UUID walletId, UUID categoryId, String type, long amount,
            String note, String source, LocalDate transactionDate, String createdAt,
            String updatedAt, @JsonProperty("is_deleted") boolean isDeleted, long serverVersion) {}

    public record TransferRow(UUID id, UUID userId, UUID sourceWalletId, UUID destinationWalletId, UUID goalId,
            long amount, LocalDate transferDate, String note,
            String updatedAt, @JsonProperty("is_deleted") boolean isDeleted, long serverVersion) {}

    public record BudgetRow(UUID id, UUID userId, UUID categoryId, String month, long spendingLimit,
            String updatedAt, @JsonProperty("is_deleted") boolean isDeleted, long serverVersion) {}
}
