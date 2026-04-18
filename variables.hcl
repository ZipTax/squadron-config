variable "anthropic_api_key" {
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