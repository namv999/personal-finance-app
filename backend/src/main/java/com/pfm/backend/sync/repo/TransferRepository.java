package com.pfm.backend.sync.repo;
import com.pfm.backend.sync.entity.Transfer;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
public interface TransferRepository extends JpaRepository<Transfer, UUID> {}
