# Capture reusable learning

## Ask for discoveries from the work actually performed

Ask the Devin sessions that did the work whether they encountered anything difficult to
discover and worthwhile to preserve for a future case. Their working context contains the
failed approaches, unexpected constraints, and decisive evidence that a summary may omit.
Do not infer lessons from a PR diff, an action-item list, or a ticket outcome alone.

Use `delegated_session`: follow up with `send_message`, then collect the response with
`check_session`. Include the task context and the session's part of the work, and make the
request read-only. Ask for no quota; “nothing worth recording” is a complete answer.

Ask for a concrete future decision or action, its conditions, and the mistake it prevents.
Include product or tool mechanics only when they change that action; one evidence reference
per lesson is enough. A description of work performed is not a lesson.

For each proposed lesson, ask Devin to explain:

- What the product does that was hard to discover, and why it was hard.
- When it applies: the state, seller, or order conditions.
- What a future session would do differently, and the mistake or effort that saves.
- Whether existing guidance already covers it.

Ask for the session's findings without suggesting a lesson it should endorse. Use a bounded
follow-up when a proposal lacks support. Do not commission a fresh investigation merely to
produce learning material. If a session is unavailable, use only lessons it explicitly
proposed in its recorded report, retain that attribution, and disclose the unavailable
response. An unavailable session is not a session that reported no lessons.

## Collect without composing a second brief

Check the recorded investigation, fix, ratevariant-cases, and Bruno owners, including any
independent verification session that worked on the case. Ask each distinct available session;
record explicit “none” and unavailable responses separately. Do not silently omit investigation.
Squadron owns the A/B audit, not a Devin audit session: include its recorded audit findings as
source material, with attribution, rather than asking for a nonexistent session.

Pass the responses unchanged, or provide accessible references to their full text, with their
source sessions and evidence. Do not merge them into “accepted lessons,” rewrite them into
technical narratives, or prescribe entries and destinations. Devin's writeback playbook owns
selection, deduplication, evidence checks, and editing for the next maintainer. If all sources
report no candidates, finish without starting a writeback.

## Delegate collection to one writeback owner

Use one Devin writeback session for the ticket, covering the collected proposals across
repositories. Recover and reuse an existing writeback session before starting one; save its ID in the checkpoint's
`learning-writeback` lane. Send later lessons and revision requests to that session through
`send_message`.

When none exists, use delegated_session and devin_code with the task-supplied writeback playbook
and `prompt_mode: "raw"`. Supply the source responses and Squadron audit findings, their
attribution and evidence, destination repositories, base branches keyed by repository, and the
ticket's existing documentation PRs; do not supply documentation PRs from other tickets.
The new session does not inherit that context. If the owner is unavailable, recover its work
before replacing it; do not start parallel writeback sessions for the same ticket.

## Review the result without expanding it

Read the returned diffs as instructions for a future maintainer. Check that each amendment
changes a useful action or decision, preserves necessary conditions, and is supported by the
linked evidence. A shorter account of the ticket is not enough.

- `recorded`: verify the PRs and review the actual amendments, not just the session's summary.
- `already_documented`: verify the cited guidance covers the proposals.
- `not_worth_recording`: accept a supported explanation that no proposal adds useful guidance.
- `blocked`: report the failed step and what is needed; do not treat failure as no lessons.

Return specific deficiencies to the same owner. Ask it to remove repetition, narrow unsupported
claims, or explain why a new section cannot amend existing guidance. Do not re-inject omitted
code traces, run history, or broader scope simply because they appeared in a source response.
Request a detail only when its absence makes the instruction wrong or unusable. Do not reopen
implementation or acceptance testing to manufacture a lesson.

Report which sources were asked, response references, explicit “none” or unavailable responses,
and the writeback outcome. No worthwhile lesson is a successful outcome.
