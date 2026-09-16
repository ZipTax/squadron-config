# Read and write a rate ticket's current checkpoint

The checkpoint is the current mission routing state for one Jira ticket. It is not Jira data, a
transcript, or a history of prior states. Its purpose is to let a later mission continue from the
latest decision without re-running finished work.

## Read the current state

Read `rate_checkpoint/<TICKET>.yaml` and validate it against
`docs/schemas/rate-ticket-checkpoint.schema.json` before using it. Reject an unsupported
`schema_version`; guessing how an unknown format maps to the current mission can route work to the
wrong lane.

`checkpoint_revision` identifies the current checkpoint write. It is unrelated to Jira issue
revisions and does not create stored snapshots.

If no checkpoint exists, read the legacy `rate_resume_state/<TICKET>.md` record. Convert
that record to schema version 1 with `checkpoint_revision: 1`, verify the YAML, and only then delete
the legacy file. Do not infer fields that the old record did not contain.

## Represent work not yet reached

Keep the required envelope, but do not fabricate results. Use empty strings for unknown
verdict/mechanism, empty lists for uncollected evidence and completed stages, null for lanes
or PRs that do not yet exist, and zero audit counters with an empty last_result before audit.
For an existing session awaiting its first result, use output_revision: 0. For a known PR,
leave unknown branch/head fields empty rather than inventing values.

The stage and next_entry identify actual continuation work even before a verdict exists.
A blocker can retain empty comment identifiers while posting is incomplete. Do not treat
that state as a successfully registered human wait. See the early checkpoint example under
[rate-ticket-checkpoint.early.json](../docs/schemas/examples/rate-ticket-checkpoint.early.json).

## Write the current state

You maintain the checkpoint; Devin supplies evidence, not checkpoint edits. Before writing:

1. Re-read the current file.
2. Stop if its `checkpoint_revision` differs from the `checkpoint_revision` this run read, because
   another run has already made a newer routing decision.
3. Preserve `schema_version`, increment `checkpoint_revision`, update `updated_at`, and validate the
   complete document against the schema.

Keep only the current decision and pointers to evidence. Session output remains in Devin, Jira
discussion remains in Jira, pull-request evidence remains in GitHub, and ratevariant captures remain
with the run. The checkpoint stores their identifiers and concise conclusions so those sources do
not acquire a second, drifting copy.

Delete the checkpoint when the case closes with no active blocker. Otherwise, a later mission may
resume work that was already completed.
