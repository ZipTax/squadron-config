skill "devin_code" {
  description  = "Load when you use the code_develop tool in the Devin plugin"
  instructions = <<-EOT
                # Devin Plugin Skill Guide
                
                Use the Devin plugin to delegate code development tasks to Devin AI and retrieve results.
                
                ## Workflow
                
                ### 1. Develop Code with `code_develop`
                
                Use `code_develop` to assign a development task to Devin. Devin clones the repo, implements changes, runs tests, and opens a pull request.
                
                **Required parameters:**
                - `repo_url` — full GitHub repository URL (e.g. `https://github.com/org/repo`)
                - `task` — clear description of what to implement
                
                **Optional parameters:**
                - `branch` — branch name for Devin to create (Devin picks one if omitted)
                - `instructions` — additional context, constraints, or coding guidelines
                
                **Tips for effective prompts:**
                - Be specific about what to change and where in the codebase
                - Mention coding conventions, test requirements, or files to modify
                - Reference existing patterns in the repo when relevant
                - Include acceptance criteria so Devin knows when the task is complete
                
                **Example:**
                ```json
                {
                  "repo_url": "https://github.com/org/repo",
                  "task": "Add pagination to the GET /users API endpoint using cursor-based pagination",
                  "branch": "feature/users-pagination",
                  "instructions": "Follow the existing pagination pattern used in the /orders endpoint. Add tests."
                }
                ```
                
                The response includes the session ID, status, any pull request links, and Devin's messages describing what was done. The session is archived automatically after completion.
                
                ### 2. Check a Session with `check_session`
                
                Use `check_session` to inspect a Devin session after it completes. This returns the full status, Devin's messages, pull request links, and session insights (action items, issues, timeline).
                
                **Required parameter:**
                - `session_id` — the Devin session ID returned by `code_develop`, `code_qa`, or `code_review`
                
                **Example:**
                ```json
                {
                  "session_id": "32fee96e7997499ca010301aa50eefce"
                }
                ```
                
                Use `check_session` when:
                - The `code_develop` response is missing Devin's message and you need to retrieve it
                - You want to review session insights (issues found, action items, timeline)
                - You need to check on a session that was created earlier
                
                ### 3. Interpreting Responses
                
                **Devin's Response section** — contains Devin's own summary of what it did. Use this to understand the changes and decide next steps.
                
                - If the response says "Devin returned an error in messaging", review the session directly at the provided URL
                - If the response says "Devin did not return a message", the session completed but produced no message output — continue to the next task
                
                **Session Insights section** (check_session only) — contains AI-generated analysis:
                - **Issues** — problems encountered during the session
                - **Action Items** — follow-up tasks or improvements
                - **Timeline** — key milestones and what Devin did at each stage
                
                **Pull Requests** — if Devin opened a PR, the URL and state are included in the response. Use this to review or merge the changes.
                
                ## Other Tools
                
                ### `code_qa`
                Performs a QA review of a pull request. Devin checks out the branch, runs tests, and reports bugs, coverage gaps, and regressions.
                
                ```json
                {
                  "pr_url": "https://github.com/org/repo/pull/123",
                  "instructions": "Focus on error handling and edge cases"
                }
                ```
                
                ### `code_review`
                Performs a code review of a pull request. Devin reviews the diff and posts inline comments directly on the GitHub PR.
                
                ```json
                {
                  "pr_url": "https://github.com/org/repo/pull/123",
                  "instructions": "Check for security vulnerabilities"
                }
                ```
                
                Both tools return a session ID that can be passed to `check_session` if you need to retrieve Devin's full response later.
                EOT
}

