package com.exit8.repository;

import com.exit8.domain.DummyDataRecord;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Slice;
import org.springframework.data.jpa.repository.JpaRepository;

public interface DummyDataRepository
        extends JpaRepository<DummyDataRecord, Long> {
    // findAll(), save() 반복 호출용

    // count 쿼리 없이 LIMIT (size+1)로 Slice 생성
    Slice<DummyDataRecord> findAllBy(Pageable pageable);
}
