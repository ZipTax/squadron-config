# Verdict loops

A stage that can send work back must exit on a named verdict, within a stated bound. An
unbounded "keep improving" loop burns the run and ends in a hedge.

## Emit exactly one verdict

Pick from the stage's declared vocabulary and put it in a scalar output field. The router
reads that field; prose is not routable. Verdicts split three ways:

- **terminal-good** — the stage's goal is met; downstream stages may proceed.
- **terminal-bad** — the goal cannot be met and a human decision is required; stop and
  escalate with what turns on it.
- **routed-back** — a specific, named deficiency in a specific lane; loop.

A routed-back verdict must name the lane, the deficiency, and the evidence that establishes
it (see `session_lane`, `delegated_session`). "Needs more work" is not a verdict.

## Bound the loop

- State the iteration cap in the objective and count iterations in an output field.
- Each iteration must consume new evidence. If an iteration would send the same message
  again, the loop is stuck: exit terminal-bad and say what is stuck.
- On hitting the cap, exit terminal-bad with the open items — never upgrade to
  terminal-good to close out the run.

## Never launder a failure into a pass

The pressure at the cap is to accept a hedge. `evidence_gate` forbids it: an unproven claim
cannot support a terminal verdict. Escalating an honest incomplete costs one human read;
a laundered pass costs a bad change in production.

## Disagreement between stages

When two stages reach opposite conclusions, re-run the question once with the counter-evidence
attached — stated as a challenge, not as the answer, since either side may be wrong. If they
disagree a second time, stop and hand the standoff to a human: both positions, what each
turns on, and the evidence each rests on. Do not re-fire further.
