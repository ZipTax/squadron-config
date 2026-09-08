## Overview

Playbook for investigating TaxCloud customer support issues. You will pull details from a Jira ticket, investigate the likely cause using the `txc-sqlserver-database` and/or `txcapp` repos, propose a fix, QA your changes, open a PR carrying the full detail, and post a brief product-level update back to Jira. You diagnose and propose; a human decides what is a bug and what ships.

> **Tax-calculation changes are not in this playbook's scope.** Anything whose fix would change how tax is calculated — a wrong rate, wrong reporting/filing figures, TIC behavior, imported-order rates, or the rate/exemption data behind them — goes through the staged rate-fix flow instead (`!rate_investigation` → `!rate-fix` → `!ratevariant-cases` → audit → `!bruno-regression`), because those changes require an evidence-gated diagnosis and ratevariant A/B coverage that a single diagnose-and-fix session cannot produce. See Step 1. This playbook keeps the API/app, account, configuration, and "explain the behavior" work.

## MANDATORY: SQL Identifiers — One Convention

Mixing database-relative and three-part identifiers has repeatedly caused statements to execute against the wrong database and **corrupt data**. There is exactly one convention, it is not a judgment call, and it applies to every statement you write:

> **Every SQL artifact is scoped to exactly one database. Inside it, every object reference is two-part `[dbo].[Object]`. Three-part `[Database].[dbo].[Object]` appears only for a reference that genuinely crosses into the other database.**

This is the convention the schema dump under `output/schema/` already uses — `CREATE PROCEDURE [dbo].[spGenerateTransactionsWide]`, with `[FedTax].[dbo].[States]` appearing inside Reports procs only because it has to. Follow it so your SQL matches the code around it and produces no diff noise.

### Declare the scope, every time

Two-part names are only safe because the scope is unambiguous, so the scope must always be stated. How depends on the artifact:

| Artifact | How the scope is declared |
|---|---|
| Proc/function definitions under `output/schema/` | The schema folder it lives in: `fedtax-prod/` → FedTax, `reports-prod/` → Reports. Never add a `USE`. |
| Migration / ALTER / INSERT / UPDATE scripts, and any diagnostic or verification query you hand to a person to run | A `USE [<database>]; GO` header as the first line of the script. |
| `sqlprobe` probes | The `PROBE_DB` environment variable. |

```sql
USE [FedTax];   -- or the staging copy, e.g. USE [FedTax-20260521];
GO

SELECT stm.[State], stm.[TIC], stm.[Rate]
FROM [dbo].[StatesTaxMatrix] AS stm WITH (NOLOCK)
JOIN [dbo].[TICs] AS t WITH (NOLOCK) ON t.[TIC] = stm.[TIC]
WHERE stm.[State] = 42;
```

That header is the one line a human edits to retarget the whole script — there are no identifiers to find-and-replace.

### Rules

- **One database per artifact.** If a diagnostic needs data from both, deliver two scripts, each with its own header. Never write a script whose statements assume different scopes.
- **Never omit the scope.** A script without a `USE` header, or a probe without `PROBE_DB`, is a statement waiting to hit the wrong database. Never rely on a connection's default database.
- **Never write a bare reference** (`StatesTaxMatrix`) — always at least `[dbo].[StatesTaxMatrix]`.
- **Cross-database references are the only three-part names you write.** A `[Reports]` proc calling `[FedTax].[dbo].[fnGetTaxRatesforTx]` cannot be expressed two-part. Use the canonical database name — `[FedTax]` or `[Reports]` — and **never** a versioned staging name like `FedTax-20260521`; ratebench rewrites the canonical name to whichever copy it is targeting.
- In a script, prefer restructuring to avoid a cross-database reference; when one is unavoidable, note it in a comment above the statement so the runner knows the script reaches outside its scope.
- Bracket every identifier, alias every table, and prefix every column with its alias.
- When quoting existing proc/function code, keep the quote verbatim rather than restyling it.

Before committing SQL or handing over a script, re-read it and confirm the scope is declared once at the top and every reference is two-part except deliberate cross-database calls.

## Key Terminology: Merchant IDs vs Connection IDs

Understanding these identifiers is critical — confusing them will lead you to investigate the wrong account entirely.

