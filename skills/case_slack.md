# Communicate progress or updates via Slack

Use these instructions to choose what belongs in Slack, compose the update, and maintain
the saved root message.
See the [example flow](../docs/slack-rate-workflow.md#example-root-changes-and-thread-replies) for root edits versus thread posts.

## 1. Decide what to publish

**Update the root** when the case status, accepted Cause, or PR links change.
A stage transition changes the root status; it does not need a thread reply.
For a new PR, add only its labeled link to the root's PR list. Post its brief change summary
as a separate thread reply. These are two distinct updates, not two copies of the summary.

**You may post a thread reply only for:**

- An accepted investigation, verification, or case outcome that changes the reader's
  understanding of the issue.
- A new PR or a substantive revision, with the change it proposes and its effect.
- Completed test coverage, assessed test results, or a material coverage gap.
- A lessons outcome, a response to review feedback, or case closure.
- A question requiring human input, or its accepted resolution. Use `builtins.human.ask`
  for the question; it posts to the thread, so do not duplicate it with a gateway post.

**You may not post a thread reply solely to report:**

- A task starting, finishing, handing off, or waiting for the next stage.
- A status that is already shown on the root.
- Session creation, suspension, resumability, ownership checks, or metadata corrections.
- Routing decisions, checkpoint maintenance, or inventories of work not yet started.
- Findings or artifacts already reported, without a meaningful change.

For example, omit "Triage complete; findings intact, session suspended, no fix PR yet."
Keep that bookkeeping in the case record. If it creates a human dependency, ask for the
needed action and explain its consequence, following your task instructions and `blocked_run`.

## 2. Compose the root

The root body must contain only the four fields below, in this order. Read the saved root
before editing to preserve current facts and links, then render this format. Remove extra
sections and commentary already present; preserving facts does not mean preserving prose.

- **Title:** ticket key and title.
- **Cause:** the accepted problem and its effect, with uncertainty where needed. Keep it
  to two sentences and about 25-30 words. Do not include the proposed solution or
  implementation details. Use "Under investigation" until an accepted cause is available.
- **Status:** the complete label specified in your task instructions, including its emoji.
- **PRs:** one labeled link per line, using repository and purpose, such as
  `txc-sqlserver-database fix`, `txc-bruno tests`, or `squadron-config lessons`.

Do not add change summaries, branch names, commit hashes, labels, database objects, row counts,
test results, or audit commentary to the root. Do not annotate PR links with those details.
The gateway appends the mission links and requester footer; do not recreate it in the body.

Use Slack mrkdwn with line breaks, `*bold*` titles, and `<url|label>` links:

```text
*DEV-10679: NEW TIC - Carbon Credits - TIC 99985*
Cause: Carbon credits are missing from the tax catalog, so purchases default to taxable even in jurisdictions where they should be exempt.
Status: :writing_hand: Authoring Bruno tests
PRs:
- <fix-pr-url|txc-sqlserver-database fix>
- <bruno-pr-url|txc-bruno tests>
```

## 3. Compose a permitted reply

Follow your task's content instructions and examples. Adapt examples to supported
facts and actual links. Write as concisely as you can without losing context, consequence,
or meaning; include enough information to understand the result or answer the question.
These writing and formatting rules also apply to every visible human-ask field, including
`additional_context`. Use it only for context needed to answer the question; omit it when the
question is self-contained. Do not paste checkpoint contents or lane-by-lane session reports.
Use clickable `<actual-url|label>` links for PR, Jira, and CI references, using URLs from the
case record or tool results. Bare PR numbers, run IDs, and commit hashes are not links.

Summarize the outcome and link to Jira, the PR, or CI for detail. Do not reproduce their reports
or enumerate implementation changes and test cases in the reply.

For PR and implementation summaries, describe the change and its effect at the level of
the high-level approach. For example: "<fix-pr-url|Fix PR> adds a branch for TIC 40030 so
local tax is preserved." Keep implementation details and supporting logs in linked work.

Report the relevant case outcome, not the internal session report:

- Result: "API tests still show local tax being cleared after deployment; the fix session
  is investigating." Include the CI link.
- Question: "Please follow up when the fix is deployed to staging. If applicable, provide
  any relevant deployment details so I can verify the fix."
- Resolution: "Deployment is confirmed; resuming verification."

After assessing an answer according to your task instructions, update the root status and
report the accepted resolution. Follow `blocked_run` for human dependencies.

## 4. Deliver and record the update

Use `rate_checkpoint` to maintain the case memory.

1. Read the current case before writing so the update preserves newer findings and links.
2. **Create a root:** read the ticket title and save the desired text with `root_post_pending: true`. Post with
   `root: true` and the `channel` specified in your task instructions, when provided. The gateway reuses an
   existing conversation regardless of that initial channel choice. Save the returned ID
   immediately in `slack.root_message_id`, together with the full text and runtime's mission
   thread ID; clear `root_post_pending`. Later updates reuse this root.
3. **Edit the root:** render only the four root fields using the latest case facts. Persist `root_text` with
   `update_pending: true`, then call `gateway.edit` with the saved ID and complete text.
   On success, save `published_text` and clear `update_pending`.
4. **Post a permitted reply:** routing comes from the mission thread; omit payload routing
   keys. Record the last confirmed update in `last_update` so resumption skips delivered replies.

Slack delivery is nonblocking. On failure, record the failure and pending update in the case
record and mission result, then continue mission work. Mark delivery only on success.
Retry a failed edit against the same ID using the latest desired text on the next update.

If an uncertain root post leaves `root_post_pending` set with no root ID, flag the missing
reference for operator recovery and continue mission work. Recover that reference before
posting another root so the case keeps one conversation.
