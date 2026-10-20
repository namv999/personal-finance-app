package com.pfm.backend.auth.dto;

public record AuthResponse(String token, UserInfo user) {}
