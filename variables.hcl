variable "anthropic_api_key" {
  secret = true  # Mask value in output
}

variable "claude_routine_fellow_key" {
  secret = true  # Mask value in output
}

variable "claude_routine_trigger_id" {
  secret = true  # Mask value in output
}

variable "devin_api_key" {
  secret = true  # Mask value in output — service user token (cog_ prefix)
}

variable "github_token" {
  secret = true  # GitHub personal access token for API operations
}

variable "linear_token" {
  secret = true
}

variable "devin_org_id" {
  secret = true
}

variable "jira_sessions_field" {
  # The "Devin Sessions" custom field on the DEV project: one line per Devin
  # session that worked a ticket, `<stage tag>: <session url>`. Override with
  # `squadron vars set jira_sessions_field customfield_NNNNN` — the default is a
  # placeholder, and a field id that does not exist reads as an absent field.
  default = "customfield_XXXXX"
}

variable "ratevariant_webhook_secret" {
  secret = true  # Shared secret for the /ratevariant mission webhook
}
