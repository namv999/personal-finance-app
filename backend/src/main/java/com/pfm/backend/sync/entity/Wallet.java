package com.pfm.backend.sync.entity;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;
@Entity @Table(name = "wallets") @Getter @Setter
public class Wallet extends SyncEntity {
    private String walletName;
    private String walletType;
    private long openingBalance;
    private String color;
    private String icon;
}
