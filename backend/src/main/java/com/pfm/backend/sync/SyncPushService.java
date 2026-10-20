package com.pfm.backend.sync;

import com.pfm.backend.common.ApiException;
import com.pfm.backend.sync.dto.*;
import com.pfm.backend.sync.entity.*;
import com.pfm.backend.sync.repo.*;
import java.time.*;
import java.time.temporal.ChronoUnit;
import java.util.*;
import java.util.function.Function;
import java.util.regex.Pattern;
import org.springframework.dao.DataIntegrityViolationException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.support.TransactionTemplate;

@Service
public class SyncPushService {
    private static final ZoneId VN = ZoneId.of("Asia/Ho_Chi_Minh");
    private static final Pattern MONTH = Pattern.compile("^\\d{4}-(0[1-9]|1[0-2])$");
    private static final Set<String> TYPES = Set.of("INCOME", "EXPENSE");
    private static final Set<String> SOURCES = Set.of("MANUAL", "SMS", "IMAGE", "TEXT");
    private static final int MAX_RECORDS = 500;
    private final TransactionTemplate tx;
    private final ServerVersionService versions;
    private final WalletRepository wallets;
    private final CategoryRepository categories;
    private final SavingGoalRepository goals;
    private final TransactionRepository transactions;
    private final TransferRepository transfers;
    private final MonthlyBudgetRepository budgets;

    public SyncPushService(TransactionTemplate tx, ServerVersionService versions, WalletRepository wallets,
            CategoryRepository categories, SavingGoalRepository goals, TransactionRepository transactions,
            TransferRepository transfers, MonthlyBudgetRepository budgets) {
        this.tx = tx; this.versions = versions; this.wallets = wallets; this.categories = categories;
        this.goals = goals; this.transactions = transactions; this.transfers = transfers; this.budgets = budgets;
    }

    private record Outcome(PushStatus status, RejectReason reason, String message) {
        static Outcome applied() { return new Outcome(PushStatus.APPLIED, null, null); }
        static Outcome skipped() { return new Outcome(PushStatus.SKIPPED_NEWER, null, null); }
        static Outcome invalid(String m) { return rejected(RejectReason.INVALID, m); }
        static Outcome rejected(RejectReason r, String m) { return new Outcome(PushStatus.REJECTED, r, m); }
    }

    public PushResponse push(UUID uid, PushRequest req) {
        PushRequest.Records r = req == null ? null : req.records();
        if (r == null) throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_FAILED", "Thiếu records");
        int total = size(r.wallets()) + size(r.categories()) + size(r.savingGoals()) + size(r.transactions())
                + size(r.transfers()) + size(r.monthlyBudgets());
        if (total > MAX_RECORDS) throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_FAILED", "Tối đa 500 bản ghi mỗi request");
        List<PushResult> out = new ArrayList<>();
        each(out, "wallets", r.wallets(), d -> pushWallet(uid, d));
        each(out, "categories", r.categories(), d -> pushCategory(uid, d));
        each(out, "saving_goals", r.savingGoals(), d -> pushGoal(uid, d));
        each(out, "transactions", r.transactions(), d -> pushTransaction(uid, d));
        each(out, "transfers", r.transfers(), d -> pushTransfer(uid, d));
        each(out, "monthly_budgets", r.monthlyBudgets(), d -> pushBudget(uid, d));
        return new PushResponse(out);
    }

    private static int size(List<?> xs) { return xs == null ? 0 : xs.size(); }
    private <D extends SyncDto> void each(List<PushResult> out, String table, List<D> rows, Function<D, Outcome> action) {
        if (rows == null) return;
        for (D d : rows) {
            UUID id = d == null ? null : d.id();
            Outcome result;
            if (d == null || id == null) result = Outcome.invalid("id là bắt buộc");
            else {
                try {
                    result = tx.execute(status -> action.apply(d));
                    if (result == null) result = Outcome.invalid("Không xử lý được bản ghi");
                } catch (DataIntegrityViolationException | IllegalArgumentException e) {
                    result = Outcome.invalid("Dữ liệu không hợp lệ hoặc vi phạm ràng buộc");
                }
            }
            out.add(new PushResult(table, id, result.status(), result.reason(), result.message()));
        }
    }

