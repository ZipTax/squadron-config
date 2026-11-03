# Hand off a rate case

Use `rate_checkpoint` to read and write the shared case. Squadron accepts and records
results; Devin supplies the underlying reports.

## Enter work

1. Read the current case before briefing a session, so it receives the latest accepted work.
2. Recover missing context from supplied inputs and recorded reports. Preserve established
   findings when an older launch payload contains different values.

## Hand off work

1. Save accepted results and their source references before returning or routing.
2. Preserve complete per-issue findings so scope, authority, and effective dates survive
   the handoff. Keep raw evidence with its source.
3. Store the continuation supplied by the caller or router so interrupted work can resume.
   Route selection, destination inputs, and stage prerequisites belong to the missions.

Field mappings and write rules belong to `rate_checkpoint`. Slack presentation belongs
to `case_slack`; the mission selects when each update occurs.

## Finish

Close the case when the calling task establishes its completion criteria. Retain the
checkpoint for reference or reuse. Read closed cases as history until work is explicitly reopened.
