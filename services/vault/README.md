# Vault AppRole 설정 가이드

## 📋 개요

이 디렉토리는 HashiCorp Vault와 AppRole 인증을 사용한 안전한 비밀 관리를 위한 설정 파일과 스크립트를 포함합니다.

### 아키텍처 (격리 보안)

```
┌──────────────────────────────────────────────────────────────┐
│                     Vault 서버                                │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │ 🔐 Manager Tokens (CI/CD 전용, 3-Tier 격리)             │ │
│  │  ├── service-a-manager-token                            │ │
│  │  │   └─ service-a SECRET_ID 발급만 가능 ✓               │ │
│  │  │   └─ service-b, infra 접근 차단 ❌                   │ │
│  │  ├── service-b-manager-token                            │ │
│  │  │   └─ service-b SECRET_ID 발급만 가능 ✓               │ │
│  │  │   └─ service-a, infra 접근 차단 ❌                   │ │
│  │  └── infra-manager-token                                │ │
│  │      └─ secret/infra/* 읽기만 가능 ✓                    │ │
│  │      └─ service-a, service-b 접근 차단 ❌               │ │
│  └─────────────────────────────────────────────────────────┘ │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │ Secrets 저장소 (격리됨)                                 │ │
│  │  ├── secret/infra/*        (PostgreSQL, Redis, Grafana) │ │
│  │  ├── secret/service-a/*    (Service A 전용)            │ │
│  │  └── secret/service-b/*    (Service B 전용)            │ │
│  └─────────────────────────────────────────────────────────┘ │
│  ┌─────────────────────────────────────────────────────────┐ │
│  │ AppRole 인증 (Runtime)                                  │ │
│  │  ├── service-a-backend (role)                           │ │
│  │  │   └── service-a-policy (secret/service-a/* 읽기)    │ │
│  │  └── service-b-backend (role)                           │ │
│  │      └── service-b-policy (secret/service-b/* 읽기)    │ │
│  └─────────────────────────────────────────────────────────┘ │
└──────────────────────────────────────────────────────────────┘
           ↓                           ↓
    (role-id + secret-id)       (role-id + secret-id)
           ↓                           ↓
   ┌──────────────┐            ┌──────────────┐
   │  Service A   │   ⚡ 격리  │  Service B   │
   │  (Spring)    │  ═══════════ │  (FastAPI)   │
   └──────────────┘            └──────────────┘
           ↓                           ↓
   ┌─────────────────────────────────────────────┐
   │  Infrastructure (docker-compose.yml)         │
   │  ├── PostgreSQL (from Vault)                 │
   │  ├── Redis (from Vault)                      │
   │  └── Grafana (from Vault)                    │
   └─────────────────────────────────────────────┘
```

**3-Tier 격리 보안:**
- 🔐 **Service Manager**: SECRET_ID 발급만 가능 (secrets 읽기 불가)
- 🔐 **Infra Manager**: 인프라 secrets 읽기만 가능 (SECRET_ID 발급 불가)
- 🚫 **완전 격리**: Service-A ⚡ Service-B ⚡ Infra
- ✅ **ROOT_TOKEN 제거**: GitHub Secrets에 저장되지 않음
- ✅ **하드코딩 제거**: docker-compose.yml에 평문 credentials 없음

## 🚀 빠른 시작

### 1. Vault 컨테이너 시작

```bash
docker-compose up -d vault
```

### 2. Vault 초기화 (최초 1회만)

```bash
# Vault 초기화 및 root 토큰 획득
docker exec -it vault vault operator init

# unseal key와 root token을 안전하게 보관하세요!
# 3개의 key로 unseal 수행
docker exec -it vault vault operator unseal <key-1>
docker exec -it vault vault operator unseal <key-2>
docker exec -it vault vault operator unseal <key-3>
```

### 3. KV 시크릿 엔진 활성화

```bash
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=<your-root-token>

# KV v2 시크릿 엔진 활성화
vault secrets enable -version=2 -path=secret kv
```

