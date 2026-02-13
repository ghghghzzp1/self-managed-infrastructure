# --- 설정 변수 ---
$VAULT_ADDR = "http://127.0.0.1:8200"
$VAULT_TOKEN = "root-token"
$ROLE_NAME = "service-a-backend"
$POLICY_NAME = "service-a-policy"
$SECRET_PATH = "secret/service-a-backend"
# ----------------

Write-Host "[1] Policy 생성 중..." -ForegroundColor Cyan
'path "secret/data/service-a-backend" { capabilities = ["read"] }' | docker exec -i -e VAULT_TOKEN="$VAULT_TOKEN" vault vault policy write -address="$VAULT_ADDR" $POLICY_NAME -

Write-Host "`n[2] AppRole 활성화 및 Role 생성 중..." -ForegroundColor Cyan
docker exec -i -e VAULT_TOKEN="$VAULT_TOKEN" vault vault auth enable -address="$VAULT_ADDR" approle
docker exec -i -e VAULT_TOKEN="$VAULT_TOKEN" vault vault write -address="$VAULT_ADDR" auth/approle/role/$ROLE_NAME token_policies="$POLICY_NAME" token_ttl=1h token_max_ttl=4h

Write-Host "`n[3] 실제 시크릿 데이터 입력 중..." -ForegroundColor Cyan
docker exec -i -e VAULT_TOKEN="$VAULT_TOKEN" vault vault kv put -address="$VAULT_ADDR" $SECRET_PATH db.name="appdb" db.username="admin" db.password="changeme"

Write-Host "`n[4] 네트워크 연결 (Vault <-> DB)..." -ForegroundColor Cyan
docker network connect db vault

Write-Host "`n==========================================" -ForegroundColor Yellow
Write-Host "[결과 확인] 아래 정보를 .env 파일에 복사하세요." -ForegroundColor Yellow
Write-Host "==========================================" -ForegroundColor Yellow

Write-Host "`n① Role ID 확인:" -ForegroundColor Green
docker exec -i -e VAULT_TOKEN="$VAULT_TOKEN" vault vault read -address="$VAULT_ADDR" auth/approle/role/$ROLE_NAME/role-id

Write-Host "`n② Secret ID 발급:" -ForegroundColor Green
docker exec -i -e VAULT_TOKEN="$VAULT_TOKEN" vault vault write -f -address="$VAULT_ADDR" auth/approle/role/$ROLE_NAME/secret-id

Write-Host "`n③ 저장된 데이터 확인:" -ForegroundColor Green
docker exec -i -e VAULT_TOKEN="$VAULT_TOKEN" vault vault kv get -address="$VAULT_ADDR" $SECRET_PATH

Write-Host "`n작업이 완료되었습니다. 아무 키나 누르면 종료됩니다..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")