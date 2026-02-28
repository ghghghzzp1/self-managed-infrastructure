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
        List<DummyDataRecord> cached = null;

        // 1) Redis Cache Read (실패하면 캐시 무시하고 DB로 진행)
        try {
            @SuppressWarnings("unchecked")
            var result = (List<DummyDataRecord>) ops.get(cacheKey);
            cached = result;
        } catch (org.springframework.data.redis.RedisConnectionFailureException |
                 org.springframework.data.redis.RedisSystemException |
                 org.springframework.data.redis.serializer.SerializationException e) {
            // read 실패 -> miss로 처리될 수 있으나, miss 집계는 DB 조회 시점에 1회만 수행
        }

        // 2) Cache Hit
        if (cached != null) {
            cacheMetrics.incrementHit();
            return;
        }

        // 3) Cache Miss -> DB 조회 (DB 조회 발생 시 miss 1회만 증가)
        cacheMetrics.incrementMiss();
        var page = dummyDataRepository.findAll(pageable);

        // 4) Redis Cache Write (실패해도 DB 결과로 정상 처리, DB 재조회 없음)
        try {
            long ttl = Math.max(cacheTtlSeconds, 1);
            ops.set(cacheKey, page.getContent(), Duration.ofSeconds(ttl));
        } catch (org.springframework.data.redis.RedisConnectionFailureException |
                 org.springframework.data.redis.RedisSystemException |
                 org.springframework.data.redis.serializer.SerializationException e) {
            // write 실패 -> 캐시 저장만 실패.
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