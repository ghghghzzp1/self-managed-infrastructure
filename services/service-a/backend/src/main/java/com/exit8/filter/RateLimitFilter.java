package com.exit8.filter;

import com.exit8.logging.LogEvent;
import io.github.bucket4j.Bandwidth;
import io.github.bucket4j.Bucket;
import io.github.bucket4j.Refill;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.web.filter.OncePerRequestFilter;
import com.github.benmanes.caffeine.cache.Cache;
import com.github.benmanes.caffeine.cache.Caffeine;

import java.util.concurrent.TimeUnit;


import java.io.IOException;
import java.time.Duration;


@Slf4j
public class RateLimitFilter extends OncePerRequestFilter {
    /**
     * IP 기반 Rate Limit Filter
     *
     * - 요청 초기에 실행되어 과도한 트래픽을 차단
     * - Bucket4j를 사용한 Token Bucket 방식
     * - CircuitBreaker 이전 단계에서 동작
     */

    private final ClientIpResolver clientIpResolver;
    private final boolean rateLimitEnabled;

    // IP별 Bucket 저장소 (TTL + 최대 크기 제한)
    private final Cache<String, Bucket> bucketStore =
            Caffeine.newBuilder()
                    .expireAfterAccess(10, TimeUnit.MINUTES)   // 10분간 요청 없으면 제거
                    .maximumSize(10_000)                       // 최대 1만 IP 제한
                    .build();

    public RateLimitFilter(
            ClientIpResolver clientIpResolver,
            boolean rateLimitEnabled
    ) {
        this.clientIpResolver = clientIpResolver;
        this.rateLimitEnabled = rateLimitEnabled;
    }

    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain
    ) throws ServletException, IOException {
        // 필터 활성화 여부 확인 (설정값에 따른 동적 제어)
        if (!rateLimitEnabled) {
            filterChain.doFilter(request, response);
            return;
        }

        // 특정 API(/api/load)에만 제한을 적용하여 시스템 안정성 확보
        if (!request.getRequestURI().startsWith("/api/load")) {
            filterChain.doFilter(request, response);
            return;
        }

        // ClientIpResolver를 사용하여 요청자의 IP 식별
        String clientIp = clientIpResolver.resolve(request);
        Bucket bucket = bucketStore.get(clientIp, this::createBucket);

        // 토큰 소비 시도 (Rate Limit 체크)
        if (bucket.tryConsume(1)) {
            filterChain.doFilter(request, response);
            return;
        }

        // 제한 초과 시 차단 및 429 에러 응답
        log.warn(
                "event={} ip={} uri={}",
                LogEvent.RATE_LIMIT_REJECTED,
                clientIp,
                request.getRequestURI()
        );

        response.setStatus(HttpStatus.TOO_MANY_REQUESTS.value());
        response.setContentType(MediaType.APPLICATION_JSON_VALUE);
        response.getWriter().write(
                """
                {
                  "httpCode": 429,
                  "data": null,
                  "error": {
                    "code": "RATE_LIMIT_EXCEEDED",
                    "message": "Too many requests"
                  }
                }
                """
        );
        response.getWriter().flush();

    }

    /**
     * IP당 Rate Limit 정책
     *
     * - 초당 5 req
     * - burst 10 허용
     * 실험용 Rate Limit (Normal-TG 생존)
     *
     * - 초당 20 req
     * - burst 40 허용
     */
    private Bucket createBucket(String ip) {
        Bandwidth limit = Bandwidth.classic(
                40, // // 최대 버스트(보관 가능한 토큰)
                Refill.intervally(20, Duration.ofSeconds(1)) // 초당 충전되는 토큰 수
        );

        return Bucket.builder()
                .addLimit(limit)
                .build();
    }
}

