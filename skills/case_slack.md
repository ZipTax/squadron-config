# Keep the case visible in Slack

Use this skill at stage changes, accepted results, questions, and close-out. The runtime
must provide mission-thread routing, `builtins.gateway.post` returning a message ID,
`builtins.gateway.edit`, and Slack delivery of `builtins.human.ask`.

## Start or update the root

1. Read the current case memory so an update preserves the latest cause, status, and PRs.
2. On first triage, read the ticket title, save the desired text with `root_post_pending: true`,
   and post one root with `root: true`. Save the returned ID immediately in `slack.root_message_id`, together with the full text and
   the runtime's mission thread ID; clear `root_post_pending`. Investigation reuses this root.
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
about 25–30 words, stating uncertainty until established. List only PRs that exist.

```text
*DEV-1234: Incorrect tax rate in Austin, TX*
Cause: The remote seller needs a ZIP+4 override because the current address match selects the wrong local rate. The fix targets the affected location and effective period.
Status: :hammer: Fixing
PRs:
• <https://github.com/ZipTax/txc-sqlserver-database/pull/123|txc-sqlserver-database fix>
• <https://github.com/ZipTax/txc-bruno/pull/45|bruno tests>
• <https://github.com/ZipTax/squadron-config/pull/67|lessons>
```

## Status by work stage

| Stage | Status |
| --- | --- |
| discover_sessions (new case) | :mag: Triaging |
| start/continue/forward investigation, confirm_wai, assess_investigation | :mag: Investigating |
| develop; audit corrections assigned to the fix owner | :hammer: Fixing |
| author_tests; audit corrections assigned to the cases owner | :test_tube: Testing |
| audit (assessing returned evidence) | :microscope: Auditing |
| verify_wai | :mag: Verifying working-as-intended |
| bruno_tests | :test_tube: Preparing Bruno verification |
| record_learnings | :memo: Recording lessons |
| pending human question | :question: Blocked on question |
| closed case | :white_check_mark: Review ready, or the evidenced WAI/unsupported outcome |

The Bruno lane authors regressions without live execution. State “authored; live tests
not run” in its result reply. Review ready means PRs are ready for review, not deployed.
When no lesson qualifies, report that result and keep existing PR links.

## Questions

Use `blocked_run` to screen and choose the question's channel. Save the question and
resume stage, edit the root to Blocked on question, then call `human.ask`. The gateway
posts that question in the same Slack thread; it is the question update, so a second
identical post is unnecessary. Jira questions include the confirmed comment link and ask
whether answers are ready there. A Slack acknowledgement triggers assessment, not acceptance
of a tax or product answer. After assessment resolves the dependency, save the answer/source,
post a short resolution reply, and restore the active stage's status.
