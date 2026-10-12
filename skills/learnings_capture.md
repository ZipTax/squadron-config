# Capture reusable learning

## Ask for discoveries from the work actually performed

Ask the Devin sessions that did the work whether they encountered anything difficult to
discover and worthwhile to preserve for a future case. Their working context contains the
failed approaches, unexpected constraints, and decisive evidence that a summary may omit.
Do not infer lessons from a PR diff, an action-item list, or a ticket outcome alone.

Use `delegated_session`: follow up with `send_message`, then collect the response with
`check_session`. Include the ticket and the session's part of the work, and make the request
read-only. Ask for no quota; “nothing worth recording” is a complete answer.

For each proposed lesson, ask Devin to explain:

- What it discovered during its own work and what made that discovery difficult.
- Which evidence established the finding and the conditions where it applies.
- What a future maintainer would do differently and why that would save meaningful effort
  or prevent a consequential mistake.
- Whether the relevant skills or references already explain it, and what is missing if so.

Ask for the session's findings without suggesting a lesson it should endorse. Use a bounded
follow-up when a proposal lacks support. Do not commission a fresh investigation merely to
produce learning material. If a session is unavailable, use only lessons it explicitly
proposed in its recorded report, retain that attribution, and disclose the unavailable
response. An unavailable session is not a session that reported no lessons.

## Assess the candidate and destination

Accept a session-proposed lesson only when it was difficult to discover, is supported by
evidence, changes a future decision, and adds something missing from maintained guidance.
Routine fixes, obvious code behavior, generic best practices, and restatements of existing
instructions do not meet that bar. Ask Devin to check the proposed destination before
accepting the addition, because duplicate instructions drift.

Require a citation and distinguish established findings from hypotheses. State the rule
and the conditions under which it matters before choosing where to record it. If the only
content is what one PR changes, why a particular row was chosen, or what remains to check,
keep that evidence with the PR or session instead of creating a ticket-specific document.
A durable reference must help resolve a future case without reproducing this fix's history.

| Learning | Destination |
| --- | --- |
| Repository procedure, query trap, or tool usage | Owning repository's skills or docs |
| Workflow boundary, evidence gate, or routing behavior | Corresponding workflow skill |
| Proven data-model or configuration constraint that changes future decisions | Relevant maintained repository reference |
| Proven rate-audit precedent | SQL repository's ratevariant-audit case-law reference |
| Proven limitation deferred under new-rate-engine | SQL repository's ratevariant-audit limitations reference |

Apply the same value and evidence bar to limitations and precedents. A ticket's disposition
does not itself justify another reference entry. Do not invent a new-rate-engine deferral
or convert an unresolved hypothesis into a lesson to fill a destination.

## Separate a supported lesson from unfinished work

A lesson summarizes established evidence; it does not choose an unresolved implementation
value. If correctness still depends on tracing a consumer, deciding between configuration
values, or running missing proof, report the gap and its consequence. Do not turn a request
for learning into instructions to change SQL, migrations, tests, or ticket registration.
Changing those artifacts can invalidate the evidence on which the lesson would rest.

Documentation is not a substitute for that proof. Keep an unresolved hypothesis explicitly
unproven, and do not present it as a rule merely because a plausible explanation can be
written. A read-only clarification of existing evidence may establish whether a lesson
qualifies; implementation and new acceptance testing are separate work.

## Delegate only accepted writebacks

Request documentation only after a proposal qualifies. Supply the originating session's
finding, evidence references, intended future use, and selected guidance files. Keep the
wording for Devin to author; supplying a finished paragraph bypasses its repository context.
Prefer a focused amendment to relevant maintained guidance over a new ticket document.

Use `delegated_session` and `devin_code` for a new documentation assignment, with
`prompt_mode: "raw"` and an explicit documentation-only scope. The default development
wrapper asks for implementation and tests, which are not authorized by a learning writeback.
A new session does not inherit the source session's context, so include the accepted evidence
and its provenance. Continue an existing documentation assignment with `send_message`
rather than opening another session or PR. Collect its result and review the actual diff.

## Write the lesson a future maintainer needs

State what was learned, explain why, and retain only enough evidence to support it. Organize
around the outcome and the decision it changes, because a future maintainer needs to know
when and why to apply the lesson without reconstructing the investigation. Use headings that
name the finding rather than numbered attempts or fix cycles. Choose the structure to fit
the lesson; do not copy a neighboring entry's format just for consistency.

Keep chronology only when the order explains the result. Link to the supporting PR or commit
instead of repeating run logs, status, or session history. Preserve the conditions and limits
of the evidence: a changed result can establish that a branch was exercised without proving
that its output was correct. Apply these principles when briefing Devin and reviewing its
writeback.

**Bad:** “Cycle 1: All six replay cases matched. Cycle 2: We replaced the transactions and
reran the audit. Four cases differed. The audit was satisfactory.”

**Good:** “Matching replays did not establish coverage because an earlier zero-rate condition
bypassed the changed exemption logic. Replaying transactions with non-zero stored rates
produced differences in four of six cases. Before trusting a match, verify that the case
reaches the changed branch. See [PR #282](https://github.com/FedTax/txc-sqlserver-database/pull/282),
commit `f8cab41`.”

## Finish

Report the sessions asked, their proposals or explicit “none” responses, and any unavailable
responses. Accept a concise rule with its supporting case in a reviewable PR, or explain why
the returned proposals did not qualify. Check that the diff contains reusable guidance rather
than a ticket narrative, release status, deployment instructions, or a copy of the PR explanation. Reject changes
to implementation, migrations, or test artifacts from a documentation-only assignment.

The mission's rate_case_log is separate: use your mission file tools for its run ledger.
Do not ask Devin to commit that log into a repository if the memory slot is unavailable.
The ledger records runs; repository references preserve only what generalizes.
