package com.exit8.config.filter;

import com.exit8.filter.ClientIpResolver;
import com.exit8.filter.RateLimitFilter;
import com.exit8.filter.TraceIdFilter;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Filter 실행 순서를 명시적으로 고정하기 위한 작업
 *
 * - RateLimitFilter : 가장 앞단 (부하 자체 차단)
 * - TraceIdFilter   : 실제 처리되는 요청만 trace_id 생성
 *
 * 로직은 Filter에 두고, 이 클래스는 "순서"만 책임
 */
@Configuration
public class FilterOrderConfig {

    // RateLimitFilter 등록 및 최우선 순위 설정
    @Bean
    public FilterRegistrationBean<RateLimitFilter> rateLimitFilterRegistration(
            ClientIpResolver clientIpResolver,
            @Value("${rate-limit.enabled:false}") boolean rateLimitEnabled
    ) {
        // 주입받는 게 아니라 필터 객체를 직접 생성
        RateLimitFilter filter = new RateLimitFilter(clientIpResolver, rateLimitEnabled);

        FilterRegistrationBean<RateLimitFilter> registration = new FilterRegistrationBean<>();
        registration.setFilter(filter);

        // Order(1): 어떤 로직보다 먼저 실행되어 부하가 크면 즉시 차단함
        registration.setOrder(1);
        return registration;
    }

    // TraceIdFilter 등록 (Rate Limit 통과 이후 실행)
    @Bean
    public FilterRegistrationBean<TraceIdFilter> traceIdFilterRegistration() {
        // 파라미터에서 TraceIdFilter filter를 제거하고 메서드 내부에서 직접 생성
        TraceIdFilter filter = new TraceIdFilter();

        FilterRegistrationBean<TraceIdFilter> registration = new FilterRegistrationBean<>();
        registration.setFilter(filter);

        // Order(2): Rate Limit을 통과한 유효한 요청에 대해서만 로그 추적 ID 생성
        registration.setOrder(2);

        return registration;
    }
}