## Overview

Implement a tax-rate fix in `FedTax/txc-sqlserver-database` whose cause has **already been
proven** by a separate evidence-only investigation (`!rate_investigation`), then open the PR and
label it so ratevariant A/B testing can run.

You implement a diagnosis; you do not re-derive one. If the caller has not given you a divergence
and a disposition, say so rather than starting an investigation of your own — that is a different
stage with different rules, and an investigation run from a session that can write code tends to
stop at the first plausible cause.

You also do **not** author the ratevariant cases. That split is deliberate: finding an eligible
merchant, transaction and date for a case is a large discovery job with no bearing on the fix, and
carrying it here makes both worse. A separate session runs `!ratevariant-cases` on your branch
after you push.

Reusable mechanics live in the repo's skills — load them rather than re-deriving:

- `tax-rule-change` — data/configuration changes and migration script conventions.
- `write-taxcloud-sql-query` / `query-staging-snapshot` — any read-only verification.
- `ratevariant-testing` — how the A/B workflows fire (you need the label part only).

## What's Needed From User

- The ticket key, and the investigation's result: the expected-vs-actual divergence, the
  remediation disposition, the affected roots (procs/functions) or tables/rows.
- The base branch, if not the repo default.
- Whether you are writing the fix or **adopting** one that already exists (see below).

If the disposition is `unsupported at available granularity`, there is no fix to write: the proven
mechanism is one this engine cannot express, and the deliverable is that limitation, not a diff.
Report it back. A narrower partial fix may still be worth filing — but only if the caller briefed
it as feasible and accurate, and never presented as closing the class.

## Adopting an existing fix PR

Sometimes the fix already exists and the session that wrote it is gone. Then your job is to take
over the lane, not to redo the work: later stages route corrections to whoever owns the fix, and
an unowned PR strands every finding the audit reaches.

Read the PR diff and its branch, confirm the change matches the briefed mechanism, and report what
you found. Do not re-implement it, revert it, widen it, or open a second PR. If the existing change
contradicts the diagnosis, say so and stop — whether to correct it is the auditor's call once the
A/B has run, not a rewrite before anyone has seen a result.

## Procedure

1. **Confirm the brief against the code.** Read the affected roots and check the briefed
   divergence is actually there. If the code contradicts the diagnosis, stop and report what you
   found instead — do not improvise a different fix, and do not re-open whether the ticket is
   valid.

2. **Implement the proven disposition, and nothing wider.** When the disposition is `both`,
   implement both halves: a rate row that is wrong *and* applied wrongly needs the migration and
   the proc change, and shipping one is shipping half a fix.

   - *Procedure/function change*: edit the object under `output/schema/`. Every object exists in
     **both** a prod and a staging copy, and in both databases when the logic is duplicated there
     — change every copy of the object you touch: `output/schema/fedtax-prod/…`,
     `output/schema/fedtax-staging/…`, `output/schema/reports-prod/…`,
     `output/schema/reports-staging/…`. `ratevariant plan` only watches the `-prod` copies, so a
     staging-only edit gets no A/B, and a prod-only edit leaves the mirror stale. See DEV-9519
     (#198) and DEV-9402 (#182) for the shape.
   - *Data/configuration change*: author the migration under `scripts/`, per `tax-rule-change`.
     One database per script, two-part `[dbo].[Object]` names, `USE [<database>]; GO` header. You
     do **not** author the mirroring alteration YAML — that is the case session's.
   - Non-SSUTA warning: the cart path computes inline in `spTransactionLookup_nonssuta` while the
     ETL recalculates in `fnGetTaxRatesforTx_nonssuta` — separate implementations that drift.
     Fixing one copy of a four-copy function is this repo's most repeated defect, so state
     explicitly which paths your change reaches.

3. **Stay in your lane.** You own `output/schema/**` and `scripts/**`. You must NOT touch
   `tests/ratevariant-cases/**` — cases and alterations belong to the case-authoring session,
   which pushes to your branch after you. A PR comment asking for a case or coverage change is
   out of your lane: report it rather than answering it with code.

4. **Open the PR and label it.** Push the branch, open the PR against the base branch, then:

   ```
   gh pr edit <pr> --add-label ratevariant
   gh pr view <pr> --json number,url,headRefName,labels
   ```

   Confirm the label landed — without it `ratevariant plan` never runs and the fix ships
   unaudited. Adopting an existing PR: check out its head branch, open no PR, and *check* the
   label rather than assuming, since a prior run may never have applied it.

5. **The PR description is shared state.** Several sessions push to this branch and edit this
   description — see `CLAUDE.md` § "Sharing a PR with other sessions". Every edit is a
   read-then-append: fetch the current description, add your part, put the whole thing back. This
   binds you at the end of the run and again every time someone messages you to change something:
   composing the description from what you remember silently deletes whatever landed after you
   started, and what is lost is the last thing written — usually the investigation link or a
   coverage note a reviewer needs.

6. **Do not run or interpret the A/B.** Never add `ratevariant:run`. A separate auditor owns
   running it and reading the result, precisely so the session that wrote the fix is not the one
   grading it. Expect to be messaged mid-audit with a specific correction and its supporting data;
   implement exactly that, and push to the same branch.

7. **Report** the PR URL and number, the head branch, exactly what changed and where, which paths
   the change reaches, and anything about the brief that did not survive contact with the code.
   When adopting, report what the existing change does and that the lane now has an owner.

## Specifications

- The change implements the briefed disposition at the briefed scope — both halves when the
  disposition is `both` — with every copy of each edited object updated.
- The `ratevariant` label is present on the PR.
- No file outside `output/schema/**` and `scripts/**` is modified.
- Product-level ticket comments belong to the investigating session, which holds the Jira
  credentials, unless the caller asks you for one.

## Advice & Pointers

- The repo's `CLAUDE.md` describes `output/` as generated; for tax fixes the `output/schema`
  procedure/function sources **are** the editable source of truth, which is how every recent rate
  fix shipped. The weekly extract job reconciles them with the live databases, so the change has
  to reach the database too or the next extraction reverts your file.
- Keep the blast radius minimal and mechanical. A fix that also cleans up adjacent logic makes the
  A/B unreadable, because the auditor can no longer predict a per-case outcome from the diff.
- Effective dates are part of the fix. An override effective tomorrow cannot be demonstrated by a
  case dated yesterday.
- Running as a delegated session with no human available: never block. Implement what the evidence
  supports and return the open question in your report.

## Forbidden Actions

- Never author or edit ratevariant cases, alterations, or Bruno tests.
- Never add the `ratevariant:run` label, run `ratevariant deploy/run/run-alter/cleanup`, or mutate
  staging.
- Never widen the change beyond the proven disposition, and never re-litigate the investigation's
  verdict.
- Never paste SQL into a Jira comment — a data change ships as a script in the PR.
- Never open a second PR or branch for the same ticket; later stages push to yours.
- Never rewrite the PR description from a template or from memory, and never force-push the
  branch: other sessions are working on it.
