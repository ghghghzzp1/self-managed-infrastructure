ui = true
disable_mlock = true

storage "file" {
  path = "/vault/data"
}

listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = 1  # Phase 5+: Enable TLS in production
}

api_addr = "http://0.0.0.0:8200"
