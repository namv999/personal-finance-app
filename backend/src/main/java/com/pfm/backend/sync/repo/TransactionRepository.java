package com.pfm.backend.sync.repo;
import com.pfm.backend.sync.entity.Transaction;
import java.util.UUID;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.domain.Pageable;
public interface TransactionRepository extends JpaRepository<Transaction, UUID> {
    List<Transaction> findByUserIdAndServerVersionGreaterThanOrderByServerVersionAsc(UUID userId, long serverVersion, Pageable pageable);
}
