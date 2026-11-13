# Keep the case visible in Slack

Publish the status or result supplied by the mission. Read the saved message before
editing it so the latest cause and PR links are preserved.

## Start or update the root

1. Read the current case memory so an update preserves the latest cause, status, and PRs.
2. When the case has no root, read the ticket title, save the desired text with `root_post_pending: true`,
   and post one root with `root: true` and the mission-supplied `channel`, when provided.
   The gateway reuses an existing conversation regardless of that initial channel choice.
   Save the returned ID immediately in `slack.root_message_id`, together with the full text and
   the runtime's mission thread ID; clear `root_post_pending`. Later updates reuse this root.
3. For later updates, merge only the changed facts into the saved full text. Persist the
   desired `root_text` with `update_pending: true`, then call `gateway.edit` with the saved
   ID and complete text. On success, save `published_text` and clear `update_pending`.
4. Stage transitions update the root;
   reserve thread replies for artifacts, accepted case findings, test results, and questions
   that need attention.
   Routing comes from the mission thread; omit payload routing keys. Record the last
   confirmed update in `last_update` so a resume can skip updates already delivered.

Slack updates are notifications: continue mission work when delivery fails. Record the failure
and pending update in the case record and mission result; mark delivery only on success.
Retry a failed edit against the same ID using the latest desired text on the next update.
If `root_post_pending` remains set with no root ID after an uncertain post, flag the missing
reference for operator recovery and continue mission work. Recover that reference before
posting another root so the case keeps one conversation.

Use Slack mrkdwn: bold title and `<url|label>` links. Keep Cause to two sentences and
about 25-30 words: explain the problem and its effect, stating uncertainty until established.
Do not include the proposed solution or implementation details in Cause.

Write replies as concisely as you can without losing context, consequence, or meaning.
Include enough information for the reader to understand the result or answer the question.
Post when there is new information about the case or something the reader needs to act on.
Keep session-state corrections, ownership checks, routing decisions, and inventories of work
not yet started in the checkpoint and task output. When these create an operator dependency,
explain its consequence and the needed action in the question.

For PR and implementation summaries, describe the change and its effect at the level of the
high-level approach, such as a ZIP+4 override or a TIC-specific branch that preserves local tax.
Keep implementation details and supporting logs in the linked PR or case record.
Summarize the relevant case outcome instead of copying the internal report. Preserve the
accepted Cause unless the mission supplies a revised finding.

```text
*DEV-1234: Incorrect tax rate in Austin, TX*
Cause: The address match selects the wrong local rate for this remote seller because the location needs ZIP+4 resolution, causing the reported tax discrepancy.
Status: :hammer: Fixing
PRs:
- <https://github.com/ZipTax/txc-sqlserver-database/pull/123|txc-sqlserver-database fix>
- <https://github.com/ZipTax/txc-bruno/pull/45|bruno tests>
- <https://github.com/ZipTax/squadron-config/pull/67|lessons>
```

## Status and results

Use the complete status supplied by the caller, including its emoji. Report the supplied outcome and
supporting links. Preserve existing PR links when a stage produces no new PR.

## Wording examples

The calling task specifies the content for its stage and gives examples. Adapt examples to the
supported facts and use actual links; keep supporting technical evidence in the case record.

For questions or unexpected results, state what needs attention and the next action:
- "Please follow up when the fix is deployed to staging. If applicable, provide any relevant deployment details so I can verify the fix."
- "API tests still show local tax being cleared after deployment; the fix session is investigating."
- "The comparison found tax changes for unaffected items; the fix session is correcting them."
- "No reusable lessons emerged from this case; moving to review."

## Questions

The caller supplies the question status. The human-ask tool posts the question in the
thread. When the calling
stage accepts the answer, post its resolution and restore the supplied work status.
The calling task owns question assessment; `blocked_run` handles dependency questions.
