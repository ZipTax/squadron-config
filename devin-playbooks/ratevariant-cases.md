# Author ratevariant situations

Author cases and migration alterations on the existing fix PR branch in
`FedTax/txc-sqlserver-database`. Own only `tests/ratevariant-cases/**`. The fix session owns
schema objects and migrations; Squadron accepts the audit verdict. Separating these jobs
prevents a case author from changing the fix to fit its probes.

A case describes inputs, not expected outputs. Do not encode an expected rate, tax amount,
threshold, or result in YAML, names, descriptions, or tags. Literal transaction inputs such
as item prices are valid. Do not build an assertion framework or harness.

## Load the relevant repository guidance

| Responsibility | Source in `txc-sqlserver-database` |
| --- | --- |
| Lane and current-head plan | `ratevariant-testing`, including `references/process.md` step 2 |
| Merchant eligibility, validity gates, and legitimate fixtures | `ratevariant-case-data` |
| Query construction and read-only execution | `write-taxcloud-sql-query`, then `query-staging-snapshot` |
| YAML fields and alteration/fixture SQL | `tests/ratevariant-cases/README.md` |
| Offline loader validation | `ratevariant-testing` |

Read repository instructions and register with `registering-on-the-ticket` under
`ratevariant-cases`. Report missing skills or conflicting requirements before affected
work. In particular, do not copy a predicted outcome from a process example into case
metadata; describe that prediction separately as an audit finding.

## Build and hand off coverage

1. Read the ticket, supplied mechanism, actual PR diff, existing cases, and plan at the
   current head. Use the PR's existing branch; do not independently merge a base branch,
   because that changes the code the other lanes are reviewing.
2. Build the coverage checklist from plan roots plus every root consuming a table changed
   by a migration. Empty roots with changed procedures/functions is a plan failure;
   an empty procedure list on a data-only change is expected.
3. For a migration, author a matching alteration with reversible apply/teardown per the
   cases README. The alteration represents the change under test; a fixture supplies
   realistic prerequisites to both arms. Document which effect each supplies when a
   combined data/procedure fix needs separate probes.
4. Author at least one case per affected root and relevant guardrails for the changed
   geography, effective date, merchant eligibility, and TIC. Let the repository's case-data
   skill choose suitable data. State why each case needs a fixture or can run without one.
   Report unreachable paths and unconstructable cases with evidence rather than silently
   dropping coverage or manufacturing eligibility.
5. Validate with the repository's offline loader procedure, push only lane files, and
   return the attached schema: mode, authored files, per-root coverage, fixture decisions,
   and coverage gaps. Never commit credentials; use the loader's runtime key resolution.

On adoption, retain existing justified cases and complete the missing work. After a fix
pivot, compare the new plan/diff with existing cases, report valid/obsolete/missing coverage,
and update the migration's mirroring alteration when needed.

Do not independently run the harness or grade its result. On an explicit Squadron request,
you may apply/reapply `ratevariant:run` and return the exact-head result and captures; this
is evidence collection, not permission to accept your own coverage. Never run commands
that deploy to or mutate shared staging from the session.

Return `outcome: needs_human` with exact question-and-context pairs only when a person's
answer is necessary to finish authoring safely. Otherwise use `completed` and empty
`human_questions`. An evidenced coverage limit can be a completed result for audit to judge.
Do not wait or change workflow state. If asked to write on Jira, use `writing-ticket-updates`.
Keep session registration on the ticket and preserve others' content in any PR edit.
