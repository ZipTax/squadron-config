# Rate-ticket orchestration

Squadron coordinates a rate case from investigation through review. Devin sessions own
repository work, Jira holds product findings and questions, and Slack provides progress
updates and operator interaction. Missions exchange information through a shared checkpoint,
retained after completion for reference or reuse.

For starting a case and answering questions, see [the Slack workflow](slack-rate-workflow.md).
Connection settings belong in [Slack setup](slack-setup.md) and
[bridge setup](bridge-infrastructure.md).

## Work through a rate case

1. **Investigate.** Establish the cause, scope, and supporting authority. Post the results
   in product language on Jira. A working-as-intended conclusion receives an independent
   check; a proven defect proceeds to a proposed fix.
2. **Propose and test the fix.** The fix owner implements the accepted remedy. The
   ratevariant-cases owner supplies A/B coverage. Squadron audits the evidence for
   directional correctness and regressions, directing corrections to the appropriate owner.
3. **Add API regressions.** The Bruno owner authors and reviews tests; CI runs them in
   staging. Before deployment, should-change tests fail and guardrails pass. Those expected
   failures demonstrate the regression and allow the work to proceed to review.
4. **Record lessons.** Assess lessons from the work sessions. One writeback session records
   accepted, durable guidance, with one documentation PR per repository.
5. **Review and follow up.** Squadron accepts feedback, collects current session work,
   re-audits changed commits, and directs corrections to the existing owners.
6. **Verify after staging deployment.** The operator deploys manually and tells Squadron.
   Squadron has the Bruno owner review fresh CI results: should-change tests now pass and
   guardrails remain passing. Unchanged or new failures return to investigation and correction.

The Slack root shows the cause, status, and PRs. Detailed progress and questions appear in
its thread. Updating Slack preserves the product-language investigation results on Jira.

## Keep work with its owner

| Owner | Responsibility |
| --- | --- |
| Squadron | Accept evidence, select the next work, maintain case state, and coordinate questions and review |
| Investigation session | Establish production facts, applicable authority, and the execution path |
| Fix session | Implement the accepted remedy |
| Ratevariant-cases session | Author A/B fixtures and supply captures and coverage evidence |
| Bruno session | Author API regressions and review automatic staging CI results |
| Learning-writeback session | Record accepted lessons in maintained guidance |
| Bridge | Resume a recorded Jira wait when an explicit ready signal arrives |

Session ownership separates implementation from test construction and evidence acceptance.
Squadron retains the audit verdict while sessions provide analysis and captures. For example,
a fixture gap goes to the cases owner, a migration defect to the fix owner, and an uncertain
production fact to investigation. A missing investigation session can be handled by asking
another available session a bounded question within its existing ownership constraints.

Working-as-intended verification uses a separate session to challenge the original conclusion.
Sharing a Squadron agent profile does not remove that independence requirement.

Reuse the recorded owner when continuing work. If it is unavailable, retain its evidence and
select an explicit replacement through [delegated_session](../skills/delegated_session.md).
The session that raised a question may differ from the owner best placed to act on its answer.

## Put instructions at the appropriate level

| Location | Belongs here |
| --- | --- |
| Mission | Work to perform, acceptance criteria, entry points, and routing decisions |
| Squadron skill | Repeated coordination: session reuse, evidence assessment, questions, and checkpoint handling |
| Devin playbook | The session's assignment, repository skill entry points, and report contract |
| Repository skill | Investigation, SQL, fixture selection, test mechanics, and writing procedures |
| Schema | Field definitions, required values, and result structure |

Squadron requests evidence and assesses it. Devin reads repository code, derives predictions,
selects test data, and interprets captures using repository guidance. Keep those procedures
with Devin so the orchestrator does not maintain a competing copy or improvise missing analysis.

For published prose, Squadron supplies facts, purpose, and constraints; the context-owning
Devin session writes for the ticket or repository audience. See the
[playbook guide](../devin-playbooks/README.md) for maintaining and publishing playbooks.

## Keep task objectives and outputs distinct

A task objective states what to accomplish and what evidence establishes completion. Output
descriptions define the accepted result and its source. For example:

- Case authoring must obtain coverage and explain gaps: that belongs in the objective.
- Preserving accepted investigation findings belongs in the output description; the test
  author is carrying forward a conclusion, not establishing its authority again.

