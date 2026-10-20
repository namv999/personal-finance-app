package com.pfm.backend.sync.entity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import java.util.UUID;
import lombok.Getter;
import lombok.Setter;
@Entity @Table(name = "monthly_budgets") @Getter @Setter
public class MonthlyBudget extends SyncEntity {
    private UUID categoryId;
    @Column(name = "month") private String month;
    private long spendingLimit;
}
