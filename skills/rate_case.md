# Maintain one case across missions

Use `rate_checkpoint/<TICKET>.yaml` as the shared case record. Load `rate_checkpoint`
for safe writes and `case_slack` for operator updates. Squadron owns this file;
Devin supplies reports and evidence.

## At stage entry

1. Accept any bridge event through `blocked_run` before changing state or Slack.
2. Read the current checkpoint. Recover a missing file from explicit legacy inputs and
   recorded reports; ask the operator if a required finding or owner cannot be recovered.
3. On a first run, initialize the required checkpoint envelope from the early example.
   Persist the ticket and next entry before creating the Slack root. Import only missing
   values from legacy inputs so an older payload cannot overwrite accepted work.
4. Use `case_slack` to show the stage's status. Entry routers retain the current status
   until they select the next work stage; new triage starts at Triaging.

## Save before returning or routing

1. Re-read and merge the accepted result, session owners, PRs, evidence pointers,
   completed stages, counters, remaining questions, and `next_entry`.
2. Keep complete per-issue findings, including authority and effective dates, in
   `context.findings`. Preserve the original report references for verification.
3. Update Slack after persisting the result. Pass only `issue`, `repo_url`, `base_branch`,
   and the chosen `entry_stage` across mission routes. The destination reads the file;
   it does not need another serialized report or checkpoint input.
4. Keep the same Squadron mission thread ID across routing and restart. This identifies
   a mission chain; the Slack root message ID separately identifies the editable message.
   Resuming launchers must restore the recorded mission thread through the runtime's
   launch option before execution, so questions and replies reach the existing Slack thread.

## Field ownership

| Case field | Contents |
| --- | --- |
| `verdict`, `mechanism`, `production_evidence` | Latest accepted conclusions and observations |
| `lanes`, `artifacts`, `audit`, `wai_refire_count` | Owners, PRs, audit progress, WAI loop bound |
| `context` | Repository/base, disposition, affected roots, cited evidence, findings, legacy authority, cases mode, audit findings, open questions, close reason, WAI challenge, report references, limitation class, accepted impact radius |
| `slack` | Mission thread ID, exact root message ID, complete root text, last confirmed text, status, pending update |
| `human_wait` | Channel, question/context, Jira reference if any, answer/source, pending/resolved state |
| `blocker`, `processed_start_event_ids` | Bridge recovery identity and delivery progress |
| `next_entry` | Mission and stage that own the next action |

Store each accepted stage result before it becomes a downstream brief. Map output
`confirmed_findings` to `context.audit_findings`, merge `unwritten_scenarios` into
`context.open_questions`, and append confirmed writeback PRs to `artifacts.lessons_prs`.
Keep each result’s source in `context.report_references`.

Map legacy input `existing_pr`/`fix_pr_url` to `artifacts.fix_pr`, `bruno_pr_url` to
`artifacts.bruno_pr`, and session IDs to their lanes. Use the field-ownership table
for verdict, mechanism, evidence, counters, and context; decode JSON findings into the array. Keep messageability observations with their lane. Recover unknown PR numbers
from the saved URL and branches from the PR; preserve uncertainty until checked.

When the destination stage requires a verdict, findings, or an artifact that is absent,
recover it from the recorded report before proceeding. Treat empty legacy defaults as
unknown, so a missing case cannot look like a completed diagnosis.

On WAI refutation, persist the rebuttal in `context.wai_challenge` and increment
`wai_refire_count` before routing. Read the stored counter to enforce the existing cap.

## Close or resume

Set `case_state: closed` only when remaining work and blocking questions are settled.
Retain the checkpoint, root message, PR links, and final status so a later operator can
inspect or reopen the same case. Discovery treats closed state as history, not a resume
instruction; an explicit reopening preserves the conversation and rechecks the evidence.
