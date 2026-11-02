# Author and review API regressions

Author and review V3 regressions in `FedTax/txc-bruno` from the ticket, fix PR, and accepted audit findings.
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

## Author, review, and deliver

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
4. Review the assertions and automatic CI results. CI runs the tests in staging;
   the authoring session does not execute them. Before deployment, should-change
   assertions fail and guardrails pass. After deployment, both pass. Investigate
   results that differ from those expectations without weakening assertions.
5. Commit and open/update the Bruno PR. Describe covered behavior, cited expectations,
   unwritten scenarios, and the observed CI results. Link the Bruno PR from
   the SQL fix PR while preserving its current description. Keep session history in the
   ticket registration, not the PR body. Never commit secrets or environment files.

Return the attached schema's PR URL, scenarios with authority, `unwritten`, and `validation`.
Finish when authoring and review are complete and CI matches the deployment state:
should-change tests fail before deployment and pass afterward; guardrails pass in both.
An expected pre-deployment failure completes this stage without waiting for deployment.
Keep those tests in CI so they verify the fix after deployment.

Use `failed` for unexpected results requiring correction, such as a failing guardrail.
Use `needs_human` for an unresolved operator or product question that prevents completion;
include the exact question, evidence checked, and missing answer. A pending fix deployment
is expected at this stage. Use the repository's `prod-sql-insights` procedure for data gaps.
Squadron owns correction routing and human waits. Post Jira prose when requested,
using `writing-ticket-updates`.
