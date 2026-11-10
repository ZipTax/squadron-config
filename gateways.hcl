gateway "slack" {
  source  = "github.com/mlund01/squadron-gateway-slack"
  version = "v0.0.3"
  settings = {
    bot_token       = vars.slack_bot_token
    app_token       = vars.slack_app_token
    channel_id      = vars.default_slack_channel_id
    mcp_url         = "http://localhost:8090/mcp"
    mcp_token       = vars.mcp_host_secret
    checkpoint_path = "./.squadron/slack-gateway.json"
  }
}
