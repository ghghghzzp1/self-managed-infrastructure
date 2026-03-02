package com.exit8.service;

import com.exit8.config.constants.CircuitNames;
import com.exit8.domain.LoadTestLog;
import com.exit8.exception.ApiException;
import com.exit8.repository.LoadTestLogRepository;
import com.exit8.state.RuntimeFeatureState;
import io.github.resilience4j.circuitbreaker.annotation.CircuitBreaker;
import io.micrometer.core.annotation.Timed;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import java.util.concurrent.ExecutionException;
import java.util.concurrent.ForkJoinPool;
import java.util.stream.IntStream;

@Slf4j
@Service
@RequiredArgsConstructor
public class LoadScenarioService {

    private final LoadTestLogRepository loadTestLogRepository;
    private final RuntimeFeatureState runtimeFeatureState;
    private final DbUnitService dbUnitService;

    private static final int MAX_REPEAT = 10_000;
    private static final long MAX_DURATION_MS = 10_000;

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
     * DB READ 부하 (loop driver)
     *  - CircuitBreaker는 simulateDbReadOne() 단위로 집계됨
     *  - ForkJoinPool을 사용하여 병렬도를 제어하고, 서킷브레이커 임계치 도달 속도를 조절함
     */
    @Timed(
            value = "load.scenario",
            extraTags = {"type", "db_read"},
            histogram = true
    )
    public void simulateDbReadLoad(int repeatCount) {

        if (repeatCount <= 0 || repeatCount > MAX_REPEAT) {
            throw new ApiException("INVALID_PARAM", "repeatCount must be between 1 and 10000", HttpStatus.BAD_REQUEST);
        }

        // 요청 시작 시점의 Redis 활성화 상태 스냅샷 → 실행 도중 토글 변경으로 인한 실험 왜곡 방지
        final boolean cacheEnabled = runtimeFeatureState.isRedisCacheEnabled();

        // 병렬도를 10으로 제한하여 서킷이 순식간에 터지는 현상 방지
        ForkJoinPool customThreadPool = new ForkJoinPool(10);
        try {
            customThreadPool.submit(() ->
                    IntStream.range(0, repeatCount)
                            .parallel()
                            .forEach(i -> dbUnitService.simulateDbReadOne(i % 100, cacheEnabled))
            ).get();
        } catch (InterruptedException | ExecutionException e) {
            // 호출부로 예외 전파 혹은 스레드 인터럽트 상태 복구
            Thread.currentThread().interrupt();

            throw new ApiException(
                    "THREAD_INTERRUPTED",
                    "thread was interrupted during processing",
                    HttpStatus.INTERNAL_SERVER_ERROR
            );
        } finally {
            customThreadPool.shutdown();
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
    public void simulateDbWriteLoad(int repeatCount) {
        if (repeatCount <= 0 || repeatCount > MAX_REPEAT) {
            throw new ApiException(
                    "INVALID_PARAM",
                    "repeatCount must be between 1 and 10000",
                    HttpStatus.BAD_REQUEST
            );
        }

        for (int i = 0; i < repeatCount; i++) {
            dbUnitService.writeOne(i);
        }
    }
}