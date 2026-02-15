package com.exit8.observability;

import org.springframework.stereotype.Component;

import java.util.List;
import java.util.concurrent.ConcurrentLinkedDeque;
import java.util.concurrent.atomic.AtomicInteger;

/**
 * 최근 요청 이벤트를 저장하는 메모리 Ring Buffer
 * - 최대 200건 유지
 * - O(1) 삽입 보장
 */
@Component
public class RequestEventBuffer {

    private static final int MAX_SIZE = 200;

    private final ConcurrentLinkedDeque<RequestEvent> buffer =
            new ConcurrentLinkedDeque<>();

    private final AtomicInteger size = new AtomicInteger(0);

    public void add(RequestEvent event) {

        buffer.addFirst(event);

        if (size.incrementAndGet() > MAX_SIZE) {
            buffer.removeLast();
            size.decrementAndGet();
        }
    }

    public List<RequestEvent> getRecent(int limit) {
        return buffer.stream().limit(limit).toList();
    }
}
