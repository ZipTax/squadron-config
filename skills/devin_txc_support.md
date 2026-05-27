# TxC Support Issue Skill

You resolve TaxCloud customer support issues by delegating development work to Devin via `code_develop`.

## Input

You will receive a Jira issue ID (e.g., `DEV-1234`) via the `jira_issue` parameter.

## Workflow

### 1. Determine the target repo

Most TaxCloud support issues involve tax rate, reporting, TIC, or data problems — these live in **txc-sqlserver-database**. Only use **txcapp** if the issue is clearly an API/app bug (HTTP errors, timeouts, wrong response format, UI issues, nexus/exemption logic).

| Issue Type | Repo URL |
|---|---|
| Wrong tax rate, reporting data, TIC behavior, import/offline orders, tax rule changes | `https://github.com/FedTax/txc-sqlserver-database` |
| API errors, app bugs, nexus/exemption logic, auth issues | `https://github.com/FedTax/txcapp` |

If you are unsure which repo applies, default to `https://github.com/FedTax/txc-sqlserver-database`.

### 2. Send to Devin via `code_develop`

Call `code_develop` with the following parameters:

- **`repo_url`**: The target repo URL from step 1
- **`task`**: `"Create a new PR for issue {jira_issue} using playbook !txc-support"`
- **`branch`**: `"fix/{jira_issue}"` (e.g., `fix/DEV-1234`)

Example call for a tax rate issue:

```
code_develop(
  repo_url:  "https://github.com/FedTax/txc-sqlserver-database",
  task:      "Create a new PR for issue DEV-1234 using playbook !txc-support",
  branch:    "fix/DEV-1234"
)
```

Example call for an API/app bug:

```
code_develop(
  repo_url:  "https://github.com/FedTax/txcapp",
  task:      "Create a new PR for issue DEV-5678 using playbook !txc-support",
  branch:    "fix/DEV-5678"
)
```

### 3. Monitor the session

After `code_develop` returns, review the result. If the session is still running or you need more detail, use `check_session` with the returned session ID to get the current status, PR links, and Devin's messages.

### 4. Report results

Summarize the outcome:
- Link to the PR Devin created (if any)
- Whether Devin posted a Jira comment with the analysis
- Any open questions or issues Devin flagged
- If the session failed, include the error details

## Notes

- The `!txc-support` playbook instructs Devin to read the Jira ticket, classify the issue, investigate root cause, implement a fix, create a PR, and post a structured summary back to Jira.
- If Devin identifies the issue as a **tax rule change** (new TIC, rate change, exemption update), it will automatically delegate to the `tax-rule-change` skill internally.
- If the issue requires no code changes (data-only fix), Devin will post the SQL statements to Jira instead of creating a PR.
- For incremental updates on a ticket where this skill was already run, Devin reuses the existing branch and PR.
