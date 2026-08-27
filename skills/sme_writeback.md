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

## The format is fixed

Under ~100 words, plain prose, at most three short paragraphs. No headings, checklists, tables,
SQL, query output, proc/function names, file paths, or process narration — if it only makes
sense to someone reading the diff, it belongs on the PR. Open with the attribution line
verbatim, so nobody mistakes the comment for a person's:

```markdown
_This is an automated review from Devin._

<1-2 sentences: what appears to be happening, in customer/product terms.>

<1 sentence: what the proposed change would do for merchants.> Details are in <PR link> for
engineering review.

<1 sentence: the specific decision or confirmation needed from a human, if any.>
```

Write "appears", "looks like", "one likely explanation", "proposed", "pending review" — never
"confirmed", "verified", "root cause is", "this is a bug", "fixed", "resolved", or a risk
rating. You investigate and propose; a human decides. On a re-run against the same ticket, post
one short comment saying what changed and linking the same PR rather than reposting the
summary; it carries the same attribution line.

This is the same convention the `!txc-support` playbook uses, deliberately: a reader should not
be able to tell which flow produced the comment.

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
