# Communicate progress or updates via Slack

## FORBIDDEN

These restrictions apply to root edits, thread posts, and every human-ask field,
including `additional_context`.

- **Do not publish internal coordination reports:** session inventories, ownership or
  resumability checks, handoff comparisons, absence checks, routing decisions, or
  "everything lines up" summaries. Shortening these reports does not make them publishable.
- **Do not publish session/checkpoint diagnostics:** session IDs, activity timestamps,
  suspended/archived flags, checkpoint revisions, field dumps, serialized output, trigger
  label checks, or history-provenance bookkeeping.
- **Do not announce routine progress in the thread:** discovery complete, investigation
  starting/finished, PR opened, tests authored, expected test results, stage transitions,
  routine feedback completion, or closure. Update the root's permitted fields instead.
- **Do not paste technical reports into Slack:** SQL/schema details, branch names, commit
  hashes, test-case inventories, or raw logs. Link the relevant work and describe the
  product consequence only when the message qualifies under section 1.
- **Do not duplicate a human ask with a gateway post.** Put the ready-for-review summary
  in the review ask itself.

Before sending, check the message against these prohibitions and section 1's allowed
message types. If it is only a coordination report, **send nothing**. For example,
"Read-Only Triage Report: session suspended, fix/cases absent, no discrepancies" gets
no thread post. If a real blocker needs human action, ask for that action and explain its
consequence without attaching the internal report.

Use these instructions to choose what belongs in Slack, compose the update, and maintain
the saved root message.
See the [example flow](../docs/slack-rate-workflow.md#example-root-changes-and-thread-replies) for root edits versus thread posts.

## 1. Decide what to publish

**Update the root** for investigation, fixing, PR creation, test authoring, assessed staging
results, and other routine progress. Keep Cause, Status, and labeled PR links current.
PRs and expected results do not warrant separate announcements; their details are available
in the ticket, PR, and CI.

**Thread messages are only for:**

- Questions requiring human input. Use `builtins.human.ask`; it posts to the thread,
  so do not duplicate it with a gateway post.
- Blockers: explain what prevents progress, its consequence, and the action needed.
  Use `blocked_run` when human input is required.
- The final ready-for-review summary, including the request to follow up after staging
  deployment so the fix can be checked. Include this in the review prompt, not a second post.
- Refutation of a prior working-as-intended conclusion: update Cause and post the corrected
  understanding, its consequence, and the Jira findings link. This announces a reversal,
  not routine investigation progress. WAI confirmation only updates Cause and Jira.

For review follow-up questions, include only context needed for the next decision rather
than repeating the initial review summary.

An unexpected test result is a thread update only when it blocks progress;
otherwise update only the root status.

## 2. Compose the root

The root body contains Title, Cause, Status, then PRs when present. Read the saved root
before editing to preserve current facts and links, then render this format. Remove extra
sections and commentary already present; preserving facts does not mean preserving prose.

- **Title:** link the ticket key to its Jira ticket, followed by the title, so readers can
  open the ticket from the header. Use Slack `<ticket-url|ticket-key>` syntax and the
  ticket's actual browse URL.
- **Cause:** the accepted problem and its effect, with uncertainty where needed. Keep it
  to two sentences and at most 30 words. Do not include the proposed solution or
  implementation details. Use "Under investigation" until an accepted cause is available.
- **Status:** the complete label specified in your task instructions, including its emoji.
- **PRs:** one labeled link per line, using repository and purpose, such as
  `txc-sqlserver-database fix`, `txc-bruno tests`, or `squadron-config lessons`.
  If no PRs exist, omit the entire section, including the `PRs:` heading, so the gateway
  mission links below it do not appear to be PR entries.

Do not add change summaries, branch names, commit hashes, labels, database objects, row counts,
test results, or audit commentary to the root. Do not annotate PR links with those details.
The gateway appends the mission links and requester footer; do not recreate it in the body.

Use Slack mrkdwn with line breaks, `*bold*` titles, and `<url|label>` links:

```text
*<https://taxcloud.atlassian.net/browse/DEV-10679|DEV-10679>: NEW TIC - Carbon Credits - TIC 99985*
Cause: Carbon credits are missing from the tax catalog, so purchases default to taxable even in jurisdictions where they should be exempt.
Status: :writing_hand: Authoring Bruno tests
PRs:
- <fix-pr-url|txc-sqlserver-database fix>
- <bruno-pr-url|txc-bruno tests>
```

## 3. Write product-level summaries and permitted thread messages

State the affected behavior and consequence in product language. A reader should understand
it without knowing the database schema, repository layout, or orchestration. Translate the
meaning rather than compressing a technical report into one long sentence.

For the root Cause, replace "20 StatesTaxMatrix rows have PercentTaxable=NULL, interpreted
as 0%" with "Incorrect Washington tax settings exempt sales-tax-holiday items and software
maintenance that should be taxable during the applicable periods."
Keep database objects, column values, internal pipelines, row counts, and TIC inventories
in the linked findings. Include a date or identifier only when essential to understanding
an outcome or answering a question.

Write questions and blockers as concisely as possible without losing context, consequence,
or meaning. For example: "The ticket and published guidance disagree on the applicable
rate. Please confirm the intended treatment on <jira-url|the ticket> so the fix can proceed."
Apply the same guidance to every visible human-ask field, including `additional_context`;
omit it when the question is self-contained. Do not paste internal reports or checkpoints.

The final ready-for-review summary links the fix, tests, and lessons PRs, briefly states
readiness and material limits, and requests feedback and staging follow-up. For example:
"Ready for review: <fix-pr-url|Fix and cases>, <bruno-pr-url|API tests>, <lessons-pr-url|Lessons>.
A/B checks support the correction; API tests reproduce the issue before staging deployment.
Please follow up when the fix is deployed to staging. If applicable, provide any relevant
deployment details so I can verify the fix."
Adapt this to assessed facts; a PR proposes a correction, while test results provide evidence.
Use clickable `<actual-url|label>` links from the case record or tool results so readers can
open the detailed findings and evidence without reproducing them in Slack.

After a question is answered, update the root status. A routine resolution or expected
verification result needs no separate reply.

## 4. Deliver and record the update

Use `rate_checkpoint` to maintain the case memory.

1. Read the current case before writing so the update preserves newer findings and links.
   Check the draft against the allowed update types and root/reply rules above. Rewrite
   technical findings for the reader; omit internal coordination reports entirely.
2. **Create a root:** read the ticket title and save the desired text with `root_post_pending: true`. Post with
   `root: true` and the `channel` specified in your task instructions, when provided. The gateway reuses an
   existing conversation regardless of that initial channel choice. Save the returned ID
   immediately in `slack.root_message_id`, together with the full text and runtime's mission
   thread ID; clear `root_post_pending`. Later updates reuse this root.
3. **Edit the root:** render the root fields above using the latest case facts, omitting PRs when empty. Persist `root_text` with
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
