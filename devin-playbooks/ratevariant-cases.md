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
- **You author and validate; you do not run — unless the auditor asks you to.** Firing
  `ratevariant:run`, reading the result comment, and judging whether the fix is right belong to
  a separate auditor, so that the session which wrote the cases is not the one grading them.
  Default to pushing and reporting, and defer the run rather than refusing it: if the audit
  session later messages you to add the label or push a case and re-label, do it. What stays
  out of your hands is the *judgment* — don't read the result comment and decide the fix is
  right.

The mechanics live in repo skills and docs — load them instead of re-deriving:

| Need | Load |
|---|---|
| case YAML schema, field traps, `url_id` vs `MerchantID`, `order_id` prefix, report `txid` | `tests/ratevariant-cases/README.md` |
| how the workflows fire, offline validation, what not to run | `ratevariant-testing` skill |
| finding an eligible merchant/transaction on the snapshot, read-only `sqlprobe` | `query-staging-snapshot` skill |
| composing a safe, indexed, bounded query | `write-taxcloud-sql-query` skill |
| what a good/bad run looks like, precedents | `ratevariant-audit` skill (+ its `references/`) |

## What's Needed From User

- The PR number/branch in `txc-sqlserver-database` and the ticket key.
- Which surface(s) to cover — usually from the `<!-- ratevariant-plan -->` PR comment.
- The investigation's proven mechanism (what is wrong and where expected and actual part ways)
  and the shape of the change, when available: cases aimed at the mechanism beat cases aimed at
  the ticket's prose.

## Tools & Building Blocks

Four things, all of them plain files. Know which one a change calls for before you start
writing.

| Building block | Where | Use it when |
|---|---|---|
| **Case** — YAML `input:` block of literal values | `tests/ratevariant-cases/{carts,imports,reports}/` | Always. One per affected root. It is the situation you feed both arms. |
| **Fixture** — `fixtures:` block of raw T-SQL `apply`/`teardown` inside a case, applied to **BOTH** arms | same file as the case | The situation needs data staging doesn't already have, or the historical row doesn't carry. **Check this on every case you write** — see below. |
| **Alteration** — standalone YAML of raw T-SQL `apply`/`teardown` | `tests/ratevariant-cases/alterations/<ticket>.yaml` | The PR ships data rows (a `scripts/` migration). The data change *is* the variant. |
| **sqlprobe** — read-only T-SQL against the staging copy | `FedTax/ratebench` (separate clone) | You need a real `url_id`/`txid`, or to confirm a merchant's nexus/eligibility. Driven by `query-staging-snapshot`. |

**Fixtures are the most-missed piece.** Before you finish any case, ask: *does the row
this case needs actually exist in staging today?* If the answer is no or "not with the
values I need", the case needs a fixture, and without one it silently produces an empty
or meaningless diff. The two cases that almost always need one:

- **A proc-path case probing an alteration.** The alteration runs only in the alteration
  arm; the proc arm sees the old data unless a fixture replicates the same data effect.
- **A case reading a column historical rows don't populate** (e.g. `ItemPriceTaxable`),
  or needing a merchant location / exempt cert / program enrollment staging lacks.

A fixture is infrastructure for the situation, never the thing under test: a row the PR
itself ships belongs in an alteration. Fixtures apply to both arms, so a fixture can
never create a diff on its own — if it appears to, it is doing the work the fix was
supposed to do, and that is a finding.

## Procedure

1. **Set up.** Check out the PR's branch in `txc-sqlserver-database` and merge `main`
   into it. Clone `FedTax/ratebench` separately (`~/repos/ratebench`) — it holds the
   ratevariant harness, the case loader, and `cmd/sqlprobe`. Cases themselves live in
   `txc-sqlserver-database/tests/ratevariant-cases/`.

2. **Build the root checklist.** Read the `<!-- ratevariant-plan -->` comment for the
   **current head SHA**: "### Proc changes" lists affected roots, "### Alterations" lists
   data changes. Your checklist is every root under Proc changes **plus every root that
   reads a table touched by an alteration** (grep the proc bodies under `output/schema/`
   if unsure). Mapping:
   - `spTransactionLookup[_nonssuta]` → `carts/`
   - `spImportOfflineTransactions` → `imports/`
   - `spGenerateTransactionsWideForTx[_nonSsuta]` → `reports/` (set `non_ssuta: true`)

   Non-SST states (e.g. Illinois) use the `_nonssuta` roots — ratevariant covers both.

   If the roots list is empty while the PR changed dbo procs/functions, callgraph
   generation failed — stop and report rather than authoring blind. Empty roots on a
   data-only PR is expected.

3. **Author the alteration first, when the PR ships data** (`scripts/` migration). The fix
   session does not write this file, so a migration with no matching alteration is the normal
   state of the branch when you arrive, not a sign someone else has it:
   `tests/ratevariant-cases/alterations/<ticket>.yaml` with `apply` reproducing the
   migration and `teardown` reversing it exactly. Additive `apply` must be idempotent
   (`INSERT ... SELECT ... WHERE NOT EXISTS` or `MERGE`) and carry a sentinel (e.g. a
   `Comments` marker) that teardown deletes by; mutating `apply` must have teardown
   restore the pre-existing values. Use three-part names (`FedTax.dbo.X`). See
   `alterations/dev-7443-phase2-tic-41025-stm-exemption.yaml`.

