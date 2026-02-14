@echo off
chcp 65001 > nul
SETLOCAL ENABLEDELAYEDEXPANSION

:: --- 설정 변수 ---
SET VAULT_ADDR=http://127.0.0.1:8200
SET VAULT_TOKEN=root-token
SET ROLE_NAME=service-a-backend
SET POLICY_NAME=service-a-policy
SET SECRET_PATH=secret/service-a-backend
:: ----------------

echo [0] 컨테이너 상태 확인 및 실행 시작
for %%i in (postgres redis vault) do (
    docker ps --filter "name=%%i" --filter "status=running" --format "{{.Names}}" | findstr /X "%%i" > nul
    if errorlevel 1 (
        echo  - %%i 컨테이너를 시작합니다...
        docker start %%i > nul
    ) else (
        echo  - %%i 컨테이너가 이미 실행 중입니다.
    )
)

:: Vault 내부 프로세스가 준비될 때까지 대기
echo.
echo Vault 서버 응답 대기 중...
for /l %%i in (5,-1,1) do (
    <nul set /p "=%%i... "
    timeout /t 1 > nul
)
echo 완료!
echo.

echo.
echo [1] Policy 생성
echo path "secret/data/service-a-backend" { capabilities = ["read"] } | docker exec -i -e VAULT_TOKEN="%VAULT_TOKEN%" vault vault policy write -address="%VAULT_ADDR%" %POLICY_NAME% -

echo [2] AppRole 활성화 및 Role 생성
docker exec -i -e VAULT_TOKEN="%VAULT_TOKEN%" vault vault auth enable -address="%VAULT_ADDR%" approle >nul 2>&1
docker exec -i -e VAULT_TOKEN="%VAULT_TOKEN%" vault vault write -address="%VAULT_ADDR%" auth/approle/role/%ROLE_NAME% token_policies="%POLICY_NAME%" token_ttl=1h token_max_ttl=4h

echo [3] 실제 시크릿 데이터 입력
docker exec -i -e VAULT_TOKEN="%VAULT_TOKEN%" vault vault kv put -address="%VAULT_ADDR%" %SECRET_PATH% db.name="appdb" db.username="admin" db.password="changeme"

echo [4] 네트워크 연결 (Vault ^<^-^> DB)
:: 네트워크가 없을 경우 생성
docker network create db >nul 2>&1
:: 컨테이너들을 db 네트워크에 연결
docker network connect db vault >nul 2>&1
docker network connect db postgres >nul 2>&1

echo.
echo ==========================================
echo [결과 확인] ID 발급 및 .env 파일 생성
echo ==========================================

echo ① Role ID 확인:
docker exec -i -e VAULT_TOKEN="%VAULT_TOKEN%" vault vault read -field=role_id -address="%VAULT_ADDR%" auth/approle/role/%ROLE_NAME%/role-id

echo.
echo ② Secret ID 발급:
docker exec -i -e VAULT_TOKEN="%VAULT_TOKEN%" vault vault write -f -field=secret_id -address="%VAULT_ADDR%" auth/approle/role/%ROLE_NAME%/secret-id

echo.
echo ③ 저장된 데이터 확인:
docker exec -i -e VAULT_TOKEN="%VAULT_TOKEN%" vault vault kv get -address="%VAULT_ADDR%" %SECRET_PATH%

echo.
:: Role ID 및 Secret ID 추출 (권한 에러 방지를 위해 -e VAULT_TOKEN 명시)
for /f "tokens=*" %%a in ('docker exec -i -e VAULT_TOKEN^=%VAULT_TOKEN% vault vault read -field^=role_id -address^="%VAULT_ADDR%" auth/approle/role/%ROLE_NAME%/role-id') do set ROLE_ID=%%a
for /f "tokens=*" %%a in ('docker exec -i -e VAULT_TOKEN^=%VAULT_TOKEN% vault vault write -f -field^=secret_id -address^="%VAULT_ADDR%" auth/approle/role/%ROLE_NAME%/secret-id') do set SECRET_ID=%%a

echo .env 파일 업데이트
:: .env 파일 새로 작성 (공백 주의)
(
echo SPRING_PROFILES_ACTIVE=local
echo VAULT_URI=http://localhost:8200
echo VAULT_TOKEN=%VAULT_TOKEN%
echo VAULT_ROLE_ID=%ROLE_ID%
echo VAULT_SECRET_ID=%SECRET_ID%
) > .env

echo.
echo ==========================================
echo [완료] 모든 작업이 끝났습니다.
echo ==========================================
echo VAULT_ROLE_ID: %ROLE_ID%
echo VAULT_SECRET_ID: %SECRET_ID%
echo ==========================================

echo.
echo 5초 후 자동 종료됩니다...
for /l %%i in (5,-1,1) do (
    <nul set /p "=%%i... "
    timeout /t 1 > nul
)
exit