# EXIT8 – Load & Observability Test Backend

> Spring Boot 기반 단일 API 서비스에서   
> 의도적 부하, 서킷 브레이커, 관측(Observability)을 테스트하기 위한 백엔드 프로젝트

---

## 1. 프로젝트 목적

이 프로젝트는 단순 CRUD API가 아니라, 
1. 의도적으로 시스템 부하를 발생시키고
2. 서킷 브레이커가 언제 동작하는지 확인하며
3. Prometheus(Grafana 연계 전제)로 상태를 시각화
4. Docker 단일 서버 환경에서의 한계를 체험

하는 것을 목적으로 한다.

> ⚠️ 성능 최적화가 목적이 아니고, “시스템이 망가지기 직전 어떤 일이 벌어지는지”를 관측하는 테스트용 백엔드

---

## 2. 기술 스택
| 구분          | 기술                              |
| ------------- | -------------------------------- |
| Language      | Java 17                          |
| Framework     | Spring Boot **3.4.2**            |
| Build         | Gradle                           |
| DB            | PostgreSQL 16                    |
| Cache         | **2-Tier (Caffeine L1 + Redis L2)** |
| Resilience    | Resilience4j                     |
| Observability | Actuator, Micrometer, Prometheus |
| Infra         | Docker (Single-node 환경 기준)    |

---

## 3. 디렉토리 구조
```
services/service-a/backend/
├── src/main/java/com/exit8/
│   ├── controller/      # API 진입점
│   ├── service/         # 부하 생성 / 상태 계산 / 차단 제어
│   ├── repository/      # DB 접근 계층
│   ├── domain/          # 부하 / 로그 도메인
│   ├── dto/             # 공통 응답 포맷 및 상태 모델
│   ├── filter/          # TraceId / RateLimit
│   ├── logging/         # AOP 기반 관측 로깅
│   ├── observability/   # 이벤트 버퍼 / 메트릭 보조
│   ├── state/           # 런타임 Feature 상태 저장소
│   └── config/          # DB / Redis / Metrics 설정
│
└── src/main/resources/
    ├── application.yml
    ├── application-local.yml
    ├── application-docker.yml
    └── logback-spring.xml

```

---

## 4. 주요 기능

### 부하 시나리오 API
- CPU busy-loop 부하
- DB READ 반복 부하 (Redis 캐시 적용 가능)
- DB WRITE 반복 부하
- 모든 부하는 상한값 강제 적용

### 2단계 방어 구조
- 1차: IP 기반 Rate Limit
- 2차: Resilience4j CircuitBreaker

### Observability
- Prometheus 메트릭 노출
- SystemSnapshot API
- RecentRequests API
- trace_id 기반 요청 추적

### 실험 재현성 보장
- CircuitBreaker 고정 설정
- Redis TTL 고정
- Docker 자원 고정

---

## 4.1. Cache Architecture (2-Tier)

