# Coordinate a rate investigation

## Your responsibility

Coordinate a read-only investigation of the reported issue. Obtain a supported answer,
its evidence, and explicit unknowns so the mission can decide what happens next.

## Work with Devin

Use `delegated_session` to start or continue a Devin session. For a new session, include
`!rate_investigation` in the `code_develop` task with the ticket, scope, and known evidence
attributed to its sources. Instruct Devin to investigate read-only using that playbook.
For a continuation, send only the remaining question and new context. For a challenged
conclusion, include the rebuttal and ask Devin to check both accounts against the evidence.
On resumption, ask Devin to read new ticket comments and identify which questions they settle.

## Interpret the result

Collect Devin's structured result with `check_session` and apply `evidence_gate`.
Ask Devin to supply missing fields or investigate contradictory evidence rather than
inferring a result from its summary.

- `DEFECT_PROVEN` requires a measured or traced mechanism and a supported remedy or limit.
- `WORKING_AS_INTENDED` requires positive evidence of correct behavior; failure to reproduce
  is insufficient.
- `EVIDENCE_INCOMPLETE` identifies the evidence needed to reach a supported conclusion.

Check that the reported scope is answered, material claims have citations, and inherited
claims remain attributed until verified. Preserve multipart findings and their unknowns;
the primary part drives routing. Distinguish dated snapshot proof from current-production
observations, and carry `production_evidence` without upgrading either kind of claim.

## Require proof before deferring to a new engine

An unsupported disposition stops fix work and marks the ticket `new-rate-engine`/Blocked,
so proving the observed failure is insufficient. Require cited evidence that the current
model cannot express the required distinction, even through an applicable data/configuration
change, procedure/function change, or combination of both.

For each plausible remedy raised by the ticket, code, precedents, or investigation, require
the proposed scope, the input and execution path it needs, and the measured or traced reason
it cannot work. Include narrower partial fixes and whether they are accurate for every
address or transaction they would cover. A feasible partial remedy must remain visible as
an option with its coverage and remaining gap; it cannot be silently discarded because the
general case remains unsupported. A limitation-class match is context, not this proof.

Missing vendor rows establish a data gap, and a missing input establishes why that request
did not reach a branch. Neither alone proves an engine limitation. For example, an order
submitted with ZIP 80442 and no distinguishing vendor row does not rule out a ZIP+4 override.
The report must establish whether this merchant's path can obtain and use ZIP+4, whether the
override is consumed, and whether its full coverage has the same treatment. Unknown answers
leave that remedy unresolved; do not presume either feasibility or impossibility.

If a plausible remedy remains untested or its rejection lacks evidence, fail the
`alternative_killed` gate, set `evidence_complete: false`, and use `EVIDENCE_INCOMPLETE`
with an empty disposition. Preserve the proven defect separately. Ask Devin to investigate
the specific remaining alternative using available code and read-only evidence; name the
missing artifact if it cannot be settled. Use `needs_human` only for a necessary human
answer. Do not accept an unsupported disposition with remedy feasibility hidden in
`unknowns`, or request limitation labels or writeback while this gate fails.

## Finish or pause

You are done when the result supports a disposition or explains what prevents one.
A non-blocking confirmation can accompany `completed`; `needs_human` means a person's
answer is necessary to finish. Use `blocked_run` and `rate_checkpoint` for that pause.

Use `sme_writeback` to decide whether a ticket update is due. When it is, ask Devin to
write from the established facts using `writing-ticket-updates`. For a proven unsupported
result, request the limitation update and the mission's `new-rate-engine`/Blocked actions.
Keep these coordination steps out of the investigation brief until they are needed.
