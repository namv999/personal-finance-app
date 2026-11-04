package com.pfm.backend.sync.repo;

import com.pfm.backend.sync.entity.ScheduledTransaction;
import java.util.List;
import java.util.UUID;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;

public interface ScheduledTransactionRepository extends JpaRepository<ScheduledTransaction, UUID> {
    List<ScheduledTransaction> findByUserIdAndServerVersionGreaterThanOrderByServerVersionAsc(UUID userId,
            long serverVersion, Pageable pageable);
}
