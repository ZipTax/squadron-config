# Capture reusable learning

## Ask for discoveries from the work actually performed

Ask the Devin sessions that did the work whether they encountered anything difficult to
discover and worthwhile to preserve for a future case. Their working context contains the
failed approaches, unexpected constraints, and decisive evidence that a summary may omit.
Do not infer lessons from a PR diff, an action-item list, or a ticket outcome alone.

Use `delegated_session`: follow up with `send_message`, then collect the response with
`check_session`. Include the ticket and the session's part of the work, and make the request
read-only. Ask for no quota; “nothing worth recording” is a complete answer.

For each proposed lesson, ask Devin to explain:

- What it discovered during its own work and what made that discovery difficult.
- Which evidence established the finding and the conditions where it applies.
- What a future maintainer would do differently and why that would save meaningful effort
  or prevent a consequential mistake.
- Whether the relevant skills or references already explain it, and what is missing if so.

Ask for the session's findings without suggesting a lesson it should endorse. Use a bounded
follow-up when a proposal lacks support. Do not commission a fresh investigation merely to
produce learning material. If a session is unavailable, use only lessons it explicitly
proposed in its recorded report, retain that attribution, and disclose the unavailable
response. An unavailable session is not a session that reported no lessons.

## Assess the candidate and destination

Accept a proposal only when Devin's answers establish difficulty, cited evidence, future
value, and a gap in maintained guidance. Clarify a missing answer; reject routine fixes,
obvious facts, generic advice, or duplicate guidance. Keep explanations of one PR's changes
and unresolved checks with that PR or session rather than creating a ticket document.

Select the owning repository and relevant maintained guidance from the proposal. Use the
rate-learning-writeback playbook's destination rules; a ticket disposition alone does not
justify an entry or establish an engine deferral.

## Separate a supported lesson from unfinished work

A lesson summarizes established evidence; it does not choose an unresolved implementation
value. If correctness still depends on tracing a consumer, deciding between configuration
values, or running missing proof, report the gap and its consequence. Do not turn a request
for learning into instructions to change SQL, migrations, tests, or ticket registration.
Changing those artifacts can invalidate the evidence on which the lesson would rest.

Clarify existing evidence read-only when needed. If proving a proposed lesson requires new
implementation or acceptance testing, leave it unrecorded and report the missing proof.

## Delegate only accepted writebacks

For an accepted proposal, use delegated_session and devin_code to start a separate session
with `!rate-learning-writeback` and `prompt_mode: "raw"`. Supply the ticket, originating
session, accepted finding, evidence references, intended future use, destination repository
and guidance files, base branch, and any existing documentation PR. The new session does
not inherit that context. Continue an existing writeback through send_message instead of
creating another session or PR.

The playbook owns documentation scope, destination checks, writing style, and delivery.
Let Devin author the prose. Collect its structured result and assess the actual diff:

- `recorded`: accept only the supplied lesson, supported by cited evidence, in a documentation PR.
- `already_documented`: verify the cited guidance covers the lesson; no new document is needed.
- `blocked`: report the failed step and what is needed, without treating failure as no lessons.

Return specific deficiencies for revision. Report the work sessions asked, their proposals
or explicit “none” responses, unavailable responses, and the writeback outcome. If no proposal
qualifies, finish without starting a writeback.
