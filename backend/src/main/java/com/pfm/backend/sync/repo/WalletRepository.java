package com.pfm.backend.sync.repo;
import com.pfm.backend.sync.entity.Wallet;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
public interface WalletRepository extends JpaRepository<Wallet, UUID> {}
