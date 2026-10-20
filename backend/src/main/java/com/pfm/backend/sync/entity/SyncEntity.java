package com.pfm.backend.sync.entity;

import jakarta.persistence.Column;
import jakarta.persistence.Id;
import jakarta.persistence.MappedSuperclass;
import java.time.Instant;
import java.util.UUID;
import lombok.Getter;
import lombok.Setter;

@MappedSuperclass
@Getter @Setter
public abstract class SyncEntity {
    @Id private UUID id;
    @Column(name = "user_id") private UUID userId;
    @Column(name = "updated_at", nullable = false) private Instant updatedAt;
    @Column(name = "is_deleted", nullable = false) private boolean deleted;
    @Column(name = "server_version", nullable = false) private long serverVersion;
}
