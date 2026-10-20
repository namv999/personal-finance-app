package com.pfm.backend.sync.repo;
import com.pfm.backend.sync.entity.Transaction;
import java.util.UUID;
import org.springframework.data.jpa.repository.JpaRepository;
public interface TransactionRepository extends JpaRepository<Transaction, UUID> {}
