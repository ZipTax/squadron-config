# Writing back to the ticket

The ticket is read by support, product, and subject-matter experts — not by the engineer who
made the change. Engineering detail belongs on the PR and in the session history, which are
linked and permanent; it does not belong in the ticket comment.

One comment per stage outcome: a couple of sentences of plain product language, the PR link for
engineering review, and whatever a human still has to decide. Under ~100 words, opening with
the attribution line verbatim so nobody mistakes it for a person's:

```markdown
_This is an automated review from Devin._

<1-2 sentences: what appears to be happening, in customer/product terms.>

<1 sentence: what the proposed change would do for merchants.> Details and the code are in
<PR link> for engineering review.

<1 sentence: the specific decision or confirmation needed from a human, if any.>
```

> _This is an automated review from Devin._
>
> For merchant 12345, PA orders with TIC 40030 look like they are picking up the state rate
> without the county portion, which would explain the lower tax on the orders in the
> attachment. The proposed change would apply the county rate to these orders going forward;
> details and the SQL are in FedTax/txc-sqlserver-database#456 for engineering review. Someone
> on the tax side should confirm the county rate is expected to apply here before this ships.

That wording and example are lifted from the `!txc-support` playbook's Step 6 deliberately, and
stay in sync with it: a reader should not be able to tell which flow produced the comment. The
session posts it (it holds the Atlassian credentials, via `addCommentToJiraIssue` with
`contentFormat: "markdown"`); a mission stage only decides *when* one is due.

If it only makes sense to someone reading the diff — a proc name, a query, a trace, what was
ruled out — it belongs on the PR. No risk ratings. On a re-run against the same ticket, one
short comment saying what changed, linking the same PR.

## Certainty is an input, not a house style

This skill tailors *language*; the calling stage says how strong the finding is (the
`evidence_gate` basis behind it) and the comment is written to match. Rendering a traced,
gate-passing finding as a guess is as wrong as rendering a theory as a fact — the first gets
ignored, the second gets acted on. So: measured/traced with the gates passing reads as what the
data shows; anything inferred or hedged keeps "appears" / "one likely explanation" / "pending
review" and says what would settle it; and where the question turns on tax or legal judgment,
ask regardless of basis — the system's behavior is yours to establish, what is *correct* is the
SME's. No basis supplied means hedge, and is worth reporting upstream as a gate failure.

Where the gap is evidence someone else holds, ask for the specific artifacts rather than for
confirmation in general — the calling stage's `unknowns` already names them, so pass them
through: the transaction or order ids, the rate they expected with the authority behind it, the
effective date, the merchant configuration. "Please confirm" comes back in a week meaning
nothing; "were these three orders expected at 7.975%, and from which notice?" comes back
usable.

## The ticket is the only place questions are asked

Every question a run blocks on goes in the ticket comment — all of them, in one comment, each
naming the artifact that answers it. A question that exists only in a session's structured output
or a PR comment does not get answered, because nobody who has the answer is reading either. If a
stage returned three questions, the comment carries three; consolidate wording, never the set.

Don't route them. No @-mentions, no naming who should answer, no severity — bandwidth on the tax
side is scarce and a human decides who to pull in. Say what is needed and from what authority; the
ticket's watchers do the rest.

When the run is ending on those questions, label the ticket `ratevariant:awaiting-info` in the same
breath. That label is the resume trigger (see the mission's resumption contract) — the comment
without it asks a question nobody will act on, and the label without the comment asks nothing.

Two claims are never the comment's regardless of basis, because they are lifecycle facts owned
elsewhere: that something is "fixed"/"resolved" (a human merges and deploys), and any risk
rating.

## Don't overwrite history

If a previous comment stated a conclusion you are now revisiting, annotate it as under
investigation rather than silently contradicting it. Someone has already read it and may be
acting on it.
