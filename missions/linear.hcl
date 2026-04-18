mission "Linear Ticket Info" {
  commander {
    model = models.anthropic.claude_opus_4_6

    compaction {
      token_limit    = 250000
      turn_retention = 3
    }

    tool_response {
      max_tokens = 250000
    }
  }

  agents = [agents.CodeGen, agents["Quality Assurance"], agents["Peer Review"]]

  # ---------------------------------------------------------------------------
  # Inputs — mapped to Devin code_develop parameters
  # ---------------------------------------------------------------------------

  input "issue" {
    type        = "string"
    description = "Linear issue ID"
  }


  # ---------------------------------------------------------------------------
  # Task 1 — CodeGen: use Devin code_develop to implement changes and open PR
  # ---------------------------------------------------------------------------

  task "Get Linear Ticket Details" {
    objective = <<-EOT
      Linear Issue Number: ${inputs.issue}

      Use the linear MCP  tool `getIssue` to pull in the Linear issue details 
      for the issue number input. 

      Check for documents on the Linear Issue and pull in the full document contents
      as Markdown. 

      If you see a document named "Technical Spec" this is a full development design spec. 
      Use this to build a full development design spec. 

    EOT
    agents = [agents["Linear"]]

    output {
      field "Issue Title" {
        type        = "string"
        description = "Title of the issue"
        required    = true
      }
      field "Issue Description" {
        type        = "string"
        description = "Full issue description"
        required    = false
      }
      field "Comments" {
        type        = "string"
        description = "Full comment thread"
        required    = false
      }
      field "Documents" {
        type        = "string"
        description = "Full document content as markdown"
        required    = false
      }
      field "Technical Spec" {
        type        = "string"
        description = "Full development design spec"
        required    = false
      }
    }
  }
}