#!/bin/sh
# auto-unseal.sh - Starts Vault server and auto-unseals
# Unseal keys are read from environment variables (set via .env)

# Fix data directory permissions so vault user (UID 100, GID 1000) can write
# Docker named volumes are created as root:root by default
chown -R 100:1000 /vault/data 2>/dev/null || true
chmod 750 /vault/data 2>/dev/null || true

# Start vault server as vault user (UID 100) using su-exec
su-exec vault vault server -config=/vault/config &
VAULT_PID=$!

# Wait for Vault to be reachable, then unseal
for i in $(seq 1 30); do
  sleep 1
  # exit 0 = unsealed, exit 2 = sealed, exit 1 = not ready
  vault status -address=http://localhost:8200 > /dev/null 2>&1
  rc=$?

  if [ $rc -eq 0 ]; then
    echo "Vault is already unsealed"
    break
  elif [ $rc -eq 2 ]; then
    echo "Vault is sealed. Unsealing..."
    vault operator unseal -address=http://localhost:8200 "$VAULT_UNSEAL_KEY_1" > /dev/null 2>&1 || true
    vault operator unseal -address=http://localhost:8200 "$VAULT_UNSEAL_KEY_2" > /dev/null 2>&1 || true
    vault operator unseal -address=http://localhost:8200 "$VAULT_UNSEAL_KEY_3" > /dev/null 2>&1 || true
    if vault status -address=http://localhost:8200 > /dev/null 2>&1; then
      echo "Vault unsealed successfully"
      break
    fi
  fi
  echo "Waiting for Vault to start... ($i/30)"
done

# Keep container running with vault server process
wait $VAULT_PID
