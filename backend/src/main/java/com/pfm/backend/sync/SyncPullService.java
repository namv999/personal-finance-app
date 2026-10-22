package com.pfm.backend.sync;

import com.pfm.backend.common.ApiException;
import com.pfm.backend.sync.dto.PullResponse;
import com.pfm.backend.sync.entity.*;
import com.pfm.backend.sync.repo.*;
import java.time.Instant;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.UUID;
import java.util.function.Function;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class SyncPullService {
    private static final int MAX_LIMIT = 500;
    private static final DateTimeFormatter TS =
            DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'").withZone(ZoneOffset.UTC);

    private final WalletRepository wallets;
    private final CategoryRepository categories;
    private final SavingGoalRepository goals;
    private final TransactionRepository transactions;
    private final TransferRepository transfers;
    private final MonthlyBudgetRepository budgets;

    public SyncPullService(WalletRepository wallets, CategoryRepository categories, SavingGoalRepository goals,
            TransactionRepository transactions, TransferRepository transfers, MonthlyBudgetRepository budgets) {
        this.wallets = wallets;
        this.categories = categories;
        this.goals = goals;
        this.transactions = transactions;
        this.transfers = transfers;
        this.budgets = budgets;
    }

    @Transactional(readOnly = true)
    public PullResponse pull(UUID uid, long cursor, int limit) {
        if (cursor < 0 || limit < 1 || limit > MAX_LIMIT) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_FAILED",
                    "cursor phải >= 0 và limit từ 1 đến 500");
        }

        Pageable page = PageRequest.of(0, limit + 1);
        var w = wallets.findByUserIdAndServerVersionGreaterThanOrderByServerVersionAsc(uid, cursor, page);
        var c = categories.findByUserIdAndServerVersionGreaterThanOrderByServerVersionAsc(uid, cursor, page);
        var g = goals.findByUserIdAndServerVersionGreaterThanOrderByServerVersionAsc(uid, cursor, page);
        var t = transactions.findByUserIdAndServerVersionGreaterThanOrderByServerVersionAsc(uid, cursor, page);
        var f = transfers.findByUserIdAndServerVersionGreaterThanOrderByServerVersionAsc(uid, cursor, page);
        var b = budgets.findByUserIdAndServerVersionGreaterThanOrderByServerVersionAsc(uid, cursor, page);

        List<Long> all = new ArrayList<>();
        versions(all, w); versions(all, c); versions(all, g); versions(all, t); versions(all, f); versions(all, b);
        Collections.sort(all);
        boolean hasMore = all.size() > limit;
        long cutoff = all.isEmpty() ? cursor : all.get(Math.min(limit, all.size()) - 1);

        var changes = new PullResponse.Changes(
                cut(w, cutoff, SyncPullService::walletRow), cut(c, cutoff, SyncPullService::categoryRow),
                cut(g, cutoff, SyncPullService::goalRow), cut(t, cutoff, SyncPullService::transactionRow),
                cut(f, cutoff, SyncPullService::transferRow), cut(b, cutoff, SyncPullService::budgetRow));
        return new PullResponse(changes, cutoff, hasMore);
    }

    private static void versions(List<Long> out, List<? extends SyncEntity> rows) {
        for (SyncEntity entity : rows) out.add(entity.getServerVersion());
    }

    private static <E extends SyncEntity, D> List<D> cut(List<E> rows, long cutoff, Function<E, D> map) {
        return rows.stream().filter(entity -> entity.getServerVersion() <= cutoff).map(map).toList();
    }

    private static String ts(Instant value) { return value == null ? null : TS.format(value); }

    private static PullResponse.WalletRow walletRow(Wallet e) {
        return new PullResponse.WalletRow(e.getId(), e.getUserId(), e.getWalletName(), e.getWalletType(),
                e.getOpeningBalance(), e.getColor(), e.getIcon(), ts(e.getUpdatedAt()), e.isDeleted(), e.getServerVersion());
    }

    private static PullResponse.CategoryRow categoryRow(Category e) {
        return new PullResponse.CategoryRow(e.getId(), e.getUserId(), e.getCategoryName(), e.getType(),
                e.getColor(), e.getIcon(), ts(e.getUpdatedAt()), e.isDeleted(), e.getServerVersion());
    }

    private static PullResponse.GoalRow goalRow(SavingGoal e) {
        return new PullResponse.GoalRow(e.getId(), e.getUserId(), e.getWalletId(), e.getGoalName(), e.getTargetAmount(),
                e.getExpectedCompletionDate(), e.getStatus(), ts(e.getUpdatedAt()), e.isDeleted(), e.getServerVersion());
    }

    private static PullResponse.TransactionRow transactionRow(com.pfm.backend.sync.entity.Transaction e) {
        return new PullResponse.TransactionRow(e.getId(), e.getUserId(), e.getWalletId(), e.getCategoryId(), e.getType(),
                e.getAmount(), e.getNote(), e.getSource(), e.getTransactionDate(), ts(e.getCreatedAt()),
                ts(e.getUpdatedAt()), e.isDeleted(), e.getServerVersion());
    }

    private static PullResponse.TransferRow transferRow(Transfer e) {
        return new PullResponse.TransferRow(e.getId(), e.getUserId(), e.getSourceWalletId(), e.getDestinationWalletId(),
                e.getGoalId(), e.getAmount(), e.getTransferDate(), e.getNote(), ts(e.getUpdatedAt()), e.isDeleted(), e.getServerVersion());
    }

    private static PullResponse.BudgetRow budgetRow(MonthlyBudget e) {
        return new PullResponse.BudgetRow(e.getId(), e.getUserId(), e.getCategoryId(), e.getMonth(),
                e.getSpendingLimit(), ts(e.getUpdatedAt()), e.isDeleted(), e.getServerVersion());
    }
}
