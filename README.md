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

앱 컨테이너 로그는 `gcplogs` 드라이버로 Cloud Logging에 직접 전송되며, 두 가지 저장소로 라우팅됩니다.

```
앱 컨테이너 (gcplogs driver)
  └─→ Cloud Logging
        ├─→ BigQuery: exit8_logs     [INFO+, 90일 자동 만료]
        └─→ GCS: error-archive       [ERROR+, 1년 보관]
                  ├ STANDARD  0-30일   $0.02/GB
                  ├ NEARLINE  30-90일  $0.01/GB
                  └ COLDLINE  90일~    $0.004/GB

인프라 컨테이너 (json-file driver)  →  로컬 보관만 (docker logs 지원)
```

**로그 소스별 필터**

| 소스 | BigQuery (exit8_logs) | GCS (error-archive) |
|------|-----------------------|---------------------|
| 앱 컨테이너 (gce_instance) | INFO 이상 | ERROR 이상 |
| Cloud SQL | WARNING 이상 | ERROR 이상 |
| Redis | WARNING 이상 | ERROR 이상 |

**BigQuery 로그 조회**

```sql
-- 최근 앱 에러 로그 조회
SELECT timestamp, severity, jsonPayload.message, labels.`com_docker_compose_service`
FROM `thinking-orb-485613-k3.exit8_logs.*`
WHERE severity >= 'ERROR'
  AND timestamp > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 24 HOUR)
ORDER BY timestamp DESC
LIMIT 100;

-- 서비스별 에러 집계
SELECT labels.`com_docker_compose_service` AS service,
       COUNT(*) AS error_count
FROM `thinking-orb-485613-k3.exit8_logs.*`
WHERE severity >= 'ERROR'
  AND timestamp > TIMESTAMP_SUB(CURRENT_TIMESTAMP(), INTERVAL 7 DAY)
GROUP BY service
ORDER BY error_count DESC;
```

> **주의**: 앱 컨테이너(`service-a-backend`, `service-b-backend` 등)는 `gcplogs` 드라이버를 사용하므로 `docker logs` 명령이 동작하지 않습니다. 로그는 Cloud Logging Console 또는 BigQuery에서 조회하세요.

## Estimated Costs

| Service | Cost |
|---------|------|
| Cloud SQL | ~$50/month |
| Memorystore | ~$35/month |
| Compute Engine | ~$70/month |
| HTTPS LB + Cloud Armor | ~$20/month |
| BigQuery (exit8_logs, 90일) | ~$1/month (첫 10GB 무료) |
| GCS Error Archive | ~$0.1/month (ERROR 로그만, COLDLINE) |
| **Total** | **~$176/month (~₩253,000)** |

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
| 2026-03-01 | BigQuery 앱 로그 수집 (gcplogs + GCS Error Archive) |
| 2026-02-28 | GCP Load Balancer 헬스체크 포트 8081로 변경 |
| 2026-02-27 | Vault → GCP Secret Manager 완전 이관 |
| 2026-02-26 | 2-Tier Cache (Caffeine + Redis) 구현 |
| 2026-02-25 | GCP Managed Services (Cloud SQL, Memorystore) 도입 |
| 2026-02-24 | Terraform + Ansible IaC 구축 |
