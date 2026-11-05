package com.pfm.backend.ai.dto;

public record ChatResponse(Status status, String reply, String message) {
    public enum Status { OK, INSUFFICIENT_DATA }
}
