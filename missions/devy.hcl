mission "Dev'y" {
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

  agents = [agents.CodeGen, agents["Quality Assurance"], agents["Peer Review"]]

  # ---------------------------------------------------------------------------
  # Inputs — mapped to Devin code_develop parameters
  # ---------------------------------------------------------------------------

  input "repo_url" {
    type        = "string"
    description = "Full URL of the GitHub repository (e.g. https://github.com/org/repo)"
  }

  input "branch" {
    type        = "string"
    description = "Branch name for Devin to create. If omitted, Devin chooses an appropriate name."
    default     = ""
  }

  input "base_branch" {
    type        = "string"
    description = "Target branch the PR will merge into"
    default     = "stage"
  }

  input "issue" {
    type        = "string"
    description = "Linear issue ID"
  }

  # ---------------------------------------------------------------------------
  # Task 1 — CodeGen: use Devin code_develop to implement changes and open PR
  # ---------------------------------------------------------------------------

  task "develop" {
    objective = <<-EOT
      Use the code_develop and check_session tools from the Devin plugin to 
      implement the development task described below.

      Repository: ${inputs.repo_url}
      Branch: ${inputs.branch}
      Base branch: The pull request must target the "${inputs.base_branch}" branch as the base.

      Linear Issue Number: ${inputs.issue}

      Use the linear MCP  tool `getIssue` to pull in the Linear issue details 
      for the issue number input. 

      Check for documents on the Linear Issue and pull in the full document contents
      as Markdown. 

      If you see a document named "Technical Spec" this is a full development design spec. 
      Use this to inform the agent development. 

      Send the full details of the Linear Issue and documents to Devin for development. 

      Devin will create the branch if it doesn't already exist (check every time), 
      implement the changes if needed,
      and open a pull request if one does not already exist (check every time).
    
      Once Devin completes, return the PR URL, PR number, and the exact
      branch name from its response along with a summary of what was developed.

      Use check_session from the Devin plugin to check the session 
      messages and insights after each run. 

      Move to the next step in this mission when complete. 
    EOT
    agents = [agents.CodeGen]

    output {
      field "pr_url" {
        type        = "string"
        description = "Full URL of the created pull request"
        required    = true
      }
      field "pr_number" {
        type        = "number"
        description = "Pull request number"
        required    = true
      }
      field "branch" {
        type        = "string"
        description = "Exact branch name that Devin created or pushed to"
        required    = true
      }
      field "development_summary" {
        type        = "string"
        description = "Summary of all code changes made"
        required    = true
      }
    }
  }

  # ---------------------------------------------------------------------------
  # Task 2 — QA cycle: commander loops QA ↔ CodeGen until QA passes
  # ---------------------------------------------------------------------------

  task "qa_cycle" {
    objective = <<-EOT
      Manage the QA review cycle for the pull request. The PR URL, PR
      number, and branch name are available from the `develop` task output.

      Repeat the following loop until QA passes:

      1. Call the "Quality Assurance" agent and instruct it to run a full QA
         review on the PR using its Devin code_qa tool. Tell it to focus on:
         correctness, logic errors, test coverage gaps, edge cases, error
         handling, regressions, security vulnerabilities, and performance.
         Devin will post its findings as comments on the PR in GitHub.

      2. Evaluate the QA agent's report. If the code PASSES QA, exit the loop
         and complete this task.

      3. If fixes are required, call the "CodeGen" agent to apply ONLY the
         specific fixes identified by QA — do NOT re-implement the original
         development task. Instruct it to use its code_develop tool with:
         - repo_url: ${inputs.repo_url}
         - task: ONLY the specific fixes needed from the QA report. Do NOT
           repeat the original development task description.
         - branch: the exact branch name from the `develop` task output
           so Devin pushes fixes to the EXISTING branch
         - instructions: Tell Devin this is an incremental fix on an existing
           branch and PR — it must NOT create a new branch, must NOT
           re-implement prior work, and must ONLY address the specific QA
           findings listed in the task. Reference the PR URL for context.

      4. After CodeGen confirms the fixes are pushed, go back to step 1 and
         request another QA review.

      IMPORTANT: When calling CodeGen for fixes, you must be precise. Only
      describe the specific issues that need fixing. Never include the original
      development task description — that work is already complete on the branch.

      Continue this cycle until the QA agent confirms the code passes review.
      Track how many review cycles were needed and summarize all findings.

      Use check_session from the Devin plugin to check the session messages and insights after each run. 

      Move to the next step in this mission when complete. 
    EOT
    agents = [agents.CodeGen, agents["Quality Assurance"]]

    output {
      field "qa_passed" {
        type        = "boolean"
        description = "Whether QA ultimately passed"
        required    = true
      }
      field "review_cycles" {
        type        = "number"
        description = "Number of QA review cycles completed"
        required    = true
      }
      field "qa_summary" {
        type        = "string"
        description = "Cumulative summary of all QA findings and fixes across every cycle"
        required    = true
      }
    }

    depends_on = [tasks.develop]
  }

  # ---------------------------------------------------------------------------
  # Task 3 — Peer review cycle: commander loops Review ↔ CodeGen until clean
  # ---------------------------------------------------------------------------

  task "review_cycle" {
    objective = <<-EOT
      Manage the peer review cycle for the pull request. The PR URL and
      branch name are available from prior task outputs.

      Repeat the following loop until the peer review passes:

      1. Call the "Peer Review" agent and instruct it to run a full code review
         on the PR using its Devin code_review tool. Tell it to focus on:
         correctness, maintainability, security, alignment with codebase
         conventions, architecture, documentation, API design, and error
         handling. Devin will post structured review comments on the PR in
         GitHub (summary verdict, inline findings, recommended next steps).

      2. Evaluate the Peer Review agent's report. If the PR is CLEAN, exit the
         loop and complete this task.

      3. If changes are required, call the "CodeGen" agent to apply ONLY the
         specific changes identified by the review — do NOT re-implement the
         original development task. Instruct it to use its code_develop tool with:
         - repo_url: ${inputs.repo_url}
         - task: ONLY the specific changes needed from the review report. Do NOT
           repeat the original development task description.
         - branch: the exact branch name from prior task outputs so Devin pushes
           fixes to the EXISTING branch
         - instructions: Tell Devin this is an incremental fix on an existing
           branch and PR — it must NOT create a new branch, must NOT
           re-implement prior work, and must ONLY address the specific review
           findings listed in the task. Reference the PR URL for context.

      4. After CodeGen confirms the fixes are pushed, go back to step 1 and
         request another peer review.

      IMPORTANT: When calling CodeGen for fixes, you must be precise. Only
      describe the specific issues that need fixing. Never include the original
      development task description — that work is already complete on the branch.

      Continue this cycle until the Peer Review agent confirms the PR is clean.
      Track how many review cycles were needed and summarize all findings.

      Use check_session from the Devin plugin to check the session messages and insights after each run. 

      Move to the next step in this mission when complete. 
    EOT
    agents = [agents.CodeGen, agents["Peer Review"]]

    output {
      field "review_passed" {
        type        = "boolean"
        description = "Whether peer review ultimately passed"
        required    = true
      }
      field "review_cycles" {
        type        = "number"
        description = "Number of peer review cycles completed"
        required    = true
      }
      field "review_summary" {
        type        = "string"
        description = "Cumulative summary of all peer review findings and fixes across every cycle"
        required    = true
      }
    }

    depends_on = [tasks.qa_cycle]
  }

  # ---------------------------------------------------------------------------
  # Task 4 — Mission complete: compile final report
  # ---------------------------------------------------------------------------

  task "complete" {
    objective = <<-EOT
      The autonomous development mission is complete. The pull request has
      passed both QA review and peer review.

      Compile a final summary that includes:
      - What was developed (based on the original task)
      - Number of QA review cycles and key findings
      - Number of peer review cycles and key findings
      - All fixes applied across every review cycle
      - Final PR URL ready for human review and merge
    EOT

    output {
      field "final_summary" {
        type        = "string"
        description = "Complete summary of the entire development mission"
        required    = true
      }
      field "pr_url" {
        type        = "string"
        description = "URL of the PR ready for human review"
        required    = true
      }
    }

    depends_on = [tasks.review_cycle]
  }
}
