# Blocking on a human, and resuming

Two halves of one mechanism, and a stage may need either: **ending** a run when something only a
person can supply is missing, and **entering** a run that a previous one ended that way. Read the
entry half if you are the first stage of a run; read the rest when you hit the wall.

## If you are the first stage of a run

Before anything else, and through the session you brief (you hold no ticket credentials yourself):

1. **Clear the sentinel label** — `TaxRates:Needs-Info`, once, if it is there. It is what fired this
   run, and leaving it on means every later comment on the ticket, including the writeback this run
   is about to post, fires another one; an ordinary ticket discussion would then cost a run per
   message. Removing it is not the same as answering: only a stage that again ends blocked puts it
   back, which is what keeps the label meaning "a human owes us something".
2. **Read the answers.** The comments added since the marker in the resume-state record are the
   replies to its open questions — use the marker rather than eyeballing recency, or you re-litigate
   answers a previous run already judged insufficient. Per question: is what came back enough to
   act on? Answered means acting on it needs nothing invented — a value with its authority and
   period, an order id, a named decision. A short answer from someone who knows the domain is
   usually complete; take it and move. Ask again only when acting would require making up the part
   they left out, and then ask for exactly that part.

A resumption where nothing came back usable is not a failure: it ends again, with the questions
sharper than they were.

## End, don't wait

No stage waits for an answer. Runs are not suspendable, and a session parked on a question burns its
context re-reading itself. The stage that hits the wall names what is missing, records it, asks on
the ticket, and the run ends there.

## Two records, two audiences

Both, every time, and they are not substitutes:

- **The resume-state record** (mission memory, one file per ticket) is for the *next run*. Overwrite
  an existing file — it is current state, not history.
- **The ticket comment** is for the *human*. It is the only place anyone answers: a question sitting
  in a session's structured output, a PR comment, or the memory file reaches nobody. Every question
  the run blocked on goes in one comment, per `sme_writeback`, alongside the sentinel label.

You almost certainly hold no ticket credentials, so both are a session's to do: `send_message` the
session that already owns the context (or the one you opened for this stage), tell it what to post
and to label, and check on return that it did. A run that ends blocked without that comment leaves
the ticket sitting until somebody happens to look.

## What the record has to contain

It is an **index, not an archive**: enough for the next run to re-enter at the right point without
re-deriving, with pointers to where the substance already lives. Copying evidence in duplicates
something that will drift.

The test to apply before you stop writing: *could a run that knows only the ticket key and this file
pick up where I left off?* If a downstream stage would have to re-derive something to take its first
step, that something is missing.

- **Where it blocked** — the stage. This is what decides whether the next run re-enters downstream
  or investigates again, and it is the field most often left out.
- **The verdict and the mechanism it rests on**, one line each, with the basis label. The next run
  proceeds on this without re-proving it, so an inferred claim recorded as traced is the one error
  here that ships a wrong fix.
- **Pointers to the evidence, not the evidence** — the session ids that hold it, the PRs, the query
  or capture by name. Say which sessions can still be messaged and which are terminated: a
  resumption that messages a dead session strands itself, and one that starts fresh where a live
  session exists produces a second, disagreeing answer.
- **Which stages finished and what each produced** — the fix PR, the cases branch, the A/B result,
  so finished work is not redone.
- **The open questions**, each with the artifact that would close it and who was asked.
- **Branches and identifiers the next run would otherwise have to find** — the fix branch, the
  cases branch, the ticket-tag under which sessions were opened.
- **A marker of when this run stopped** — a timestamp, or the last ticket comment it had already
  read. The entry stage judges "the replies since the last automated review", and without this it
  cannot tell a new answer from one a previous run already found insufficient.
- **Counters the resumed stage would otherwise restart at zero** — how many audit iterations ran
  and whether they were stalling, how many times a working-as-intended conclusion has been
  re-fired. A resumed loop that forgets it is on its ninth pass will happily run nine more.
- **What is left**, in one line: where the next run picks up.

## The sentinel label

Ending a run blocked means setting `TaxRates:Needs-Info` in the same breath as the comment.
Automation fires the mission when a new comment lands on a labelled ticket, so the answer arriving is
the trigger — the comment alone waits on somebody noticing, and the label alone asks nothing. The
entry half above is the other side of this: whoever enters clears it exactly once.
