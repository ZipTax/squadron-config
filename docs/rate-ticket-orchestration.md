# Rate-ticket orchestration

This document proposes how Squadron, Devin, Jira, and a small bridge service should cooperate on
long-running rate tickets. These tickets may pause for days while a tax or product question is
answered. Keeping an agent call open during that pause is fragile, while restarting from the ticket
alone causes the next run to repeat investigation and sometimes reach a different conclusion.

The design therefore separates active work from durable coordination:

- Devin holds the working context for one engineering lane.
- Squadron owns decisions, routing, and the current case checkpoint.
- Jira is where people receive and answer product-level questions.
- The bridge reliably wakes Squadron when Jira receives an explicit ready signal; it does not
  decide what work happens next or select a Devin session.
- Repository skills and documentation hold reusable engineering procedure and precedents.

This is a target design. The Devin blocker contract, production-evidence contract, and checkpoint
schema are now defined in this repository. Runtime instructions target the bridge workflow. Bridge endpoints, tools, and mission event
inputs must be wired before deployment; this text does not establish that they are available.
During deployment, triage converts an existing `rate_resume_state/<TICKET>.md` record only when no
new checkpoint exists, verifies the new checkpoint with `checkpoint_revision: 1`, and then removes
the legacy record.
This read-once path prevents already-waiting tickets from disappearing during the format change.

Apply the four updated playbooks and their structured-output schemas in Devin before deploying the
mission changes that require `outcome` and `human_questions`. The files under `devin-playbooks/` are a
reviewable mirror, not an automatic UI sync; reversing this order would make an old-format session
look like a failed mission stage. Existing sessions that may resume during rollout must also be
checked for the new contract before the mission requirement is enabled.

## Where instructions belong

Keep each decision at the layer that has the context to make it. A mission should not carry
a second copy of a SQL or test-authoring procedure: Squadron cannot inspect the repository
itself, and a copied procedure can disagree with the skill Devin reads there.

| Layer | Owns | Changes when |
| --- | --- | --- |
| Squadron missions | Entry points, inputs/outputs, route conditions, and case-specific handoffs | The workflow graph or handoff contract changes. |
| Squadron skills | Session lifecycle, evidence acceptance, blockers, checkpointing, and correction routing | A coordination rule changes across stages. |
| Devin playbooks | Lane boundary, repository skill entry points, and mapping results to the attached schema | A lane or its machine-readable contract changes. |
| Repository skills | Investigation, SQL, fixture selection, test mechanics, and writing for repository/ticket readers | Engineering practice changes. |
| Attached schemas | Field names, types, and allowed result values | A consumer needs a different result contract. |

Squadron asks for evidence and accepts or rejects it. Devin reads diffs, derives predictions,
reconciles rates, selects case data, and interprets captures. Asking Squadron to repeat those
calculations from pasted procedure bodies adds another interpretation without another source
of evidence. Missing support should therefore produce a bounded request to the evidence owner,
not a calculation improvised by the orchestrator.

Audit acceptance remains with Squadron. A Devin session with relevant context supplies read-only technical
analysis using the repository audit skill, while cases supplies captures and fixture evidence.
This does not create a new implementation lane or let either author approve its own work.
If no investigation session is available, Squadron asks another Devin session with relevant
context to investigate the bounded question. The session keeps its file ownership, while
Squadron judges the evidence; a missing lane alone does not block the audit. WAI verification retains its separate session
because it exists specifically to challenge the original investigation's conclusion.

Agent profiles group reusable responsibilities with relevant capability access. The
`taxcloud_legacy_sql_investigator`, `taxcloud_legacy_sql_implementer`, and
`taxcloud_legacy_sql_reviewer` retain SQL/data skills because their evidence needs differ
from general code work. Their roles do not select Devin playbooks. Both A/B review and WAI
verification use the reviewer profile; their tasks still require different session ownership
and independence. Sharing the profile does not mean sharing the Devin session.

Ratevariant and Bruno authoring share `test_authoring_coordinator` because both delegate test
construction and assess coverage. Their tasks and playbooks specify the repository, allowed
execution, and whether artifacts contain inputs or assertions. Repository query mechanics stay
with Devin. The current rate checkpoint skill remains attached where needed; generalizing its
storage and schema to other ticket workflows is a separate change.

