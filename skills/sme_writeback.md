# Writing back to the ticket

The ticket is read by support, product, and subject-matter experts — not by the engineer who
made the change. Engineering detail belongs on the PR and in the session history, which are
linked and permanent; it does not belong in the ticket comment.

## One comment, product-level

Per stage outcome, exactly one comment. It contains:

1. **The customer-facing issue as you understand it** — restated so the reader can correct you
   if you have it wrong.
2. **What was found or done** — briefly, in plain terms.
3. **What you need confirmed** — the specific question for the SME.

Name entities plainly. Include only the minimum identifiers an SME needs to act. Keep code
paths, traces, raw queries, and the engineering checklist out of it.

## Frame domain questions as questions

Where the answer depends on domain or legal judgment rather than on the system's behavior,
ask — do not assert. An asserted wrong premise gets adopted downstream and costs a full round
to unwind.

## Don't overwrite history

If a previous comment stated a conclusion you are now revisiting, annotate it as under
investigation rather than silently contradicting it. Someone has already read it and may be
acting on it.

## Never claim more than the evidence

The comment inherits `evidence_gate`: an inferred conclusion is presented as a hypothesis
with the evidence that would settle it, not as a finding.
