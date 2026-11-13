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
4. Post a short reply for a stage transition, accepted result, new PR, or blocked question.
   Routing comes from the mission thread; omit payload routing keys. Record the last
   confirmed update in `last_update` so a resume can skip updates already delivered.

If `root_post_pending` remains set with no root ID after a restart or uncertain post,
ask the operator to recover its exact message reference before creating another root. Retry a failed edit against the same ID
and saved desired text; keep pending state until delivery is confirmed. Gateway failures
remain visible in the case record and mission result; they do not imply successful delivery.

Use Slack mrkdwn: bold title and `<url|label>` links. Keep Cause to two sentences and
about 25-30 words, stating uncertainty until established. List only PRs that exist.

Write progress replies as one short sentence about the product change, result, or decision
needed. For example: "Preparing the taxability correction for the affected states." Keep
branch names, commit hashes, database objects, row counts, labels, and test-plan details
in the linked PR or case record. Summarize the supplied outcome for the reader instead of
copying the internal report. Report this stage's progress without repeating another stage's findings; preserve the accepted Cause unless the mission supplies a revised finding.

```text
*DEV-1234: Incorrect tax rate in Austin, TX*
Cause: The remote seller needs a ZIP+4 override because the current address match selects the wrong local rate. The fix targets the affected location and effective period.
Status: :hammer: Fixing
PRs:
- <https://github.com/ZipTax/txc-sqlserver-database/pull/123|txc-sqlserver-database fix>
- <https://github.com/ZipTax/txc-bruno/pull/45|bruno tests>
- <https://github.com/ZipTax/squadron-config/pull/67|lessons>
```

## Status and results

Use the complete status supplied by the caller, including its emoji. Report the supplied outcome and
supporting links. Preserve existing PR links when a stage produces no new PR.

## Questions

The caller supplies the question status. The human-ask tool posts the question in the
thread. When the calling
stage accepts the answer, post its resolution and restore the supplied work status.
The calling task owns question assessment; `blocked_run` handles dependency questions.
