#!/bin/bash

# Infrastructure Secrets Initialization Script
# Fetches infrastructure credentials from Vault and updates .env file

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
VAULT_ADDR="${VAULT_ADDR:-http://localhost:8200}"
INFRA_MANAGER_TOKEN="${INFRA_MANAGER_TOKEN:-}"
ENV_FILE="${ENV_FILE:-.env}"

echo -e "${GREEN}=== Infrastructure Secrets Initialization ===${NC}"
echo ""

# Check if INFRA_MANAGER_TOKEN is set
if [ -z "$INFRA_MANAGER_TOKEN" ]; then
    echo -e "${RED}Error: INFRA_MANAGER_TOKEN environment variable is not set${NC}"
    echo "Please export INFRA_MANAGER_TOKEN=<your-infra-manager-token>"
    exit 1
fi

export VAULT_ADDR
export VAULT_TOKEN="$INFRA_MANAGER_TOKEN"

# Function to check Vault status
check_vault_status() {
    echo -e "${YELLOW}Checking Vault status...${NC}"
    if ! vault status > /dev/null 2>&1; then
        echo -e "${RED}Error: Cannot connect to Vault at ${VAULT_ADDR}${NC}"
        echo "Make sure Vault is running and unsealed"
        exit 1
    fi
    echo -e "${GREEN}✓ Vault is accessible${NC}"
}

# Function to get secret from Vault
# Returns: value on success, empty string on failure (sets return code 1)
get_secret() {
    local path=$1
    local key=$2

    local value=$(vault kv get -field="$key" "secret/infra/$path" 2>/dev/null)

    if [ -z "$value" ]; then
        echo -e "${RED}Error: Failed to get $path/$key from Vault${NC}" >&2
        return 1
    fi

    echo "$value"
}

# Function to update or add env variable in .env file
update_env() {
    local key=$1
    local value=$2

    if [ -f "$ENV_FILE" ]; then
        # Check if key exists
        if grep -q "^${key}=" "$ENV_FILE"; then
            # Update existing
            sed -i.bak "s|^${key}=.*|${key}=${value}|" "$ENV_FILE"
        else
            # Add new
            echo "${key}=${value}" >> "$ENV_FILE"
        fi
    else
        # Create new file
        echo "${key}=${value}" >> "$ENV_FILE"
    fi
}

# Main execution
main() {
    check_vault_status

    echo ""
    echo -e "${GREEN}=== Fetching Infrastructure Secrets ===${NC}"
    echo ""

    # Backup .env if it exists
    if [ -f "$ENV_FILE" ]; then
        cp "$ENV_FILE" "${ENV_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
        echo -e "${GREEN}✓ Backup created: ${ENV_FILE}.backup.$(date +%Y%m%d_%H%M%S)${NC}"
    fi

    # Fetch PostgreSQL credentials
    echo -e "${YELLOW}Fetching PostgreSQL credentials...${NC}"
    POSTGRES_USER=$(get_secret "postgres" "user")
    POSTGRES_PASSWORD=$(get_secret "postgres" "password")
    POSTGRES_DB=$(get_secret "postgres" "database")

    update_env "POSTGRES_USER" "$POSTGRES_USER"
    update_env "POSTGRES_PASSWORD" "$POSTGRES_PASSWORD"
    update_env "POSTGRES_DB" "$POSTGRES_DB"
    echo -e "${GREEN}✓ PostgreSQL credentials updated${NC}"

    # Fetch Redis credentials (optional)
    echo -e "${YELLOW}Fetching Redis credentials...${NC}"
    REDIS_PASSWORD=""
    if REDIS_PASSWORD=$(get_secret "redis" "password"); then
        update_env "REDIS_PASSWORD" "$REDIS_PASSWORD"
        echo -e "${GREEN}✓ Redis credentials updated${NC}"
    else
        echo -e "${YELLOW}⊘ Redis password not set in Vault (optional, skipping)${NC}"
    fi

    # Fetch Grafana credentials
    echo -e "${YELLOW}Fetching Grafana credentials...${NC}"
    GRAFANA_USER=$(get_secret "grafana" "admin_user")
    GRAFANA_PASSWORD=$(get_secret "grafana" "admin_password")

    update_env "GRAFANA_USER" "$GRAFANA_USER"
    update_env "GRAFANA_PASSWORD" "$GRAFANA_PASSWORD"
    echo -e "${GREEN}✓ Grafana credentials updated${NC}"

    echo ""
    echo -e "${GREEN}✓ 모든 인프라 secrets를 성공적으로 가져왔습니다!${NC}"
    echo -e "${GREEN}✓ .env 파일 업데이트: ${ENV_FILE}${NC}"
    echo ""
    echo -e "${YELLOW}┌─────────────────────────────────────────────────────────┐${NC}"
    echo -e "${YELLOW}│  보안 주의사항                                          │${NC}"
    echo -e "${YELLOW}│  - .env 파일에는 민감한 credentials가 포함됩니다        │${NC}"
    echo -e "${YELLOW}│  - .env 파일이 .gitignore에 있는지 확인하세요           │${NC}"
    echo -e "${YELLOW}│  - 파일 권한: chmod 600 .env                            │${NC}"
    echo -e "${YELLOW}└─────────────────────────────────────────────────────────┘${NC}"
    echo ""

    # Set secure permissions
    chmod 600 "$ENV_FILE"
    echo -e "${GREEN}✓ 보안 권한 설정 완료 (600)${NC}"
}

main
