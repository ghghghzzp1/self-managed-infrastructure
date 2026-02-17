package com.exit8.state;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import java.util.concurrent.atomic.AtomicBoolean;

@Component
public class RuntimeFeatureState {

    private final AtomicBoolean rateLimitEnabled;
    private final AtomicBoolean redisCacheEnabled;

    public RuntimeFeatureState(
            @Value("${rate-limit.enabled:false}") boolean rateInit,
            @Value("${redis-cache.enabled:false}") boolean redisInit
    ) {
        this.rateLimitEnabled = new AtomicBoolean(rateInit);
        this.redisCacheEnabled = new AtomicBoolean(redisInit);
    }

    public boolean isRateLimitEnabled() {
        return rateLimitEnabled.get();
    }

    public boolean toggleRateLimit() {
        return rateLimitEnabled.getAndSet(!rateLimitEnabled.get());
    }

    public boolean isRedisCacheEnabled() {
        return redisCacheEnabled.get();
    }

    public boolean toggleRedisCache() {
        return redisCacheEnabled.getAndSet(!redisCacheEnabled.get());
    }
}

