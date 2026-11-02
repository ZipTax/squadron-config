# Coordinate review until the PRs merge

Keep Squadron available to accept operator feedback, re-audit, and direct the recorded
Devin owners. Use `rate_case` for context, `rate_checkpoint` for progress, and `case_slack`
for updates. This is a review loop, not a Jira evidence blocker.

## Wait for feedback

1. Read the case and collect the current PR states, heads, and session results through
   the registered owners. Include lessons PRs in the merge check. If the closing criteria
   below are already met, finish without opening another question.
2. Save `next_entry` as `rate_finalize/review_followup` and the current review progress.
3. Set Slack status to Awaiting review and call `builtins.human.ask` without
   `timeout_seconds`: "What should I review or change? Tell me when staging is deployed or the PRs are merged."
   Offer "Re-audit current work", "Check staging deployment", "Check whether PRs are merged",
   and "End review".
   The Other answer accepts detailed feedback, including work requested directly from Devin.
4. Wait for the answer in this task. An interrupted or unavailable ask retains active
   case state for resumption at this stage; it does not complete review.

## Act on feedback

1. Save the feedback before directing work. Re-read affected sessions and PR heads so
   direct operator messages to Devin are included in the assessment.
2. Send investigation questions, fix changes, cases, Bruno changes, and lessons to their
   recorded owners through `delegated_session`. Preserve each session's file lane.
3. Set the status to Auditing and re-audit changed work with `evidence_gate`, `ab_audit`, and `txc_rate_audit`. Obtain new
   captures for affected changes; have the Bruno owner review automatic staging CI results
   against deployment state: should-change tests fail before deployment and pass afterward;
   guardrails pass throughout.
   Record the assessed heads and evidence so a prior pass cannot approve a later commit.
4. Report the result and return to the feedback ask. Use `verdict_loop` to bound automated
   corrections to 10 attempts per feedback round or two attempts without improvement;
   report unresolved findings to the operator at the limit.
   A new feedback round preserves prior counters and evidence rather than silently resetting them.

Use `blocked_run` for an actual operator/product dependency discovered during review.
After it is settled, return to this review loop. Keep merge decisions with the operator.

## Check a staging deployment

1. When the operator reports a manual staging deployment, record which fix was deployed
   and have the Bruno owner review a CI run made after that deployment. If no fresh run
   is available, keep verification pending and report the missing evidence.
2. Compare should-change and guardrail results with the pre-deployment run. Both should
   pass now. Unchanged failures, new failures, or an unexpected lack of change require
   investigation, even when the SQL A/B audit was satisfactory.
3. Delegate the discrepancy and CI evidence to the existing investigation, fix, case,
   or Bruno owner as appropriate. Re-audit returned corrections through the feedback
   loop above. A correction requiring deployment waits for the operator's next manual
   deployment before its post-deployment check.
4. Post the result, delegated follow-ups, and remaining work in Slack. Save the deployed
   fix reference and CI evidence with review progress. Keep review open while a reported
   deployment has unresolved verification or corrections.

## Finish or recover

- On "check merged", confirm all case PRs are merged through the sessions. If any remain
  open, report which and return to the ask. A closed-unmerged PR needs operator disposition.
- When all PRs are merged and no requested verification or corrections remain, record
  that outcome and close the case. A case with no PRs
  can close when its accepted disposition leaves no pending work.
- On an explicit "end review", record remaining work and close the review by operator choice.
- On resume, reconcile the saved pending action with session results before resending work.
  Recover unrecorded direct feedback by asking the operator; never claim it was assessed.
