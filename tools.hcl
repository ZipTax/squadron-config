# Bind credentials here so the agent supplies blocker data, never an authentication header.
tool "save_rate_blocker" {
  implements = builtins.http.post
  description = "Register a human wait or resolve its exact generation. Retries preserve the same payload."
  inputs {
    field "blocker" {
      type = "object"
      description = "Blocker record defined by the bridge skill: identity, generation, state, Jira references, and resume target/inputs."
      required = true
    }
  }
  url = "${vars.bridge_url}/blockers"
  headers = {
    Authorization = "Bearer ${vars.bridge_registration_token}"
    "Content-Type" = "application/json"
  }
  body = inputs.blocker
}