> Main README의 [Cache Architecture](../../../README.md#cache-architecture-2-tier) 섹션과 동일한 구조

```
┌─────────────────────────────────────────────────────────────┐
│                    Application Layer                        │
│                                                             │
│  ┌─────────────────┐                                        │
│  │ L1: Caffeine    │  TTL: 60s, Max: 1000 entries           │
│  │ (In-Memory)     │  Hit Ratio: ~90% (hot data)            │
│  └────────┬────────┘                                        │
│           │ Miss                                             │
│           ▼                                                 │
│  ┌─────────────────┐                                        │
│  │ L2: Redis       │  TTL: 300s (5분)                       │
│  │ (Memorystore)   │  Hit Ratio: ~80% (warm data)           │
│  └────────┬────────┘                                        │
│           │ Miss                                             │
│           ▼                                                 │
│  ┌─────────────────┐                                        │
│  │ PostgreSQL      │  Source of Truth                       │
│  │ (Cloud SQL)     │                                        │
│  └─────────────────┘                                        │
└─────────────────────────────────────────────────────────────┘
```

### 캐시 계층 구조

| 계층 | 기술 | 위치 | TTL | 용도 |
|------|------|------|-----|------|
| **L1** | Caffeine | JVM In-Memory | 60s | 핫 데이터, 빈번한 조회 |
| **L2** | Redis (Memorystore) | GCP Private IP | 300s | 웜 데이터, 인스턴스 간 공유 |
| **Source** | PostgreSQL (Cloud SQL) | GCP Private IP | - | 원본 데이터 |

### 장애 시 동작

| 상황 | 영향 | 복구 |
|------|------|------|
| Redis 재시작 | L2 캐시 miss → DB 부하 일시 증가 | 수 분 내 자동 워밍업 |
| Redis 장애 | L1(Caffeine)만 동작, DB 직접 조회 | CircuitBreaker 보호 하에 정상 서비스 |
---

## 5. 프로젝트 실행 방법 (Quick Start)

###  로컬 실행 (Gradle)
```
SPRING_PROFILES_ACTIVE=local ./gradlew bootRun
```

### Docker 실행
```
docker run -p 8080:8080 \
  --name service-a-backend \
  --env-file .env \
  --network db \
  exit8/service-a-backend:test
```
> Vault 및 Docker 네트워크 구성은 `docs/setup.md` 참고

### 헬스 체크 
```
curl http://localhost:8080/actuator/health
```

---

## 6. 앞으로의 확장 / 완료 현황 정리

### ✅ 이미 완료된 항목
1. 트래픽 제어 및 장애 재현
   - Resilience4j CircuitBreaker 적용
     - CLOSED / HALF_OPEN / OPEN 상태 전이 확인
     - 고정 실험 설정(testCircuit)
   - IP 기반 Rate Limit 1차 방어
   - CPU / DB READ / DB WRITE 부하 API 구현
2. Observability & 계측
   - Spring Boot Actuator 적용
   - Micrometer + Prometheus 연동
   - `/actuator/health`, `/actuator/prometheus` 노출
   - Custom Metrics 추가
     - `rate_limit_blocked_total`
     - `rate_limit_allowed_total`
   - Built-in Metrics 활용
     - `resilience4j.circuitbreaker.*`
     - `hikaricp.connections.*`
     - `http.server.requests`
   - 모든 부하 실행 결과 spring_load_test_logs 저장
   - SystemSnapshot / RecentRequests API 제공
3. 로깅 아키텍처
   - AOP 기반 단일 진입점 로깅 (LogAspect)
   - LOAD_START / END / FAIL / ERROR 이벤트 체계 확립
   - **trace_id** 기반 요청 단위 추적
   - JSON Logback 구조화 로그 적용
     - `trace_id / level / duration / event`
     - Wazuh 연계 전제
4. 실행 환경 및 보안 기반
   - Profile 분리 전략 (local / docker)
   - Vault KV(v2) 기반 DB 자격 증명 외부화
     - username / password 하드코딩 제거
   - Docker 기반 실행 및 Healthcheck 구성
   - Graceful Shutdown 적용
     - SIGTERM 수신 시 안전 종료
5. 실험 재현성 보장
   - CircuitBreaker 설정 고정
   - Redis TTL 고정 (5분)
   - Docker 자원 조건 고정
   - JMeter 기반 외부 부하 테스트 연계
    
<br>

### ⏳ 향후 진행 예정
1. DB 로그 영속화 완성
   - spring_logs 테이블 실제 저장 로직 연결
     - LogAspect → SystemLog 저장
   - 배치 기반 로그 백업 및 정리 전략 수립

2. 보안 계층 확장
   - Spring Security 도입
     - 테스트 API 보호
     - 오남용 방지
     - 최소 인증/인가 레이어 설계
---

## 📚 상세 문서
 
### 실행 환경 구성 및 인프라 연동
- [docs/setup.md](docs/setup.md)

### 시스템 아키텍처 및 설계 원칙  
- [docs/architecture.md](docs/architecture.md)

### API 및 관측 계약  
- [docs/api-and-observability.md](docs/api-and-observability.md)
  