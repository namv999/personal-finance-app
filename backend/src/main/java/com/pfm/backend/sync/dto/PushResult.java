package com.pfm.backend.sync.dto;
import java.util.UUID;
public record PushResult(String table, UUID id, PushStatus status, RejectReason reason, String message) {}
