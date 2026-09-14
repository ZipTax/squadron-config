storage {
  backend = "sqlite"
}

mcp_host {
  enabled = true
  port    = 8090
  secret  = vars.mcp_host_secret
}
