# Maintain the rate workflow

For starting cases, answering questions, and requesting another audit, see
[the operator workflow](slack-rate-workflow.md). Connection settings belong in
[Slack setup](slack-setup.md) and [bridge setup](bridge-infrastructure.md).

## Keep responsibilities separate

| Scope | Owner | Instructions |
| --- | --- | --- |
| Work selection and acceptance | Squadron mission | Task objectives and route conditions |
| Repeated coordination | Squadron skill | Session reuse, questions, case handoffs, review follow-up |
| Repository work | Devin session | Playbook assignment and the owning repository's skills |
| Message presentation | Slack skill | Root content, edits, progress replies |
| Durable state | Checkpoint schema and skill | Field meanings, validation, revisions, retention |
| Resuming an ended Jira wait | Bridge | Delivery identity, registration, and recovery |

Task objectives state the work and acceptance criteria. Output descriptions define the
reported result. Keep repeated procedures in skills so a correction has one owner.
A playbook gives Devin its assignment and points to repository procedures; Squadron
supplies facts and constraints, while Devin writes repository and ticket prose.

## Hand off accepted work

1. Have the assigned agent collect the session's report and assess it against the task's
   evidence requirements.
2. Save accepted work through [rate_case](../skills/rate_case.md).
3. Select the next task or mission. Cross-mission routes pass the ticket and entry;
   the receiving mission reads the shared checkpoint.

A task output and a Devin report are separate contracts. A valid report shape does not
establish that the evidence supports its conclusion. The
[playbook guide](../devin-playbooks/README.md) covers publishing text and schemas together.

## Direct work to its owner

| Work | Session responsibility |
| --- | --- |
| Investigation | Establish the mechanism, scope, authority, and supporting evidence |
| Fix | Implement the accepted remedy |
| Ratevariant cases | Supply A/B fixtures and captures |
| Bruno | Test the fix in staging |
| Lessons | Propose supported, reusable guidance |

Squadron owns audit acceptance. It obtains analysis and captures from the appropriate
sessions, sends corrections to their owners, and reassesses the returned evidence. An
independent WAI verification uses a separate session to challenge the original conclusion.
Use [delegated_session](../skills/delegated_session.md) for session selection and recovery.

## Questions and review

[blocked_run](../skills/blocked_run.md) owns question screening and channel selection.
Operator choices and tool-access needs use human ask. Product questions go to Jira, with
an ask in Slack to signal when answers are ready for assessment.

After lessons, `review_followup` keeps Squadron available for operator feedback until
PRs merge or the operator ends review. It reuses the work sessions and requests another
audit when feedback or changed commits invalidate the prior result. The
[review_followup skill](../skills/review_followup.md) owns that loop; it is separate from
Jira blocker recovery.

## State and recovery

The [checkpoint skill](../skills/rate_checkpoint.md) owns reads and writes. The
[checkpoint schema](schemas/rate-ticket-checkpoint.schema.json) owns field definitions;
the [examples](schemas/examples/rate-ticket-checkpoint.slack.json) show complete records.
Retain accepted findings and source references so a resumed stage can use the requirement
without repeating investigation. Raw captures remain with their source.

The [bridge skill](../skills/bridge.md) owns registering and resolving Jira waits. The
bridge carries the saved mission and entry; Squadron assesses the answer and selects the
session that acts on it. An active human ask and a bridge recovery must not own the same
continuation, so bridge registration follows an unresolved ask's end.