    private Instant clamp(Instant at) {
        Instant now = Instant.now().truncatedTo(ChronoUnit.MILLIS);
        return at == null || at.isAfter(now.plus(Duration.ofMinutes(5))) ? now : at.truncatedTo(ChronoUnit.MILLIS);
    }
    private boolean future(LocalDate date) { return date.isAfter(LocalDate.now(VN)); }
    private boolean blank(String value) { return value == null || value.isBlank(); }
    private void stamp(SyncEntity entity, Instant at, boolean deleted) {
        entity.setUpdatedAt(at); entity.setDeleted(deleted); entity.setServerVersion(versions.next());
    }
    private <E extends SyncEntity> Outcome gate(UUID uid, SyncDto d, E current, Instant at) {
        if (uid == null || (d.userId() != null && !uid.equals(d.userId()))) return Outcome.invalid("user_id không khớp token");
        if (current != null && (current.getUserId() == null || !uid.equals(current.getUserId()))) return Outcome.invalid("id không thuộc người dùng");
        if (d.updatedAt() == null) return Outcome.invalid("updated_at là bắt buộc");
        if (current != null && !at.isAfter(current.getUpdatedAt())) return Outcome.skipped();
        return null;
    }
    private Outcome checkWallet(UUID uid, UUID id, boolean deleting) {
        Wallet p = id == null ? null : wallets.findById(id).orElse(null);
        if (p == null || !uid.equals(p.getUserId())) return Outcome.invalid("Ví không tồn tại");
        return p.isDeleted() && !deleting ? Outcome.rejected(RejectReason.PARENT_DELETED, "Ví đã bị xóa") : null;
    }
    private Outcome checkCategory(UUID uid, UUID id, boolean deleting) {
        Category p = id == null ? null : categories.findById(id).orElse(null);
        if (p == null || (p.getUserId() != null && !uid.equals(p.getUserId()))) return Outcome.invalid("Danh mục không tồn tại");
        return p.isDeleted() && !deleting ? Outcome.rejected(RejectReason.PARENT_DELETED, "Danh mục đã bị xóa") : null;
    }

