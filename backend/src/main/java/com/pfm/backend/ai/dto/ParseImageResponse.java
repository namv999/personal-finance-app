package com.pfm.backend.ai.dto;

import com.pfm.backend.ai.dto.ParseTextResponse.Status;
import com.pfm.backend.ai.dto.ParseTextResponse.Suggestion;

public record ParseImageResponse(Status status, Suggestion suggestion) {
}
