package com.exit8.dto;

public record ToggleResponse(
        boolean ToggleEnabled,
        String statusMessage
) {}