### 4. AppRole 초기화 스크립트 실행

```bash
cd services/vault

docker exec -i vault sh -c "VAULT_ADDR=http://127.0.0.1:8200 VAULT_TOKEN=$VAULT_TOKEN sh" < ./init-approle.sh
```

다음과 같은 인증 정보가 출력됩니다:

```bash
# Service A Credentials
SERVICE_A_ROLE_ID=abc123...
SERVICE_A_SECRET_ID=def456...

# Service B Credentials
SERVICE_B_ROLE_ID=ghi789...
SERVICE_B_SECRET_ID=jkl012...
```

### 5. .env 파일 업데이트

생성된 인증 정보를 `.env` 파일에 복사합니다:

```bash
cp .env.example .env
# step 4에서 출력된 인증 정보로 .env 파일 수정
```

### 6. Vault에 시크릿 추가

```bash
# 🔐 인프라 시크릿 (PostgreSQL, Redis, Grafana)
vault kv put secret/infra/postgres \
  user="admin" \
  password="secure-postgres-password" \
  database="appdb"

vault kv put secret/infra/redis \
  password="secure-redis-password"

vault kv put secret/infra/grafana \
  admin_user="admin" \
  admin_password="secure-grafana-password"

# Service A 시크릿
vault kv put secret/service-a-backend/config \
  db.password="secure-password" \
  api.key="service-a-api-key"

# Service B 시크릿
vault kv put secret/service-b-backend/config \
  db.password="secure-password" \
  api.key="service-b-api-key"
```

### 7. 인프라 Secrets를 .env에 적용

```bash
# Vault에서 인프라 credentials 가져오기
export INFRA_MANAGER_TOKEN=<from step 4>
export VAULT_ADDR=http://localhost:8200

./init-infra-secrets.sh
```

이 스크립트는 Vault에서 인프라 credentials를 가져와 `.env` 파일을 자동 생성/업데이트합니다.

### 8. 애플리케이션 시작

```bash
docker-compose up -d
```

## 📁 파일 구조

```
services/vault/
├── README.md                    # 이 파일
├── config/
│   └── vault.hcl               # Vault 서버 설정
├── policies/
│   ├── service-a-policy.hcl    # Service A 접근 정책
│   └── service-b-policy.hcl    # Service B 접근 정책
└── init-approle.sh             # AppRole 초기화 스크립트
```

## 🔄 CI/CD 통합 (하이브리드 방식)

### 개요

이 프로젝트는 **하이브리드 방식**으로 Vault 인증 정보를 관리합니다:
- **CI/CD 배포 시**: 새로운 SECRET_ID 자동 발급 및 갱신
- **수동 재시작 시**: 기존 SECRET_ID 재사용 (30일 유효)

### 동작 방식

```
┌───────────────────────────────────────────────────┐
│ GitHub Actions Workflow                           │
├───────────────────────────────────────────────────┤
│                                                    │
│ 1. 변경 감지 (service-a/service-b backend)       │
│ 2. Docker 이미지 빌드                             │
│ 3. Vault에서 새 SECRET_ID 발급 ⚡                │
│    - VAULT_TOKEN으로 Vault 접속                   │
│    - 새 SECRET_ID 생성 (30일 TTL)                 │
│ 4. 서버 SSH 접속                                  │
│ 5. .env 파일 업데이트                             │
│    - SERVICE_A_SECRET_ID=<new-value>              │
│    - SERVICE_B_SECRET_ID=<new-value>              │
│ 6. Docker Compose 재시작                          │
│                                                    │
│ ✓ 새로운 SECRET_ID로 컨테이너 시작               │
└───────────────────────────────────────────────────┘
```

### GitHub Secrets 설정 (격리 보안)

다음 secrets를 GitHub Repository에 추가하세요:

