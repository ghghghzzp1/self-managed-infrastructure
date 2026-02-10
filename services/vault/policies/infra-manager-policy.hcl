# Manager Policy for Infrastructure Secrets
# Allows reading infrastructure credentials (postgres, redis, grafana, etc.)
# Used by CI/CD and init-infra-secrets.sh

# 인프라 secrets 읽기 권한
path "secret/data/infra/*" {
  capabilities = ["read", "list"]
}

# 인프라 secrets 메타데이터 읽기
path "secret/metadata/infra/*" {
  capabilities = ["read", "list"]
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
# 명시적 거부: 서비스 secrets 차단
# ===================================
path "secret/data/service-a-backend/*" {
  capabilities = ["deny"]
}

path "secret/data/service-b-backend/*" {
  capabilities = ["deny"]
}

path "auth/approle/role/service-a-backend/*" {
  capabilities = ["deny"]
}

path "auth/approle/role/service-b-backend/*" {
  capabilities = ["deny"]
}
