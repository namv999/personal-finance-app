package com.pfm.backend.sync.repo;

import com.pfm.backend.sync.entity.Transaction;
import java.util.UUID;
import java.util.List;
import java.time.LocalDate;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.JpaSpecificationExecutor;
import org.springframework.data.domain.Pageable;

public interface TransactionRepository extends JpaRepository<Transaction, UUID>, JpaSpecificationExecutor<Transaction> {
    List<Transaction> findByUserIdAndDeletedFalseAndTransactionDateBetween(UUID userId, LocalDate from, LocalDate to);
    List<Transaction> findByUserIdAndServerVersionGreaterThanOrderByServerVersionAsc(UUID userId, long serverVersion,
            Pageable pageable);
}
