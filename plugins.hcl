plugin "devin" {
  source = "github.com/FedTax/squadron-plugin-devin"
  version = "v0.0.6"
  settings {
    api_key              = vars.devin_api_key
    org_id               = vars.devin_org_id
    poll_timeout_minutes = "240"
    archive_on_complete  = "false"
  }
}

plugin "shell" {
  source  = "github.com/mlund01/plugin_shell"
  version = "v0.0.1"
  settings = {
    mode  = "local"
    shell = "bash" 
  }
}