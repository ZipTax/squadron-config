## Overview

Author Bruno API regression tests for a TaxCloud ticket's tax fix, in
`V3/Tax/Regression/<TICKET>[-TIC-NNNNN]/` under `FedTax/txc-bruno`.

You will be:
1. **Gathering context** (read the Jira ticket and the txc-sqlserver-database PR)
2. **Authoring** a representative set of live-API tests that confirm the fix

Each test is a real V3 Tax API call asserting the corrected rate/amount. Draw your cases
from the PR's test cases — both the scenarios expected to CHANGE (the fix's effect) and the
guardrails expected to STAY THE SAME (no over-reach). Example folders like
`DEV-7225-TIC-40085` show the exact shape; lean on them.

Note that you may define multiple tests per file - think of them like groupings or scenarios.
E.g. testing proportional shipping could have an SST file where it applies, and a non-SST file
where it does not. For the SST file, you could include tests such as:
- `exempt line items = $0 shipping tax`
- `25% tax on line items = 25% shipping tax`
- `mix of exempt and non-exempt line items allocates correctly`

## Core principles (read first)

These exist because past sessions have gone wrong here. Follow them exactly.

- **Authority is the ticket's stated correct figure, or state-published material — nothing
  else.** Every asserted rate, amount, date, jurisdiction, and TIC traces to one of those
  two, and you name which one per scenario (the PR's test cases only tell you which
  scenarios to cover). Where the ticket carries an SME's explicit correct value, it wins.
  Where it doesn't, a state DOR rate table/bulletin is acceptable authority — cite it.
  Never substitute your own guess, a "reasonable-looking" rate, current staging output, or
  ratevariant's variant-arm value for either.
- **No authority, no assertion.** A scenario whose correct value you cannot source from the
  ticket or a state publication does not get a softened test, an approximate value, or a
  quiet omission: leave it unwritten and report it as an open question naming exactly what
  figure you need and from whom.
- **Assert the CORRECTED (post-fix) values — the tests are SUPPOSED to fail today.** The fix
  is not deployed to staging, so these tests would fail if run right now. That is the intended
  design: they turn green only once the fix ships. Never weaken an assertion, assert the
  current (buggy) behavior, add a tolerance, or comment out a scenario to make it look
  "safe."
- **A scenario that would PASS today is a red flag — investigate, don't ship it quietly.** If
  the staging snapshot already returns the corrected value (see the sqlprobe check below), the
  test would pass now, which means EITHER the assertion is wrong (a test bug) OR the fix is
  already (or partially) deployed. Check the ticket comments for a prior/partial deployment,
  and report the inconsistency to the user — do not just ship an already-green regression
  test or silently adjust it to look failing.
- **Do not hedge or bail on uncertainty.** "I'm not sure, so I'll skip it / soften it / assert
  something vague" is a failure mode. Resolve uncertainty from the ticket and PR first. If a
  specific value or scenario is genuinely undetermined after reading both, ask the user a
  concrete question (see step 1) — do NOT silently drop the scenario, guess, or produce a
  watered-down assertion.
- **Cover the full set of scenarios.** Author every should-change scenario and every
  should-not-change guardrail the PR's test cases call for. Do not trim the suite because a
  case is hard to reason about — reason it out or ask.

## Procedure

0. **Delegated (orchestrated) mode**: when an orchestrator invokes you rather than a human,
   never block — author every scenario you have authority for, and return the questions you
   would have asked (with the exact figure needed, per scenario) in your report instead of
   waiting. Everything else below is unchanged.

   An unwritten scenario is not lost work: name it precisely (the scenario, and the exact figure
   and authority you need), because the orchestrator records it against the ticket and the next
   run on that ticket resumes from it — and it will message this session rather than start a new
   one, if this session is still alive. What cannot be resumed is a vague "needs confirmation".

1. **Gathering context**: read the ticket (`https://taxcloud.atlassian.net/browse/<TICKET>`)
   and the txc-sqlserver-database PR. Take the scenarios from the PR's test cases — the ones
   that should now differ and the guardrails that should not — and the expected rate/amount for
   each from the ticket. If a needed value or scenario is ambiguous or missing after reading
   both, ask the user one specific question (quote the exact rate/scenario in doubt) rather
   than guessing or dropping it.

2. **Match the conventions**: work in `txc-bruno` on a branch (e.g. `<TICKET>-bruno`). Read
   `README.md` and an existing per-ticket folder before writing, and follow it.

3. **Create the folder** `V3/Tax/Regression/<TICKET>[-TIC-NNNNN]/`: a `folder.bru` (Jira
   link, one-line summary, table of its tests) plus one `.bru` per scenario.

