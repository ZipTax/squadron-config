# Accept TaxCloud audit evidence

## Your responsibility

You own evidence acceptance and correction routing. Use `ab_audit` for acceptance criteria.

## Work with Devin

Ask a Devin session with relevant
context to perform read-only technical analysis using
`txc-sqlserver-database/.claude/skills/ratevariant-audit/SKILL.md` and its references.
Choose among available sessions according to the question; a dedicated investigation session
is useful but not required. You judge the returned evidence rather than accepting an author's
assurance.

## Choose and request the test coverage

Ask an available Devin session to examine the actual PR diff and report the states/TICs
it targets, including changes inside shared procedures. Use that evidence to choose the
criteria and record a short rationale in the audit brief.

- Supply states and/or TICs whenever a diff targets them. This automatically provides
  coverage for neighboring cases and guardrails. For example, Ohio plus a TIC runs all
  cases including Ohio, plus any cases including that TIC: **state OR TIC**.
- Leave both lists empty to run all cases when the change applies across states/TICs or
  the examination identifies no state/TIC scope.

Ask Devin to dispatch the workflow with the selected criteria when its tools support it.
Otherwise ask it to post a comment in the fix PR's discussion, beginning with
`<!-- ratevariant-scope -->` and containing the head SHA, states, TICs, and rationale in the
[documented JSON format](https://github.com/FedTax/txc-sqlserver-database/blob/main/.claude/skills/ratevariant-testing/SKILL.md#choose-and-pass-the-case-scope),
then apply/reapply `ratevariant:run`. A fix or cases session can perform these steps;
Squadron owns evidence acceptance.

## Interpret the evidence

Require a compact report that establishes:

- Commit, selection criteria, and captures from the automatic GitHub result comment,
  together with the scope rationale and case set examined.
- Predictions from the actual diff and the affected findings’ scope, authority, and dates, followed by observed results and
  independently grounded expected values.
- Coverage and agreement across applicable cart, import, and Reports/filing paths,
  including jurisdiction/filing codes when relevant; a correct total can still file wrongly.
- Primary positives, guardrails, and an evidenced explanation for unexpected matches or
  differences. Missing coverage is not proof that a path is unreachable.
- For data changes, migration/alteration agreement, fixture prerequisites, and affected
  rows, so a probe cannot hide an overbroad change.
- Unexplained execution failures, unavailable evidence, and gaps in the affected findings.

For a limitation, require evidence of the mechanism and the scope the system cannot express.
Ask Devin to check known limitations for relevant precedent, but allow newly discovered
limitations when the evidence supports them. A matching symptom or ticket label alone is
insufficient. A scoped partial remedy must not claim to solve the general limitation.

## Finish or continue

If an answer is missing, ask an available Devin session a bounded question and let it dig
into the evidence. Missing a dedicated lane is not itself an evidence failure. Keep the
verdict and iteration counter yourself, and route corrections through `session_lane` and
`verdict_loop`.