| Term | DB Column | Format | Scope | Description |
|---|---|---|---|---|
| **Merchant ID** | FedTax `dbo.Merchants.MerchantID`, `dbo.URLs.MerchantID` | Numeric | Per merchant | Identifies the merchant/account. **Jira ticket titles will nearly always contain Merchant IDs.** |
| **URL ID** | FedTax `dbo.URLs.ID` | Numeric | Per connection | Identifies a specific connection/store. A merchant can have MULTIPLE connections. |
| **Connection ID** / **API Key** | FedTax `dbo.URLs.APIKey` | UUID | Per connection | The API key string for a connection. Synonymous with "Connection ID" or "API Login". |

**Critical rules:**
- A **Merchant** can have **multiple Connections** (URLs). Do NOT assume a numeric ID from a Jira ticket is a URL ID — it is almost always a Merchant ID.
- When a ticket title or description mentions a numeric ID, treat it as a **Merchant ID** unless explicitly stated otherwise.
- To query by Merchant ID: filter `m.[MerchantID] = <id>` directly on `[dbo].[Merchants]`, `[dbo].[SSTExcludedState]`, `[dbo].[Locations]`, etc. (all in FedTax).
- To query by URL/Connection ID: filter `u.[ID] = <id>` on `[dbo].[URLs]` with a JOIN to get the MerchantID.
- If the ticket mentions a UUID, that's a **Connection ID / API Key**.
- The results may show duplicates (one row per connection) when querying by MerchantID on tables that JOIN to `[dbo].[URLs]` — this is expected for merchants with multiple connections.

## Step 0: Read the Jira ticket

Use the Atlassian MCP integration to pull the full ticket into context. The Jira cloudId is `taxcloud.atlassian.net`.

```
getJiraIssue(
  cloudId: "taxcloud.atlassian.net",
  issueIdOrKey: "<TICKET_KEY>",
  fields: ["summary", "description", "status", "assignee", "comment", "attachment", "priority", "labels", "issuetype"],
  responseContentFormat: "markdown"
)
```

Extract ALL of the following:
- **Summary**: one-line description of the problem
- **Affected merchant/account**: any IDs mentioned. Numeric IDs in ticket titles are nearly always **Merchant IDs** (see Key Terminology above). UUIDs are Connection IDs / API Keys.
- **Affected states/jurisdictions**: state names, FIPS codes, zip codes
- **Affected TICs**: TIC IDs, product descriptions
- **Transaction IDs or order IDs**: specific transactions cited as examples
- **Expected vs actual behavior**: what the customer expected and what happened
- **Dates**: when the issue started, any effective dates, transaction dates
- **Attachments**: download any `.xlsx`, `.csv`, `.tsv`, `.txt` attachments — these often contain the **authoritative data** about the problem

Also read all **comments** on the ticket for follow-up context, clarifications, or data added after the initial report.

> **Attachments are ground truth.** If the ticket has an attachment showing specific orders or states, those are the exact cases to investigate — not a subset you infer from the description. Do not narrow or expand the scope beyond what the ticket and its attachments explicitly describe. If an attachment shows a PA order, investigate PA — don't go off on a tangent about DC or other states just because they appear in related data. Stay focused on the reported problem.

## Step 1: Classify the issue

Determine which category the support issue falls into. This determines your repo and investigation path:

| Category | Symptoms | Primary Repo | Starting Point |
|---|---|---|---|
| **Wrong tax rate** | Cart tax is incorrect, rate mismatch | `txc-sqlserver-database` | Debugging checklist (see Step 2) |
| **Wrong reporting/filing data** | Cart was correct but reports show different rates | `txc-sqlserver-database` | Reports DB ETL path |
| **Missing/wrong TIC behavior** | TIC not taxed correctly, new TIC needed | `txc-sqlserver-database` | StatesTaxMatrix + PCTA tables |
| **Tax rule change request** | State changed a rate, new exemption, new TIC | `txc-sqlserver-database` | **Delegate to the `tax-rule-change` skill** |
| **API error or app bug** | HTTP errors, timeouts, wrong API response format, UI issues | `txcapp` | Relevant service in `cmd/` |
| **Import/offline order issue** | Imported orders have wrong rates | `txc-sqlserver-database` | Reports DB functions only (imports skip cart calc) |
| **Nexus/exemption issue** | Tax collected in wrong states, exemption not applied | `txcapp` | `biz/` business logic layer |

