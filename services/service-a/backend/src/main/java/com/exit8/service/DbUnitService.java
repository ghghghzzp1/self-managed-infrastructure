package com.exit8.service;

import com.exit8.config.constants.CircuitNames;
import com.exit8.domain.DummyDataRecord;
import com.exit8.observability.CacheMetrics;
import com.exit8.repository.DummyDataRepository;
import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.beans.factory.annotation.Value;
import java.time.Duration;
import java.util.List;

@Service
@RequiredArgsConstructor
public class DbUnitService {

    private final DummyDataRepository dummyDataRepository;
    private final RedisTemplate<String, Object> redisTemplate;
    private final CacheMetrics cacheMetrics;

    @Value("${redis-cache.ttl-seconds:300}")
    private long cacheTtlSeconds;

    @Value("${spring.application.name}")
    private String applicationName;

    /**
     * 1회 READ 단위 (CircuitBreaker 단위)
     * - 이 메서드가 1 call로 집계되므로 slow-call/failed-call 판단이 의미 있어짐
     * - READ 부하 실험 시 slow-call / failure-rate 판단 기준
     * - 구조 단순화를 위해 Redis I/O도 동일 트랜잭션 경계 내에서 수행
     */
    @CircuitBreaker(name = CircuitNames.TEST_CIRCUIT)
    @Transactional(readOnly = true) // REQUIRED 기본
    public void simulateDbReadOne(int pageIndex, boolean cacheEnabled) {

        final String cacheKey = String.format(
                "test:%s:spring:dummy-data-page:%d-20",
                applicationName,
                pageIndex
        );
        final Pageable pageable = PageRequest.of(pageIndex, 20, Sort.by("id").ascending());

        // Redis 비활성화 시 → DB 직행 (캐시 지표 집계 제외)
        if (!cacheEnabled) {
            dummyDataRepository.findAll(pageable);
            return;
        }
        // Redis ValueOperations 핸들 (동일 연산 반복 호출 시 가독성 및 코드 단순화 목적)
        final var ops = redisTemplate.opsForValue();

        try {
            @SuppressWarnings("unchecked")
            var cached = (List<DummyDataRecord>) ops.get(cacheKey);

            if (cached != null) {
                cacheMetrics.incrementHit();
                return;
            }
            // Cache Miss
            cacheMetrics.incrementMiss();
            var page = dummyDataRepository.findAll(pageable);

            // 3) 캐시 저장 (TTL 보정: 최소 1초)
            long ttl = Math.max(cacheTtlSeconds, 1);
            ops.set(cacheKey, page.getContent(), Duration.ofSeconds(ttl));

        } catch (org.springframework.data.redis.RedisConnectionFailureException |
                 org.springframework.data.redis.RedisSystemException |
                 org.springframework.data.redis.serializer.SerializationException e) {
            // Redis 장애 시 → DB fallback (miss는 이미 집계됨)
            dummyDataRepository.findAll(pageable);
        }
    }

    /**
     * 1회 WRITE 단위 (CircuitBreaker 집계 단위)
     *
     * - WRITE 부하 실험에서 CB 집계 단위를 "1 record 저장"으로 고정
     * - save + flush로 DB I/O를 즉시 발생시켜 커넥션 점유/지연을 재현
     */
    @CircuitBreaker(name = CircuitNames.TEST_CIRCUIT)
    @Transactional
    public void writeOne(int idx) {
        dummyDataRepository.save(new DummyDataRecord("payload-" + idx));
        // 즉시 DB에 반영 (쓰기 지연 방지)
        dummyDataRepository.flush();
    }
}