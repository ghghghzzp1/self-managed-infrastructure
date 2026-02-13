@echo off
SETLOCAL

:: --- 설정 변수 ---
SET VAULT_ADDR=http://127.0.0.1:8200
SET VAULT_TOKEN=root-token
SET ROLE_NAME=service-a-backend
SET POLICY_NAME=service-a-policy
SET SECRET_PATH=secret/service-a-backend
:: ----------------

echo [1] Policy 생성 중...
echo path "secret/data/service-a-backend" { capabilities = ["read"] } | docker exec -i -e VAULT_TOKEN="%VAULT_TOKEN%" vault vault policy write -address="%VAULT_ADDR%" %POLICY_NAME% -

echo [2] AppRole 활성화 및 Role 생성 중...
docker exec -i -e VAULT_TOKEN="%VAULT_TOKEN%" vault vault auth enable -address="%VAULT_ADDR%" approle
docker exec -i -e VAULT_TOKEN="%VAULT_TOKEN%" vault vault write -address="%VAULT_ADDR%" auth/approle/role/%ROLE_NAME% token_policies="%POLICY_NAME%" token_ttl=1h token_max_ttl=4h

echo [3] 실제 시크릿 데이터 입력 중...
docker exec -i -e VAULT_TOKEN="%VAULT_TOKEN%" vault vault kv put -address="%VAULT_ADDR%" %SECRET_PATH% db.name="appdb" db.username="admin" db.password="changeme"

echo [4] 네트워크 연결 (Vault <-> DB)...
docker network connect db vault

echo.
echo ==========================================
echo [결과 확인] 아래 정보를 .env 파일에 복사하세요.
echo ==========================================

echo ① Role ID 확인:
docker exec -i -e VAULT_TOKEN="%VAULT_TOKEN%" vault vault read -address="%VAULT_ADDR%" auth/approle/role/%ROLE_NAME%/role-id

echo.
echo ② Secret ID 발급:
docker exec -i -e VAULT_TOKEN="%VAULT_TOKEN%" vault vault write -f -address="%VAULT_ADDR%" auth/approle/role/%ROLE_NAME%/secret-id

echo.
echo ③ 저장된 데이터 확인:
docker exec -i -e VAULT_TOKEN="%VAULT_TOKEN%" vault vault kv get -address="%VAULT_ADDR%" %SECRET_PATH%

pause