### Routing gate — apply before Step 2

The first four rows above (wrong tax rate, wrong reporting/filing data, TIC behavior, tax rule
change) and imported-order rates are **out of scope for this playbook's fix path**. Their
fixes edit tax-calculation procs/functions or rate/exemption data, which must ship with a
proven cause and ratevariant A/B coverage.

For those tickets: investigate read-only as far as the evidence takes you, then **stop before
implementing**. Report the classification, what you observed, and hand off to the staged flow
(`!rate_investigation` for the evidence-only diagnosis; the squadron `ratevariant_ab`
mission drives the rest). Post the product-level Jira update per Step 6 if nobody else has,
and say the ticket has been routed to the rate-fix flow. Do not open a proc/data PR, and do
not invoke `tax-rule-change` to generate scripts — the `!rate-fix` stage owns that.

Continue through Steps 2-6 as written for API/app bugs, nexus/exemption behavior in `txcapp`,
account/connection configuration, and any ticket whose answer is an explanation rather than a
tax-calculation change.

> **v1 SOAP API issues**: The v1 API is handled by `svTaxAPI` (or similar), NOT `txcapp`. If the issue involves the legacy SOAP/v1 API, look at the database-level stored procedures (FedTax `dbo.spTransactionLookup`, etc.) rather than `txcapp`.

## Step 2: Investigate the root cause

### For `txc-sqlserver-database` issues (most cases)

Start by reading these documentation files for context:
- `docs/tax-calculation-architecture.md` — the 6 tax calculation code paths, SSUTA vs non-SSUTA routing
- `docs/debugging-tax-calculations.md` — debugging checklist, sample queries, common bug sources
- `docs/tax-code-reference.md` — state overrides, TIC special handling, PCTA, function dependencies
- `CLAUDE.md` — project overview and debugging quick-start

Also use the repo wiki (`read_wiki_contents` for `FedTax/txc-sqlserver-database`) for deeper architectural understanding — especially the "Debugging Tax Calculations" and "Tax Rules and State-Specific Logic" sections.

#### Debugging workflow

**A) Determine SSUTA vs non-SSUTA routing**

Check `docs/tax-calculation-architecture.md` for the full list of non-SSUTA states. This determines which code path to examine.

**B) Determine where the bug manifests**

- **Cart tax is wrong** → bug is in FedTax layer:
  - SSUTA: FedTax `dbo.spTransactionLookup` → `dbo.fnGetTaxRatesforTx`
  - Non-SSUTA: FedTax `dbo.spTransactionLookup_nonssuta` (calculates rates inline — does NOT call `fnGetTaxRatesforTx_nonssuta`)
- **Reporting/filing data is wrong but cart was correct** → bug is in Reports DB ETL:
  - SSUTA: Reports `dbo.spGenerateTransactionsWide` → `[FedTax].[dbo].[fnGetTaxRatesforTx]` (a genuine cross-database call)
  - Non-SSUTA: Reports `dbo.spGenerateTransactionsWide_nonssuta` → `dbo.fnGetTaxRatesforTx_nonssuta`
- **Imported orders are wrong** → rates are only calculated in Reports DB ETL (imports skip cart calc entirely). Start with the Reports functions.

**C) Check for logic drift (non-SSUTA states)**

For non-SSUTA states, the cart calculation (inline in FedTax `dbo.spTransactionLookup_nonssuta`) and ETL recalculation (Reports `dbo.fnGetTaxRatesforTx_nonssuta`) are **separate implementations**. If cart rates are correct but reporting rates differ, logic drift between these two is the most likely cause.

**D) Read the relevant schema files**

Always use **prod** schemas first (`output/schema/fedtax-prod/`, `output/schema/reports-prod/`). Key files:
- Stored procedures: `output/schema/fedtax-prod/dbo/StoredProcedures/`
- Functions: `output/schema/fedtax-prod/dbo/Functions/` and `output/schema/reports-prod/dbo/Functions/`
- Table definitions: `output/schema/fedtax-prod/dbo/Tables/`

