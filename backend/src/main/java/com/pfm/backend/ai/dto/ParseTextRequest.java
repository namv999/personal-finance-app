package com.pfm.backend.ai.dto;

import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.util.List;
import java.util.UUID;

public record ParseTextRequest(
        @NotEmpty @Size(max = 10) List<@Valid @NotNull Item> items,
        @NotNull @Size(max = 100) List<@Valid @NotNull Cat> categories) {
    public enum Source {
        SMS, TEXT
    }

    public record Item(@NotNull UUID ref, @NotNull Source source, @NotBlank @Size(max = 1000) String content) {
    }

    public record Cat(@NotNull UUID id, @NotBlank @Size(max = 100) String categoryName,
            @NotNull @Pattern(regexp = "INCOME|EXPENSE") String type) {
    }
}
