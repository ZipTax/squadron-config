# Investigate a rate ticket

Establish whether the reported behavior is a defect, and identify its mechanism and viable
remedy. Work in `FedTax/txc-sqlserver-database` without changing repository files, opening a
branch, or implementing a fix. A separate fix session uses your evidence, so the diagnosis
must stand on its own.

## Load the procedure where it is maintained

Read the repository instructions and `investigate-tax-behavior`. That skill owns scope,
source context and attachments, component reconciliation, execution-path tracing, authority,
limitations, and invalidation gates. Use `write-taxcloud-sql-query` and
`query-staging-snapshot` for database proof; do not reproduce their procedure here.
Register with `registering-on-the-ticket` under `rate-investigation`.

The caller supplies the ticket, known evidence, and the requested mode:

- Fresh investigation: answer the reported question using the repository procedure.
- Gap closure: preserve established findings and investigate only the named gap.
- WAI challenge: independently check the prior conclusion against the supplied rebuttal;
  neither account is proof merely because the caller supplied it.

Inherited findings remain attributed to their source until you re-check their evidence.
If a required skill is missing or contradicts the lane or output contract, report the
specific conflict before the affected work; do not invent a replacement procedure.

## Return a result Squadron can route

Use the attached structured-output schema, including its gate results and evidence citations.
Keep the question-matched verdict and explain its mapping to exactly one routing verdict:

| Routing verdict | Required support |
| --- | --- |
| `DEFECT_PROVEN` | Measured or traced mechanism establishes incorrect or unsupported requested behavior. |
| `WORKING_AS_INTENDED` | Positive evidence establishes correct behavior, including the decomposed value or a precluding condition. Failure to reproduce alone does not qualify. |
| `EVIDENCE_INCOMPLETE` | A load-bearing claim remains inferred or unknown; name the artifact that would settle it. |

On a multipart ticket, report each part; the primary part drives routing without hiding the
others. Use `data/configuration change`, `procedure/function change`, `both`, or
`unsupported at available granularity` for a proven defect's disposition. `both` preserves
a remedy that needs data and code; report both even though the repository skill lists them
separately. For unsupported behavior, identify the proven limitation and whether a scoped
partial fix is feasible and accurate throughout its scope. Do not implement it here.

Snapshot evidence establishes behavior in that dated copy, not current production state.
A proven local mechanism can proceed with a bounded production verification query in
`unknowns`; an unproven production claim stays unproven. When governed production access is
available, record observations in `production_evidence` using the attached schema: status,
query reference, time, catalog objects, bounded scope, conclusion, and ticket gap outcome.
Distinguish no matching rows, missing history, refused access, and truncated output. Keep
raw results in the evidence source. Production observations do not replace SQL Server proof.

Return `outcome: needs_human` with exact question-and-context pairs in `human_questions`
only when a person's answer is necessary to reach a supported result. Otherwise return
`completed`, an empty `human_questions`, and non-blocking questions in `unknowns`.
Return available findings instead of waiting for a person.

Squadron chooses when a Jira update is needed. When asked, read `writing-ticket-updates`
as you draft, post the product-level finding or question, and return the comment reference.
Do not independently change workflow labels or ticket status. Squadron owns the blocker
and next entry; a session report alone does not notify the person who must answer.
