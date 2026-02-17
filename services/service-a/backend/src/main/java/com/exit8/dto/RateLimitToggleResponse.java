package com.exit8.dto;

public record RateLimitToggleResponse(
        boolean rateLimitEnabled,
        String statusMessage
) {}
