# Run rate cases from Slack

1. Run `/squadron`, select `rate_triage`, and enter the Jira ticket key.
2. Follow the case message for the cause, current status, and PRs. Questions and more
   detailed updates appear in its thread.
3. Answer operator questions with the question's Answer control. Answer product questions
   on Jira, then tell Squadron that the answers are ready.
4. At review, send feedback or request another audit through the review prompt. Squadron
   checks the current work and directs corrections to the existing sessions.
5. When the PRs are merged, tell Squadron to check their status and finish the case.

Investigation results are posted in product language on the ticket. The Slack message is
updated for progress, with questions or more detailed updates posted in a thread.
Bruno tests the fix in the staging environment only. CI runs the tests automatically:
should-change tests fail before deployment and pass afterward; guardrails pass throughout.

Missions record and exchange information via a shared checkpoint file, which is retained
upon completion for reference or reuse.

## Review and follow-up

The review prompt keeps Squadron available for feedback after the initial audit. If you
message a Devin session directly, ask Squadron to re-audit so it can collect that session's
latest work and reassess the change. Each round returns to the same review prompt flow.
Use its Answer control; ordinary Slack replies are conversation, not answers to Squadron.

“Awaiting review” means the work is ready for your feedback. It does not mean the changes
have been merged. You can also explicitly end the review and retain the case for later use.

For Slack credentials and channel selection, see [Slack setup](slack-setup.md).
