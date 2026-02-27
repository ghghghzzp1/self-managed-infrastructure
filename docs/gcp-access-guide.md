# GCP Cloud Managed Services 접근 가이드

## 개요

이 문서는 Exit8 프로젝트에서 사용하는 GCP Managed Services (Cloud SQL, Memorystore, Secret Manager)에 접근하는 방법을 설명합니다.

---

## Prerequisites

```bash
# gcloud CLI 설치
brew install google-cloud-sdk

# 인증
gcloud auth login

# 프로젝트 설정
gcloud config set project thinking-orb-485613-k3
```

---

## GCP Infrastructure Overview

| Resource | Name | Private IP | Purpose |
|----------|------|------------|---------|
| **Cloud SQL** | exit8-postgres | 10.101.0.3 | PostgreSQL 15 |
| **Memorystore** | exit8-redis | 10.101.1.3 | Redis 7.0 |
| **Compute Engine** | exit8-vm | 10.0.0.2 | Docker Host |
| **Load Balancer** | exit8-lb | 34.128.162.9 | HTTPS LB |
| **VPC** | exit8-vpc | 10.0.0.0/24 | Private Network |

---

## 1. VM 접속 (SSH)

### 방법 1: gcloud compute ssh (권장)

```bash
# 기본 SSH 접속
gcloud compute ssh exit8-vm --zone=asia-northeast3-a

# 특정 사용자로 접속
gcloud compute ssh exit8-vm --zone=asia-northeast3-a --user=deploy-bot
```

### 방법 2: SSH 키 직접 사용

```bash
# SSH 키 생성 (최초 1회)
ssh-keygen -t rsa -b 4096 -f ~/.ssh/exit8-deploy -C "deploy-bot"

# VM 메타데이터에 공개 키 추가
gcloud compute instances add-metadata exit8-vm \
  --zone=asia-northeast3-a \
  --metadata="ssh-keys=deploy-bot:$(cat ~/.ssh/exit8-deploy.pub)"

# SSH 접속
ssh -i ~/.ssh/exit8-deploy deploy-bot@34.64.160.98
```

---

## 2. Cloud SQL 접속

### VM 내부에서 접속 (Private IP)

```bash
# VM에 SSH 접속 후
gcloud compute ssh exit8-vm --zone=asia-northeast3-a

# psql 클라이언트 설치 (필요시)
sudo apt-get update && sudo apt-get install -y postgresql-client

# DB 비밀번호 가져오기
DB_PASSWORD=$(gcloud secrets versions access latest --secret=exit8-db-password)

# PostgreSQL 접속
PGPASSWORD=$DB_PASSWORD psql \
  --host=10.101.0.3 \
  --port=5432 \
  --username=exit8_app_user \
  --dbname=exit8_app
```

### 로컬에서 Cloud SQL Proxy 사용

```bash
# Cloud SQL Proxy 설치
brew install cloud-sql-proxy

# Proxy 시작 (별도 터미널)
cloud-sql-proxy thinking-orb-485613-k3:asia-northeast3:exit8-postgres

# 다른 터미널에서 접속
DB_PASSWORD=$(gcloud secrets versions access latest --secret=exit8-db-password)
PGPASSWORD=$DB_PASSWORD psql \
  --host=127.0.0.1 \
  --port=5432 \
  --username=exit8_app_user \
  --dbname=exit8_app
```

### 유용한 SQL 쿼리

```sql
-- 연결 상태 확인
SELECT * FROM pg_stat_activity;

-- 데이터베이스 크기 확인
SELECT pg_size_pretty(pg_database_size('exit8_app'));

-- 테이블 목록
\dt

-- 종료
\q
```

---

## 3. Memorystore (Redis) 접속

### VM 내부에서 접속

```bash
# VM에 SSH 접속 후
gcloud compute ssh exit8-vm --zone=asia-northeast3-a

# redis-cli 설치 (필요시)
sudo apt-get install -y redis-tools

# Redis 접속
redis-cli -h 10.101.1.3 -p 6379

# Ping 테스트
redis-cli -h 10.101.1.3 ping
# 응답: PONG
```

### 유용한 Redis 명령어

```bash
# 모든 키 조회
KEYS *

# 캐시 히트율 확인
INFO stats | grep keyspace_hits
INFO stats | grep keyspace_misses

# 메모리 사용량
INFO memory

# 특정 키 삭제
DEL cache:key:name

# TTL 확인
TTL cache:key:name

# 종료
exit
```

---

## 4. Secret Manager 접근

### CLI로 시크릿 조회

```bash
# 모든 시크릿 목록
gcloud secrets list

# 시크릿 값 조회
gcloud secrets versions access latest --secret=exit8-db-password

# JSON 형식 시크릿 조회
gcloud secrets versions access latest --secret=exit8-grafana-admin | jq .

# 특정 필드만 추출
gcloud secrets versions access latest --secret=exit8-grafana-admin | jq -r '.admin_password'
gcloud secrets versions access latest --secret=exit8-wazuh-credentials | jq -r '.indexer_password'
```

### VM 내부에서 접근

