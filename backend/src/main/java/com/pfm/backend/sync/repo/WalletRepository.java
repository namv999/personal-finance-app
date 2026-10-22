package com.pfm.backend.sync.repo;
import com.pfm.backend.sync.entity.Wallet;
import java.util.UUID;
import java.util.List;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.domain.Pageable;
public interface WalletRepository extends JpaRepository<Wallet, UUID> {
    List<Wallet> findByUserIdAndServerVersionGreaterThanOrderByServerVersionAsc(UUID userId, long serverVersion, Pageable pageable);
}