The task commander arranges session work through its Squadron agent. Devin's report and the
commander's accepted task output are separate contracts: a correctly shaped report still
needs assessment against the task's evidence requirements.

Route conditions guide the commander's choice. Keep meaningful decisions with the route,
such as an audit no-op proceeding to lessons. Cross-mission handoffs explicitly supply the
receiving mission's ticket and entry; the destination reads accepted context from the shared
checkpoint. A task summary alone does not populate the destination inputs. Use
[rate_case](../skills/rate_case.md) for the shared handoff procedure.

## Handle questions without losing context

Screen a question against available evidence before asking a person. Then use the channel
appropriate to the answer:

| Question | Handling |
| --- | --- |
| Operator decision, date choice, access, or deployment | Squadron's human ask in Slack |
| Product question or inconsistent requirements | Jira question, followed by a Slack human ask to signal when answers are ready |
| Missing production data | Try alternative tools or a tool extension before raising an operator dependency |

Use [blocked_run](../skills/blocked_run.md) for question handling. Save the question and
progress, show `Blocked on question`, and have the appropriate owner assess the answer before
continuing. A ready signal means there is new information to assess; it does not establish
that the question is resolved.

While a human ask is active, its answer continues the current work. If a Jira wait ends
unresolved, persist the continuation and register bridge recovery. Register after the active
ask ends so the same answer cannot start two continuations.

## Resume an ended Jira wait

1. A person answers on Jira and adds the configured ready label.
2. The bridge delivers that signal to the recorded Squadron entry.
3. Squadron reads the checkpoint and new discussion, then asks the appropriate owner to
   assess the answer.
4. Squadron accepts the result and continues, refines the question, or closes the case.

Ordinary Jira comments do not start a mission. The bridge delivers the saved continuation;
Squadron chooses the work and session. Delivery retries retain the same identity, while a
new human wait receives a new generation, so old events cannot restart newer work.

The [bridge skill](../skills/bridge.md) owns registration and recovery rules. Endpoint,
outbox, and delivery setup belong in [bridge infrastructure](bridge-infrastructure.md).

## Keep final review available

After lessons, Squadron waits for feedback through its review prompt. Feedback may request
another audit, include changes requested directly from Devin, or report a manual staging
deployment. Squadron collects current session results and PR heads before assessing the work.

After deployment, fresh Bruno CI results can reveal an ineffective fix or new regressions.
Squadron delegates those findings to the existing owners and re-audits corrections. If a
correction needs another deployment, the operator deploys it and requests the next check.
Results and pending work are posted in Slack.

The `review_followup` task in [rate_finalize](../missions/rate-finalize.hcl) owns this loop.
Review remains open until
PRs merge and requested checks and corrections are settled, or the operator explicitly ends
it. An interrupted wait retains the next action for resumption.

## Retain accepted state and source evidence

Squadron maintains the checkpoint so later missions can continue from accepted findings and
recorded ownership. Read the latest record before updating it to preserve other completed
work. An incomplete record is valid context; an empty result is not proof of completion.

The [checkpoint skill](../skills/rate_checkpoint.md) owns updates and recovery. The
[checkpoint schema](schemas/rate-ticket-checkpoint.schema.json) defines its fields, and the
[examples](schemas/examples/rate-ticket-checkpoint.early.json) show partial state.

Raw evidence remains with Jira, session reports, PRs, and captures. The checkpoint retains
accepted findings and references. Reusable lessons belong in maintained guidance; PR
descriptions explain the proposed change rather than storing coordination history.

## Use production evidence appropriately

Production observations establish data, configuration, transaction facts, and history.
Repository analysis establishes how the code consumes them; A/B demonstrates baseline and
proposed behavior. Bruno verifies the API behavior as deployment changes staging.

No matching rows, missing history, stale data, denied access, and truncated results have
different meanings. Preserve those distinctions so unavailable evidence cannot be mistaken
for proof that behavior is correct.

For a data gap, the owner first tries other tools or another way to obtain the answer.
When necessary, extend `prod-sql-insights` and raise an operator dependency for access or
deployment. See [production evidence coordination](../skills/txc_staging_access.md).
Jira questions remain focused on product decisions. If evidence cannot support a conclusion,
retain that limitation instead of inferring a verdict.
