# Author API regressions for a settled rate fix

Author V3 coverage in `FedTax/txc-bruno` from the ticket, fix PR, and accepted audit findings.
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

Take scenarios from the audited change and its guardrails, then assess API portability.
A snapshot fixture does not exist in the live API. Report scenarios needing unavailable
merchant configuration, and scenarios outside this lane's V3 surface, with the reason and
what would be needed. Do not silently omit a required scenario or soften its assertion.

## Author and deliver

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
4. Review structure and assertions without executing live API calls. Repository run
   instructions explain how execution works; this authoring-only lane does not authorize
   it or assume the fix has deployed. If snapshot checks are useful, use the SQL repository's
   `write-taxcloud-sql-query` and `query-staging-snapshot` skills rather than copying a command.
5. Commit and open/update the Bruno PR. Describe covered behavior, cited expectations,
   unwritten scenarios, and the fact that live tests were not run. Link the Bruno PR from
   the SQL fix PR while preserving its current description. Keep session history in the
   ticket registration, not the PR body. Never commit secrets or environment files.

Return the attached schema's PR URL, scenarios with authority, and `unwritten_scenarios`.
Distinguish a deliberate API coverage limit from a required assertion missing its authority.
Use `outcome: needs_human` and exact question-and-context pairs in `human_questions` when
that missing answer prevents a valid deliverable. Otherwise use `completed` with an empty
list; a justified coverage limit can coexist with completion. Return instead of waiting.
Squadron owns blocker handling and next-stage routing; post Jira prose only when requested,
using `writing-ticket-updates`.
