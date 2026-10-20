package com.pfm.backend.auth.dto;

import java.util.UUID;

public record UserInfo(UUID id, String fullName, String email) {}
