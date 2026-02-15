package com.exit8.config.observability;

import io.micrometer.core.instrument.Counter;
import io.micrometer.core.instrument.MeterRegistry;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * 관측 메트릭 정의
 * - RateLimit 관련 Counter를 명시적으로 등록
 * - Prometheus / Grafana 시계열 분석용
 */
@Configuration
public class MetricsConfig {

    /**
     * Rate Limit에 의해 차단된 요청 누적 카운터
     * (Cardinality 폭발 방지를 위해 label 사용하지 않음)
     */
    @Bean
    public Counter rateLimitBlockedCounter(MeterRegistry registry) {
        return Counter.builder("rate_limit_blocked_total")
                .description("Total blocked requests by rate limit")
                .register(registry);
    }

    /**
     * Rate Limit을 통과한 요청 누적 카운터
     */
    @Bean
    public Counter rateLimitAllowedCounter(MeterRegistry registry) {
        return Counter.builder("rate_limit_allowed_total")
                .description("Total allowed requests by rate limit")
                .register(registry);
    }
}
