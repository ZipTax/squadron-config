# Capture reusable learning

## Your responsibility

Decide whether a case established a useful, new rule for future work. Most cases need no
writeback. A ticket outcome belongs on its ticket; a reusable discovery belongs where the
next person doing similar work will look for guidance.

## Work with Devin

Ask the Devin sessions that did the work for concrete discoveries supported by evidence.
Use their reports when they cannot be messaged. Have Devin check the intended destination
for existing guidance before proposing another rule, because duplicate instructions drift.

For a qualifying lesson, ask Devin to author a reviewable documentation PR, supplying the
established finding, the future decision it changes, and the destination rather than a
drafted body. Confirm that the proposed change belongs in maintained guidance before
requesting a document; a ticket identifier and a completed fix are not a lesson. One Devin
session may update several repositories when each needs a distinct part of the lesson.
Prefer amending existing guidance.

## Assess the candidate and destination

A useful lesson changes how a similar case would be handled: a proven failure pattern,
an expensive environment discovery, or a mismatch between documented and actual behavior.
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
| Unproven mechanism | Open-theories reference, explicitly labelled as a hypothesis |

New limitations need not match an existing entry. Preserve the proven scope in case law
when no deferral has been decided; do not invent a new-rate-engine decision to fit the
limitations reference. For an existing limitation, add useful new evidence or the new case
rather than restating the rule.

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

Accept a concise rule with its supporting case in a reviewable PR, or state why nothing
qualifies. Check that the diff contains reusable guidance rather than a ticket narrative,
release status, deployment instructions, or a copy of the PR explanation. Reject changes
to implementation, migrations, or test artifacts from a documentation-only assignment.

The mission's rate_case_log is separate: use your mission file tools for its run ledger.
Do not ask Devin to commit that log into a repository if the memory slot is unavailable.
The ledger records runs; repository references preserve only what generalizes.
