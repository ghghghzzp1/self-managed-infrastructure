# Manager Policy for Service B CI/CD
# Allows ONLY SECRET_ID generation for service-b-backend
# Used by GitHub Actions to rotate credentials

# SECRET_ID 발급 권한 (write)
path "auth/approle/role/service-b-backend/secret-id" {
  capabilities = ["update"]
}

# Role-ID 조회 권한 (선택적)
path "auth/approle/role/service-b-backend/role-id" {
  capabilities = ["read"]
}

# Token self-renewal
path "auth/token/renew-self" {
  capabilities = ["update"]
}

# Token self-lookup (for debugging)
path "auth/token/lookup-self" {
  capabilities = ["read"]
}

# ===================================
# 명시적 거부: service-a 접근 차단
# ===================================
path "auth/approle/role/service-a-backend/*" {
  capabilities = ["deny"]
}

path "secret/data/service-a-backend/*" {
  capabilities = ["deny"]
}
