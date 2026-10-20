package com.pfm.backend.sync.dto;
import java.util.List;
public record PushRequest(Records records) {
    public record Records(List<WalletDto> wallets, List<CategoryDto> categories, List<SavingGoalDto> savingGoals,
            List<TransactionDto> transactions, List<TransferDto> transfers, List<MonthlyBudgetDto> monthlyBudgets) {}
}
