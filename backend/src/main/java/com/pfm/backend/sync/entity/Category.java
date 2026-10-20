package com.pfm.backend.sync.entity;
import jakarta.persistence.Entity;
import jakarta.persistence.Table;
import lombok.Getter;
import lombok.Setter;
@Entity @Table(name = "categories") @Getter @Setter
public class Category extends SyncEntity {
    private String categoryName;
    private String type;
    private String color;
    private String icon;
}
