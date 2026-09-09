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

variable "jira_cloud_id" {
  # Which Atlassian site a Jira tool call goes to. The MCP takes either the host
  # or the site's uuid (3ba51218-aad2-443d-b43f-1125657b7505); the host is the
  # readable one. An agent left to infer this guesses hostnames until one is
  # granted, so hand it over in the brief.
  default = "taxcloud.atlassian.net"
}

variable "jira_sessions_field" {
  # The "Devin Sessions" custom field on the DEV project: one paragraph per Devin
  # session that worked a ticket, `<stage tag>: <session url>`. It is a rich-text
  # textarea, so it reads back as ADF rather than a plain string.
  #
  # Override with `squadron vars set jira_sessions_field customfield_NNNNN` if the
  # field is ever rebuilt — a field id that does not exist reads as an absent field,
  # silently.
  default = "customfield_11724"
}

variable "ratevariant_webhook_secret" {
  secret = true  # Shared secret for the /ratevariant mission webhook
}