skill "devin_qa" {
  description  = "Load when you use the code_qa tool in the Devin plugin"
  instructions = <<-EOT
                  # Devin QA Review Skill Guide
                  
                  Use the Devin plugin to perform automated QA reviews of pull requests.
                  
                  ## Workflow
                  
                  ### 1. Run a QA Review with `code_qa`
                  
                  Use `code_qa` to have Devin perform a full QA review of a pull request. Devin checks out the PR branch, analyzes the changes, runs existing tests, and returns a comprehensive summary.
                  
                  **Required parameter:**
                  - `pr_url` — full GitHub pull request URL (e.g. `https://github.com/org/repo/pull/123`)
                  
                  **Optional parameter:**
                  - `instructions` — additional instructions or focus areas for the QA review
                  
                  **What Devin checks:**
                  - Bug detection, edge cases, and logic errors
                  - Error handling adequacy
                  - Test execution and failure reporting
                  - Missing test coverage for new or changed code
                  - Regression risks in related functionality
                  - Alignment with PR description and linked issues
                  - Performance concerns
                  
                  **Example:**
                  ```json
                  {
                    "pr_url": "https://github.com/org/repo/pull/123",
                    "instructions": "Focus on the new payment processing logic and verify edge cases around refunds"
                  }
                  ```
                  
                  The response includes the session ID, status, and Devin's QA findings. The session is archived automatically after completion.
                  
                  ### 2. Retrieve Results with `check_session`
                  
                  If the QA response is missing Devin's findings, use `check_session` with the session ID to retrieve the full results including messages and session insights.
                  
                  ```json
                  {
                    "session_id": "32fee96e7997499ca010301aa50eefce"
                  }
                  ```
                  
                  ### 3. Interpreting the QA Response
                  
                  **Devin's Response section** — contains Devin's QA summary with categorized findings (critical issues, warnings, suggestions, and things that look good).
                  
                  - If the response says "Devin returned an error in messaging", review the session directly at the provided URL
                  - If the response says "Devin did not return a message", the session completed but produced no message output — continue to the next task
                  
                  **Session Insights** (via `check_session`) — provides additional analysis including issues found, action items, and a timeline of what Devin reviewed.
                  
                  ## Tips for Effective QA Reviews
                  
                  - Use `instructions` to direct Devin toward areas of concern (e.g. "focus on concurrency safety" or "verify database migration rollback")
                  - For large PRs, narrow the scope with instructions like "focus on changes in the auth module"
                  - Combine with `code_review` for both QA testing and code-level review on the same PR
                  EOT
}

skill "devin_review" {
  description  = "Load when you use the code_review tool in the Devin plugin"
  instructions = <<-EOT
                 # Devin Code Review Skill Guide

                  Use the Devin plugin to perform automated code reviews of pull requests. Devin posts inline comments directly on the GitHub PR.
                  
                  ## Workflow
                  
                  ### 1. Run a Code Review with `code_review`
                  
                  Use `code_review` to have Devin review a pull request. Devin reviews every changed file, posts inline comments on the GitHub PR, and submits an overall review summary.
                  
                  **Required parameter:**
                  - `pr_url` — full GitHub pull request URL (e.g. `https://github.com/org/repo/pull/123`)
                  
                  **Optional parameter:**
                  - `instructions` — additional instructions or focus areas for the review
                  
                  **What Devin reviews:**
                  - Code quality, readability, and maintainability
                  - Correctness and potential bugs
                  - Security concerns and vulnerabilities
                  - Adherence to best practices and coding conventions
                  - Improvement suggestions
                  
                  **Example:**
                  ```json
                  {
                    "pr_url": "https://github.com/org/repo/pull/123",
                    "instructions": "Pay close attention to SQL injection risks and input validation"
                  }
                  ```
                  
                  The response includes the session ID, status, pull request links, and Devin's review summary. Inline comments are posted directly on the GitHub PR. The session is archived automatically after completion.
                  
                  ### 2. Retrieve Results with `check_session`
                  
                  If the review response is missing Devin's summary, use `check_session` with the session ID to retrieve the full results including messages and session insights.
                  
                  ```json
                  {
                    "session_id": "32fee96e7997499ca010301aa50eefce"
                  }
                  ```
                  
                  ### 3. Interpreting the Review Response
                  
                  **Devin's Response section** — contains Devin's overall review summary describing what was found across the PR.
                  
                  **Inline comments** — Devin posts detailed comments directly on the GitHub PR at specific lines. These are visible on the PR page in GitHub, not in the plugin response.
                  
                  - If the response says "Devin returned an error in messaging", review the session directly at the provided URL
                  - If the response says "Devin did not return a message", the session completed but produced no message output — check the PR on GitHub for inline comments
                  
                  **Session Insights** (via `check_session`) — provides additional analysis including issues found, action items, and a timeline of what Devin reviewed.
                  
                  ## Tips for Effective Code Reviews
                  
                  - Use `instructions` to focus on specific concerns (e.g. "check for memory leaks" or "verify error propagation")
                  - Devin posts comments directly on GitHub, so reviewers see them alongside the diff
                  - Combine with `code_qa` to get both a code review and a QA test pass on the same PR
                  - For security-focused reviews, add instructions like "focus on authentication, authorization, and input sanitization"
                  EOT

}