Search for the state's FIPS code and relevant TICs in the SP/function code to understand the current logic. The schema folder tells you which database an object lives in — that is the scope you declare in a `USE` header or `PROBE_DB`, and it is how you tell whether a reference is same-database (two-part) or a genuine cross-database call (three-part).

**E) Check data tables**

Common data issues live in these FedTax tables (check schema definitions and reference `docs/tax-code-reference.md`):
- `dbo.StatesTaxMatrix` — rate/exemption mappings by state+TIC+jurisdiction
- `dbo.PostCalculateTICActions` — post-calculation overrides by ActionID
- `dbo.TICs` — TIC definitions, ParentTIC, isSSUTA flags
- `dbo.TDSDataNonSsuta` — non-SSUTA jurisdiction boundary data

To inspect the ACTUAL configured rows (not just the schema), query read-only staging with ratebench's `cmd/sqlprobe` — `FedTax/ratebench` is available and the `RATEBENCH_DB_*` connection env vars are loaded. `PROBE_DB` declares the scope, so the query itself is two-part.

```bash
PROBE_DB=FedTax-20260521 go run ./cmd/sqlprobe \
  "SELECT stm.[State], stm.[TIC], stm.[Rate] FROM [dbo].[StatesTaxMatrix] AS stm WITH (NOLOCK) WHERE stm.[State] = 42"
```

You can also pass the query on stdin. The staging login is a CONTAINED user scoped to one copy, so it cannot follow cross-database references: probe FedTax and Reports in separate invocations (`PROBE_DB=Reports-<suffix>` for the latter). If a query does carry a cross-database three-part reference, sqlprobe rewrites the canonical database name to the copy `PROBE_DB` names and echoes the rewrite to stderr — but the contained login still cannot follow it, so split the query instead. Filter on indexed predicates (e.g. `MerchantID` or `URLs.ID` plus a `TransactionDate` range on transaction tables); an unindexed scan hangs.

**When writing queries, use the correct ID type** (see Key Terminology above). If the ticket gives you a Merchant ID, filter on `[MerchantID]` — do NOT assume it's a URL ID.

Staging is READ-ONLY — never write to or mutate it. The read-only login also has column-level DENY on sensitive columns: never `SELECT *` on FedTax `[dbo].[Merchants]`, `[dbo].[URLs]`, `[dbo].[ExemptionCertificateDetails]`, or Reports `[dbo].[TexasSingleRateLicenses]`, and never reference `Merchants.EIN`, `URLs.APIKey` / `DisabledAPIKey` / `MarketplaceAuthToken`, `ExemptionCertificateDetails.TaxID`, or `TexasSingleRateLicenses.TaxpayerID` anywhere — referencing a denied column fails the whole statement. Select only the columns you need.

### For `txcapp` issues

Use the repo wiki (`read_wiki_contents` for `FedTax/txcapp`) for architectural guidance. Key areas:
- **Tax API issues**: `cmd/taxapi/` and `biz/` (business logic)
- **Order/cart issues**: see wiki sections on "Order and Cart Management" and "Order Lifecycle Flows"
- **Auth issues**: `cmd/proxy/` and wiki section on "Authentication and Authorization"
- **Exemption issues**: `biz/` and wiki section on "Exemption Certificate Management"
- **Nexus issues**: wiki section on "Tax Collection and Nexus Management"

Run `go build .` from the repo root to validate your changes compile. Any SQL embedded in Go source you touch follows the same convention: the connection declares the scope, so references are two-part, with three-part only for a genuine cross-database call.

## Step 3: Implement the fix

Only for tickets the routing gate left in scope — tax-calculation changes stop at diagnosis.

1. Create a new branch with syntax: `fix/<TICKET_KEY>-<short-summary>` (e.g., `fix/DEV-1234-pa-county-rate`)
2. Make the necessary code changes:
   - For `txc-sqlserver-database`: this typically means writing SQL migration scripts (ALTER, INSERT, UPDATE statements) in the appropriate location. Open every script with a `USE [<database>]; GO` header and keep references two-part `[dbo].[Object]`, matching the schema dump. When editing a proc/function definition in place, leave its existing two-part style alone — do not add a `USE` and do not requalify.
   - For `txcapp`: modify Go source files, ensuring you follow existing code patterns and conventions
