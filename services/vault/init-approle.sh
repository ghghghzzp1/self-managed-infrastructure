#!/bin/bash

# Vault AppRole Initialization Script
# This script sets up AppRole authentication for service-a and service-b

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
VAULT_ADDR="${VAULT_ADDR:-http://localhost:8200}"
VAULT_TOKEN="${VAULT_TOKEN:-}"

# Resolve script directory (compatible with sh/dash/bash)
if [ -n "${BASH_SOURCE[0]:-}" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
elif [ -n "$0" ] && [ "$0" != "-bash" ] && [ "$0" != "bash" ]; then
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
else
    SCRIPT_DIR="$(pwd)"
fi
POLICY_DIR="${SCRIPT_DIR}/policies"

echo -e "${YELLOW}Script directory: ${SCRIPT_DIR}${NC}"
echo -e "${YELLOW}Policy directory: ${POLICY_DIR}${NC}"

echo -e "${GREEN}=== Vault AppRole Initialization ===${NC}"
echo ""

# Check if VAULT_TOKEN is set
if [ -z "$VAULT_TOKEN" ]; then
    echo -e "${RED}Error: VAULT_TOKEN environment variable is not set${NC}"
    echo "Please export VAULT_TOKEN=<your-root-token>"
    exit 1
fi

export VAULT_ADDR

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

# Function to enable AppRole if not already enabled
enable_approle() {
    echo -e "${YELLOW}Enabling AppRole auth method...${NC}"
    if vault auth list | grep -q "approle/"; then
        echo -e "${GREEN}✓ AppRole already enabled${NC}"
    else
        vault auth enable approle
        echo -e "${GREEN}✓ AppRole enabled${NC}"
    fi
}

# Function to create policy
create_policy() {
    local service_name=$1
    local policy_file="${POLICY_DIR}/${service_name}-policy.hcl"

    echo -e "${YELLOW}Creating policy for ${service_name}...${NC}"

    if [ ! -f "$policy_file" ]; then
        echo -e "${RED}Error: Policy file not found: ${policy_file}${NC}"
        exit 1
    fi

    vault policy write "${service_name}-policy" "$policy_file"
    echo -e "${GREEN}✓ Policy created: ${service_name}-policy${NC}"
}

# Function to create AppRole role
create_approle_role() {
    local service_name=$1
    local policy_name="${service_name}-policy"

    echo -e "${YELLOW}Creating AppRole role for ${service_name}...${NC}"

    vault write "auth/approle/role/${service_name}-backend" \
        token_period=1h \
        token_policies="${policy_name}" \
        bind_secret_id=true \
        secret_id_ttl=720h \
        secret_id_num_uses=0

    echo -e "${GREEN}✓ AppRole role created: ${service_name}-backend${NC}"
}

# Function to get role-id
get_role_id() {
    local service_name=$1
    vault read -field=role_id "auth/approle/role/${service_name}-backend/role-id"
}

# Function to generate secret-id
generate_secret_id() {
    local service_name=$1
    vault write -field=secret_id -f "auth/approle/role/${service_name}-backend/secret-id"
}

# Main execution
main() {
    check_vault_status
    enable_approle

    echo ""
    echo -e "${GREEN}=== Setting up Service A ===${NC}"
    create_policy "service-a"
    create_approle_role "service-a"

    echo ""
    echo -e "${GREEN}=== Setting up Service B ===${NC}"
    create_policy "service-b"
    create_approle_role "service-b"

    echo ""
    echo -e "${GREEN}=== Generating Credentials ===${NC}"
    echo ""

    # Service A credentials
    SERVICE_A_ROLE_ID=$(get_role_id "service-a")
    SERVICE_A_SECRET_ID=$(generate_secret_id "service-a")

    # Service B credentials
    SERVICE_B_ROLE_ID=$(get_role_id "service-b")
    SERVICE_B_SECRET_ID=$(generate_secret_id "service-b")

    # Output credentials
    echo -e "${YELLOW}┌─────────────────────────────────────────────────────────┐${NC}"
    echo -e "${YELLOW}│  Copy these credentials to your .env file              │${NC}"
    echo -e "${YELLOW}└─────────────────────────────────────────────────────────┘${NC}"
    echo ""
    echo "# Service A Credentials"
    echo "SERVICE_A_ROLE_ID=${SERVICE_A_ROLE_ID}"
    echo "SERVICE_A_SECRET_ID=${SERVICE_A_SECRET_ID}"
    echo ""
    echo "# Service B Credentials"
    echo "SERVICE_B_ROLE_ID=${SERVICE_B_ROLE_ID}"
    echo "SERVICE_B_SECRET_ID=${SERVICE_B_SECRET_ID}"
    echo ""
    echo -e "${YELLOW}┌─────────────────────────────────────────────────────────┐${NC}"
    echo -e "${YELLOW}│  SECURITY WARNING                                       │${NC}"
    echo -e "${YELLOW}│  - Keep SECRET_IDs private (like passwords)             │${NC}"
    echo -e "${YELLOW}│  - Add .env to .gitignore                               │${NC}"
    echo -e "${YELLOW}│  - SECRET_IDs expire in 30 days (720 hours)             │${NC}"
    echo -e "${YELLOW}│  - CI/CD will auto-rotate on each deployment            │${NC}"
    echo -e "${YELLOW}│  - Manual restart OK within 30 days                     │${NC}"
    echo -e "${YELLOW}└─────────────────────────────────────────────────────────┘${NC}"
    echo ""

    # ===================================
    # Create Manager Policies and Tokens
    # ===================================
    echo -e "${GREEN}=== Creating CI/CD Manager Tokens (Isolated) ===${NC}"
    echo ""

    # Service A Manager Policy
    echo -e "${YELLOW}Creating manager policy for service-a...${NC}"
    vault policy write "service-a-manager-policy" "${POLICY_DIR}/service-a-manager-policy.hcl"
    echo -e "${GREEN}✓ service-a-manager-policy created${NC}"

    # Service B Manager Policy
    echo -e "${YELLOW}Creating manager policy for service-b...${NC}"
    vault policy write "service-b-manager-policy" "${POLICY_DIR}/service-b-manager-policy.hcl"
    echo -e "${GREEN}✓ service-b-manager-policy created${NC}"

    # Infra Manager Policy
    echo -e "${YELLOW}Creating manager policy for infra...${NC}"
    vault policy write "infra-manager-policy" "${POLICY_DIR}/infra-manager-policy.hcl"
    echo -e "${GREEN}✓ infra-manager-policy created${NC}"

    echo ""
    echo -e "${YELLOW}Generating manager tokens...${NC}"

    # Service A Manager Token
    SERVICE_A_MANAGER_TOKEN=$(vault token create \
        -policy="service-a-manager-policy" \
        -ttl=8760h \
        -period=8760h \
        -display-name="service-a-ci-cd-manager" \
        -field=token)

    # Service B Manager Token
    SERVICE_B_MANAGER_TOKEN=$(vault token create \
        -policy="service-b-manager-policy" \
        -ttl=8760h \
        -period=8760h \
        -display-name="service-b-ci-cd-manager" \
        -field=token)

    # Infra Manager Token
    INFRA_MANAGER_TOKEN=$(vault token create \
        -policy="infra-manager-policy" \
        -ttl=8760h \
        -period=8760h \
        -display-name="infra-ci-cd-manager" \
        -field=token)

    echo ""
    echo -e "${GREEN}✓ Manager tokens created (Service A, Service B, Infra)${NC}"
    echo ""

    # ===================================
    # Output Manager Tokens for GitHub
    # ===================================
    echo -e "${YELLOW}┌─────────────────────────────────────────────────────────┐${NC}"
    echo -e "${YELLOW}│  GitHub Secrets (CI/CD Manager Tokens)                  │${NC}"
    echo -e "${YELLOW}└─────────────────────────────────────────────────────────┘${NC}"
    echo ""
    echo "# Vault Address"
    echo "VAULT_ADDR=http://vault:8200"
    echo ""
    echo "# Service A Manager Token (SECRET_ID 발급 전용)"
    echo "SERVICE_A_MANAGER_TOKEN=${SERVICE_A_MANAGER_TOKEN}"
    echo ""
    echo "# Service B Manager Token (SECRET_ID 발급 전용)"
    echo "SERVICE_B_MANAGER_TOKEN=${SERVICE_B_MANAGER_TOKEN}"
    echo ""
    echo "# Infra Manager Token (인프라 secrets 읽기 전용)"
    echo "INFRA_MANAGER_TOKEN=${INFRA_MANAGER_TOKEN}"
    echo ""
    echo "# Service A Role ID"
    echo "SERVICE_A_ROLE_ID=${SERVICE_A_ROLE_ID}"
    echo ""
    echo "# Service B Role ID"
    echo "SERVICE_B_ROLE_ID=${SERVICE_B_ROLE_ID}"
    echo ""
    echo -e "${YELLOW}┌─────────────────────────────────────────────────────────┐${NC}"
    echo -e "${YELLOW}│  SECURITY BENEFITS                                      │${NC}"
    echo -e "${YELLOW}│  ✓ No ROOT_TOKEN in GitHub Secrets                      │${NC}"
    echo -e "${YELLOW}│  ✓ Service-A ⚡ Service-B ⚡ Infra 완전 격리            │${NC}"
    echo -e "${YELLOW}│  ✓ Service tokens: SECRET_ID 발급만 가능                │${NC}"
    echo -e "${YELLOW}│  ✓ Infra token: 인프라 secrets 읽기만 가능              │${NC}"
    echo -e "${YELLOW}│  ✓ Docker-compose credentials Vault 중앙 관리           │${NC}"
    echo -e "${YELLOW}│  ✓ 1 year TTL with auto-renewal                         │${NC}"
    echo -e "${YELLOW}└─────────────────────────────────────────────────────────┘${NC}"
    echo ""
    echo -e "${GREEN}✓ AppRole setup complete with isolated manager tokens!${NC}"
}

main
