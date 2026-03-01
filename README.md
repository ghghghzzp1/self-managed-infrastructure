# Exit8 Project

GCP 기반 All-in-one 보안 플랫폼 - Terraform + Ansible IaC 구축

## Architecture Overview

```
                    ┌─────────────────────────────────────────────────────────────┐
                    │                    GCP (asia-northeast3)                     │
                    │                                                             │
   Internet         │  ┌─────────────────┐     ┌─────────────────────────────┐ │
   ────────► Cloud  │  │  HTTPS LB       │     │      Compute Engine         │ │
            Armor   │  │  34.128.162.9   │────►│  e2-standard-4 (16GB/4vCPU) │ │
                    │  └─────────────────┘     │  34.64.160.98               │ │
                    │                          │                             │ │
                    │                          │  ┌───────────────────────┐  │ │
                    │                          │  │  Docker Compose        │  │ │
                    │                          │  │  ├─ service-a (Spring) │  │ │
                    │                          │  │  ├─ service-b (FastAPI)│  │ │
                    │                          │  │  ├─ Nginx Proxy Mgr    │  │ │
                    │                          │  │  ├─ Prometheus         │  │ │
                    │                          │  │  ├─ Grafana            │  │ │
                    │                          │  │  └─ Wazuh SIEM         │  │ │
                    │                          │  └───────────────────────┘  │ │
                    │                          └──────────────┬──────────────┘ │
                    │                                         │                │
                    │  ┌─────────────────┐    ┌──────────────┴──────────────┐ │
                    │  │ Memorystore     │    │  Private Service Access     │ │
                    │  │ Redis 7.0 (1GB) │◄───│  10.101.0.0/16              │ │
                    │  │ 10.101.1.3:6379 │    └──────────────┬──────────────┘ │
                    │  └─────────────────┘                   │                │
                    │                                        │                │
                    │                          ┌──────────────┴──────────────┐ │
                    │                          │  Cloud SQL (PostgreSQL 15)  │ │
                    │                          │  db-custom-2-8192           │ │
                    │                          │  10.101.0.3:5432            │ │
                    │                          └─────────────────────────────┘ │
                    │                                                             │
                    └─────────────────────────────────────────────────────────────┘
```

## GCP Managed Services

| Service | Tier | Private IP | Purpose |
|---------|------|------------|---------|
| **Cloud SQL** | db-custom-2-8192 (2 vCPU, 8GB) | 10.101.0.3:5432 | PostgreSQL 15 Database |
| **Memorystore** | Basic 1GB | 10.101.1.3:6379 | Redis 7.0 Cache |
| **Compute Engine** | e2-standard-4 | 10.0.0.2 | Docker Host |
| **Cloud Armor** | Standard | - | WAF/DDoS Protection |
| **HTTPS LB** | Global | 34.128.162.9 | SSL Termination |
| **Secret Manager** | - | - | Secrets Management |

## Cache Architecture (2-Tier)

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
│  │ L2: Redis       │  TTL: 300s                             │
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

## Server Specs

| 항목 | 사양 |
|------|------|
| CPU | 4 vCPU |
| Memory | 16 GB |
| Platform | GCP Compute Engine (e2-standard-4) |
| Disk | 100 GB SSD |
| Region | asia-northeast3 (Seoul) |

## Services

| Service | Port | Description |
|---------|------|-------------|
| **Nginx Proxy Manager** | 80, 443, 81 | Reverse Proxy / SSL |
| **Service-A Backend** | 8080 | Spring Boot API (2-Tier Cache) |
| **Service-A Frontend** | 3000 | React + Vite |
| **Service-B Backend** | 8000 | FastAPI API |
| **Service-B Frontend** | 3002 | React + Vite |
| **Prometheus** | 9090 | Metrics Collector |
| **Grafana** | 3001 | Visualization Dashboard |
| **Wazuh Manager** | 1514, 1515, 55000 | SIEM Agent |
| **Wazuh Dashboard** | 8443 | SIEM Web UI |

## Service Scenarios

### Service-A: Load & Observability Test

Spring Boot 기반 부하 테스트 및 관측(Observability) 백엔드입니다.

**목적:**
- 의도적 시스템 부하 발생 → 서킷 브레이커 동작 확인
- Prometheus/Grafana로 상태 시각화
- Docker 단일 서버 환경의 한계 체험

