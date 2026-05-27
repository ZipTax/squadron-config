mission "Fellow>>Linear" {
  commander {
    model = models.anthropic.claude_opus_4_7

    compaction {
      token_limit    = 1000000
      turn_retention = 3
    }

    tool_response {
      max_tokens = 1000000
    }
  }

  agents = [agents["Claude Code Routines"]]

  # ---------------------------------------------------------------------------
  # Inputs
  # ---------------------------------------------------------------------------

  input "fellow_meeting_link" {
    type        = "string"
    description = "Fellow meeting URL i.e. the 'share' link"
  }

  input "linear_issue" {
    type        = "string"
    description = "Linear issue number. e.g. ZIP-123"
  }

  # ---------------------------------------------------------------------------
  # Tasks
  # ---------------------------------------------------------------------------

  task "trigger_routine" {
    objective = <<-EOT
      This task requires triggerring a Claude Code Routine with the following 
      POST configuration. 

      curl -X POST https://api.anthropic.com/v1/claude_code/routines/${vars.claude_routine_trigger_id}/fire \
        -H "Authorization: Bearer ${vars.claude_routine_fellow_key}" \
        -H "anthropic-beta: experimental-cc-routine-2026-04-01" \
        -H "anthropic-version: 2023-06-01" \
        -H "Content-Type: application/json" \
        -d '{"text": "Update Linear issue ${inputs.linear_issue}"} with the context from Fellow ${inputs.fellow_meeting_link}"}' 

    
    EOT
    agents = [agents["Claude Code Routines"]]
  }
}