The shortened playbooks remain self-contained at their boundary: Devin cannot assume it can
read this repository's README or Squadron-only skills. A few repeated lines about registration,
completion, and lane scope are intentional; the reusable engineering procedure is referenced
rather than copied. See [the playbook maintenance guide](../devin-playbooks/README.md) for
known upstream conflicts and the deployment checks needed before these mirrors run in Devin.

## What belongs in a task objective versus its output

Organize runtime instructions around responsibility, interaction with Devin, evidence
assessment, and completion. Address the executing agent as “you” and name a “Devin session”
when that is the intended recipient. Send Devin only the task and relevant constraints;
checkpoint handling and other orchestration responsibilities stay with the coordinating agent.

A task objective states the desired result, the work needed to establish it, and constraints
on that work. Its `output` field descriptions state how to synthesize the result: field meaning,
source/provenance, allowed values, and what an empty value means. Do not repeat a list of fields
as “return these” in the objective. Squadron presents the schema to the commander and requires
schema-matching submission through `submit_output`; downstream tasks can query that stored data.
See [Tasks](https://docs.squadron.sh/missions/tasks).

For example, case authoring must obtain coverage and evidence for gaps, so that work belongs in
the objective. Copying `target_authority` from development or the checkpoint belongs in the output
field's description: this stage preserves a prior conclusion rather than establishing authority.
Evidence acceptance still needs an objective or skill because a correctly shaped result can be
unsupported.

The mission objective addresses a task commander. Plugin access belongs to its Squadron agent,
which delegates repository work to Devin. An objective's request to inspect a session therefore
means arranging that inspection through the stage agent, not giving the commander plugin tools.
See [The Harness](https://docs.squadron.sh/missions/harness).

Within a mission, summaries and queryable ancestor outputs provide context, including across a
selected dynamic route. Cross-mission routing creates another instance: `task_complete` presents
the destination inputs for the commander to fill. Keep meaningful mappings, such as an audit
no-op selecting `record_learnings`, with the route rather than repeating the destination schema.
Route conditions are natural-language choices evaluated by the commander, not executable scalar
expressions. See [Routing](https://docs.squadron.sh/missions/routing).

Devin's attached schema and Squadron's task output remain separate contracts. The former reports
lane work; the latter records the commander's accepted result and orchestration metadata. Removing
an objective's field list does not remove the need to collect and assess the Devin result.

## Why a case has several Devin sessions

Investigation, implementation, ratevariant cases, and Bruno coverage require different repositories,
evidence, and permissions. One session owns each lane so that a test author does not silently change
the fix and an implementer does not manufacture expectations from the current behavior.

The lane registry records the exact owner:

| Lane | Responsibility |
| --- | --- |
| `investigation` | Establish production facts, applicable authority, and the SQL Server execution path. |
| `fix` | Implement the diagnosis Squadron approved. |
| `ratevariant-cases` | Author and maintain local A/B fixtures and alterations. |
| `bruno-tests` | Author live-API regression coverage from settled expectations. |

The checkpoint records each lane's exact owner. The independent WAI verifier is a verification
session, not a replacement owner of the investigation lane. When new information arrives, Squadron chooses
which owner needs it; the session that raised a question is not necessarily the session that can
answer the resulting engineering question. The bridge must never choose the newest session or
combine conclusions from several sessions. If the selected owner is unavailable, Squadron handles
that as an explicit recovery case.

Audit is a Squadron responsibility rather than another implementation lane. It uses the existing
sessions to obtain work and evidence:

- A procedure or migration problem goes to the fix session.
- A fixture, reachability, or coverage problem goes to the ratevariant-cases session.
- A production fact, tax treatment, or execution-path question goes to the investigation session.

When audit asks investigation a question, investigation returns evidence and unknowns. Audit keeps
the verdict. This preserves independent judgment without creating a second research lane.

## When Squadron remains active

Squadron should remain active while Devin is doing bounded engineering work. In that case Squadron
can use `send_message` and `check_session`, receive structured output, update the checkpoint, and
route the next task within the same mission.

For example, an audit iteration can ask the cases session to cover a missing root, wait for that
turn, inspect the new output, and audit the new commit. The bridge adds no value inside this live
loop.

Devin needs no live-versus-cold mode. It responds to a message and becomes idle when messages stop.
Squadron always collects the result in the same way: it sends work to the chosen session and then
uses the returned result and `check_session`. Whether the mission was already running or was just
started by a Jira webhook is invisible to Devin.

## When Squadron ends the mission

Squadron should not remain open while waiting for a person. Squadron persists crash-recovery state,
but a week-long tool call still depends on a process, network connection, plugin timeout, and model
context remaining usable. A deliberate human wait is therefore a completed, checkpointed run—not
an interrupted tool call.

When Devin reports `needs_human`, Squadron owns the blocking workflow:

1. Validate that the missing information really requires a person.
2. Record which session raised the question and which mission stage must reconsider it when Jira
   receives new information. This does not preselect the session that will consume the answer.
3. Ask a context-owning session to author the Jira question using the repository's ticket-writing
   skill. Usually this is the session that raised it, but Squadron may choose another session with
   better product context. Devin supplies the words because it can read the ticket and the
   co-located guidance; Squadron decides that the question may be posted.
4. Confirm the Jira comment exists, then register the blocker with the bridge.
5. Write the current checkpoint, add the configured needs-information label, remove any stale
   ready-for-Squadron label, and end the mission.

The order matters. A label without a visible question leaves a ticket that appears blocked but gives
the reader nothing to answer. A question without a registered blocker cannot reliably wake
Squadron to evaluate the response.

If any step fails, record the partial state and retry idempotently. Do not create a second question
or a second Devin session to escape an uncertain result.

## What the bridge does

The bridge is delivery infrastructure, not an agent and not an alternate workflow engine. It needs
two conceptual endpoints:

```text
POST /blockers       Squadron registers or revises a human blocker.
POST /webhooks/jira  Jira delivers ready-label changes on tickets waiting for information.
```

It also needs a durable outbox for calls to Squadron. A webhook receiver should persist an accepted
event before returning success, then deliver it asynchronously. This protects the workflow from
process restarts, Jira retries, and an unavailable Squadron instance. Because the bridge does not
message Devin, it does not need a Devin API key.

The bridge may validate webhook identity, the ready-label transition, and blocker generation, but
it does not infer the next phase or whether the discussion answers the question. Squadron records a
resume mission and entry stage when it registers the blocker. The bridge later invokes exactly that
target with the Jira event ID and the active blocker generation.

For example, if audit pauses while investigation obtains a human tax decision, the blocker can say
that new Jira activity returns to `rate-fix` at `audit`. The resumed audit stage may send the answer
to investigation, the fix session, or more than one session in sequence. The bridge does not make
that choice.

## How a human answer resumes work

The cold continuation is:

```text
Squadron registers blocker and exits
                    |
                    | time passes
                    v
Human adds ready label -> bridge -> recorded Squadron entry point
                                           |
                                           v
                              selected Devin session(s)
```

In detail:

1. A person answers or discusses the question in its existing Jira discussion. Ordinary comments
   do not start a mission.
2. When the person believes the available answer is ready for another attempt, they add the
   configured ready-for-Squadron label.
3. Jira sends an issue-update webhook. The bridge accepts only an addition of that label on a
   ticket with an active blocker and the needs-information label; removals and unrelated field
   changes do nothing.
4. The bridge claims that ready transition and invokes the recorded Squadron mission and entry
   stage. Its payload identifies the Jira event and active blocker generation; it does not claim
   that the discussion is a sufficient answer.
5. Squadron clears the ready label, then reads the checkpoint and Jira discussion after the last
   processed comment. It may discard a duplicate or unrelated event without waking Devin; domain
   sufficiency is assessed by the selected context-owning session.
6. If engineering interpretation is needed, Squadron selects the appropriate registered lane and
   sends that session a bounded request to read the Jira update. This may be different from the
   session that raised or authored the question.
7. Squadron receives the normal Devin result, checks the session as it would in any live mission,
   updates the checkpoint, and decides whether to continue, refine the blocker, or close the case.

This means Devin neither restarts Squadron nor chooses the next phase. It only performs the work
Squadron routes to it and reports what remains unknown.

## How duplicate resumes are prevented

Jira delivery retries and repeated human discussion are different problems. The bridge therefore
tracks both webhook delivery and the logical blocker.

A blocker has a stable Jira discussion and a monotonically increasing question generation:

```yaml
blocker_id: TAX-123/start-date-treatment
ticket: TAX-123
generation: 3
raised_by:
  lane: fix
  session_id: devin-fix
root_comment_id: "184900"
current_question_comment_id: "184927"
last_processed_comment_id: "184926"
last_dispatched_ready_event_id: "jira-event-5512"
question_digest: sha256-of-normalized-open-questions
state: waiting
resume_mission: rate-fix
resume_entry_stage: audit
```

The generation advances only when Squadron approves a materially different question set. Receiving
a Jira webhook does not advance it. When an answer exposes a missing date, scope, or other necessary
detail, Squadron replies in the existing Jira discussion with the refined question and advances the
generation. The root comment remains stable, while `current_question_comment_id` identifies the ask
that the next reply must address. A net-new top-level comment would separate the clarification from
the context that explains it.

If a reply is merely irrelevant and Squadron asks nothing new, the generation does not advance. The
same question remains current.

At minimum, storage enforces uniqueness for:

```text
Jira webhook identifier
(blocker_id, blocker generation)
(blocker_id, blocker generation, ready-label transition ID)
Squadron start event ID
```

The bridge dispatches only a newly observed addition of the ready label for the active generation.
It does not dispatch merely because the generation is higher than the last successful one: a person
may add the ready label again for the same generation after supplying a better answer to an
unchanged question. Duplicate deliveries of one label transition are ignored, while a later
remove-and-add transition is a new request for review.

The Squadron start request carries a stable event ID derived from the blocker generation and ready
transition ID. Both the bridge and the mission deduplicate it. This covers the case where Squadron
accepts a start but the response is lost before the bridge records success.

Only one resume may be in flight for a blocker. Squadron reads all discussion after
`last_processed_comment_id`, so comments written before it claims the ready signal are considered
together. The ready label is an edge-trigger: Squadron removes it when the mission starts so a later
addition can request another review. The needs-information label is durable state and remains until
Squadron decides the blocker is resolved.

## How missions remain coarse-grained

Webhook support does not require one mission per task. The existing phase boundaries are suitable
entry points:

- `rate-triage` owns discovery, investigation, and the initial disposition.
- `rate-fix` owns implementation, ratevariant case authoring, audit, and Bruno handoff.
- `rate-finalize` owns WAI verification, learning capture, and close-out.

Each phase can accept an `entry_stage` plus the checkpoint and session identifiers it needs. Internal
tasks remain ordinary mission tasks and routes. Only the stable phase boundaries need webhook entry
points.

Squadron chooses and records `resume_mission` and `resume_entry_stage` before it exits. The bridge
consequently makes no dynamic routing decision when Jira reports new information. An optional
single webhook-ingress mission could validate and forward events, but it is not required if the
bridge calls the recorded phase webhook directly.

Squadron's documented `max_parallel` behavior skips a webhook-triggered run when the mission is at
capacity rather than queueing it. The bridge outbox must therefore retain the start request until
Squadron accepts it. The mission also deduplicates the supplied start event ID in case acceptance
succeeds but its response is lost.

## What Squadron remembers

Squadron is the only writer of the per-ticket checkpoint. The bridge passes delivery records and
Devin returns structured facts, but neither edits orchestration memory directly. Single ownership
prevents a late Jira delivery from overwriting a newer audit decision.

The checkpoint is an index and decision record, not a transcript. Required keys describe the
coordination envelope, not completed work: lanes and artifacts may be null, results and lists
may be empty, and a new session has output_revision 0 until a result is collected. See the
[early checkpoint](schemas/examples/rate-ticket-checkpoint.early.json). Its authoritative contract is
[`schemas/rate-ticket-checkpoint.schema.json`](schemas/rate-ticket-checkpoint.schema.json); the
production observations it contains use
[`schemas/production-evidence.schema.json`](schemas/production-evidence.schema.json). Readers reject
an unknown `schema_version`, and writers increment `checkpoint_revision` after re-reading the
current file so a late mission cannot overwrite a newer decision. This field identifies the current
checkpoint write; it is not a Jira revision or a history of stored snapshots.

The following excerpt shows the responsibilities rather than every required field:

```yaml
schema_version: 1
ticket: TAX-123
checkpoint_revision: 4
updated_at: 2026-09-10T19:20:00Z
stage: audit
verdict: defect_proven
mechanism: district rate selected from an obsolete effective row
lanes:
  investigation:
    session_id: 8e72920a57d04c5592603de7085cb45e
    output_revision: 4
  fix:
    session_id: 93b2501d2bf94cc7a81208134c8c1ca2
  ratevariant-cases:
    session_id: ab854fca652b46bf98e98c55c862f1a8
artifacts:
  fix_pr:
    url: https://github.com/FedTax/txc-sqlserver-database/pull/123
    branch: TAX-123-fix
    head_sha: abc123
audit:
  iteration: 2
  last_result: changes_requested
blocker: null
completed_stages:
  - develop
  - author_tests
wai_refire_count: 0
processed_start_event_ids: []
next_entry:
  mission: rate-fix
  stage: audit
```

Evidence stays in the systems that produced it: Jira, Devin session output, PRs, and ratevariant
captures. Generalizable lessons move into repository skills or reference documentation through the
learning-capture process. Copying either into the checkpoint would create another version that can
drift.

PR descriptions are not workflow storage. They describe the proposed code change and may be edited
by authors or reviewers. Session links and process state belong in the checkpoint and, if people
need a convenient index, a dedicated Jira field or bridge status view.

## Where production evidence fits

Databricks MCP access is only for production observation: rows, configuration, transaction facts,
and historical state made available through governed Unity Catalog objects. It does not replace the
local `txc-sqlserver-database` checkout, SQL Server execution, or the ratevariant harness.

The production-query identity should be read-only, limited to approved catalogs or views, and
audited. Queries should be bounded by ticket-relevant identifiers and dates. The evidence record
captures a stable query reference, execution time, relevant catalog objects, bounded scope, and the
domain conclusion. Raw rows and large tool output stay with the system that produced them because
copying them into the checkpoint would make it a second evidence store.

Production evidence has an explicit status: `sufficient`, `insufficient`, or `unavailable`. No
matching rows, incomplete history in the replica, stale synchronization, access refusal, and a
truncated result are different findings and must not be collapsed into "production showed
nothing." In particular, absence from the accessible Databricks data is not proof that the reported
behavior is working as intended.

When missing production data prevents a supported conclusion, Squadron surfaces the gap on the Jira
ticket. The comment identifies the unavailable artifact or period, why it matters to the decision,
and whether local investigation can still proceed. The same blocker workflow applies if a person
can supply the missing evidence; otherwise the case closes or escalates with an explicit
`insufficient_production_evidence` outcome rather than an inferred verdict.

The proof chain remains:

1. Databricks establishes what production data contained.
2. The SQL Server repository establishes which procedure or function consumes that data.
3. The local harness demonstrates baseline and proposed behavior.
4. Bruno captures the settled live-API contract when that coverage is appropriate.

Production observations can explain a result, but they cannot by themselves prove that a stored
procedure change is correct.

## Incremental implementation

The design can be introduced without rewriting every mission at once:

1. Define a typed Devin output for `needs_human`. **Defined:** every rate-lane playbook schema now
   returns `outcome` plus structured question-and-context pairs in `human_questions`.
2. Define the production-evidence status and ticket-visible gap outcome. **Defined:** investigation
   output and checkpoint records distinguish `sufficient`, `insufficient`, and `unavailable`, then
   say whether the ticket outcome is `none`, `needs_human`, or
   `insufficient_production_evidence`.
3. Replace the free-form resume record with a checkpoint that has an explicit schema version.
   **Defined and adopted by the mission memory contract:** `rate_checkpoint/<TICKET>.yaml` is
   Squadron-owned, and `checkpoint_revision` identifies its current write.
4. Build blocker registration, the Jira receiver, delivery deduplication, and the durable outbox.
5. Make the three existing rate phases webhook-entry-capable and accept explicit entry stages.
6. Add the read-only Databricks MCP evidence path independently; it does not depend on the bridge.

Deploy these blocking instructions with the bridge wiring and disable the old comment-triggered
resumption for the migrated tickets. Both triggers must not own the same ticket.
