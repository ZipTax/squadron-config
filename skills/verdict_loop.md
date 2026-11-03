# Verdict loops

A stage that sends work back identifies the finding to correct and assesses the returned
evidence. Continue while making progress; ask for help when progress stalls or information
is missing.

## Emit exactly one verdict

Pick from the stage's declared vocabulary and put it in a scalar output field, spelled as
declared — an adjacent stage's verdict is not a synonym, and a router given one routes nowhere.
The router reads that field; prose is not routable. Verdicts split three ways:

- **terminal-good** — the stage's goal is met; downstream stages may proceed.
- **terminal-bad** — the goal cannot be met and a human decision is required; stop and
  escalate with what turns on it.
- **routed-back** — a specific, named deficiency in a specific lane; loop.

A routed-back verdict must name the lane, the deficiency, and the evidence that establishes
it (see `session_lane`, `delegated_session`). "Needs more work" is not a verdict.

## Assess progress

- Continue corrections when new evidence or a concrete next step can advance the work.
- When progress stalls or required information is missing, ask the operator with the
  unresolved finding, what was tried, and what would unblock it.
- Preserve the supported verdict and open items while waiting for direction.

## Never launder a failure into a pass

Pressure to finish can lead to accepting a hedge. `evidence_gate` forbids it: an unproven claim
cannot support a terminal verdict. Escalating an honest incomplete costs one human read;
a laundered pass costs a bad change in production.

## Disagreement between stages

When two stages reach opposite conclusions, re-run the question once with the counter-evidence
attached — stated as a challenge, not as the answer, since either side may be wrong. If they
disagree a second time, stop and hand the standoff to a human: both positions, what each
turns on, and the evidence each rests on. Do not re-fire further.
