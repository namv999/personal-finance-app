package com.pfm.backend.ai.dto;

import com.pfm.backend.ai.dto.ParseTextRequest.Cat;
import jakarta.validation.Valid;
import jakarta.validation.constraints.*;
import java.util.List;

public record ParseImageRequest(
        @NotBlank @Size(max = 4_200_000) String imageBase64,
        @NotNull @Pattern(regexp = "image/(jpeg|png|webp)") String mimeType,
        @NotNull @Size(max = 100) List<@Valid @NotNull Cat> categories) {
}
