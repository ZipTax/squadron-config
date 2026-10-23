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

Before each run, inspect the actual diff at the current PR head and decide whether its
state/TIC boundary is reliable. You own that risk decision; ask Devin for technical evidence
when needed. Use the ticket as context, not as proof that the implementation is contained.

- Supply states and/or TICs when the diff preserves an explicit boundary, such as inserting
  matrix rows for named states and products. Selection is **state OR TIC**: Ohio plus a TIC
  runs Ohio cases for other TICs and that TIC's cases in other states.
- Leave both lists empty to run all cases when scope is uncertain, shared calculation
  behavior changes, or a state/TIC boundary itself changes.
- Keep required positives and guardrails in the executed set. Check the selection report;
  if a required guardrail is excluded, broaden the criteria or run all. New/modified cases
  and cases with unknown coverage remain included by the repository's selection rules.

Record the head SHA, selected states/TICs (or all), and a short rationale grounded in the
diff. Explain what makes the boundary reliable and what regression coverage is excluded;
a scoped pass does not establish behavior outside its selected coverage. After any push,
reassess the decision and issue a request for the new head rather than reusing stale scope.

Use the current `ratevariant-testing` skill for the run request contract. If the available
Devin session can dispatch the workflow, delegate dispatch with the approved criteria.
Otherwise have it write the structured, current-head scope request and apply/reapply
`ratevariant:run`. The label alone does not carry the criteria. Delegating those mechanics
to a fix or cases session does not transfer your risk decision or verdict to its author.
Never ask the session to run staging-mutating harness commands itself.

Check that the result comment records the requested criteria and current head before using
its captures. Reuse evidence only when both head and executed coverage satisfy the current
audit; request all cases if the evidence reveals effects beyond the chosen boundary.

## Interpret the evidence

Require a compact report that establishes:

- PR head, plan/run references, selection criteria/rationale, and the case set examined,
  so an older run cannot approve a newer change.
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
