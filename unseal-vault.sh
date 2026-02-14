#!/bin/bash
# unseal-vault.sh - Manual Vault unseal script
# Reads VAULT_UNSEAL_KEY_1/2/3 from .env and unseals Vault
#
# Usage: ./unseal-vault.sh
# Prerequisites: Add to .env:
#   VAULT_UNSEAL_KEY_1=<key1>
#   VAULT_UNSEAL_KEY_2=<key2>
#   VAULT_UNSEAL_KEY_3=<key3>

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"

# Load .env
if [ ! -f "$ENV_FILE" ]; then
  echo "Error: .env file not found at $ENV_FILE"
  exit 1
fi

source "$ENV_FILE"

# Validate unseal keys exist
if [ -z "$VAULT_UNSEAL_KEY_1" ] || [ -z "$VAULT_UNSEAL_KEY_2" ] || [ -z "$VAULT_UNSEAL_KEY_3" ]; then
  echo "Error: VAULT_UNSEAL_KEY_1, VAULT_UNSEAL_KEY_2, and VAULT_UNSEAL_KEY_3 must be set in .env"
  exit 1
fi

echo "Waiting for Vault container to be ready..."

for i in $(seq 1 15); do
  # Check if Vault container is running
  if ! docker exec vault vault status -address=http://localhost:8200 -format=json > /dev/null 2>&1; then
    # vault status exit codes: 0=unsealed, 1=error, 2=sealed
    EXIT_CODE=$(docker exec vault vault status -address=http://localhost:8200 -format=json > /dev/null 2>&1; echo $?)

    if [ "$EXIT_CODE" -eq 2 ]; then
      echo "Vault is sealed. Unsealing... (attempt $i/15)"
      docker exec vault vault operator unseal -address=http://localhost:8200 "$VAULT_UNSEAL_KEY_1" > /dev/null 2>&1 || true
      docker exec vault vault operator unseal -address=http://localhost:8200 "$VAULT_UNSEAL_KEY_2" > /dev/null 2>&1 || true
      docker exec vault vault operator unseal -address=http://localhost:8200 "$VAULT_UNSEAL_KEY_3" > /dev/null 2>&1 || true

      if docker exec vault vault status -address=http://localhost:8200 > /dev/null 2>&1; then
        echo "Vault unsealed successfully!"
        exit 0
      fi
    elif [ "$EXIT_CODE" -eq 1 ]; then
      echo "Vault container not ready yet... ($i/15)"
    fi
  else
    echo "Vault is already unsealed!"
    exit 0
  fi

  sleep 2
done

echo "Error: Failed to unseal Vault after 15 attempts"
exit 1
