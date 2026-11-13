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
4. Confirm the root was published with the supplied status. Stage transitions update the root;
   reserve thread replies for artifacts, accepted results, and questions that need attention.
   Routing comes from the mission thread; omit payload routing keys. Record the last
   confirmed update in `last_update` so a resume can skip updates already delivered.

If `root_post_pending` remains set with no root ID after a restart or uncertain post,
ask the operator to recover its exact message reference before creating another root. Retry a failed edit against the same ID
and saved desired text; keep pending state until delivery is confirmed. Gateway failures
remain visible in the case record and mission result; they do not imply successful delivery.

Use Slack mrkdwn: bold title and `<url|label>` links. Keep Cause to two sentences and
about 25-30 words, stating uncertainty until established. List only PRs that exist.

Write replies as concisely as you can without losing context, consequence, or meaning.
Include enough information for the reader to understand the result or answer the question.

For PR and implementation summaries, describe the change and its effect at the level of the
high-level approach, such as a ZIP+4 override or a TIC-specific branch that preserves local tax.
Keep implementation details and supporting logs in the linked PR or case record.
Summarize the supplied outcome instead of copying the internal report. Report this stage's
outcome; preserve the accepted Cause unless the mission supplies a revised finding.

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

## Wording examples

Adapt these examples to the supported facts; link the actual PR or evidence when relevant.
Keep supporting technical evidence in the case record and linked work.

| Stage | Artifact or result reply |
| --- | --- |
| Investigation | "The state exemption is also clearing local tax for TIC 40030." |
| Fixing | "[Fix PR] adds a branch for TIC 40030 so local tax is preserved." |
| Fixing | "[Fix PR] adds a ZIP+4 override so affected addresses receive the correct local rate." |
| Testing | "Test cases now cover local-tax preservation for TIC 40030 and unaffected items." |
| Auditing | "A/B checks show local tax is preserved for TIC 40030, with no regressions found in the covered cases." |
| Authoring Bruno tests | "API tests reproduce the lost local tax before deployment; checks for unaffected items pass." |
| Verifying working-as-intended | "Local tax still applies despite the state exemption; the supporting explanation is on the ticket." |
| Recording lessons | "[Lessons PR] adds guidance to check local tax separately when changing state exemptions." |
| Awaiting review | "Your requested local-tax coverage is added and ready for another look." |
| Verifying in staging | "After deployment, API tests confirm local tax is preserved and unaffected items still pass." |
| Blocked on question | "Deployment is confirmed; resuming verification." |

For questions or unexpected results, state what needs attention and the next action:
- "Which staging deployment includes this fix? Verification is waiting on confirmation."
- "API tests still show local tax being cleared after deployment; the fix session is investigating."
- "The comparison found tax changes for unaffected items; the fix session is correcting them."
- "No reusable lessons emerged from this case; moving to review."

Investigation also replaces the root's provisional Cause with its accepted product finding,
for example: "The state exemption is also clearing local tax for TIC 40030, causing eligible purchases to be undertaxed."
Later stages preserve that finding while updating status and PR links.

## Questions

The caller supplies the question status. The human-ask tool posts the question in the
thread. When the calling
stage accepts the answer, post its resolution and restore the supplied work status.
The calling task owns question assessment; `blocked_run` handles dependency questions.
