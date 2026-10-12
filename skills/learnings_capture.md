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

Include these writing criteria in the documentation assignment; the writing session does
not inherit this skill. Ask Devin to read relevant maintained guidance before drafting,
both to avoid duplication and to select a useful style reference. Prefer an entry that
explains a finding and its consequence over one organized as an incident log. Use the
DEV-10223 entry in `ratevariant-audit/references/case-law.md`, as revised in
[PR #288, commit 2c571e6](https://github.com/FedTax/txc-sqlserver-database/commit/2c571e6f1f06539a817f5c3081f4585256ad3249),
as an example. Borrow its clarity, not its tax facts or a mandatory heading template.

- Lead with the reusable finding or required action. A heading should tell the reader what
  to understand or verify, rather than name a topic or recount what a session got wrong.
- Explain why the rule matters and what follows from it. Use explicit causal language:
  TaxCloud output cannot independently validate TaxCloud data because it derives from that
  data; therefore, the expected value needs independent evidence.
- Give only the case facts needed to understand and support that conclusion. Introduce the
  relevant system, source, and period before comparing values. Retain dates or quantities
  that explain the discrepancy, and link the evidence instead of copying attachment IDs,
  row IDs, endpoint syntax, session history, or the sequence of attempts unless those details
  are necessary to apply the lesson.
- Preserve unresolved obligations. Missing authority leaves an expected value unresolved;
  omitting its test does not satisfy the coverage requirement. Explain what evidence would
  resolve the gap without treating a workaround, omission, or documented limitation as proof.
- Use short, connected paragraphs for distinct findings. A skill should give actionable
  guidance with its reason; a case reference should show the evidence and consequence.
  Avoid repeating the same rule in an opening, a case narrative, and a closing rules list.

Leave wording and structure to Devin within these criteria. Review the result for whether a
maintainer unfamiliar with the case can explain the finding, why it matters, when it applies,
and what remains unproven. Return specific writing defects for revision instead of supplying
a replacement article or accepting prose merely because it contains citations.

## Finish

Report the sessions asked, their proposals or explicit “none” responses, and any unavailable
responses. Accept a concise rule with its supporting case in a reviewable PR, or explain why
the returned proposals did not qualify. Check that the diff contains reusable guidance rather
than a ticket narrative, release status, deployment instructions, or a copy of the PR explanation.
Reject changes to implementation, migrations, or test artifacts from a documentation-only
assignment.

The mission's rate_case_log is separate: use your mission file tools for its run ledger.
Do not ask Devin to commit that log into a repository if the memory slot is unavailable.
The ledger records runs; repository references preserve only what generalizes.