```bash
# Vault 접근 정보
VAULT_ADDR=http://your-vault-server:8200

# 🔐 격리된 Manager Tokens (완전 분리)
SERVICE_A_MANAGER_TOKEN=hvs.xxxxx  # Service A SECRET_ID 발급 전용
SERVICE_B_MANAGER_TOKEN=hvs.xxxxx  # Service B SECRET_ID 발급 전용
INFRA_MANAGER_TOKEN=hvs.xxxxx      # 인프라 secrets 읽기 전용 (postgres, redis, grafana)

# AppRole ROLE_IDs (변하지 않음)
SERVICE_A_ROLE_ID=abc123...
SERVICE_B_ROLE_ID=def456...

# 서버 접속 정보
SERVER_HOST=your-server-ip
SERVER_USER=deploy-bot
SERVER_SSH_KEY=<your-private-key>
```

**🔐 보안 강화 포인트:**
- ❌ **ROOT_TOKEN 제거**: GitHub Secrets에 Root 권한 토큰 저장 안 함
- ✅ **3-Tier 격리**: Service-A ⚡ Service-B ⚡ Infra 완전 분리
- ✅ **최소 권한**:
  - Service Manager: SECRET_ID 발급만 가능
  - Infra Manager: 인프라 secrets 읽기만 가능
- ✅ **docker-compose 하드코딩 제거**: 모든 credentials를 Vault에서 관리

**중요**:
- `SERVICE_A_SECRET_ID`, `SERVICE_B_SECRET_ID`는 GitHub Secrets에 저장하지 **않습니다**.
- `POSTGRES_PASSWORD`, `GRAFANA_PASSWORD` 등도 GitHub Secrets에 저장하지 **않습니다**.
- 모든 Manager 토큰은 `init-approle.sh` 실행 시 자동 생성됩니다.

### 수동 재시작 시나리오

#### ✅ 가능: 30일 이내 재시작

```bash
# 서버에서 직접 재시작
cd /opt/exit8/self-managed-infrastructure
docker-compose restart service-a-backend

# 또는 완전히 재시작
docker-compose down service-a-backend
docker-compose up -d service-a-backend
```

`.env` 파일의 SECRET_ID가 아직 유효하므로 정상 작동합니다.

#### ⚠️ 주의: 30일 경과 후

```bash
# SECRET_ID 만료로 인증 실패
❌ Vault authentication failed: invalid secret_id
```

**해결 방법:**
1. GitHub Actions에서 재배포 (자동으로 새 SECRET_ID 발급)
2. 또는 수동으로 SECRET_ID 재발급:

```bash
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=<your-root-token>

# 새 SECRET_ID 발급
NEW_SECRET=$(vault write -field=secret_id -f auth/approle/role/service-a-backend/secret-id)

# .env 업데이트
sed -i "s|SERVICE_A_SECRET_ID=.*|SERVICE_A_SECRET_ID=${NEW_SECRET}|" .env

# 재시작
docker-compose restart service-a-backend
```

### 배포 흐름 상세

```yaml
# .github/workflows/deploy.yml

jobs:
  # 1. SECRET_ID 발급
  rotate-vault-credentials:
    steps:
      - name: Generate new SECRET_IDs
        run: |
          # 변경된 서비스만 새 SECRET_ID 발급
          vault write -field=secret_id -f auth/approle/role/service-a-backend/secret-id

  # 2. 서버에 배포
  deploy:
    needs: rotate-vault-credentials
    steps:
      - name: Update .env and restart
        run: |
          # .env 파일 업데이트
          sed -i "s|SERVICE_A_SECRET_ID=.*|SERVICE_A_SECRET_ID=${NEW_SECRET}|" .env

          # 컨테이너 재시작 (새 SECRET_ID 적용)
          docker-compose up -d service-a-backend
```

### SECRET_ID 생명주기

