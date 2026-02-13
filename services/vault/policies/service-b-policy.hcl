# Policy for service-b-backend
# Allows read access to service-b specific secrets

# KV v2 secrets access
path "secret/data/service-b-backend" {
  capabilities = ["read"]
}

path "secret/data/service-b-backend/*" {
  capabilities = ["read", "list"]
}

# Metadata access (for listing)
path "secret/metadata/service-b-backend" {
  capabilities = ["read", "list"]
}

path "secret/metadata/service-b-backend/*" {
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
