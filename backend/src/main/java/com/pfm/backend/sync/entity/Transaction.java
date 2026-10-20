package com.pfm.backend.sync.entity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import java.time.Instant;
import java.time.LocalDate;
import java.util.UUID;
import lombok.Getter;
import lombok.Setter;
@Entity @Table(name = "transactions") @Getter @Setter
public class Transaction extends SyncEntity {
    private UUID walletId;
    private UUID categoryId;
    private String type;
    private long amount;
    private String note;
    private String source;
    private LocalDate transactionDate;
    @Column(name = "created_at", nullable = false, updatable = false)
    private Instant createdAt;
}