```
┌─────────────────────────────────────────────────────┐
│ SECRET_ID 생명주기 (30일)                            │
├─────────────────────────────────────────────────────┤
│                                                      │
│ Day 0:  GitHub Actions에서 발급                     │
│         └─> .env 파일에 저장                        │
│         └─> 컨테이너 시작                           │
│                                                      │
│ Day 1-29: 수동 재시작 OK                            │
│           └─> .env의 SECRET_ID 재사용               │
│                                                      │
│ Day 30: SECRET_ID 만료                              │
│         └─> 수동 재시작 실패 ❌                     │
│         └─> GitHub Actions 재배포 필요              │
│                                                      │
└─────────────────────────────────────────────────────┘
```

### 장점

1. **자동화**: 배포마다 자동으로 SECRET_ID 갱신
2. **유연성**: 30일 이내 수동 재시작 가능
3. **보안성**: SECRET_ID가 GitHub Secrets에 저장되지 않음
4. **효율성**: 추가 컨테이너(vault-agent) 불필요

## 🔐 보안 모범 사례

### Secret-ID 관리

- **TTL**: Secret-ID는 30일(720시간) 후 만료됩니다
- **자동 순환**: CI/CD 배포 시 자동으로 새 SECRET_ID 발급
- **수동 순환**: 30일 경과 후 수동으로 재발급 필요
- **저장**: Secret-ID를 절대 Git에 커밋하지 마세요 (서버의 .env에만 저장)
- **GitHub Secrets**: SECRET_ID는 GitHub Secrets에 저장하지 **않습니다** (배포마다 갱신)

### 토큰 관리

- **자동 갱신**: Spring Cloud Vault가 자동으로 토큰을 갱신합니다
- **TTL**: 토큰은 1시간 TTL, 최대 4시간입니다
- **로깅**: Vault 감사 로그에서 토큰 사용을 모니터링하세요

### 정책 원칙

- **최소 권한**: 각 서비스는 자신의 시크릿만 접근합니다
- **읽기 전용**: 서비스는 읽기 전용 접근 권한을 가집니다 (쓰기/삭제 불가)
- **경로 격리**: service-a는 service-b의 시크릿을 읽을 수 없습니다

## 🔄 인증 정보 순환

### Secret-ID 자동 순환 (CI/CD)

**GitHub Actions를 통한 배포 시 자동으로 처리됩니다.**

```yaml
# .github/workflows/deploy.yml
# 배포 시 자동으로:
# 1. 새 SECRET_ID 발급
# 2. 서버 .env 업데이트
# 3. 컨테이너 재시작
```

별도 작업 불필요! GitHub에 push하면 자동 실행됩니다.

### Secret-ID 수동 순환 (30일 경과 후)

CI/CD를 사용하지 않거나 SECRET_ID가 만료된 경우:

```bash
# Service A의 새 Secret-ID 생성
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=<your-root-token>

# 새 SECRET_ID 발급
NEW_SECRET=$(vault write -field=secret_id -f auth/approle/role/service-a-backend/secret-id)

# .env 파일 업데이트
cd /opt/exit8/self-managed-infrastructure
sed -i "s|SERVICE_A_SECRET_ID=.*|SERVICE_A_SECRET_ID=${NEW_SECRET}|" .env

# 컨테이너 재시작
docker-compose restart service-a-backend
```

### Role-ID 순환 (덜 빈번함)

```bash
# Vault와 .env 모두 업데이트 필요
vault write auth/approle/role/service-a-backend/role-id role_id=<new-role-id>

# .env 파일의 ROLE_ID 업데이트
# service-a-backend 재시작
docker-compose restart service-a-backend
```

## 🐛 문제 해결

### Vault가 sealed 상태인 경우

```bash
# 상태 확인
docker exec -it vault vault status

# 3개의 key로 unseal
docker exec -it vault vault operator unseal <key-1>
docker exec -it vault vault operator unseal <key-2>
docker exec -it vault vault operator unseal <key-3>
```

### 서비스가 인증할 수 없는 경우

1. **.env 파일의 인증 정보 확인**
   ```bash
   cat .env | grep SERVICE_A
   ```

2. **AppRole 존재 확인**
   ```bash
   vault read auth/approle/role/service-a-backend
   ```

