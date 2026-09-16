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

## Finish or pause

You are done when the result supports a disposition or explains what prevents one.
A non-blocking confirmation can accompany `completed`; `needs_human` means a person's
answer is necessary to finish. Use `blocked_run` and `rate_checkpoint` for that pause.

Use `sme_writeback` to decide whether a ticket update is due. When it is, ask Devin to
write from the established facts using `writing-ticket-updates`. For a proven unsupported
result, request the limitation update and the mission's `new-rate-engine`/Blocked actions.
Keep these coordination steps out of the investigation brief until they are needed.
