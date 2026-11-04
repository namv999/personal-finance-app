package com.pfm.backend.sync.entity;

import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import java.time.LocalDate;
import java.util.UUID;
import lombok.Getter;
import lombok.Setter;

@Entity
@Table(name = "scheduled_transactions")
@Getter
@Setter
public class ScheduledTransaction extends SyncEntity {
    private UUID walletId;
    private UUID categoryId;
    private String type;
    private long amount;
    private String note;
    private LocalDate startDate;
    private String timeOfDay;
    private String repeatUnit;
    private Integer repeatEvery;
    private LocalDate endDate;
    private LocalDate nextDueDate;
}