**핵심 기능:**
- CPU / DB READ / DB WRITE 부하 API
- 2단계 방어: IP Rate Limit + CircuitBreaker
- 2-Tier Cache (Caffeine L1 + Redis L2)
- trace_id 기반 요청 추적

👉 [상세 문서](services/service-a/backend/README.md)

### Service-B: Security Vulnerability Lab

FastAPI 기반 보안 취약점 재현/탐지 실험용 백엔드입니다.

**목적:**
- SQLi, Brute Force 공격 요청 유입 → Wazuh 탐지 검증
- 공격 징후 로그(JSON) 생성 → 알림 체계 동작 확인
- Defense-in-Depth (3단계 방어) 아키텍처 검증

**핵심 기능:**
- 의도적 SQLi 취약점 (문자열 결합 쿼리)
- 인증 실패 반복 허용 (Brute Force 시나리오)
- Wazuh Level 12 탐지 / 이메일 알림

**방어 계층:**
- L1: Cloud Armor (Edge WAF, 승인 대기 중)
- L2: Wazuh (Host 감시, Post-Exploitation 탐지)
- L3: GCS (로그 장기 보관, 포렌식)

👉 [상세 문서](services/service-b/backend/README.md)

## Quick Start

### Prerequisites

```bash
# gcloud CLI 설치 및 인증
gcloud auth login
gcloud config set project thinking-orb-485613-k3

# Terraform 설치
brew install terraform
```

### Infrastructure Deploy

```bash
# Terraform 초기화 및 적용
cd infra/terraform
terraform init
terraform apply

# SSH로 VM 접속
gcloud compute ssh exit8-vm --zone=asia-northeast3-a
```

### Application Deploy

```bash
# VM에서 수행
cd /opt/exit8/self-managed-infrastructure

# Secret Manager에서 비밀번호 가져오기
DB_PASSWORD=$(gcloud secrets versions access latest --secret=exit8-db-password)
GRAFANA_PASSWORD=$(gcloud secrets versions access latest --secret=exit8-grafana-admin | jq -r '.admin_password')

# .env 파일 생성
cat > .env << EOF
DATABASE_HOST=10.101.0.3
DATABASE_PORT=5432
DATABASE_NAME=exit8_app
DATABASE_USER=exit8_app_user
DATABASE_PASSWORD=${DB_PASSWORD}
REDIS_HOST=10.101.1.3
REDIS_PORT=6379
GRAFANA_USER=admin
GRAFANA_PASSWORD=${GRAFANA_PASSWORD}
EOF

# 서비스 시작
docker compose up -d
```

## Secrets Management

### GCP Secret Manager

| Secret Name | Description |
|-------------|-------------|
| `exit8-db-password` | Cloud SQL Password |
| `exit8-grafana-admin` | Grafana Admin Credentials (JSON) |
| `exit8-wazuh-credentials` | Wazuh Passwords (JSON) |

### Access Secrets

```bash
# Cloud SQL 비밀번호
gcloud secrets versions access latest --secret=exit8-db-password

# Grafana 비밀번호
gcloud secrets versions access latest --secret=exit8-grafana-admin | jq -r '.admin_password'

# Wazuh 비밀번호
gcloud secrets versions access latest --secret=exit8-wazuh-credentials | jq -r '.indexer_password'
```

## CI/CD Pipeline

**Workflows:**

| Workflow | Trigger | 설명 |
|----------|---------|------|
| Deploy | main push | 변경 서비스 감지 → Docker 빌드 → SSH 배포 → 헬스체크 |
| Security | main, weekly | 의존성/컨테이너/시크릿 스캔 |

**GitHub Secrets:**

| Secret | Description |
|--------|-------------|
| `SERVER_HOST` | GCP VM 외부 IP |
| `SERVER_USER` | SSH 사용자 (deploy-bot) |
| `SERVER_SSH_KEY` | SSH Private Key |
| `DOCKER_HUB_TOKEN` | Docker Hub Token |
| `DATABASE_PASSWORD` | From Secret Manager |
| `GRAFANA_PASSWORD` | From Secret Manager |
| `WAZUH_*_PASSWORD` | From Secret Manager |

## Observability

```bash
# Prometheus: http://34.64.160.98:9090
# Grafana:    http://34.64.160.98:3001
```

**수집 메트릭:**
- Node Exporter: CPU, Memory, Disk
- Postgres Exporter: DB 연결, 쿼리 통계
- Redis Exporter: 캐시 히트율, 메모리
- Custom: Cache Hit Ratio, Rate Limit

## Logging Architecture