3. Commit with message format: `<TICKET_KEY>: <description>` (e.g., `DEV-1234: fix PA county rate lookup for TIC 40030`)

## Step 4: QA review

Perform a structured QA review before creating the PR:

### For SQL changes (`txc-sqlserver-database`)
- [ ] **Scope declared once, references two-part**: every script opens with `USE [<database>]; GO` (or `PROBE_DB` for a probe) and scopes exactly one database; every object reference inside is `[dbo].[Object]`, with three-part used only for a deliberate cross-database call written against the canonical `[FedTax]`/`[Reports]` name. No bare references, no versioned staging names, nothing relying on a connection default.
- [ ] Verify the SQL is syntactically valid T-SQL
- [ ] Confirm all `SELECT` diagnostics use `WITH (NOLOCK)` on base tables (prod is a busy OLTP server)
- [ ] Check date handling: expire old rows with `[END]` = day before new effective date; new rows use `[END]` = 99991231
- [ ] Verify no overlapping date ranges would be created in FedTax `dbo.StatesTaxMatrix`
- [ ] For non-SSUTA changes: confirm both the cart SP and Reports function are updated consistently (logic drift prevention)
- [ ] Check that the fix doesn't affect unrelated states, TICs, or jurisdictions
- [ ] Generate postflight verification queries to confirm the change works as expected

### For Go changes (`txcapp`)
- [ ] Run `go build .` — must compile cleanly
- [ ] Run `go test ./...` — all tests must pass
- [ ] Review for unintended side effects on other endpoints or services
- [ ] Ensure no hardcoded values, secrets, or test data is committed

## Step 5: Create the PR

Create a PR targeting the `main` branch. The PR description should include:
- **Jira ticket link**: link to the original ticket
- **Problem summary**: what the customer reported
- **Likely cause**: what the evidence shows, kept separate from your theory of why
- **Fix description**: what was changed and how it resolves the issue
- **Testing notes**: verification queries or test steps for reviewers
- **Risk assessment**: what could this change affect? Any states/TICs beyond the reported issue?

Wait for CI checks to pass before proceeding.

## Step 6: Post a short Jira update

The ticket audience is product and support, not engineering. Detail lives on the PR; the ticket gets a short, plain-language, directional note. Post exactly one comment per run, once the PR is up (or when you are blocked and need input).

Post it using the Atlassian MCP:

```
addCommentToJiraIssue(
  cloudId: "taxcloud.atlassian.net",
  issueIdOrKey: "<TICKET_KEY>",
  body: "<comment_content>",
  contentFormat: "markdown"
)
```

### Format

Under 100 words, plain prose, three short paragraphs at most, no headings, no checklists, no tables. Always open with the attribution line verbatim so no one mistakes the comment for a person's:

```markdown
_This is an automated review from Devin._

<1-2 sentences: what appears to be happening, in customer/product terms.>

<1 sentence: what the proposed change would do for merchants.> Details and the code are in <PR link> for engineering review.

<1 sentence: the specific decision or confirmation needed from a human, if any.>
```

Example:

> _This is an automated review from Devin._
>
> For merchant 12345, PA orders with TIC 40030 look like they are picking up the state rate without the county portion, which would explain the lower tax on the orders in the attachment. The proposed change would apply the county rate to these orders going forward; details and the SQL are in FedTax/txc-sqlserver-database#456 for engineering review. Someone on the tax side should confirm the county rate is expected to apply here before this ships.

### Language and ownership

You investigate and propose; a human decides. This is not optional phrasing preference — it is how the comment must read.

- Never write "confirmed", "verified", "root cause is", "this is a bug", "fixed", "resolved", or a risk rating. Use "appears", "looks like", "one likely explanation", "proposed", "pending review".
- Never declare behavior correct or incorrect. Report what you observed and what you would propose, and name the person/team decision it depends on.
- Do not restate the ticket back to the reporter, and do not narrate your process or what you ruled out.

### Keep out of the ticket

