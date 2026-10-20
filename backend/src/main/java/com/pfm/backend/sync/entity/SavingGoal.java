package com.pfm.backend.sync.entity;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import java.time.LocalDate;
import java.util.UUID;
import lombok.Getter;
import lombok.Setter;
@Entity @Table(name = "saving_goals") @Getter @Setter
public class SavingGoal extends SyncEntity {
    private UUID walletId;
    private String goalName;
    private long targetAmount;
    private LocalDate expectedCompletionDate;
    private String status;
}