3. **수동으로 인증 테스트**
   ```bash
   vault write auth/approle/login \
     role_id=$SERVICE_A_ROLE_ID \
     secret_id=$SERVICE_A_SECRET_ID
   ```

4. **로그 확인**
   ```bash
   docker logs service-a-backend | grep -i vault
   ```

### Secret-ID 만료됨 (30일 경과)

**권장 방법: GitHub Actions로 재배포**

```bash
# 로컬에서 빈 커밋 후 push (재배포 트리거)
git commit --allow-empty -m "chore: rotate vault credentials"
git push origin main
```

GitHub Actions가 자동으로:
1. 새 SECRET_ID 발급
2. 서버 .env 업데이트
3. 컨테이너 재시작

**대안: 수동 재발급**

```bash
# 새 Secret-ID 생성
export VAULT_ADDR=http://localhost:8200
export VAULT_TOKEN=<your-root-token>

NEW_SECRET=$(vault write -field=secret_id -f auth/approle/role/service-a-backend/secret-id)

# .env 업데이트
cd /opt/exit8/self-managed-infrastructure
sed -i "s|SERVICE_A_SECRET_ID=.*|SERVICE_A_SECRET_ID=${NEW_SECRET}|" .env

# 재시작
docker-compose restart service-a-backend
```

### 권한 거부됨

1. **정책 확인**
   ```bash
   vault policy read service-a-policy
   ```

2. **role 정책 바인딩 확인**
   ```bash
   vault read auth/approle/role/service-a-backend
   ```

3. **시크릿 경로 확인**
   ```bash
   # 다음 경로와 일치해야 함: secret/data/service-a-backend/*
   vault kv list secret/service-a-backend/
   ```

## 📊 모니터링

### 감사 로그

감사 로깅 활성화:

```bash
vault audit enable file file_path=/vault/logs/audit.log
```

로그 확인:

```bash
docker exec -it vault cat /vault/logs/audit.log | jq
```

### 헬스 체크

```bash
# Vault 상태
curl http://localhost:8200/v1/sys/health

# AppRole 상태
vault read auth/approle/role/service-a-backend
```

## 📝 주요 명령어 요약

```bash
# Vault 상태 확인
docker exec -it vault vault status

# 시크릿 추가
vault kv put secret/service-a-backend/config key=value

# 시크릿 조회
vault kv get secret/service-a-backend/config

# 시크릿 목록
vault kv list secret/service-a-backend/

# Secret-ID 재발급
vault write -f auth/approle/role/service-a-backend/secret-id

# 정책 확인
vault policy read service-a-policy

# AppRole 정보 확인
vault read auth/approle/role/service-a-backend
```

## ⚠️ 보안 경고

1. **Root Token 관리**
   - Root token은 초기 설정 후 폐기하세요
   - 필요시에만 재생성하세요

2. **Unseal Keys 보관**
   - 최소 3명의 관리자가 나눠서 보관하세요
   - Shamir's Secret Sharing 원칙 준수

3. **환경변수 보안**
   - `.env` 파일을 Git에 커밋하지 마세요
   - `.gitignore`에 `.env` 추가 확인

4. **네트워크 보안**
   - 프로덕션 환경에서는 TLS 활성화 필수
   - Vault 포트(8200)를 외부에 노출하지 마세요

## 🔗 참고 문서

- [Vault AppRole 공식 문서](https://developer.hashicorp.com/vault/docs/auth/approle)
- [Spring Cloud Vault](https://spring.io/projects/spring-cloud-vault)
- [Vault 정책 가이드](https://developer.hashicorp.com/vault/docs/concepts/policies)

## 🆘 지원

문제가 발생하면:

1. Vault 컨테이너 로그 확인: `docker logs vault`
2. 애플리케이션 로그 확인: `docker logs service-a-backend`
3. Vault unsealed 상태 확인: `docker exec -it vault vault status`
4. 이 문서 다시 확인
5. 플랫폼 팀에 문의
