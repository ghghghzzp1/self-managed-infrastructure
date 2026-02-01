# Exit8 빌드 가이드

팀원들의 개발 환경(Mac ARM, Windows Intel)과 프로덕션 환경(Linux amd64)이 다르기 때문에, 크로스 플랫폼 빌드 설정이 필요합니다.

## 목차

- [환경별 아키텍처](#환경별-아키텍처)
- [사전 준비](#사전-준비)
- [로컬 개발](#로컬-개발)
- [프로덕션 빌드](#프로덕션-빌드)
- [트러블슈팅](#트러블슈팅)

---

## 환경별 아키텍처

| 환경 | OS | 아키텍처 | Docker Platform |
|------|-----|----------|-----------------|
| 개발 (Mac M1/M2/M3) | macOS | ARM64 | `linux/arm64` |
| 개발 (Windows Intel) | Windows | x86_64 | `linux/amd64` |
| 프로덕션 (GCP) | Linux | x86_64 | `linux/amd64` |

---

## 사전 준비

### Mac (Apple Silicon)

```bash
# Docker Desktop 설치 (Rosetta 에뮬레이션 활성화 권장)
# Docker Desktop > Settings > General > "Use Rosetta for x86/amd64 emulation" 체크

# Docker Buildx 확인
docker buildx version

# 멀티 아키텍처 빌더 생성 (최초 1회)
docker buildx create --name multiarch --driver docker-container --use
docker buildx inspect --bootstrap
```

### Windows (Intel)

```powershell
# Docker Desktop 설치
# https://www.docker.com/products/docker-desktop

# WSL2 백엔드 활성화 필수
# Docker Desktop > Settings > General > "Use the WSL 2 based engine" 체크

# PowerShell에서 Docker Buildx 확인
docker buildx version

# 멀티 아키텍처 빌더 생성 (최초 1회)
docker buildx create --name multiarch --driver docker-container --use
docker buildx inspect --bootstrap
```

### 빌더 확인

```bash
# 현재 빌더 목록
docker buildx ls

# 출력 예시:
# NAME/NODE       DRIVER/ENDPOINT             STATUS  PLATFORMS
# multiarch *     docker-container
#   multiarch0    unix:///var/run/docker.sock running linux/amd64, linux/arm64
```

---

## 로컬 개발

### 방법 1: 네이티브 아키텍처로 빌드 (권장, 빠름)

자신의 머신 아키텍처에 맞게 빌드합니다. 로컬 테스트용으로 가장 빠릅니다.

```bash
# 프로젝트 루트에서 실행
cd /path/to/exit8

# 전체 서비스 빌드 및 실행
docker-compose -f docker-compose.local.yml up --build

# 특정 서비스만 빌드 (분리된 구조)
docker-compose -f docker-compose.local.yml build service-a-backend
docker-compose -f docker-compose.local.yml build service-a-frontend
docker-compose -f docker-compose.local.yml build service-b-backend
docker-compose -f docker-compose.local.yml build service-b-frontend

# 특정 서비스만 실행
docker-compose -f docker-compose.local.yml up service-a-backend service-a-frontend postgres redis
```

### 방법 2: 프로덕션 아키텍처(amd64)로 빌드

Mac ARM에서 프로덕션과 동일한 환경으로 테스트하고 싶을 때 사용합니다.

```bash
# Mac ARM에서 amd64로 빌드 (에뮬레이션, 느림)
docker buildx build --platform linux/amd64 -t exit8/service-a-backend:local ./services/service-a/backend
docker buildx build --platform linux/amd64 -t exit8/service-a-frontend:local ./services/service-a/frontend
docker buildx build --platform linux/amd64 -t exit8/service-b-backend:local ./services/service-b/backend
docker buildx build --platform linux/amd64 -t exit8/service-b-frontend:local ./services/service-b/frontend

# 또는 docker-compose에서 플랫폼 지정
DOCKER_DEFAULT_PLATFORM=linux/amd64 docker-compose -f docker-compose.local.yml up --build
```

### 프론트엔드 개발 모드 (Hot Reload)

Docker 없이 프론트엔드만 개발할 때:

```bash
# Service A 프론트엔드
cd services/service-a/frontend
npm install
npm run dev
# http://localhost:5173 에서 확인 (백엔드 API는 8080으로 프록시)

# Service B 프론트엔드
cd services/service-b/frontend
npm install
npm run dev
# http://localhost:5174 에서 확인 (백엔드 API는 8000으로 프록시)
```

### 백엔드 개발 모드

```bash
# Service A (Spring Boot)
cd services/service-a/backend
./gradlew bootRun

# Service B (FastAPI)
cd services/service-b/backend
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```

---

## 프로덕션 빌드

### GitHub Actions (자동)

`main` 브랜치에 푸시하면 자동으로 `linux/amd64` 이미지가 빌드되어 Docker Hub에 푸시됩니다.

```yaml
# .github/workflows/deploy.yml 에서 자동 처리
# 변경된 서비스만 감지하여 빌드
```

### 수동 멀티 아키텍처 빌드

로컬에서 직접 Docker Hub에 푸시할 때:

```bash
# Docker Hub 로그인
docker login

# Service A Backend - 멀티 아키텍처 빌드 & 푸시
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t exit8/service-a-backend:latest \
  --push \
  ./services/service-a/backend

# Service A Frontend - 멀티 아키텍처 빌드 & 푸시
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t exit8/service-a-frontend:latest \
  --push \
  ./services/service-a/frontend

# Service B Backend - 멀티 아키텍처 빌드 & 푸시
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t exit8/service-b-backend:latest \
  --push \
  ./services/service-b/backend

# Service B Frontend - 멀티 아키텍처 빌드 & 푸시
docker buildx build \
  --platform linux/amd64,linux/arm64 \
  -t exit8/service-b-frontend:latest \
  --push \
  ./services/service-b/frontend
```

### 프로덕션 서버 배포

```bash
# SSH로 서버 접속
ssh user@your-server

# 이미지 풀 및 재시작
cd /opt/exit8
docker-compose pull
docker-compose up -d --remove-orphans

# 헬스 체크
curl http://localhost:3000/health   # service-a-frontend
curl http://localhost:8080/actuator/health  # service-a-backend (internal)
curl http://localhost:3002/health   # service-b-frontend
curl http://localhost:8000/health   # service-b-backend (internal)

# 로그 확인
docker-compose logs -f service-a-backend
docker-compose logs -f service-a-frontend
docker-compose logs -f service-b-backend
docker-compose logs -f service-b-frontend
```

---

## 트러블슈팅

### Mac ARM에서 "exec format error" 발생

```bash
# 원인: amd64 이미지를 ARM에서 실행하려 할 때
# 해결: Rosetta 에뮬레이션 활성화
# Docker Desktop > Settings > General > "Use Rosetta for x86/amd64 emulation" 체크

# 또는 네이티브 아키텍처로 다시 빌드
docker-compose -f docker-compose.local.yml build --no-cache
```

### Windows에서 빌드 속도가 느림

```powershell
# WSL2 파일시스템 사용 권장
# 프로젝트를 Windows 파일시스템(C:\)이 아닌 WSL 내부에 배치

# WSL 터미널에서:
cd ~
git clone <repository> exit8
cd exit8
docker-compose -f docker-compose.local.yml up --build
```

### 이미지 캐시 문제

```bash
# 캐시 무시하고 완전 새로 빌드
docker-compose -f docker-compose.local.yml build --no-cache

# 모든 빌드 캐시 삭제
docker builder prune -a

# 사용하지 않는 이미지 정리
docker image prune -a
```

### Node.js 의존성 오류 (npm ci 실패)

```bash
# package-lock.json 재생성
cd services/service-a/frontend
rm -rf node_modules package-lock.json
npm install

cd services/service-b/frontend
rm -rf node_modules package-lock.json
npm install
```

### Gradle Wrapper 권한 오류

```bash
# gradlew 실행 권한 부여
chmod +x services/service-a/backend/gradlew

# Windows에서는 Git 설정 확인
git config core.autocrlf false
git checkout services/service-a/backend/gradlew
```

### 포트 충돌

```bash
# 사용 중인 포트 확인
# Mac/Linux
lsof -i :8080
lsof -i :8000

# Windows
netstat -ano | findstr :8080
netstat -ano | findstr :8000

# 다른 포트로 실행
SERVICE_A_PORT=9080 SERVICE_B_PORT=9000 docker-compose -f docker-compose.local.yml up
```

---

## 환경별 빠른 참조

### Mac ARM 사용자

```bash
# 최초 설정
docker buildx create --name multiarch --driver docker-container --use

# 로컬 개발 (네이티브, 빠름)
docker-compose -f docker-compose.local.yml up --build

# 프로덕션 테스트 (에뮬레이션, 느림)
DOCKER_DEFAULT_PLATFORM=linux/amd64 docker-compose -f docker-compose.local.yml up --build
```

### Windows Intel 사용자

```powershell
# 최초 설정 (PowerShell)
docker buildx create --name multiarch --driver docker-container --use

# 로컬 개발
docker-compose -f docker-compose.local.yml up --build

# WSL2 터미널 사용 권장 (더 빠름)
wsl
cd ~/exit8
docker-compose -f docker-compose.local.yml up --build
```

---

## 참고 링크

- [Docker Buildx 공식 문서](https://docs.docker.com/buildx/working-with-buildx/)
- [Docker Desktop for Mac - Apple Silicon](https://docs.docker.com/desktop/mac/apple-silicon/)
- [Docker Desktop for Windows - WSL2](https://docs.docker.com/desktop/windows/wsl/)