SQL, query output, proc/function names, file paths, schema details, verification steps, checklists, risk assessments, and anything a reader would need engineering context to parse. All of it belongs in the PR description. If it would only make sense to someone reading the diff, it does not go on the ticket.

On an incremental re-run of this playbook against the same ticket, post one short comment saying what changed and linking the same PR — do not repost the original summary. It carries the same attribution line.

## Advice & Pointers

- **One identifier convention** — see the mandatory section at the top: declare the scope once (`USE` header or `PROBE_DB`), then two-part `[dbo].[Object]` throughout, three-part only for a genuine cross-database call. Inconsistency here is the single most common source of data corruption in this workflow.
- **Start in `txc-sqlserver-database`** for most support issues — for read-only diagnosis, even on tickets the routing gate sends to the rate-fix flow, since the classification and observed behavior are what that flow needs from you. Only move to `txcapp` if the issue is clearly an API/app bug unrelated to underlying tax data, rates, or TICs.
- **Use the repo wikis** (`read_wiki_contents`) for both repos — they contain detailed architectural documentation that will help you understand code paths quickly.
- **Tax rule changes go to the rate-fix flow, not to you** — new TICs, rate changes, exemption updates, and PCTA modifications are routed out per the Step 1 gate; the `!rate-fix` stage invokes `tax-rule-change` there. Never hand-roll them here.
- **Ask questions** via a non-blocking message if additional context is needed, but keep investigating in parallel.
- **Logic drift is the #1 non-SSUTA bug source** — always check both the cart SP and Reports function for consistency when touching non-SSUTA states.
- **Read code and structure from prod schema files** — proc/function bodies, table definitions, and column names come from `output/schema/fedtax-prod/` and `output/schema/reports-prod/`, never by querying.
    - For the actual configured DATA a row holds (rates, exemptions, overrides), query read-only staging via ratebench's `cmd/sqlprobe` (see Step 2E).
- If the fix requires no code changes (e.g., it's a data-only issue that needs a manual DB update), still open a PR containing the script someone will run — `USE [<database>]; GO` header, two-part `[dbo].[Object]` names, one database per script — and link it from the ticket. Never paste SQL into a Jira comment.
- **The PR carries the depth, the ticket carries the direction.** Root cause reasoning, verification queries, scope analysis, and risk notes go in the PR description where engineering reads them. Resist the urge to duplicate any of it on the ticket.
- You may receive subsequent requests to run this playbook on a Jira ticket where this playbook was already run. In that case, treat the update as incremental. Make incremental comments, use the original branch and use the existing PR if it has not been merged.
- Where possible, use variables and/or set with case statements to avoid duplication of identifiers in condition evals. e.g. the same list of merchant IDs in multiple condition blocks.
- If you find HelpScout links in Jira tickets, use your HelpScout MCP connection here to access the conversation details.
- **Stay focused on the reported problem.** The ticket and its attachments define the scope. If an attachment shows a specific order in PA, investigate PA — don't go off on tangents about other states (e.g. DC) just because they appear in related data or configuration. Diagnose exactly what was reported before broadening scope.
- **Don't guess the "real issue."** If the ticket tells you the problem, investigate that problem. Don't speculate about what the issue "really" is or substitute your own theory for what the ticket explicitly states.

## Forbidden Actions

- Never hand over a script without a `USE [<database>]; GO` header, or run a probe without `PROBE_DB` — and never rely on a connection's default database.
- Never write a bare (`X`) object reference.
- Never write a three-part name for an object in the script's own scope — three-part is reserved for genuine cross-database references.
- Never hard-code a versioned staging database name (`FedTax-20260521`) in a cross-database reference — write `[FedTax]` / `[Reports]` and let the tooling rewrite it.
- Never let one script span two databases, and never mix styles within a statement, PR, or Jira comment.
- Never post a Jira comment without the `_This is an automated review from Devin._` line first — readers must never take it for a human's comment.
- Never post a Jira comment containing SQL, query output, checklists, headings, or a risk rating, and never exceed ~100 words.
- Never state in Jira that something is confirmed, verified, a bug, root-caused, fixed, or resolved — that call belongs to a human.
- Never write to or mutate staging or prod from this workflow — staging is read-only and prod changes ship as reviewed scripts.