4. **Author one case per root on the checklist**, grounded in the ticket's real
   merchant/state/situation and aimed at the proven mechanism. Add the neighbors the
   change implies: an adjacent jurisdiction that must stay untouched, a gate that should
   switch the branch off, a boundary date. Filename `<state>-<merchant>-<scenario>.yaml`;
   description names the eligibility profile + destination + path exercised; tag the axes
   (`state:XX`, `ssuta:yes|no`, `nexus:…`, `tic:NNNNN`). Re-read the checklist before
   moving on — every root must have at least one file.

5. **Walk every case you wrote and decide its fixture**, per the fixture test above —
   don't leave it implicit. Same idempotency rule as step 3, and teardown removes only
   the rows the fixture added. If a case only diffs once you patch a gating table, say
   so — the branch may be dead on current data, and that is a finding, not a fixture.

6. **Query staging** only through `query-staging-snapshot` (which owns candidate-merchant
   selection, the eligibility/validity rules a case must satisfy, and the read-only
   `sqlprobe` invocation) with `write-taxcloud-sql-query` for the query itself. Do not
   improvise SQL or scaffold a querier.

7. **Validate structurally, offline.** Run the case loader via `run-alter --dry-run` as
   documented in the `ratevariant-testing` skill ("Validate offline before you push"); it
   parses every case and prints apply/teardown SQL and the probe count without touching
   the database. `tests/ratevariant-cases/README.md` lists exactly what the loader checks
   and what only surfaces at run time.

8. **Push, and stop there.** `git add` the case/alteration files and push to the PR branch. Do
   not add the `ratevariant:run` label on your own initiative and do not run the harness — the
   audit stage fires the run and interprets it. If the auditor messages you to label or
   re-label, that is a direct request and you carry it out.

   Then append your session link to the PR description — and note that the description is
   shared state (`CLAUDE.md` § "Sharing a PR with other sessions"): read the current
   description, add your line, and write the whole thing back. Composing it from what you
   remember deletes whatever the fix session or the auditor added while you were working.

9. **Report** files authored, coverage per root, every root/path the ticket's merchant
   cannot reach and why, and any case you believe is probing a dead branch.

## Iteration Protocol

The auditor sends specific, evidenced case work back to you: a missing branch/path, an
ineffective probe, a guardrail gap, or an alteration that went stale because the fix's
migration changed. Do exactly that work on the same branch and hand back — do not re-run
the A/B, and do not answer a coverage request with a change to `output/schema/**` or
`scripts/**`, which belong to the fix session.

If the develop session pivots: list what changed, rebuild the root checklist from the new
plan comment, triage existing cases (valid / needs update / obsolete / missing), author
the gaps, and report.

## Specifications

- Every root on the checklist has ≥1 case file; alterations have a working teardown.
- Every case that needs data staging lacks carries a fixture — no case is silently
  diffing against data that isn't there.
- No file, name, description, or tag contains a rate, amount, or expected outcome.
- The loader passes offline (`run-alter --dry-run`), and the report states per-root
  coverage plus any gap with its reason.
- No run result is interpreted here, and `ratevariant:run` appears only if the auditor asked.

## Advice & Pointers

- Missing a root is a session failure — especially for alterations, where the reach is
  every root reading the altered table, not just the changed procs.
- Ground taxability in data (`StatesTaxMatrix.PercentTaxable`, `Locations`, program
  tables), never tax intuition; flag unconfirmed taxability as an open question for the
  ticket's SMEs.
- A guardrail per axis the fix keys on (geography, date, merchant, TIC) is what makes the
  run auditable; a case set with no guardrails can only be observed, not audited.
- Merchant eligibility, snapshot date traps, indexed predicates, and the column-level
  DENY list are all in `query-staging-snapshot`; field-level traps are in the cases
  README. Read them there rather than trusting a summary.
- If you are running as a delegated session with no human available, never block on a
  question: author what the evidence supports and return the open question in your final
  report.

## Forbidden Actions

- Never encode a rate, amount, or expected outcome in a filename, name, description, or
  tag — describe the jurisdictional path only.
- Never build a harness, assertion helper, or test scaffolding — cases are YAML, and
  fixtures/alterations are raw T-SQL.
- Never put a real `api_key` in a case; it resolves at run time from the URL row.
- Never write files outside `tests/ratevariant-cases/`, or off the PR's branch. Procs and
  migrations belong to the fix session.
- Never add `ratevariant:run` on your own initiative (when the auditor asks, do it), and never
  run `ratevariant deploy/run/run-alter` (without `--dry-run`) or `cleanup` from the session —
  those mutate shared staging and the read-only login can't reach the databases they default to.
- Never interpret a run result: labeling on request is mechanics, grading is the auditor's job.
- Staging access is read-only — never mutate staging outside a fixture/alteration
  teardown pair.
