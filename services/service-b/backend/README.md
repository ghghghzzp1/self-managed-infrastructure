# Service B Backend (Security Vulnerability Lab)

Service B Backend는 의도적으로 보안 취약점을 포함한 서비스입니다.  
목적은 공격 트래픽(SQL Injection, Brute Force)을 재현하고, Wazuh 탐지/관제와 알림 체계를 검증하는 것입니다.

## 1. 시나리오 목적
- 취약한 인증 API를 대상으로 SQLi, Brute Force 공격 요청 유입
- 공격 징후 로그(JSON) 생성
- Wazuh에서 이벤트 수집/탐지 규칙(Level 12) 검증
- Wazuh Dashboard + 이메일 알림 동작 검증

## 2. 핵심 시나리오
Attacker(Client) -> Frontend Web(Service B UI) -> Service B Backend API -> JSON Logs -> Wazuh

- Service B는 공격 대상(Target) 역할
- Wazuh는 수집/탐지/관제 역할
- Backend가 Wazuh를 직접 제어하지 않음

## 3. 취약점/탐지 포인트
- 대상 API: `POST /api/v1/auth/login`
- 취약점:
  - SQL 문자열 결합 방식 쿼리 (의도적 SQLi 취약점)
  - 인증 실패 반복 허용 (Brute Force 관제 시나리오)
- 탐지 로그 이벤트:
  - `SUSPICIOUS_INPUT` (SQLi 패턴 감지)
  - `AUTH_UNAUTHORIZED` (인증 실패, 반복 시 Brute Force 징후)
  - `LOGIN_SUCCESS` (인증 성공)
  - `SYSTEM_ERROR`, `CLIENT_ERROR`
- IP 추적: `X-Forwarded-For` 헤더 우선 사용
- 추적 ID: `X-Trace-Id` 자동/수동 지원

## 4. Wazuh 탐지/알림 정책
- 탐지 대상 공격:
  - SQL Injection 시도
  - Brute Force 시도(반복 인증 실패)
- 룰 심각도: `Level 12`
- 알림 채널:
  - Wazuh Dashboard 경보
  - 이메일 알림
- 목표: 공격 이벤트 발생 시 운영자가 즉시 인지 가능한지 확인

## 5. 주요 API
- `POST /api/v1/auth/register` : 테스트 계정 생성
- `POST /api/v1/auth/login` : 정상/공격 요청 대상
- `GET /api/v1/auth/profile/{user_id}` : 내 정보 조회
- `GET /health` : 컨테이너 헬스체크
- `GET /metrics` : Prometheus 메트릭

## 6. 로컬 실행
`docker-compose.local.yml` 기준:

```bash
docker compose -f docker-compose.local.yml up --build service-b-backend
```

직접 호출 예시:

```bash
curl -X POST http://localhost:8000/api/v1/auth/login \
  -H "Content-Type: application/json" \
  -H "X-Forwarded-For: 10.10.10.10" \
  -H "X-Trace-Id: attack-test-001" \
  -d '{"username":"admin'"'"' OR 1=1 --","password":"x"}'
```

## 7. 관제 로그 확인 포인트
로그는 JSON 포맷으로 stdout에 기록됩니다.

확인 필드:
- `@timestamp`
- `level`
- `message`
- `ip`
- `user_id`
- `mdc.trace_id`

우선 확인할 이벤트:
- SQL Injection 시도 -> `SUSPICIOUS_INPUT`
- 반복 인증 실패 -> `AUTH_UNAUTHORIZED`
- 서버 예외 발생 -> `SYSTEM_ERROR`

## 8. 주의사항
- 본 서비스는 보안 취약점 재현/탐지 실험용입니다.
- 본 시나리오는 성능 테스트가 아니라 보안 탐지/알림 검증 목적입니다.
