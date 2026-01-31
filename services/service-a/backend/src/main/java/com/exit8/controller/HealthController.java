package com.exit8.controller;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import java.util.Map;

@RestController
public class HealthController {

    @GetMapping("/health")
    public Map<String, String> health() {
        return Map.of(
            "status", "ok",
            "service", "service-a"
        );
    }

    @GetMapping("/api/dashboard")
    public Map<String, Object> dashboard() {
        return Map.of(
            "message", "Dashboard API",
            "data", Map.of(
                "totalUsers", 150,
                "activeUsers", 42
            )
        );
    }
}
