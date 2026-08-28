## Overview

Author ratevariant A/B inputs — cases, and an alteration file when the PR ships data —
on the existing branch of a labeled `FedTax/txc-sqlserver-database` PR.

**Read this twice, it is the thing sessions get wrong:**

- **A case is a situation, not an assertion.** ratevariant runs the same input against
  baseline and variant and diffs the output. You never write an expected rate, amount,
  or pass/fail condition anywhere. Your job is to pick *situations* — a merchant, a
  destination, a TIC, a date — that route through the changed jurisdictional/eligibility
  path, plus neighbors that must stay unchanged. The harness decides what differs.
- **It is just YAML and raw T-SQL.** A case is a YAML file with an `input:` block of
  literal values. Fixtures and alterations are lists of raw `sql:` strings. There is no
  test framework, no assertion DSL, no Go/Python to write, no helper to build. If you
  find yourself scaffolding code, stop — you are off the rails.

## What's Needed From User

- The PR number/branch in `txc-sqlserver-database` and the ticket key.
- Which surface(s) to cover — usually from the `<!-- ratevariant-plan -->` PR comment.

## Tools & Building Blocks

Four things, all of them plain files. Know which one a change calls for before you start
writing.

| Building block | Where | Use it when |
|---|---|---|
| **Case** — YAML `input:` block of literal values | `tests/ratevariant-cases/{carts,imports,reports}/` | Always. One per affected root. It is the situation you feed both arms. |
| **Fixture** — `fixtures:` block of raw T-SQL `apply`/`teardown` inside a case, applied to **BOTH** arms | same file as the case | The situation needs data staging doesn't already have, or the historical row doesn't carry. **Check this on every case you write** — see below. |
| **Alteration** — standalone YAML of raw T-SQL `apply`/`teardown` | `tests/ratevariant-cases/alterations/<ticket>.yaml` | The PR ships data rows (a `scripts/` migration). The data change *is* the variant. |
| **sqlprobe** — read-only T-SQL against the staging copy | `FedTax/ratebench` (separate clone) | You need a real `url_id`/`txid`, or to confirm a merchant's nexus/eligibility. |

**Fixtures are the most-missed piece.** Before you finish any case, ask: *does the row
this case needs actually exist in staging today?* If the answer is no or "not with the
values I need", the case needs a fixture, and without one it silently produces an empty
or meaningless diff. The two cases that almost always need one:

- **A proc-path case probing an alteration.** The alteration runs only in the alteration
  arm; the proc arm sees the old data unless a fixture replicates the same data effect.
- **A case reading a column historical rows don't populate** (e.g. `ItemPriceTaxable`),
  or needing a merchant location / exempt cert / program enrollment staging lacks.

A fixture is infrastructure for the situation, never the thing under test: a row the PR
itself ships belongs in an alteration.

## Procedure

1. **Set up.** Check out the PR's branch in `txc-sqlserver-database` and merge `main`
   into it. Clone `FedTax/ratebench` separately (`~/repos/ratebench`) — it holds the
   ratevariant harness, the case loader, and `cmd/sqlprobe`. Cases themselves live in
   `txc-sqlserver-database/tests/ratevariant-cases/`.

2. **Build the root checklist.** Read the `<!-- ratevariant-plan -->` comment: "### Proc
   changes" lists affected roots, "### Alterations" lists data changes. Your checklist is
   every root under Proc changes **plus every root that reads a table touched by an
   alteration** (grep the proc bodies under `output/schema/` if unsure). Mapping:
   - `spTransactionLookup[_nonssuta]` → `carts/`
   - `spImportOfflineTransactions` → `imports/`
   - `spGenerateTransactionsWideForTx[_nonSsuta]` → `reports/` (set `non_ssuta: true`)

   Non-SST states (e.g. Illinois) use the `_nonssuta` roots — ratevariant covers both.

3. **Author the alteration first, when the PR ships data** (`scripts/` migration):
   `tests/ratevariant-cases/alterations/<ticket>.yaml` with `apply` reproducing the
   migration and `teardown` reversing it exactly. Additive `apply` must be idempotent
   (`INSERT ... SELECT ... WHERE NOT EXISTS` or `MERGE`) and carry a sentinel (e.g. a
   `Comments` marker) that teardown deletes by; mutating `apply` must have teardown
   restore the pre-existing values. Use three-part names (`FedTax.dbo.X`). See
   `alterations/dev-7443-phase2-tic-41025-stm-exemption.yaml`.

