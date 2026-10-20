package com.pfm.backend.sync.dto;
import java.time.Instant;
import java.util.UUID;
public interface SyncDto {
    UUID id();
    UUID userId();
    Instant updatedAt();
    boolean isDeleted();
}
