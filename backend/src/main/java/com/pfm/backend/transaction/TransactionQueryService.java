package com.pfm.backend.transaction;

import com.pfm.backend.common.ApiException;
import com.pfm.backend.sync.entity.Transaction;
import com.pfm.backend.sync.repo.TransactionRepository;
import com.pfm.backend.transaction.dto.TransactionItem;
import com.pfm.backend.transaction.dto.TransactionPageResponse;
import jakarta.persistence.criteria.Predicate;
import java.time.ZoneOffset;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Set;
import java.util.UUID;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class TransactionQueryService {
    private static final DateTimeFormatter TS = DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'")
            .withZone(ZoneOffset.UTC);
    private static final Sort SORT = Sort.by(Sort.Order.desc("transactionDate"),
            Sort.Order.desc("createdAt"), Sort.Order.desc("id"));
    private static final Set<String> TYPES = Set.of("INCOME", "EXPENSE");

    private final TransactionRepository repo;

    public TransactionQueryService(TransactionRepository repo) {
        this.repo = repo;
    }

    @Transactional(readOnly = true)
    public TransactionPageResponse search(UUID userId, TransactionFilter filter, int page, int size) {
        validate(filter, page, size);
        Page<Transaction> result = repo.findAll(build(userId, filter), PageRequest.of(page, size, SORT));
        List<TransactionItem> items = result.getContent().stream().map(this::toItem).toList();
        return new TransactionPageResponse(items, page, size, result.getTotalElements(), result.getTotalPages());
    }

    private void validate(TransactionFilter f, int page, int size) {
        if (page < 0)
            bad("page phải >= 0");
        if (size < 1 || size > 100)
            bad("size phải từ 1 đến 100");
        if (f.q() != null && f.q().trim().length() > 100)
            bad("q tối đa 100 ký tự");
        if (f.type() != null && !TYPES.contains(f.type()))
            bad("type phải là INCOME hoặc EXPENSE");
        if (f.minAmount() != null && f.minAmount() < 1)
            bad("min_amount phải >= 1");
        if (f.maxAmount() != null && f.maxAmount() < 1)
            bad("max_amount phải >= 1");
        if (f.minAmount() != null && f.maxAmount() != null && f.minAmount() > f.maxAmount()) {
            bad("min_amount lớn hơn max_amount");
        }
        if (f.from() != null && f.to() != null && f.from().isAfter(f.to()))
            bad("from lớn hơn to");
    }

    private void bad(String message) {
        throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDATION_FAILED", message);
    }

    private Specification<Transaction> build(UUID userId, TransactionFilter f) {
        return (root, query, cb) -> {
            List<Predicate> predicates = new ArrayList<>();
            predicates.add(cb.equal(root.get("userId"), userId));
            predicates.add(cb.isFalse(root.<Boolean>get("deleted")));
            if (f.type() != null)
                predicates.add(cb.equal(root.get("type"), f.type()));
            if (f.walletId() != null)
                predicates.add(cb.equal(root.get("walletId"), f.walletId()));
            if (f.categoryId() != null)
                predicates.add(cb.equal(root.get("categoryId"), f.categoryId()));
            if (f.from() != null)
                predicates.add(cb.greaterThanOrEqualTo(root.<java.time.LocalDate>get("transactionDate"), f.from()));
            if (f.to() != null)
                predicates.add(cb.lessThanOrEqualTo(root.<java.time.LocalDate>get("transactionDate"), f.to()));
            if (f.minAmount() != null)
                predicates.add(cb.greaterThanOrEqualTo(root.<Long>get("amount"), f.minAmount()));
            if (f.maxAmount() != null)
                predicates.add(cb.lessThanOrEqualTo(root.<Long>get("amount"), f.maxAmount()));
            if (f.q() != null && !f.q().isBlank()) {
                predicates.add(cb.like(cb.lower(root.<String>get("note")), likePattern(f.q()), '\\'));
            }
            return cb.and(predicates.toArray(new Predicate[0]));
        };
    }

    static String likePattern(String q) {
        String escaped = q.trim().toLowerCase(Locale.ROOT)
                .replace("\\", "\\\\").replace("%", "\\%").replace("_", "\\_").replace("[", "\\[");
        return "%" + escaped + "%";
    }

    private TransactionItem toItem(Transaction t) {
        return new TransactionItem(t.getId(), t.getUserId(), TS.format(t.getUpdatedAt()), t.isDeleted(),
                t.getWalletId(), t.getCategoryId(), t.getType(), t.getAmount(), t.getNote(), t.getSource(),
                t.getTransactionDate().toString(), TS.format(t.getCreatedAt()));
    }
}