4. **Author one case per root on the checklist**, grounded in the ticket's real
   merchant/state/situation. Add the neighbors the change implies: an adjacent
   jurisdiction that must stay untouched, a gate that should switch the branch off, a
   boundary date. Filename `<state>-<merchant>-<scenario>.yaml`; description names the
   eligibility profile + destination + path exercised; tag the axes (`state:XX`,
   `ssuta:yes|no`, `nexus:…`, `tic:NNNNN`). Re-read the checklist before moving on —
   every root must have at least one file.

5. **Walk every case you wrote and decide its fixture**, per the fixture test above —
   don't leave it implicit. Same idempotency rule as step 3, and teardown removes only
   the rows the fixture added. If a case only diffs once you patch a gating table, say
   so — the branch may be dead on current data, and that is a finding, not a fixture.

6. **Query staging from ratebench** when you need a real `url_id`, `txid`, or to confirm
   a merchant collects in a state. `RATEBENCH_DB_*` is already in your environment
   (read-only), so no setup is needed:
   ```
   cd ~/repos/ratebench && go run ./cmd/sqlprobe "SELECT TOP 5 ID FROM dbo.URLs WHERE ..."
   ```
   It also reads stdin, and `PROBE_DB=Reports-<copy>` switches database.

7. **Validate structurally** with ratebench's case loader (command in the Validate step
   of `.claude/commands/ratevariant-cases.md`); no DB needed.

8. **Push and run.** `git add` only the case/alteration files, push to the PR branch,
   then add the `ratevariant:run` label. Wait for the run, read the diffs, and fix cases
   that produce nothing or diff somewhere unexpected.

9. **Report** files authored, coverage per root, run results, and any root/path the
   ticket's merchant can't reach. Append your session link to the PR description after
   the develop session link.

## Iteration Protocol

If the develop session pivots: list what changed, rebuild the root checklist, triage
existing cases (valid / needs update / obsolete / missing), author the gaps, and
re-trigger `ratevariant:run`.

## Specifications

- Every root on the checklist has ≥1 case file; alterations have a working teardown.
- Every case that needs data staging lacks carries a fixture — no case is silently
  diffing against data that isn't there.
- No file, name, description, or tag contains a rate, amount, or expected outcome.
- Case loader passes and the `ratevariant:run` diffs are explained in your report.

## Advice & Pointers

- Missing a root is a session failure — especially for alterations, where the reach is
  every root reading the altered table, not just the changed procs.
- Ground taxability in data (`StatesTaxMatrix.PercentTaxable`, `Locations`, program
  tables), never tax intuition; flag unconfirmed taxability to the ticket's SMEs.
- A merchant collects in a state when it has an active physical `Locations` row
  (`Zip IS NOT NULL`, today `BETWEEN CreatedOn AND DeletedOn` — int `YYYYMMDD`) in that
  `StateFIPSCode`, the merchant/URL aren't disabled, the URL has gone live, and
  `transaction_date` ≥ both go-live and merchant-created (smalldatetime). Otherwise the
  proc errors out before reaching the changed logic.
- Always filter `transactions`/`transactiondetails` on an indexed predicate (`URLID`
  plus a `TransactionDate` range) — an unindexed scan hangs. Read column names from
  `output/schema/.../Tables/` instead of querying for them.
- `imports`: `order_id` must embed `{{ uuid }}` with a prefix ≤13 chars (TVP columns are
  `VARCHAR(50)`); `merchant_tax_rate` is the *claimed* rate and drives import taxability.
- `reports`: needs a real `txid` from the copy.

## Forbidden Actions

- Never encode a rate, amount, or expected outcome in a filename, name, description, or
  tag — describe the jurisdictional path only.
- Never build a harness, assertion helper, or test scaffolding — cases are YAML, and
  fixtures/alterations are raw T-SQL.
- Never put a real `api_key` in a case; it resolves at run time from the URL row.
- Never `SELECT *` on `Merchants`, `URLs`, `ExemptionCertificateDetails`, or
  `Reports.dbo.TexasSingleRateLicenses`, and never reference `Merchants.EIN`,
  `URLs.APIKey`/`DisabledAPIKey`/`MarketplaceAuthToken`,
  `ExemptionCertificateDetails.TaxID`, or `TexasSingleRateLicenses.TaxpayerID` — the
  read-only login has column-level DENY and the whole statement fails.
- Never write files outside `tests/ratevariant-cases/`, or off the PR's branch.
- Staging access is read-only — never mutate staging outside a fixture/alteration
  teardown pair.
