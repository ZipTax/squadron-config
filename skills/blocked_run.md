# Ending a run on a human, and resuming it

Load this when a stage runs out of things it can do without a person: an answer only an SME has, a
value only a published source settles, a decision only an owner can make. It covers how a run ends,
how the human is asked, and how the next run picks up instead of starting over. Any stage can be the
one that ends a run, so any stage can need this.

## End, don't wait

No stage waits for an answer. Runs are not suspendable, and a session parked on a question burns its
context re-reading itself. The stage that hits the wall names what is missing, records it, asks on
the ticket, and the run ends there.

Ending is not failing. A run that ends with the question sharpened — "which rate applied in Cook
County in June, and from what notice" instead of "rates look wrong" — has done the work that makes
the next one short.

## Two records, two audiences

Both, every time, and they are not substitutes:

- **The open-items file** (mission memory, one file per ticket) is for the *next run*. What is
  outstanding, which stages already finished and where their PRs are, which sessions exist and
  whether each can still be messaged, and where to pick up. Overwrite an existing file — it is
  current state, not history. Whatever you leave out is what somebody re-derives.
- **The ticket comment** is for the *human*. It is the only place anyone answers: a question sitting
  in a session's structured output, a PR comment, or the memory file reaches nobody. Every question
  the run blocked on goes in one comment, per `sme_writeback`.

You almost certainly hold no credentials for the ticket, so the comment is a session's to do:
`send_message` the session that already owns the context (or the one you opened for this stage), tell
it what to post, and check on return that it did. A run that ends blocked without that comment has
asked nobody anything.

## The sentinel label

Alongside the comment, the session labels the ticket `TaxRates:Needs-Info`. That label — not the
comment, and not the memory file — is what gets the run restarted: automation fires the mission when
a new comment lands on a ticket carrying it.

The load-bearing rule is the removal. **The first session a run briefs removes the label before it
does anything else, exactly once.** Without that, every later comment on the ticket — including the
writeback that run is about to post — fires another run, and an ordinary ticket discussion costs a
mission per message. Only a stage that again ends blocked re-adds it, which is what makes the label
mean "a human owes us something" rather than "this ticket is in the flow".

## Reading the answer

The session that can read the ticket judges whether the answer is usable, because it is the one that
knows what its next step needs. Per open question: answered, or still open. Answered means it can be
acted on without a second guess — a value with its authority and period, an order id, a named
decision. A reply that only restates the direction of the problem leaves the question open.

That judgment is about *sufficiency for the next step*, not about how the human phrased it. A short
answer from someone who knows the domain is often complete — if it names the thing that was missing,
take it and move. Ask again only when acting on it would require inventing the part they left out,
and then ask for exactly that part rather than re-asking the whole question.

## Blocked where

Record which stage the run stopped at, not just what is missing. It is the difference between a
resumption that re-enters the flow at the right lane and one that re-runs finished work: a ticket
blocked in case authoring does not need another investigation, and the stage that blocked is usually
the stage that should be handed the answer.
