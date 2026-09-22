# Register a human wait with the bridge

Load this skill when blocked_run requires registration or resolution. The configured URL
is public configuration; the tool binds the secret Bearer token. Never ask a delegated work session to register
blockers or place credentials in a checkpoint, Jira comment, or tool payload.

## Register the next round of waiting

After confirming the Jira question, call save_rate_blocker with a blocker object containing:

- `blocker_id`, `ticket`, and integer `generation` from the checkpoint;
- `state: waiting`;
- `root_comment_id`, `current_question_comment_id`, and `last_processed_comment_id`;
- `resume_mission`: the mission that owns the remaining work;
- `resume_entry_stage` and `resume_inputs`: the mission inputs needed for that entry.

Build `resume_inputs` from the destination mission's declared inputs and the latest accepted
state. Include its required inputs and the context needed at the selected entry stage, using
completed task outputs and checkpoint state to update values that changed during the run.
The bridge forwards this payload; it does not recover omitted context. Because resumption
starts a new mission instance, copying only the original inputs can lose work completed since
that instance began. The destination mission owns the input contract.

Every new human wait increments generation, even when the question remains unchanged.
An uncertain registration or label update retries the same generation and payload.
The bridge must enforce one automatic ready dispatch per generation and reject stale writes.
A successful response must identify the accepted blocker ID, generation, and state; an HTTP
error or mismatched response is not registration. Keep partial checkpoint state and retry a
transient error without posting another question. Report rejected configuration or payloads.

After acceptance, remove any stale ready label and end the run. A person adds the configured
ready label when the ticket is ready to resume.
The bridge receives the next ready-label addition from Jira and starts the recorded mission
through MCP. It supplies `start_event_id`, `blocker_id`, and `blocker_generation`; it does not
choose a work session. See blocked_run for checkpoint deduplication before side effects.

## Resolve a wait

When Squadron accepts the answer, call the same tool with the same identity, generation,
comment references, and resume target/inputs, but `state: resolved`. Confirm acceptance.
Preserve the resolved generation in the checkpoint until the
case closes, so a later wait for this blocker increments it rather than reusing an old round.
Resolution is idempotent and must not resolve a newer generation.
