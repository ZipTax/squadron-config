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

`prompt_mode` decides what the session is told to do beyond your task. The default appends the
create-a-branch / add-tests / commit / open-a-PR workflow, which is right for exactly one kind
of stage: the one that authors the fix. For a read-only stage, or a stage that must push to a
branch and PR that already exist, pass `prompt_mode: "raw"` — otherwise the session is under
instruction to do the thing you are telling it not to do, and prohibitions in your task text
are then arguing with its prompt. In `raw` mode your task is the entire prompt, so it carries
everything, including the prohibitions.

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