### 전체 파이프라인

```
[앱 컨테이너] gcplogs driver
  └─→ Cloud Logging (_Default 버킷, 30일 무료)
        └─→ Log Sink → GCS: exit8-error-archive  ERROR+ / 1년 보관

[인프라 컨테이너] json-file driver (docker logs 지원)
  └─→ VM 로컬 저장 → logrotate(.gz) → GCS: exit8-vm-log-archive (매일 새벽 3시)
        ├─→ system/  7일 로컬 → GCS 30일
        ├─→ nginx/   7일 로컬 → GCS 30일
        └─→ wazuh/   7일 로컬 → GCS 180일 (보안 규정)

[Cloud SQL] 자동 → Cloud Logging (슬로우쿼리 500ms+, 잠금대기, 체크포인트)
  └─→ Log Sink → GCS: exit8-error-archive  ERROR+ / 1년 보관

[HTTPS LB] log_config(100% 샘플링) → Cloud Logging (http_load_balancer, 30일)
  └─→ Log Sink → GCS: exit8-error-archive  5xx (httpRequest.status>=500) / 1년 보관

[Memorystore] 자동 → Cloud Logging (시스템 이벤트, BASIC tier 제약)
```

### Cloud SQL 로깅 설정

| 플래그 | 값 | 목적 |
|--------|----|------|
| `log_checkpoints` | on | 체크포인트 성능 추적 |
| `log_connections` / `log_disconnections` | on | 연결 감사 |
| `log_min_duration_statement` | 500ms | 슬로우 쿼리 탐지 (N+1, 풀스캔) |
| `log_lock_waits` | on | 데드락·트랜잭션 충돌 원인 추적 |
| `log_temp_files` | 0 (전체) | 메모리 부족·정렬 이슈 탐지 |

> **Query Insights** 활성화: 실시간 쿼리 분석은 GCP Console → Cloud SQL → Query Insights

### HTTPS LB 로깅

LB 로그는 모든 요청이 `severity=INFO`로 기록됩니다 (HTTP 5xx도 포함).
`httpRequest.status` 필드로 상태 코드를 확인하세요.

```
# Log Explorer - LB 5xx 조회
resource.type="http_load_balancer" AND httpRequest.status>=500

# Log Explorer - 특정 경로 응답시간 조회
resource.type="http_load_balancer" AND httpRequest.requestUrl=~"/api/"
```

> **주의**: 5xx는 경보(Alert Policy)가 별도 존재합니다. Log Sink로 GCS 1년 보관도 자동 적용됩니다.

### VM 로컬 보관 정책

| 로그 경로 | 보관 기간 | 크기 제한 | 비고 |
|-----------|-----------|-----------|------|
| `/var/log/journal/` | 7일 / Max 500MB | - | journald 설정 |
| `/var/log/syslog` 등 | 7일 | 100MB 초과 시 즉시 로테이션 | logrotate daily |
| NPM `/data/logs/` | 7일 | 50MB 초과 시 즉시 로테이션 | logrotate + copytruncate |
| Wazuh `/wazuh_logs/` | 7일 | - | 보안 사고 최소 확인 기간 |
| Docker infra 컨테이너 | size 기반 | 10MB × 3파일 = 30MB/컨테이너 | json-file driver |

### GCS 장기 보관 전략

| 출처 / GCS prefix | 보관 기간 | 스토리지 클래스 전환 | 용도 |
|-------------------|-----------|----------------------|------|
| VM: `nginx/`, `system/` | 30일 | 1일 → NEARLINE | 장애 분석 |
| VM: `wazuh/` | 180일 | 7일 → NEARLINE → 30일 → COLDLINE | 보안 규정 / 침해 조사 |
| Cloud Logging Sink (ERROR+, LB 5xx) | 1년 | 30일 → NEARLINE → 90일 → COLDLINE | 에러 아카이브 |

### 로그 조회 빠른 참조

앱 컨테이너(`service-a-backend` 등)는 `gcplogs` 드라이버를 사용하므로 `docker logs`가 동작하지 않습니다.

```
# 앱 에러 조회
resource.type="gce_instance" AND severity>=ERROR
labels."com.docker.compose.service"="service-a-backend"

# Cloud SQL 슬로우 쿼리
resource.type="cloudsql_database" AND textPayload=~"duration:"

# LB 5xx
resource.type="http_load_balancer" AND httpRequest.status>=500
```

## Backup Strategy

### Cloud SQL (PostgreSQL 15)

