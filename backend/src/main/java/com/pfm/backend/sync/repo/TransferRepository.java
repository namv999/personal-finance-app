package com.pfm.backend.sync.repo;
import com.pfm.backend.sync.entity.Transfer;
import java.util.UUID;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.domain.Pageable;
public interface TransferRepository extends JpaRepository<Transfer, UUID> {
    List<Transfer> findByUserIdAndServerVersionGreaterThanOrderByServerVersionAsc(UUID userId, long serverVersion, Pageable pageable);
}
