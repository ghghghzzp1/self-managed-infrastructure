package com.exit8.service;

import com.exit8.config.constants.CircuitNames;
import com.exit8.domain.DummyDataRecord;
import com.exit8.domain.LoadTestLog;
import com.exit8.exception.ApiException;
import com.exit8.observability.CacheMetrics;
import com.exit8.repository.DummyDataRepository;
import com.exit8.repository.LoadTestLogRepository;
import com.exit8.state.RuntimeFeatureState;
import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import io.micrometer.core.annotation.Timed;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.data.redis.core.RedisTemplate;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;

import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;

import java.time.Duration;
import java.util.List;

@Service
@RequiredArgsConstructor
public class LoadScenarioService {

    private final DummyDataRepository dummyDataRepository;
    private final LoadTestLogRepository loadTestLogRepository;
    private final TransactionTemplate transactionTemplate;

    private final RuntimeFeatureState runtimeFeatureState;
    private final RedisTemplate<String, Object> redisTemplate;
    private final CacheMetrics cacheMetrics;

    private static final int MAX_REPEAT = 10_000;
    private static final long MAX_DURATION_MS = 10_000;
    private static final Duration CACHE_TTL = Duration.ofMinutes(5);

    @Value("${spring.application.name}")
    private String applicationName;

    /**
     * CPU 재귀 부하
     * CPU 부하 → CircuitBreaker OPEN까지 연결 (추후)
     */
    @Timed(
            value = "load.scenario",
            extraTags = {"type", "cpu"},
            histogram = true
    )
    @CircuitBreaker(name = CircuitNames.TEST_CIRCUIT)
    public void generateCpuLoad(long durationMs) {
        if (durationMs <= 0 || durationMs > MAX_DURATION_MS) {
            throw new ApiException(
                    "INVALID_PARAM",
                    "durationMs must be between 1 and 10000 ms",
                    HttpStatus.BAD_REQUEST
            );
        }

        long start = System.currentTimeMillis();
        long end = start + durationMs;

        while (System.currentTimeMillis() < end) {
            Math.sqrt(System.nanoTime());
        }

        long duration = System.currentTimeMillis() - start;

        loadTestLogRepository.save(
                new LoadTestLog("CPU", duration)
        );
    }


    /**
     * DB READ 부하
     */
    @Timed(
            value = "load.scenario",
            extraTags = {"type", "db_read"},
            histogram = true
    )
    @CircuitBreaker(name = CircuitNames.TEST_CIRCUIT)
    public void simulateDbReadLoad(int repeatCount) {

        if (repeatCount <= 0 || repeatCount > MAX_REPEAT) {
            throw new ApiException("INVALID_PARAM", "repeatCount must be between 1 and 10000", HttpStatus.BAD_REQUEST);
        }

        // 요청 시작 시점의 Redis 상태 스냅샷 (요청 도중 토글 흔들림 방지)
        final boolean cacheEnabled = runtimeFeatureState.isRedisCacheEnabled();
        // ValueOperations는 루프 밖에서 1회만 획득
        final var ops = redisTemplate.opsForValue();

        // readOnly 트랜잭션 속성 강제
        TransactionTemplate roTx = new TransactionTemplate(transactionTemplate.getTransactionManager());
        roTx.setReadOnly(true);
        roTx.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);

        for (int i = 0; i < repeatCount; i++) {
            final int pageIndex = i % 100;
            // cacheKey와 pageable의 pageIndex를 반드시 일치시켜야 hitRatio가 의미 있음
            final String cacheKey = String.format(
                    "test:%s:spring:dummy-data-page:%d-20",
                    applicationName,
                    pageIndex
            );

            // Redis OFF → DB 직행 (고정 1페이지로 통일)
            if (!cacheEnabled) {
                roTx.execute(status -> {
                    Pageable pageable = PageRequest.of(pageIndex, 20, Sort.by("id").ascending());
                    dummyDataRepository.findAll(pageable);
                    return null;
                });
                continue;
            }

            try {
                // 1) Cache 조회 (직렬화 가능한 타입 권장: List<DTO> or JSON String)
                @SuppressWarnings("unchecked")
                var cached = (List<DummyDataRecord>) ops.get(cacheKey);

                if (cached != null) {
                    cacheMetrics.incrementHit();
                    continue;
                }
                // 2. Cache Miss → DB 조회
                cacheMetrics.incrementMiss();
                Pageable pageable = PageRequest.of(pageIndex, 20, Sort.by("id").ascending());
                var page = dummyDataRepository.findAll(pageable);

                // 3) Redis 저장: Page 자체 말고 content만 저장(직렬화 안정성)
                ops.set(cacheKey, page.getContent(), CACHE_TTL);

            // Redis 장애/직렬화 문제”만 fallback 대상으로 명확히 제한
            } catch (org.springframework.data.redis.RedisConnectionFailureException |
                     org.springframework.data.redis.RedisSystemException |
                     org.springframework.data.redis.serializer.SerializationException e) {
                // Redis 계층 문제 → DB fallback
                cacheMetrics.incrementMiss();
                Pageable pageable = PageRequest.of(pageIndex, 20, Sort.by("id").ascending());
                dummyDataRepository.findAll(pageable);
            }
        }
    }

    /**
     * DB write 부하
     */
    @Timed(
            value = "load.scenario",
            extraTags = {"type", "db_write"},
            histogram = true
    )
    @CircuitBreaker(name = CircuitNames.TEST_CIRCUIT)
    public void simulateDbWriteLoad(int repeatCount) {
        if (repeatCount <= 0 || repeatCount > MAX_REPEAT) {
            throw new ApiException(
                    "INVALID_PARAM",
                    "repeatCount must be between 1 and 10000",
                    HttpStatus.BAD_REQUEST
            );
        }

        for (int i = 0; i < repeatCount; i++) {
            // 람다 내부에서 사용하기 위해 effectively final 변수로 복사
            final int idx = i;

            transactionTemplate.execute(status -> {
                // 각 반복마다 개별 트랜잭션 시작
                // (하나의 대규모 트랜잭션이 아닌, N개의 독립 트랜잭션 생성)

                dummyDataRepository.save(
                        new DummyDataRecord("payload-" + idx)
                );

                dummyDataRepository.flush();
                // 즉시 DB에 반영 (쓰기 지연 방지)
                // → 실제 DB I/O 발생 → 커넥션 점유 시간 증가
                // → 부하 시 Hikari 풀 고갈 유도 가능

                return null;
                // TransactionTemplate는 반환값이 필요하므로 null 반환
                // 예외 발생 시 자동으로 rollback 처리됨
            });
        }

    }
}