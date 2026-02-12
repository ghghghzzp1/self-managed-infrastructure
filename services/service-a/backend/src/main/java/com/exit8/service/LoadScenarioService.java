package com.exit8.service;

import com.exit8.domain.DummyDataRecord;
import com.exit8.domain.LoadTestLog;
import com.exit8.exception.ApiException;
import com.exit8.repository.DummyDataRepository;
import com.exit8.repository.LoadTestLogRepository;
import io.micrometer.core.annotation.Timed;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;

import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;

@Service
@RequiredArgsConstructor
public class LoadScenarioService {

    private final DummyDataRepository dummyDataRepository;
    private final LoadTestLogRepository loadTestLogRepository;
    private final TransactionTemplate transactionTemplate;

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
    @Transactional(readOnly = true)
    public void simulateDbReadLoad(int repeatCount) {
        if (repeatCount <= 0 || repeatCount > MAX_REPEAT) {
            throw new ApiException(
                    "INVALID_PARAM",
                    "repeatCount must be between 1 and 10000",
                    HttpStatus.BAD_REQUEST
            );
        }

        long start = System.currentTimeMillis();

        for (int i = 0; i < repeatCount; i++) {
            Pageable pageable = PageRequest.of(0, 20, Sort.by("id").ascending());
            dummyDataRepository.findAll(pageable);
        }

        // 로그 저장 추후에 진행
//        long duration = System.currentTimeMillis() - start;
//
//        try {
//            loadTestLogRepository.save(
//                    new LoadTestLog("DB_READ", duration)
//            );
//        } catch (Exception ignore) {
//            // 실험용: 로그 실패는 무시
//        }
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
            final int idx = i;

            transactionTemplate.execute(status -> {
                try {
                    dummyDataRepository.save(
                            new DummyDataRecord("payload-" + idx)
                    );
                    dummyDataRepository.flush();
                } catch (Exception e) {
                    // ✔ 트랜잭션만 롤백
                    status.setRollbackOnly();
                }
                return null;
            });
        }

        // 로그 저장 추후에 진행
//        long duration = System.currentTimeMillis() - start;
//
//        try {
//            loadTestLogRepository.save(
//                    new LoadTestLog("DB_WRITE", duration)
//            );
//        } catch (Exception ignore) {
//            // 실험용: 로그 실패는 무시
//        }
    }
}
