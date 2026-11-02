# Test a rate fix in staging

Author and run V3 regressions in staging using `FedTax/txc-bruno` from the ticket, fix PR, and accepted audit findings.
The API suite locks in an independently established expectation; copying the variant arm's
output would only preserve whatever the implementation currently does.

## Context and authority

Read `txc-bruno` repository instructions, its README, and a comparable per-ticket regression
folder. Also use the skills from `txc-sqlserver-database` for
`registering-on-the-ticket` (tag `bruno-tests`), `investigate-tax-behavior`'s authority rules,
and `writing-ticket-updates` when a Jira comment is requested. Report a missing skill or
conflict before affected work rather than inferring its instructions.

Every expected tax rate, amount, treatment, and effective period must trace to state-published
material or a tax SME's explicit ruling on the ticket. A reporter's expected figure is a
question to investigate, not automatically authority. Cite the source per scenario. Current
API output, snapshot rows, ZipTax, and A/B output are supporting observations only.

Use the accepted findings to determine scenario coverage and expected results. Take
scenarios from the audited change and its guardrails, then assess API portability.
Check that the scenario data exists in staging. Report scenarios needing unavailable
merchant configuration, and scenarios outside this lane's V3 surface, with the reason and
what would be needed. Do not silently omit a required scenario or soften its assertion.

## Author, test, and deliver

1. Work on the existing Bruno branch/PR when continuing; otherwise create a ticket branch.
   Own only this repository, not the SQL fix branch.
2. Create `V3/Tax/Regression/<TICKET>[-TIC-NNNNN]/` with `folder.bru` and scenario files,
   following the existing conventions for requests, documentation, environment variables,
   and Merchant 20. Cover each API-observable changed scenario and guardrail with a
   representative test; avoid enumerating redundant permutations.
3. Assert the corrected values. Changed scenarios are expected to fail before deployment;
   unchanged guardrails may already pass. If evidence says a changed scenario already
   passes, check for prior/partial deployment or an ineffective regression and report what
   you found. Do not force a failure or weaken the expected value.
4. Run the regressions against staging only, following the repository's execution
   instructions. Confirm the selected environment and the deployed fix version first.
   Record the tested version and results. If deployment or access is missing, return the
   operator dependency so Squadron can arrange it. Production execution is outside this lane.
5. Commit and open/update the Bruno PR. Describe covered behavior, cited expectations,
   unwritten scenarios, and staging test results. Link the Bruno PR from
   the SQL fix PR while preserving its current description. Keep session history in the
   ticket registration, not the PR body. Never commit secrets or environment files.

Return the attached schema's PR URL, scenarios with authority, `unwritten`, and `validation`.
Report completed only after the staging tests pass against the identified fix version.
Return failed results with their evidence for correction; keep the expected values intact.
Distinguish a deliberate API coverage limit from a required assertion missing its authority.
Use `needs_human` when an operator decision, staging access/deployment, or unresolved product
question prevents completion. Include the exact question, evidence checked, and missing answer.
Use the repository's `prod-sql-insights` procedure for production-data gaps.
Return `completed` only with passing staging validation; justified coverage limits may remain.
Return `failed` for technical failures and keep `human_questions` empty unless a human answer
is needed. Squadron owns correction routing and human waits. Post Jira prose when requested,
using `writing-ticket-updates`.
