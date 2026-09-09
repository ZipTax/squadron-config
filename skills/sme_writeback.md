# Briefing the ticket writeback

The session posts the comment — it holds the Jira credentials, and the wording is owned by its
`writing-ticket-updates` skill (shape, tone, worked bad/good pair). Don't restate that here or in a
stage objective: prescribing prose from Squadron produces two drifting styles. Your half is
*whether* a comment is due and *what it must carry*.

## What to hand over

- **The verdict, and how strong it is.** The `evidence_gate` basis: measured/traced with gates
  passing reads as what the data shows; inferred or hedged reads as a theory and says what would
  settle it. Supplying no basis means the session hedges, and is a gate failure worth reporting.
- **Every question the run blocks on**, each naming the artifact that answers it — the transaction
  ids, the expected rate and its published authority, the merchant configuration. The ticket is the
  only place questions get answered; one in structured output or a PR comment reaches nobody who
  holds the answer. If you return three, three are asked; the session may consolidate wording, never
  the set.
- **Whether the answer binds more than this merchant.** Configuration is per-TIC/state/jurisdiction,
  so it usually does, and that scope is what a human is actually signing off.

Don't hand over what nobody on the ticket can act on. A refused tool, unreadable session history, a
snapshot predating the order: that travels in mission output and structured output, where the
engineer weighing the change reads it. A limit in what the *product* can express is the opposite —
it changes the answer available, so it belongs in the finding.

From when the corrected treatment applies is a real question for this audience, and often the second
one: it is a tax call, and the answer changes the fix. Reprocessing what already exists — re-rating
booked orders, amending filed returns — is not, however close it sounds: that only becomes a question
once the treatment and its date are settled, and engineering raises it then.

Two other things pose as blocking questions: scope beyond the ticket (sibling codes, other states —
file as work, don't ask), and our own choices (a mirrored list, a naming convention, where a value
lives — the PR reviewer decides those). One answerable question comes back answered; a project comes
back untouched.

## When

Rarely. A run says why, once, and asks what it needs — that is the comment. Everything after it is
only due if something a reader was told is now wrong, or work hit something they have to resolve.
Finishing is neither: a comment reporting the change was built, A/B'd and audited reads as a
completion report, and a treatment nobody authorized reads as approved.

When a run does end on questions, the restart label goes on in the same breath — `blocked_run` owns
that mechanic; the comment without the label waits on someone noticing, the label without the comment
asks nothing.

Whether a run can claim a settled treatment is the `evidence_gate` basis again: an unauthorized
target value is an open question, and an audit verdict is not a substitute for one.

Never claim "fixed"/"resolved" (a human merges and deploys) or attach a risk rating. And never let a
new comment silently contradict one someone may be acting on — annotate the earlier conclusion as
under investigation.
