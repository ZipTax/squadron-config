# Run rate cases from Slack

Deployment requires Squadron and the Slack gateway with mission-thread routing, returned
message IDs, and `gateway.edit`. The earlier Link-based PRs alone do not satisfy this
contract. Install compatible builds before using this configuration.

1. Set `slack_bot_token`, `slack_app_token`, and `slack_channel_id` in Squadron variables.
   `gateways.hcl` selects a locally installed gateway; tokens stay in the variable store.
2. Start `rate_triage` with the Jira ticket key. Triage creates the case root; investigation
   updates it with the supported cause. A `/squadron` starter root is reused through `root: true`.
3. Follow the root status and replies through investigation, fixing, testing, auditing,
   Bruno preparation, and lessons. Existing PR links remain on every edit.
4. Answer operator questions with the Slack question's Answer control. Product questions
   stay on Jira; answer there, then tell the Slack question that answers are ready.
5. Read the final disposition and PRs on the root. Review ready means proposed changes
   are ready for review. Bruno currently authors tests; it does not run live verification.

Investigation continues to post product-language results on Jira through Devin's existing
writing skill. Slack holds coordination and progress.

## Continue the same case

The three missions share `rate_checkpoint/<TICKET>.yaml`. It retains accepted findings,
lane owners, evidence references, PRs, pending questions, counters, and the complete Slack
root text plus its returned message ID. Every stage reads the latest file before merging
changes. Routes pass the ticket and entry stage instead of reformatting the whole case.
Closed records remain available; they are history until explicitly reopened.

A **mission thread ID** identifies related Squadron runs. A **Slack root message ID**
identifies the message to edit. The launcher must restore the mission thread ID on a
restart before questions or replies are emitted. Saving the root ID alone does not route
questions into that thread.

If a live Jira-answer ask times out or ends unresolved, the existing bridge can register
recovery. Its launcher must support restoring the mission thread ID from the case; that
runtime/bridge integration is a prerequisite, not implemented by these config files.
Register recovery after the live ask ends so only one continuation owns the case.

## Maintainer checks

- Deploy the shared skill/config changes and extended checkpoint reader together. Optional
  v1 fields preserve old records; old writers cannot safely rewrite the extended records.
- Confirm a chained mission's post and human ask reach the original thread.
- Restart after saving a root ID; verify the next edit preserves the title, cause, and PRs.
- Interrupt an edit; retry the saved pending text against the same ID.
- Exercise operator and Jira questions, including timeout and bridge recovery.
- Confirm investigation results still appear in product language on Jira.

Shared instructions: [case state](../skills/rate_case.md),
[Slack updates](../skills/case_slack.md), [questions](../skills/blocked_run.md).
The [Slack checkpoint example](schemas/examples/rate-ticket-checkpoint.slack.json)
shows a pending operator question with multipart findings intact.
