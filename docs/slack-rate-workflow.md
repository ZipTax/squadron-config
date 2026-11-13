# Run rate cases from Slack

1. Run `/squadron`, select `rate_triage`, and enter the Jira ticket key.
2. Follow the case message for the cause, current status, and PRs. Questions and concise
   result summaries appear in its thread.
3. Answer operator questions with the question's Answer control. Answer product questions
   on Jira, then tell Squadron that the answers are ready.
4. At review, send feedback or request another audit through the review prompt. Squadron
   checks the current work and directs corrections to the existing sessions.
5. After you deploy to staging, tell Squadron through the review prompt. It reviews fresh
   Bruno CI results, delegates unexpected results for correction, and updates Slack.
6. When the PRs are merged and requested checks are settled, tell Squadron to finish the case.

Investigation results are posted in product language on the ticket. The Slack message is
updated for progress, with questions and concise result summaries posted in its thread.
Bruno tests the fix in the staging environment only. CI runs the tests automatically:
should-change tests fail before deployment and pass afterward; guardrails pass throughout.

Missions record and exchange information via a shared checkpoint file, which is retained
upon completion for reference or reuse.

## Example: root changes and thread replies

One root stays at the top: ticket title, short Cause, Status, and labeled PR links, followed
by the gateway's mission links. The table shows edits to that same root and separate replies.
Example findings are illustrative. Replace URL placeholders with actual URLs; the examples
show Slack link syntax so labels become clickable rather than plain PR numbers.

| Event | Root change | Thread post |
| --- | --- | --- |
| Case opens | Cause: Under investigation. Status: :mag: Triaging | None |
| Investigation starts | Status: :mag: Investigating | None |
| Investigation accepted | Cause: The state exemption is also clearing local tax for TIC 40030, causing eligible purchases to be undertaxed. | "The state exemption is also clearing local tax for TIC 40030. `<jira-url\|Investigation on Jira>`" |
| Fixing starts | Status: :hammer: Fixing | None |
| Fix PR ready | Add `<fix-pr-url\|txc-sqlserver-database fix>` to PRs | "`<fix-pr-url\|Fix PR>` adds a branch for TIC 40030 so local tax is preserved." |
| Case authoring starts | Status: :test_tube: Testing | None |
| Cases ready | No change | "Cases now cover local-tax preservation for TIC 40030 and unaffected items. `<fix-pr-url\|Fix PR>`" |
| Audit starts | Status: :microscope: Auditing | None |
| A/B audit accepted | No change | "A/B checks support the correction, with no regressions found in the covered cases. `<run-url\|Comparison>`" |
| Bruno authoring starts | Status: :writing_hand: Authoring Bruno tests | None |
| Bruno PR ready; pre-deployment CI assessed | Add `<bruno-pr-url\|txc-bruno tests>` to PRs | "`<bruno-pr-url\|API tests>` reproduce the lost local tax before deployment; unaffected items pass. `<run-url\|CI>`" |
| Lessons work starts | Status: :memo: Recording lessons | None |
| Lessons PR ready | Add `<lessons-pr-url\|squadron-config lessons>` to PRs | "`<lessons-pr-url\|Lessons PR>` adds guidance to check local tax separately when changing state exemptions." |
| Review opens | Status: :eyes: Awaiting review | Review prompt for feedback, including: "Please follow up when the fix is deployed to staging. If applicable, provide any relevant deployment details so I can verify the fix." |
| Operator confirms staging deployment | Status: :test_tube: Verifying in staging | None; the existing Bruno session reuses a post-deployment attempt or reruns the PR's API Tests check at the same head |
| Post-deployment CI assessed | No change | "The previously failing local-tax tests now pass, and unaffected items still pass. `<run-url\|CI>`" |

Each PR entry on the root is only a labeled link. The quoted summaries are replies, not text
to append beneath those links. Detailed findings, implementation, and test evidence remain
on Jira, the PR, or CI.

If a question blocks work, change the root to `:question: Blocked on question` and use the
human-ask tool for the question. After accepting the answer, restore the work status and
briefly report the resolution. If verification finds a failure, report the affected behavior
and correction underway rather than the passing result in this example.

## Example: review prompt

Based on the reported DEV-10528 snapshot, a concise review prompt could read as follows.
The PR links below are real; this illustrates wording rather than a fresh assessment of the work.
Use Slack `<url|label>` syntax to produce the same clickable labels in the actual prompt.

> **DEV-10528 is ready for review.**
>
> - [txc-sqlserver-database fix + cases](https://github.com/FedTax/txc-sqlserver-database/pull/374)
> - [txc-bruno tests](https://github.com/FedTax/txc-bruno/pull/113)
> - Lessons: [SQL guidance](https://github.com/FedTax/txc-sqlserver-database/pull/376), [Bruno guidance](https://github.com/FedTax/txc-bruno/pull/114)
>
> A/B checks support the correction with no unexpected regressions in the covered cases.
> Before deployment, Bruno reproduces the issue and checks for unchanged behavior pass.
> LA/KS/SD still lack usable staging coverage.
>
> Product decisions remain on TN treatment and the holiday period, NC merchant status,
> and AZ/IL local-tax scope; the ticket has the details.
>
> What should I review or change? Please follow up when the fix is deployed to staging.
> If applicable, provide any relevant deployment details so I can verify the fix.

Keep the existing choices: **Re-audit**, **Verify staging (deployment done)**, **Merge check**,
**End review**, and free-text feedback. Session ownership, commit hashes, and detailed
captures remain in the case record and linked work, rather than an appended Context report.

## Review and follow-up

The review prompt keeps Squadron available for feedback after the initial audit. If you
message a Devin session directly, ask Squadron to re-audit so it can collect that session's
latest work and reassess the change. Each round returns to the same review prompt flow.
Use its Answer control; ordinary Slack replies are conversation, not answers to Squadron.

"Awaiting review" means the work is ready for your feedback. It does not mean the changes
have been merged. You can also explicitly end the review and retain the case for later use.

For Slack credentials and channel selection, see [Slack setup](slack-setup.md).
