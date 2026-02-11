package com.exit8.config.datasource;

import org.springframework.context.annotation.Configuration;

@Configuration
public class PostgresConfig {
    // PostgreSQL DataSource 설정 향후 진행
    // - 다중 DataSource
    // - RoutingDataSource
    // - Read/Write 분리
    // - 커스텀 TransactionManager

    /**
     * 단일 DataSource
     * 단일 DB
     * 단순 부하 실험
     * → 쓸 이유가 없다.
     */
}