    private Outcome pushWallet(UUID uid, WalletDto d) {
        Instant at = clamp(d.updatedAt()); Wallet w = wallets.findById(d.id()).orElse(null);
        Outcome stop = gate(uid, d, w, at); if (stop != null) return stop;
        if (blank(d.walletName()) || blank(d.walletType()) || d.openingBalance() == null) return Outcome.invalid("wallet_name, wallet_type hoặc opening_balance không hợp lệ");
        if (w == null) { w = new Wallet(); w.setId(d.id()); w.setUserId(uid); }
        w.setWalletName(d.walletName().trim()); w.setWalletType(d.walletType()); w.setOpeningBalance(d.openingBalance());
        w.setColor(d.color()); w.setIcon(d.icon()); stamp(w, at, d.isDeleted()); wallets.save(w); return Outcome.applied();
    }
    private Outcome pushCategory(UUID uid, CategoryDto d) {
        Instant at = clamp(d.updatedAt()); Category c = categories.findById(d.id()).orElse(null);
        if (c != null && c.getUserId() == null) return Outcome.invalid("Danh mục hệ thống chỉ đọc");
        Outcome stop = gate(uid, d, c, at); if (stop != null) return stop;
        if (blank(d.categoryName()) || d.type() == null || !TYPES.contains(d.type())) return Outcome.invalid("category_name hoặc type không hợp lệ");
        if (c == null) { c = new Category(); c.setId(d.id()); c.setUserId(uid); }
        c.setCategoryName(d.categoryName().trim()); c.setType(d.type()); c.setColor(d.color()); c.setIcon(d.icon());
        stamp(c, at, d.isDeleted()); categories.save(c); return Outcome.applied();
    }
    private Outcome pushGoal(UUID uid, SavingGoalDto d) {
        Instant at = clamp(d.updatedAt()); SavingGoal g = goals.findById(d.id()).orElse(null);
        Outcome stop = gate(uid, d, g, at); if (stop != null) return stop;
        if (blank(d.goalName()) || d.targetAmount() == null || d.targetAmount() <= 0) return Outcome.invalid("goal_name hoặc target_amount không hợp lệ");
        if (d.walletId() != null) { Outcome p = checkWallet(uid, d.walletId(), d.isDeleted()); if (p != null) return p; }
        if (g == null) { g = new SavingGoal(); g.setId(d.id()); g.setUserId(uid); }
        g.setWalletId(d.walletId()); g.setGoalName(d.goalName().trim()); g.setTargetAmount(d.targetAmount());
        g.setExpectedCompletionDate(d.expectedCompletionDate()); g.setStatus(blank(d.status()) ? "IN_PROGRESS" : d.status());
        stamp(g, at, d.isDeleted()); goals.save(g); return Outcome.applied();
    }
    private Outcome pushTransaction(UUID uid, TransactionDto d) {
        Instant at = clamp(d.updatedAt()); com.pfm.backend.sync.entity.Transaction t = transactions.findById(d.id()).orElse(null);
        Outcome stop = gate(uid, d, t, at); if (stop != null) return stop;
        if (d.type() == null || !TYPES.contains(d.type()) || d.amount() == null || d.amount() <= 0 || d.transactionDate() == null) return Outcome.invalid("type, amount hoặc transaction_date không hợp lệ");
        String source = blank(d.source()) ? "MANUAL" : d.source(); if (!SOURCES.contains(source)) return Outcome.invalid("source không hợp lệ");
        if (future(d.transactionDate())) return Outcome.rejected(RejectReason.FUTURE_DATE, "Ngày ở tương lai");
        Outcome p = checkWallet(uid, d.walletId(), d.isDeleted()); if (p != null) return p;
        if (d.categoryId() != null) { p = checkCategory(uid, d.categoryId(), d.isDeleted()); if (p != null) return p; }
        if (t == null) { t = new com.pfm.backend.sync.entity.Transaction(); t.setId(d.id()); t.setUserId(uid); t.setCreatedAt(Instant.now().truncatedTo(ChronoUnit.MILLIS)); }
        t.setWalletId(d.walletId()); t.setCategoryId(d.categoryId()); t.setType(d.type()); t.setAmount(d.amount());
        t.setNote(d.note()); t.setSource(source); t.setTransactionDate(d.transactionDate()); stamp(t, at, d.isDeleted());
        transactions.save(t); return Outcome.applied();
    }
    private Outcome pushTransfer(UUID uid, TransferDto d) {
        Instant at = clamp(d.updatedAt()); Transfer t = transfers.findById(d.id()).orElse(null);
        Outcome stop = gate(uid, d, t, at); if (stop != null) return stop;
        if (d.amount() == null || d.amount() <= 0 || d.transferDate() == null) return Outcome.invalid("amount hoặc transfer_date không hợp lệ");
        if (future(d.transferDate())) return Outcome.rejected(RejectReason.FUTURE_DATE, "Ngày ở tương lai");
        Outcome p = checkWallet(uid, d.sourceWalletId(), d.isDeleted()); if (p != null) return p;
        p = checkWallet(uid, d.destinationWalletId(), d.isDeleted()); if (p != null) return p;
        if (d.goalId() != null) {
            SavingGoal g = goals.findById(d.goalId()).orElse(null);
            if (g == null || !uid.equals(g.getUserId())) return Outcome.invalid("Mục tiêu không tồn tại");
            if (g.isDeleted() && !d.isDeleted()) return Outcome.rejected(RejectReason.PARENT_DELETED, "Mục tiêu đã bị xóa");
            if (g.getWalletId() != null && !g.getWalletId().equals(d.destinationWalletId())) return Outcome.invalid("goal.wallet_id không khớp ví đích");
        }
        if (t == null) { t = new Transfer(); t.setId(d.id()); t.setUserId(uid); }
        t.setSourceWalletId(d.sourceWalletId()); t.setDestinationWalletId(d.destinationWalletId()); t.setGoalId(d.goalId());
        t.setAmount(d.amount()); t.setTransferDate(d.transferDate()); t.setNote(d.note()); stamp(t, at, d.isDeleted()); transfers.save(t); return Outcome.applied();
    }
    private Outcome pushBudget(UUID uid, MonthlyBudgetDto d) {
        Instant at = clamp(d.updatedAt()); MonthlyBudget b = budgets.findById(d.id()).orElse(null);
        Outcome stop = gate(uid, d, b, at); if (stop != null) return stop;
        if (d.categoryId() == null || d.month() == null || !MONTH.matcher(d.month()).matches() || d.spendingLimit() == null || d.spendingLimit() <= 0) return Outcome.invalid("category_id, month hoặc spending_limit không hợp lệ");
        Outcome p = checkCategory(uid, d.categoryId(), d.isDeleted()); if (p != null) return p;
        boolean loser = false;
        if (!d.isDeleted()) {
            MonthlyBudget other = budgets.findByUserIdAndCategoryIdAndMonthAndDeletedFalse(uid, d.categoryId(), d.month())
                    .stream().filter(x -> !x.getId().equals(d.id())).findFirst().orElse(null);
            if (other != null && at.isAfter(other.getUpdatedAt())) {
                other.setDeleted(true); other.setUpdatedAt(at.plusMillis(1)); other.setServerVersion(versions.next()); budgets.saveAndFlush(other);
            } else if (other != null) loser = true;
        }
        if (b == null) { b = new MonthlyBudget(); b.setId(d.id()); b.setUserId(uid); }
        b.setCategoryId(d.categoryId()); b.setMonth(d.month()); b.setSpendingLimit(d.spendingLimit());
        stamp(b, at, d.isDeleted() || loser); budgets.save(b); return Outcome.applied();
    }
}