```bash
# VM은 Service Account를 통해 자동 인증
gcloud compute ssh exit8-vm --zone=asia-northeast3-a

# 비밀번호 조회
DB_PASSWORD=$(gcloud secrets versions access latest --secret=exit8-db-password)
echo $DB_PASSWORD
```

### 시크릿 목록

| Secret Name | Description | Format |
|-------------|-------------|--------|
| `exit8-db-password` | Cloud SQL 비밀번호 | Plain text |
| `exit8-grafana-admin` | Grafana 관리자 계정 | JSON |
| `exit8-wazuh-credentials` | Wazuh 비밀번호들 | JSON |

---

## 5. Docker Compose 서비스 관리

### VM에서 Docker 관리

```bash
# VM 접속
gcloud compute ssh exit8-vm --zone=asia-northeast3-a

# 프로젝트 디렉토리로 이동
cd /opt/exit8/self-managed-infrastructure

# 서비스 상태 확인
docker compose ps

# 로그 확인
docker compose logs -f service-a-backend
docker compose logs -f prometheus

# 서비스 재시작
docker compose restart service-a-backend

# 전체 서비스 재시작
docker compose down && docker compose up -d

# 이미지 업데이트
docker compose pull && docker compose up -d
```

### 서비스 포트 매핑

| Service | Internal Port | External Port |
|---------|---------------|---------------|
| nginx-proxy-manager | 81 | 81 |
| service-a-backend | 8080 | 8081 |
| prometheus | 9090 | 9090 |
| grafana | 3000 | 3001 |
| wazuh-dashboard | 5601 | 8443 |

---

## 6. 모니터링

### Cloud Monitoring 대시보드

```
https://console.cloud.google.com/monitoring/dashboards?project=thinking-orb-485613-k3
```

### Alert Policies

| Alert | Condition |
|-------|-----------|
| High CPU Usage | CPU > 80% for 5 minutes |
| High DB Connections | Connections > 80 |
| High Redis Memory | Memory > 80% |
| High 5xx Error Rate | 5xx > 5% for 5 minutes |

### Prometheus 메트릭

```bash
# VM 내부에서 접속
curl http://localhost:9090/api/v1/query?query=up

# 주요 메트릭
# - cache_hit_ratio: 캐시 적중률
# - db_connections: DB 연결 수
# - http_server_requests: HTTP 요청 수
```

---

## 7. 로그 확인

### Cloud Logging

```bash
# VM 로그
gcloud logging read "resource.type=gce_instance AND resource.labels.instance_name=exit8-vm" --limit 50

# Cloud SQL 로그
gcloud logging read "resource.type=cloudsql_database" --limit 50
```

### Docker 로그

```bash
# VM 내부에서
docker compose logs --tail=100 -f
docker compose logs service-a-backend --since=1h
```

---

## 8. 트러블슈팅

### Cloud SQL 연결 실패

```bash
# 1. PSA 연결 상태 확인
gcloud compute networks vpc-access connectors list --region=asia-northeast3

# 2. VM에서 Private IP로 ping
ping 10.101.0.3

# 3. 방화벽 규칙 확인
gcloud compute firewall-rules list --filter="network:exit8-vpc"
```

### Redis 연결 실패

```bash
# 1. Redis 인스턴스 상태
gcloud redis instances describe exit8-redis --region=asia-northeast3

# 2. 네트워크 연결 확인
redis-cli -h 10.101.1.3 ping
```

### Secret Manager 접근 실패

```bash
# 1. Service Account 권한 확인
gcloud projects get-iam-policy thinking-orb-485613-k3 \
  --flatten="bindings[].members" \
  --filter="bindings.members:exit8-vm-sa"

# 2. 권한 추가 (필요시)
gcloud projects add-iam-policy-binding thinking-orb-485613-k3 \
  --member="serviceAccount:exit8-vm-sa@thinking-orb-485613-k3.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"
```

---

## 9. 비용 확인

```bash
# 현재 비용 확인
gcloud billing accounts list

# 프로젝트 비용
gcloud beta billing projects describe thinking-orb-485613-k3 --billing-account=$(gcloud billing accounts list --format="value(ACCOUNT_ID)")
```

### 예상 월 비용

| Service | Cost |
|---------|------|
| Cloud SQL (db-custom-2-8192) | ~$50/month |
| Memorystore (1GB Basic) | ~$35/month |
| Compute Engine (e2-standard-4) | ~$70/month |
| HTTPS LB + Cloud Armor | ~$20/month |
| **Total** | **~$175/month** |

---

## 10. 빠른 참조

### 주요 IP 주소

```
VM External IP:  34.64.160.98
VM Internal IP:  10.0.0.2
Load Balancer:   34.128.162.9
Cloud SQL:       10.101.0.3:5432
Memorystore:     10.101.1.3:6379
```

### 주요 명령어

```bash
# SSH 접속
gcloud compute ssh exit8-vm --zone=asia-northeast3-a

# DB 접속
PGPASSWORD=$(gcloud secrets versions access latest --secret=exit8-db-password) psql -h 10.101.0.3 -U exit8_app_user -d exit8_app

# Redis 접속
redis-cli -h 10.101.1.3

# 시크릿 조회
gcloud secrets versions access latest --secret=exit8-db-password

# Docker 상태
docker compose ps

# 로그 확인
docker compose logs -f
```
