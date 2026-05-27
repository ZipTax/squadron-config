mission "TaxCloud Support" {
  commander {
    model = models.anthropic.claude_opus_4_7

    compaction {
      token_limit    = 250000
      turn_retention = 3
    }

    tool_response {
      max_tokens = 250000
    }
  }

  agents = [agents.CodeGen]

  input "issue" {
    type        = "string"
    description = "Jira issue ID"
  }

  task "Get Linear Ticket Details" {
    objective = <<-EOT
      You have been given Jira issue ${inputs.issue}.

      Use the devin_txc_playbook skill to resolve this support issue. Call code_develop with:
      - repo_url: "https://github.com/FedTax/txc-sqlserver-database" (default for tax rate, reporting, TIC, and data issues) or "https://github.com/FedTax/txcapp" (for API/app bugs)
      - task: "Create a new PR for issue ${inputs.issue} using playbook !txc-support"
      - branch: "fix/${inputs.issue}"

      Monitor the Devin session with check_session and report the outcome including any PR links, Jira comments posted, and open questions.
    EOT
    agents = [agents["TaxCloud Support Engineer"]]
  }
}