package com.exit8.controller;

import com.exit8.dto.DefaultResponse;
import com.exit8.dto.SystemHealthStatus;
import com.exit8.dto.SystemSnapshot;
import com.exit8.service.SystemHealthService;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/system")
@RequiredArgsConstructor
public class SystemHealthController {

    private final SystemHealthService systemHealthService;

    /**
     * 운영 상태 판단용 Health API
     * - DOWN인 경우 503 반환
     */
    @GetMapping("/health")
    public ResponseEntity<DefaultResponse<SystemHealthStatus>> health() {

        SystemHealthStatus status = systemHealthService.getCurrentStatus();

        HttpStatus httpStatus =
                "DOWN".equals(status.getStatus())
                        ? HttpStatus.SERVICE_UNAVAILABLE
                        : HttpStatus.OK;

        return ResponseEntity
                .status(httpStatus)
                .body(DefaultResponse.success(
                        httpStatus.value(),
                        status
                ));
    }

    /**
     *  부하 실험 분석 전용 Snapshot API
     *
     * - 상태 판단하지 않음
     * - Raw 계측값만 반환
     * - JMeter 시간축과 정렬 비교 목적
     */
    @GetMapping("/snapshot")
    public ResponseEntity<DefaultResponse<SystemSnapshot>> snapshot() {

        SystemSnapshot snapshot = systemHealthService.getSnapshot();

        return ResponseEntity.ok(
                DefaultResponse.success(
                        HttpStatus.OK.value(),
                        snapshot
                )
        );
    }
}
