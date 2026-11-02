# Hand off a rate case

Use `rate_checkpoint` to read and write the shared case. Squadron accepts and records
results; Devin supplies the underlying reports.

## Enter work

1. Read the current case before briefing a session, so it receives the latest accepted work.
2. Recover missing context from supplied inputs and recorded reports. Preserve established
   findings when an older launch payload contains different values.
3. Confirm the required finding, artifact, and owner before starting the selected stage.
   Use `delegated_session` to recover a report or replace an unavailable owner.

## Hand off work

1. Save accepted results and their source references before returning or routing.
2. Preserve complete per-issue findings so scope, authority, and effective dates survive
   the handoff. Keep raw evidence with its source.
3. Record the next mission and stage. Pass `issue`, `repo_url`, `base_branch`, and
   `entry_stage` across mission routes; the receiving stage reads the case.

Field mappings and write rules belong to `rate_checkpoint`. Slack presentation belongs
to `case_slack`; the mission selects when each update occurs.

## Finish

Keep the case active through operator review. Use `review_followup` to establish completion
before closing it, so pending verification and corrections remain actionable. Retain the checkpoint
for reference or reuse. Read closed cases as history until work is explicitly reopened.
