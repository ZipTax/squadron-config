storage {
  backend = "sqlite"
}

mcp_host {
  enabled = true
  port    = 8090
  secret  = vars.mcp_host_secret
}

gateway "slack" {
  source  = "github.com/mlund01/squadron-gateway-slack"
  version = "v0.0.2"

  settings = {
    bot_token       = vars.slack_bot_token
    app_token       = vars.slack_app_token
    channel_id      = vars.slack_channel_id
    checkpoint_path = ".squadron/slack-gateway.json"
    mcp_url         = "http://localhost:8090/mcp"
    mcp_token       = vars.mcp_host_secret
    threads         = <<-EOT
      {
        "rate_triage":   {"key": "{{.issue}}", "title": "{{.issue}}: rate ticket"},
        "rate_fix":      {"key": "{{.issue}}", "title": "{{.issue}}: rate ticket"},
        "rate_finalize": {"key": "{{.issue}}", "title": "{{.issue}}: rate ticket"}
      }
    EOT
  }
}
