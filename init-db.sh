#!/bin/bash

# PostgreSQL Database Initialization Script
# Creates service-specific users and databases using credentials from Vault
# Run this ONCE after: docker-compose up → init-approle.sh → vault kv put

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
VAULT_ADDR="${VAULT_ADDR:-http://localhost:8200}"
VAULT_TOKEN="${VAULT_TOKEN:-}"
POSTGRES_HOST="${POSTGRES_HOST:-localhost}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"

# Admin credentials from .env
ENV_FILE="${ENV_FILE:-.env}"

echo -e "${GREEN}=== PostgreSQL Database Initialization ===${NC}"
echo ""

# Check if VAULT_TOKEN is set
if [ -z "$VAULT_TOKEN" ]; then
    echo -e "${RED}Error: VAULT_TOKEN environment variable is not set${NC}"
    echo "Please export VAULT_TOKEN=<your-root-token>"
    exit 1
fi

export VAULT_ADDR

# Load admin credentials from .env
if [ -f "$ENV_FILE" ]; then
    ADMIN_USER=$(grep "^POSTGRES_USER=" "$ENV_FILE" | cut -d'=' -f2)
    ADMIN_PASSWORD=$(grep "^POSTGRES_PASSWORD=" "$ENV_FILE" | cut -d'=' -f2)
    ADMIN_DB=$(grep "^POSTGRES_DB=" "$ENV_FILE" | cut -d'=' -f2)
else
    echo -e "${RED}Error: .env file not found at ${ENV_FILE}${NC}"
    echo "Run init-infra-secrets.sh first"
    exit 1
fi

if [ -z "$ADMIN_USER" ] || [ -z "$ADMIN_PASSWORD" ]; then
    echo -e "${RED}Error: POSTGRES_USER or POSTGRES_PASSWORD not found in .env${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Admin credentials loaded from .env${NC}"

# Function to get secret from Vault
get_secret() {
    local path=$1
    local key=$2
    local value
    value=$(vault kv get -field="$key" "$path" 2>/dev/null)

    if [ -z "$value" ]; then
        echo -e "${RED}Error: Failed to get $key from $path${NC}" >&2
        return 1
    fi

    echo "$value"
}

# Function to create user and database
create_service_db() {
    local service_name=$1
    local vault_path=$2

    echo -e "${YELLOW}Setting up database for ${service_name}...${NC}"

    # Fetch credentials from Vault
    local db_user db_password db_name
    db_user=$(get_secret "$vault_path" "db.user") || return 1
    db_password=$(get_secret "$vault_path" "db.password") || return 1
    db_name=$(get_secret "$vault_path" "db.name") || return 1

    echo -e "${YELLOW}  User: ${db_user}, Database: ${db_name}${NC}"

    # Create user and database via psql
    PGPASSWORD="$ADMIN_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$ADMIN_USER" -d "$ADMIN_DB" <<SQL
-- Create user if not exists
DO \$\$
BEGIN
    IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = '${db_user}') THEN
        CREATE USER ${db_user} WITH PASSWORD '${db_password}';
        RAISE NOTICE 'User ${db_user} created';
    ELSE
        ALTER USER ${db_user} WITH PASSWORD '${db_password}';
        RAISE NOTICE 'User ${db_user} already exists, password updated';
    END IF;
END
\$\$;

-- Create database if not exists
SELECT 'CREATE DATABASE ${db_name} OWNER ${db_user}'
WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '${db_name}');
\gexec

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE ${db_name} TO ${db_user};
SQL

    echo -e "${GREEN}  ✓ ${service_name} database setup complete${NC}"
}

# Main execution
main() {
    echo -e "${YELLOW}Checking Vault status...${NC}"
    if ! vault status > /dev/null 2>&1; then
        echo -e "${RED}Error: Cannot connect to Vault at ${VAULT_ADDR}${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Vault is accessible${NC}"

    echo -e "${YELLOW}Checking PostgreSQL connection...${NC}"
    if ! PGPASSWORD="$ADMIN_PASSWORD" psql -h "$POSTGRES_HOST" -p "$POSTGRES_PORT" -U "$ADMIN_USER" -d "$ADMIN_DB" -c "SELECT 1" > /dev/null 2>&1; then
        echo -e "${RED}Error: Cannot connect to PostgreSQL at ${POSTGRES_HOST}:${POSTGRES_PORT}${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ PostgreSQL is accessible${NC}"

    echo ""
    echo -e "${GREEN}=== Creating Service Databases ===${NC}"
    echo ""

    # Service A: secret/service-a-backend
    create_service_db "service-a" "secret/service-a-backend"

    echo ""

    # Service B: secret/service-b-backend
    create_service_db "service-b" "secret/service-b-backend"

    echo ""
    echo -e "${GREEN}=== Database Initialization Complete ===${NC}"
    echo ""
    echo -e "${YELLOW}┌─────────────────────────────────────────────────────────┐${NC}"
    echo -e "${YELLOW}│  서비스별 DB가 생성되었습니다                            │${NC}"
    echo -e "${YELLOW}│  - 이 스크립트는 최초 1회만 실행하면 됩니다             │${NC}"
    echo -e "${YELLOW}│  - PostgreSQL 볼륨이 유지되는 한 데이터가 보존됩니다    │${NC}"
    echo -e "${YELLOW}│  - 비밀번호 변경 시 다시 실행하면 업데이트됩니다        │${NC}"
    echo -e "${YELLOW}└─────────────────────────────────────────────────────────┘${NC}"
}

main
