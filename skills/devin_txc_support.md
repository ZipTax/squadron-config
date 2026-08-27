# TxC Support Issue Skill

You resolve TaxCloud customer support issues by delegating development work to Devin via `code_develop`.

## Not in scope: tax-calculation changes

A ticket whose fix would change how tax is calculated — a wrong rate, wrong reporting/filing
figures, TIC behavior, imported-order rates, a tax rule change, or the rate/exemption data behind
them — does **not** go through this skill. Those fixes need an evidence-gated diagnosis and
ratevariant A/B coverage, which the `Ratevariant A-B` mission produces
(`!rate_investigation` → `!rate-fix` → `!ratevariant-cases` → audit → `!bruno-regression`).

If you are handed one anyway, delegate the read-only classification and observation only, report
that the ticket belongs to the rate-fix flow, and do not let a fix PR be opened. A rate fix that
ships from here carries no `ratevariant` label, no cases, and no A/B — which is exactly the
failure this split exists to prevent.

What remains yours: `txcapp` API/app bugs, account and connection configuration, and tickets
whose answer is an explanation rather than a code change.

## Input

You will receive a Jira issue ID (e.g., `DEV-1234`) via the `jira_issue` parameter.

## Workflow

### 1. Determine the target repo

Use **txcapp** for API/app bugs (HTTP errors, timeouts, wrong response format, UI issues, nexus/exemption logic). Use **txc-sqlserver-database** for account/connection configuration questions and for read-only diagnosis of database behavior — not for a tax-calculation fix, which is out of scope above.

| Issue Type | Repo URL |
|---|---|
| API errors, app bugs, nexus/exemption logic, auth issues | `https://github.com/FedTax/txcapp` |
| Account/connection configuration, or read-only diagnosis of database behavior | `https://github.com/FedTax/txc-sqlserver-database` |
| Wrong tax rate, reporting data, TIC behavior, import/offline orders, tax rule changes | **not yours** — the `Ratevariant A-B` mission owns these (see above) |

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

- The `!txc-support` playbook instructs Devin to read the Jira ticket, classify the issue, investigate root cause, implement a fix, create a PR, and post a product-level summary back to Jira. Its Step 1 carries the same routing gate as above and stops before implementing on a tax-calculation ticket.
- A **tax rule change** (new TIC, rate change, exemption update, PCTA change) is a rate-flow ticket. The `!rate-fix` stage invokes the `tax-rule-change` skill there; nothing here hand-rolls one.
- SQL never goes into a Jira comment. Data-only fixes ship as a migration on a PR; the ticket gets the product-level note only.
- For incremental updates on a ticket where this skill was already run, Devin reuses the existing branch and PR.
