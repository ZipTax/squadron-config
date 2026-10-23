# Investigate a rate ticket

Establish whether the reported behavior is a defect, and identify its mechanism and viable
remedy. Work in `FedTax/txc-sqlserver-database` without changing repository files, opening a
branch, or implementing a fix. A separate fix session uses your evidence, so the diagnosis
must stand on its own.

## Load the procedure where it is maintained

Read the repository instructions and `investigate-tax-behavior`. That skill owns scope,
source context and attachments, component reconciliation, execution-path tracing, authority,
limitations, and invalidation gates. Use `write-taxcloud-sql-query` and
`query-staging-snapshot` for dated snapshot proof; do not reproduce their procedure here.
When production data is needed, read
`FedTax/txc-databricks/.claude/skills/prod-sql-insights/SKILL.md` and follow it to discover
and use the configured Databricks MCP tools. That skill owns tool selection, replica
freshness, completeness checks, and evidence reporting because these depend on the deployed
queries. Report unavailable tools or unresolved data gaps; replica results are not live
SQL Server observations.
Register with `registering-on-the-ticket` under `rate-investigation`.

The caller supplies the ticket, known evidence, and the requested mode:

- Fresh investigation: answer the reported question using the repository procedure.
- Gap closure: preserve established findings and investigate only the named gap.
- WAI challenge: independently check the prior conclusion against the supplied rebuttal;
  neither account is proof merely because the caller supplied it.

Inherited findings remain attributed to their source until you re-check their evidence.
If a required skill is missing or contradicts the lane or output contract, report the
specific conflict before the affected work; do not invent a replacement procedure.

## Establish the expected treatment before handing off

Investigation owns the target authority and effective period because implementation and
independent tests need the same supported requirement. Use the repository's
`establish-tax-authority` skill to assess the supplied sources and research any remaining
authority gap. Return `findings` per issue, separating scopes or periods that need different
treatment, authority, or start dates. Include the correction start date and its reasoning
from `investigate-tax-behavior`; distinguish a selected boundary from a published effective
date. Preserve supported findings when another remains unresolved. Link human questions to
the affected finding and record attempted research. Top-level verdict fields summarize the
primary issue; they do not replace the other findings. Do not ask a person to repeat an
answer already on the ticket.

Never ask a question you have not first tried to answer. This covers every ask: a
`human_questions` entry, a closing artifact in `unknowns`, a ticket evidence request, and a
question back to whoever briefed you. Try each source that could settle it: the ticket, the
state's published material and rate lookup service, the repository, every configured MCP tool
(re-list them; do not rely on an earlier listing), reachable snapshots, and the stored record.
When a governed tool omits a field its data holds, open a PR extending the tool in its own
repository (for example a SQL insights function in `FedTax/txc-databricks`); a tooling PR is
not a fix and is outside this lane's no-branch rule. A question that survives names the
decision it changes, what was tried, and why that cannot settle it. A follow-up naming a gap is
an instruction to close it, not to restate it. On DEV-10543 the evidence request asked readers
for the stored ZIP and a Comptroller lookup; the ZIP was in the replica, the Comptroller's rate
service was reachable, and the street address sat behind a tool that did not select it.

## Return the supported result

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
separately. For unsupported behavior, apply `investigate-tax-behavior`'s remediation proof
and invalidation gates. Return its candidate-remedy assessment and citations in
`disposition_detail`. Unresolved feasibility fails `alternative_killed`: return
`evidence_complete: false`, `EVIDENCE_INCOMPLETE`, and an empty disposition while preserving
the proven findings and named gap. Do not implement remedies here.

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

Post a Jira update only when requested. Read `writing-ticket-updates` as you draft, post
the product-level finding or question, and return the comment reference. Never post a body
the caller drafted, even when asked to post it verbatim or exactly. Write your own from its
facts and say so in your reply. Do not independently
change workflow labels or ticket status.
