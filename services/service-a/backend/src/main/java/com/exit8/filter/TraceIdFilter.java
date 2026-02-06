package com.exit8.filter;

import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import org.slf4j.MDC;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;

import java.io.IOException;
import java.util.Optional;
import java.util.UUID;

@Component
public class TraceIdFilter extends OncePerRequestFilter {

    /** MDC에서 사용할 trace_id 키 */
    public static final String TRACE_ID = "trace_id";

    // HTTP 요청 단위 trace_id 생성 및 MDC 전파용 Filter
    @Override
    protected void doFilterInternal(
            HttpServletRequest request,
            HttpServletResponse response,
            FilterChain filterChain
    ) throws ServletException, IOException {

        // 외부에서 trace_id를 전달한 경우 재사용, 없으면 새로 생성
        String traceId = Optional.ofNullable(request.getHeader("X-Trace-Id"))
                .orElse(UUID.randomUUID().toString());

        // MDC에 trace_id 저장 → 이후 모든 로그에 자동 포함
        MDC.put(TRACE_ID, traceId);

        try {
            filterChain.doFilter(request, response);
        } finally {
            // 요청 종료 시 반드시 제거 (서버 쓰레드 재사용으로 인한 trace_id 오염 방지)
            MDC.clear();
        }
    }
}