4. **Author the tests** — a representative sample, breadth is better than depth. Each `.bru` is a single
   API call (typically the cart-tax endpoint
   `{{baseUrl}}/tax/connections/{{merchant20ConnectionId}}/carts`, as in the existing
   tests) on Merchant 20, with a `tests {}` block asserting the expected rate/amount. Assert
   the ticket's corrected values (which will fail until the fix deploys — that is correct).
   Follow an example folder for the control-plus-scenario shape, `customerId` lookups, naming,
   and `docs {}`. Cover both the should-change scenarios and the should-not-change guardrails.

5. **(Optional) Sanity-check against the staging snapshot**: before finalizing values, you may
   use ratebench's `cmd/sqlprobe` to read the staging snapshot data (a read-only,
   always-rolled-back query tool). Get connection creds from `txc-sqlserver-database`'s `.env`
   / the `RATEBENCH_DB_*` staging vars, then e.g.
   `PROBE_DB=<snapshot> go run ./cmd/sqlprobe "SELECT ... FROM dbo.StatesTaxMatrix WHERE ..."`
   from the `ratebench` repo. Use it to confirm a jurisdiction/rate or to detect whether the
   change is already present in staging (which would make a test pass today — see the red-flag
   principle above). The snapshot is only *reasonably* accurate and is NOT authoritative: the
   ticket still wins on any conflict; if a discrepancy makes you unsure the ticket is right,
   ask the user.

6. **Push and PR**: Commit to the branch and open a PR. In the description, summarize the
   scenarios the suite locks in — what behavior each proves — not a file-by-file list; the
   diff already shows the files.

7. **Link the new PR**: Put a link to the new PR on the existing txc-sqlserver-database PR, for discoverability. This should be posted at the end of the PR description, above the Devin session links.

## Specifications

- Every asserted rate/amount/date/jurisdiction traces to a cited authority — the ticket's
  stated correct figure or state-published material — named per scenario; the scenario set
  traces to the PR's test cases.
- Scenarios with no available authority are listed as unwritten open questions rather than
  asserted approximately.
- Assertions encode the post-fix expected values, so the suite is expected to fail against
  current (un-deployed) staging — never softened to pass today.
- Both should-change scenarios and should-not-change guardrails are present.
- Deliverable: a PR into `txc-bruno` on a `<TICKET>-bruno` branch, linked from the
  txc-sqlserver-database PR.

## Advice & Pointers

- Source cases from the PR's test cases — the should-change scenarios and the guardrails
  that must stay flat — with the asserted rate/amount grounded in the ticket.
- Representative, not exhaustive: a few well-chosen cases per fix. Lean on the breadth of
  existing folders rather than enumerating every permutation.
- Most tests hit the cart-tax endpoint, but use whatever the scenario needs — match the
  example that fits.
- Use Merchant 20 (all states enabled, test certs) and the existing env vars: `{{baseUrl}}`,
  `{{merchant20ConnectionId}}`, `{{merchant20ApiKey}}`.
- **Supporting references for jurisdictions/rates (both non-authoritative):**
  - The `ziptax-lookup` skill — resolve or sanity-check a jurisdiction or rate (e.g. which
    districts apply to an address, or a base state/local rate).
  - ratebench `cmd/sqlprobe` — read the staging snapshot data directly (see step 5).
  Use either only as a supporting reference — **cited authority always wins** (the ticket's
  stated figure, else state-published material). If either disagrees with your authority,
  assert the authority's value; if the discrepancy makes you doubt the authority, raise it
  rather than proceeding. Never let a ZipTax or sqlprobe result become the asserted value.

## Forbidden actions

- Never put a real `api_key` or any secret in a `.bru`, and never commit `staging.env` /
  `prod.env` — reference `{{merchant20ApiKey}}`.
- Don't write outside `txc-bruno`, or off the branch.
- Never try to run the tests. The fixes are NOT deployed to staging, nor do you have staging credentials.
- Never weaken, remove, or soften an assertion (or drop a scenario) to avoid a test failing
  against today's un-fixed staging — the tests are meant to fail until the fix deploys.
- Never ship a regression test that would pass against today's staging without first checking
  the ticket comments and flagging the inconsistency to the user (it means a test bug or an
  already-deployed fix).
- Never assert a value from ZipTax, sqlprobe, current staging, or the ratevariant variant arm
  that contradicts your cited authority; prefer the authority and raise the conflict.
- Never derive an expected value from what the system currently returns — that is the thing
  under test.
