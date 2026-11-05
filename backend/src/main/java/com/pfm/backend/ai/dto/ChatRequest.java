package com.pfm.backend.ai.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.NotNull;
import jakarta.validation.constraints.Size;
import java.util.List;

public record ChatRequest(@NotEmpty @Size(max = 6) List<@Valid Message> messages) {
    public enum Role { USER, ASSISTANT }

    public record Message(@NotNull Role role, @NotBlank @Size(max = 500) String content) {}
}