| 항목 | 설정 | 비고 |
|------|------|------|
| 자동 백업 | 매일 새벽 2시 | 트래픽 최저점 |
| 백업 보관 수 | **14개 (2주)** | 기본값 7개에서 상향 |
| PITR (Point-in-Time Recovery) | **7일 (최대)** | 3일에서 최대치로 상향 |
| 복구 방법 | GCP Console → Cloud SQL → 백업에서 복원 | 또는 `gcloud sql backups restore` |

```bash
# 특정 시점으로 복구 (PITR)
gcloud sql instances clone exit8-postgres exit8-postgres-restored \
  --point-in-time="2026-03-01T10:00:00Z"

# 자동 백업 목록 확인
gcloud sql backups list --instance=exit8-postgres
```

### Memorystore Redis (BASIC tier)

**백업 없음 — 설계상 의도된 결정입니다.**

Redis는 L2 캐시로서 PostgreSQL(원본)의 조회 가속 역할만 합니다. 재시작 시 앱이 자동으로 DB에서 재조회하며 캐시를 워밍업합니다. BASIC tier는 GCP 제약으로 RDB 스냅샷 / AOF 지원이 없습니다.

| 상황 | 영향 | 복구 |
|------|------|------|
| Redis 재시작 | L2 캐시 miss → DB 부하 일시 증가 | 수 분 내 자동 워밍업 |
| Redis 장애 | L1(Caffeine)만 동작, DB 직접 조회 | CircuitBreaker 보호 하에 정상 서비스 |

> STANDARD tier 업그레이드 시 리전 간 복제 + RDB 스냅샷 지원 (비용 약 2배)

### HTTPS LB

별도 데이터 백업 불필요. 구성 전체가 Terraform으로 관리되어 버전 관리가 곧 백업입니다.

```bash
# 구성 복원
cd infra/terraform && terraform apply
```

## Estimated Costs

| Service | Cost |
|---------|------|
| Cloud SQL | ~$50/month |
| Memorystore | ~$35/month |
| Compute Engine | ~$70/month |
| HTTPS LB + Cloud Armor | ~$20/month |
| GCS Error Archive | ~$0.1/month (ERROR 로그만, COLDLINE) |
| GCS VM Log Archive | ~$0.05/month (nginx/system/wazuh .gz) |
| **Total** | **~$175/month (~₩252,000)** |

## Project Structure

```
exit8/
├── infra/
│   ├── terraform/           # GCP Infrastructure
│   │   ├── main.tf          # Provider 설정
│   │   ├── vpc.tf           # VPC + Subnet
│   │   ├── psa.tf           # Private Service Access
│   │   ├── cloud_sql.tf     # Cloud SQL
│   │   ├── memorystore.tf   # Memorystore Redis
│   │   ├── compute.tf       # Compute Engine
│   │   ├── load_balancer.tf # HTTPS LB + Cloud Armor
│   │   ├── monitoring.tf    # Alert Policies
│   │   └── secrets.tf       # Secret Manager
│   └── ansible/             # VM Provisioning (optional)
├── services/
│   ├── service-a/           # Spring Boot + React
│   ├── service-b/           # FastAPI + React
│   ├── npm/                 # Nginx Proxy Manager
│   ├── prometheus/          # Metrics
│   ├── grafana/             # Dashboards
│   └── wazuh/               # SIEM
├── docker-compose.yml       # Main compose file
├── .env.example             # Environment template
└── .github/workflows/       # CI/CD
```

## Documentation

- [GCP 접근 가이드](docs/gcp-access-guide.md)
- [GitHub Actions Secrets](docs/github-actions-secrets.md)
- [배포 가이드](docs/deploy-gcp.md)

## Migration History

| Date | Change |
|------|--------|
| 2026-03-01 | Cloud SQL/LB/Redis 로깅·백업 전략 수립 (PITR 7일, LB access log, GCS error sink 확장) |
| 2026-03-01 | BigQuery 제거 → Cloud Logging + GCS 전용 로깅 아키텍처로 전환 |
| 2026-02-28 | GCP Load Balancer 헬스체크 포트 8081로 변경 |
| 2026-02-27 | Vault → GCP Secret Manager 완전 이관 |
| 2026-02-26 | 2-Tier Cache (Caffeine + Redis) 구현 |
| 2026-02-25 | GCP Managed Services (Cloud SQL, Memorystore) 도입 |
| 2026-02-24 | Terraform + Ansible IaC 구축 |
