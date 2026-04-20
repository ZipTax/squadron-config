plugin "devin" {
  source = "github.com/ericlakich/squadron-plugin-devin"
  version = "v0.0.2"
  settings {
    api_key              = vars.devin_api_key
    org_id               = vars.devin_org_id
    poll_timeout_minutes = "240"
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