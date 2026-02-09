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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
POLICY_DIR="${SCRIPT_DIR}/policies"

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
        token_ttl=1h \
        token_max_ttl=4h \
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
    echo -e "${GREEN}✓ AppRole setup complete!${NC}"
}

main
