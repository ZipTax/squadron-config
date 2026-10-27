# Install a compatible thread-aware gateway locally before enabling this workflow.
gateway "slack" {
  source  = "github.com/mlund01/squadron-gateway-slack"
  version = "local"
  settings = {
    bot_token       = vars.slack_bot_token
    app_token       = vars.slack_app_token
    channel_id      = vars.slack_channel_id
    checkpoint_path = "${path.cwd}/.squadron/slack-gateway.json"
  }
}
