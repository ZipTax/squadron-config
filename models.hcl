model "anthropic" {
  provider       = "anthropic"
  allowed_models = ["claude_sonnet_4", "claude_sonnet_4_6", "claude_3_5_haiku", "claude_haiku_4_5", "claude_opus_4", "claude_opus_4_6"]
  aliases = {
    claude_opus_4_7 = "claude-opus-4-7"
  }
  api_key        = vars.anthropic_api_key
}