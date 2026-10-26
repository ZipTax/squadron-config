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

Use the fix session's `impact_radius` report and the PR description's `Impact radius`
section as the basis for each run. Accept or adjust its coverage recommendation and record
the reason in the audit brief. Ask the fix owner to update the assessment when an audit
finding changes the implementation or reveals a different scope; reuse the maintained
assessment between changes.

Ask a fix or cases session to dispatch the workflow with the chosen criteria using
[ratevariant-testing](https://github.com/FedTax/txc-sqlserver-database/blob/main/.claude/skills/ratevariant-testing/SKILL.md#choose-and-pass-the-case-scope),
which owns the state/TIC selection rules and run mechanics. If the session cannot dispatch,
use its reported tool or permission limitation to arrange execution through an operator
with workflow access. Squadron owns evidence acceptance.

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
