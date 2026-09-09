# Briefing the ticket writeback

The session posts the comment — it holds the Jira credentials, and the wording is owned by its
`writing-ticket-updates` skill (shape, tone, worked bad/good pairs). Don't restate that here or in a
stage objective: prescribing prose from Squadron produces two drifting styles. Your half is
*whether* a comment is due and *what it must carry*. Do ask for it open at drafting time — a session
that read it on arrival and writes the comment an hour later writes an engineering report.

So hand over facts and questions, never a draft. "Post this verbatim" is followed over the skill,
and the body you would write is the one made of what you hold — a verdict name, a mechanism, the
queries you want run against named columns. `delegated_session` has the general form of this,
including what to require back so you find out when a session had no skill to write from;
`blocked_run` has the blocking case. It binds every stage that asks for a comment, not only one
that blocks.

## The ticket has already answered some of this

Your questions come out of the sessions you read, and those sessions may be months old while the
ticket has moved. So the session posting must read the ticket's comments through to the latest one
before it drafts, and drop or narrow whatever is already settled there. Two ways a run gets this
wrong, both of which we have shipped:

- **Asking a question the ticket already answered.** It was asked in July, an SME answered it in
  September, and the run asked it again as a blocker — so the answer reads as not having counted,
  and the ticket is blocked on a decision that exists. An answer in the comments is an answer,
  wherever the run's own state says the question stands.
- **Asking them to confirm something the ticket already retired.** Inherited session context is
  the *older* record here: a schedule the ticket corrected a year ago still lives in a session
  that predates the correction. Where the two disagree, the ticket wins, and the question worth
  asking is about the disagreement — never a request to re-confirm the version the ticket dropped,
  which tells the reader we have not read their ticket.

If reading the comments leaves nothing unanswered, there is no comment to post: say so and record
what closed each question.

## What to hand over

- **The verdict, and how strong it is.** The `evidence_gate` basis: measured/traced with gates
  passing reads as what the data shows; inferred or hedged reads as a theory and says what would
  settle it. Supplying no basis means the session hedges, and is a gate failure worth reporting.
- **Every question the run blocks on**, each naming what would answer it — the transaction ids, the
  correct rate, the treatment for a code. Ask for the ruling, never its paperwork: an SME who knows
  the treatment answers in a sentence, and demanding the statute or bulletin alongside turns that
  into an afternoon of digging and a ticket that goes quiet. A citation is welcome when it is to
  hand and is never what makes the answer count. The ticket is the only place questions get
  answered; one in structured output or a PR comment reaches nobody who holds the answer. If you
  return three, three are asked; the session may consolidate wording, never the set.
- **Whether the answer binds more than this merchant.** Configuration is per-TIC/state/jurisdiction,
  so it usually does, and that scope is what a human is actually signing off.

Don't hand over what nobody on the ticket can act on. A refused tool, unreadable session history, a
snapshot predating the order: that travels in mission output and structured output, where the
engineer weighing the change reads it. Handing it over anyway and adding "state this on the ticket"
is worse than either — the session obeys the brief over its skill, and the comment opens on our
tooling instead of the finding. A limit in what the *product* can express is the opposite —
it changes the answer available, so it belongs in the finding.

From when the corrected treatment applies is a real question for this audience, and often the second
one: it is a tax call, and the answer changes the fix. Reprocessing what already exists — re-rating
booked orders, amending filed returns — is not, however close it sounds: that only becomes a question
once the treatment and its date are settled, and engineering raises it then.

Three other things pose as blocking questions: scope beyond the ticket (sibling codes, other states —
file as work, don't ask), our own choices (a mirrored list, a naming convention, where a value
lives — the PR reviewer decides those), and evidence we can't reach ourselves. A production read-out
is the last one: real, blocking, and owed by an engineer with access, so it is a mission-output
request and never a ticket question — asking product to run a query gets silence, plus a comment
with our column names in it. One answerable question comes back answered; a project comes
back untouched.

## When

Two conditions, either one: information that is meaningfully new and needed for a product-level
understanding of the issue, or work that cannot continue without an answer. Nothing else is due.
Finishing is neither — a comment reporting the change was built, A/B'd and audited reads as a
completion report, and a treatment nobody authorized reads as approved.

When a run does end on questions, the restart label goes on in the same breath — `blocked_run` owns
that mechanic; the comment without the label waits on someone noticing, the label without the comment
asks nothing.

Whether a run can claim a settled treatment is the `evidence_gate` basis again: an unauthorized
target value is an open question, and an audit verdict is not a substitute for one.

Never claim "fixed"/"resolved" (a human merges and deploys) or attach a risk rating. And never let a
new comment silently contradict one someone may be acting on — annotate the earlier conclusion as
under investigation.
