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

## Interpret the evidence

Require a compact report that establishes:

- PR head, plan/run references, and the case set examined, so an older run cannot approve
  a newer change.
- Predictions from the actual diff and requirement, followed by observed results and
  independently grounded expected values.
- Coverage and agreement across applicable cart, import, and Reports/filing paths,
  including jurisdiction/filing codes when relevant; a correct total can still file wrongly.
- Primary positives, guardrails, and an evidenced explanation for unexpected matches or
  differences. Missing coverage is not proof that a path is unreachable.
- For data changes, migration/alteration agreement, fixture prerequisites, affected rows,
  and teardown scope, so a probe cannot hide an overbroad change.
- Unexplained execution failures, unavailable evidence, and unresolved target authority.

For a limitation, require evidence of the mechanism and the scope the system cannot express.
Ask Devin to check known limitations for relevant precedent, but allow newly discovered
limitations when the evidence supports them. A matching symptom or ticket label alone is
insufficient. A scoped partial remedy must not claim to solve the general limitation.

## Finish or continue

If an answer is missing, ask an available Devin session a bounded question and let it dig
into the evidence. Missing a dedicated lane is not itself an evidence failure. Keep the
verdict and iteration counter yourself, and route corrections through `session_lane` and
`verdict_loop`.
