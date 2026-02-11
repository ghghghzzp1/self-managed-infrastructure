package com.exit8.service;

import com.exit8.dto.SystemHealthStatus;
import com.exit8.exception.ApiException;
import com.zaxxer.hikari.HikariDataSource;
import com.zaxxer.hikari.HikariPoolMXBean;
import io.github.resilience4j.circuitbreaker.CircuitBreaker;
import io.github.resilience4j.circuitbreaker.CircuitBreakerRegistry;
import io.micrometer.core.instrument.MeterRegistry;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import javax.sql.DataSource;
import java.sql.Connection;
import io.micrometer.core.instrument.Timer;
import java.util.concurrent.TimeUnit;

@Service
@RequiredArgsConstructor
public class SystemHealthService {

    private static final String CIRCUIT_NAME = "testCircuit";

    private final CircuitBreakerRegistry circuitBreakerRegistry;
    private final DataSource dataSource;   // HikariDataSource
    private final MeterRegistry meterRegistry;

    public SystemHealthStatus getCurrentStatus() {

        CircuitBreaker circuitBreaker =
                circuitBreakerRegistry.find(CIRCUIT_NAME)
                        .orElseThrow(() -> new ApiException(
                                "CIRCUIT_NOT_FOUND",
                                "circuit breaker not registered: " + CIRCUIT_NAME,
                                HttpStatus.INTERNAL_SERVER_ERROR
                        ));

        String cbState = circuitBreaker.getState().name();

        // 기본값
        String status = "UP";
        String reason = null;

        /* CircuitBreaker 상태가 최우선 */
        if (circuitBreaker.getState() == CircuitBreaker.State.OPEN) {
            return new SystemHealthStatus(
                    "DOWN",
                    cbState,
                    null,
                    "CIRCUIT_BREAKER_OPEN"
            );
        }

        Long avgResponseTimeMs = null;

        Timer timer = meterRegistry
                .find("load.scenario")
                .tag("type", "cpu")
                .timer();

        if (timer != null) {
            avgResponseTimeMs = Math.round(
                    timer.mean(TimeUnit.MILLISECONDS)
            );
        }

        // 상태 판단 이후, 보조 정보로만 조회
        if (circuitBreaker.getState() == CircuitBreaker.State.HALF_OPEN) {

            return new SystemHealthStatus(
                    "DEGRADED",
                    cbState,
                    avgResponseTimeMs,
                    "CIRCUIT_BREAKER_HALF_OPEN"
            );
        }

        /* DB 상태는 CLOSED 일 때만 평가 */
        if (dataSource instanceof HikariDataSource hikari) {
            HikariPoolMXBean pool = hikari.getHikariPoolMXBean();

            if (pool == null) {
                status = "DEGRADED";
                reason = "DB_POOL_MBEAN_UNAVAILABLE";
            } else {
                // 현재 사용 중인 커넥션 수 (트래픽이 많을 경우 정상적으로 max까지 도달할 수 있음)
                int active = pool.getActiveConnections();
                // 유휴 커넥션 수 (0 자체는 정상 고부하 상황에서도 발생 가능)
                int idle = pool.getIdleConnections();
                // 커넥션을 얻지 못해 대기 중인 스레드 수 (0보다 크면 이미 서비스 체감 장애가 발생 중)
                int waiting = pool.getThreadsAwaitingConnection();

                // NOTE:
                // active는 Health 상태를 변경하지 않는다.
                // waiting 발생 여부만으로 DEGRADED 판단을 한다.

                // 커넥션 대기 발생 = 이미 병목
                if (waiting > 0) {
                    status = "DEGRADED";
                    reason = "DB_CONNECTION_POOL_WAITING";
                }

                if (idle == 0 && waiting > 0) {
                    status = "DEGRADED";
                    reason = "DB_CONNECTION_POOL_EXHAUSTED";
                }

            }

        }
        // 마지막에 감지된 병목을 대표 원인으로 사용
        return new SystemHealthStatus(
                status,
                cbState,
                avgResponseTimeMs,
                reason
        );
    }
}
