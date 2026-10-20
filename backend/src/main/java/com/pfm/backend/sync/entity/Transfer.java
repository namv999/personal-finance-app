package com.pfm.backend.sync.entity;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import java.time.LocalDate;
import java.util.UUID;
import lombok.Getter;
import lombok.Setter;
@Entity @Table(name = "transfers") @Getter @Setter
public class Transfer extends SyncEntity {
    private UUID sourceWalletId;
    private UUID destinationWalletId;
    private UUID goalId;
    private long amount;
    private LocalDate transferDate;
    private String note;
}
