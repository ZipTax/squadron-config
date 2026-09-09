# Working through a delegated session

You have no repository, database, or issue-tracker credentials. Every side effect — git
operations, PR comments, labels, queries, ticket comments — happens inside a Devin session.
You instruct and you reason; the session acts.

Consequences to internalize:

- **Never claim you did something.** You asked a session to do it and it reported back.
- **Never treat your own expectation as a result.** If the session didn't report it, it
  didn't happen; ask.
- **Anything you know that the session needs, you must say.** It does not read your
  objective, your prior turns, or another session's output.

## Create once, resume after

`code_develop` creates a session and returns its id — capture it into your output the turn
you get it. To continue that work, `send_message(session_id, …)`; the session sleeps between
messages, keeps its branch and context, and costs nothing while idle.

Do **not** open a second session for the same work. A new session re-derives context, may
open a duplicate branch or PR, and loses everything the first one learned. One session owns
one lane for the life of the case (see `session_lane`).

Pass `title` (ticket key and PR number first, so the case is identifiable) and `tags` (the
ticket key plus the stage, so every session a case spawned can be listed later).

And tell it to register itself on the ticket: read the ticket's **Devin Sessions** field and write
it back carrying `<stage tag>: <its session url>`, as its first action. It is an upsert keyed on
the stage tag — a session continuing a stale one replaces that stage's line rather than adding a
second, because two urls under one tag leave the next run messaging the dead session; every other
line survives untouched. The field is `customfield_11724`, rich text: it is written as ADF, one
paragraph per line, and rejects a plain string. You cannot do this yourself and neither can the
stage that routed to you — only the session holds Jira credentials, and only it knows its URL. It is
what makes the ticket an index of its own sessions, which is the one place a later run can look
that does not depend on the Devin API letting us list sessions at all (see below). A session that
skips it is invisible to the next run and gets its work re-derived.

`prompt_mode` decides what the session is told to do beyond your task. The default appends the
create-a-branch / add-tests / commit / open-a-PR workflow, which is right for exactly one kind
of stage: the one that authors the fix. For a read-only stage, or a stage that must push to a
branch and PR that already exist, pass `prompt_mode: "raw"` — otherwise the session is under
instruction to do the thing you are telling it not to do, and prohibitions in your task text
are then arguing with its prompt. In `raw` mode your task is the entire prompt, so it carries
everything, including the prohibitions.

## Finding the sessions a case already has

Two indexes, and they fail differently.

The ticket's **Devin Sessions** field is the one that works: every session registers itself there
when it starts, and reading the field needs nothing but permission to view the issue. It names
only sessions that registered — so nothing from before the field existed, and nothing a human
opened by hand.

`find_sessions(tags: ["<TICKET>"])` covers exactly that remainder, because every session is also
tagged with the ticket key: it returns each session's id, status, title and PR links, and adding
the stage tag (`["<TICKET>", "rate-investigation"]`) asks about one lane. But listing sessions is
an organization-wide read, and our key is refused it more often than not — so treat the search as
a supplement that may simply not answer, and never as the thing your run depends on. Both read
only; neither returns structured output, so `check_session` is still what tells you what a session
concluded.

A refusal is not an empty history. "The search was refused" and "this ticket has no sessions" are
different findings, and reporting the first as the second is how a run abandons live work.

Search before you create. A tagged session that already answered the question makes a new one
pure cost: it re-reads the ticket, re-derives the context, and can reach a different answer for
no reason other than being asked twice. Zero matches is a real answer — nothing was started, so
starting is right.

Two things a search result does not settle, and `check_session` does: whether a session that
looks finished actually reached a verdict, and whether one that opened a PR opened the PR *for
this ticket's fix*.

**Several matches for one lane is the normal case, not an anomaly** — a re-fired ticket, a run
that blocked, a session someone started by hand. Pick with this order, and only among sessions
that are actually that lane (check the stage tag, not just the ticket):

1. **Messageable beats finished.** A session you can still send to is worth more than one that
   concluded and closed, because you can question it. Where two are messageable, take the one
   that got furthest — the later state, the PR, the verdict — not the newest.
2. **Among unmessageable ones, take the one that reached a conclusion**, and inherit it as a
   report (see below). A terminated session that concluded nothing is context, not an answer.
3. **Never merge two sessions' findings into one story.** They may disagree, and the disagreement
   is information. Choose one as the lane's session and cite the other as a second opinion,
   naming which session each claim came from.

Say which you chose and why you passed over the others. A later stage inherits your choice
without re-searching, so an unexplained pick is one nobody downstream can correct.

## When a session cannot be messaged

A terminated or archived session is readable but not messageable, and a stage can inherit one:
a verdict may be carried forward from a session that is already closed. Where a stage passes an
id on, it passes a `session_messageable` flag with it, and a false flag changes what you may do
with that id — not just how you send to it:

- Do not send. The failure lands at the point of use, halfway through a run, which is the worst
  time to discover it.
- Its report is the whole record. Treat every claim in it as inherited, not as something you
  can question or have re-checked.
- Do not pass a gate on the strength of a report you cannot question. Either get the specific
  missing evidence from a session that *is* open and holds the same context, or — if none does —
  open one deliberately for that gap, or return the incomplete-evidence verdict naming it.
- Carry the flag onward. The next stage messages this session too.

And one thing the stage that *notices* has to do rather than pass along: if the dead session owned
a lane someone downstream must be able to act on — the fix, the cases — that lane needs a living
owner established before the stage that routes work to it starts. A stage forbidden from opening
sessions cannot rescue itself, and it discovers the problem at the moment it has a finding and
nowhere to send it. Establishing ownership belongs where the lanes are assigned, not where the
work arrives.

## Reading a session's result

`check_session(session_id)` returns status, messages, PR links, and structured output. Use
it when a tool response arrived without the session's message, and after every
`send_message` round.

Two responses that are not failures: *"Devin returned an error in messaging"* — read the
session at its URL; *"Devin did not return a message"* — the work may still have landed,
so `check_session` before concluding anything.

A session that reports a conclusion with no basis has failed the `evidence_gate`, and the
remedy is another `send_message` naming the exact evidence wanted — not your own guess in
its place.

## Re-briefing format

Every `send_message` that routes a finding carries all three:

1. **Finding** — one sentence, what is wrong.
2. **Evidence** — the values that prove it: expected vs actual, the capture, the rows.
3. **Location** — file plus symbol, or the exact artifact to change.

Plus the boundary: *apply only this; do not re-implement prior work; push to the existing
branch.* A bare file reference forces the session to re-derive your reasoning and it will
often re-derive it differently.
