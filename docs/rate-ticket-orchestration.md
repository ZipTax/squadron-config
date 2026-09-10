# Rate-ticket orchestration

This document proposes how Squadron, Devin, Jira, and a small bridge service should cooperate on
long-running rate tickets. These tickets may pause for days while a tax or product question is
answered. Keeping an agent call open during that pause is fragile, while restarting from the ticket
alone causes the next run to repeat investigation and sometimes reach a different conclusion.

The design therefore separates active work from durable coordination:

- Devin holds the working context for one engineering lane.
- Squadron owns decisions, routing, and the current case checkpoint.
- Jira is where people receive and answer product-level questions.
- The bridge reliably delivers asynchronous events; it does not decide what work happens next.
- Repository skills and documentation hold reusable engineering procedure and precedents.

This is a target design. The existing rate missions still implement their current memory-and-label
resumption flow until the bridge and event contracts described here are available.

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

An asynchronous event always names a lane and session. The bridge must never choose the newest
session or combine conclusions from several sessions. If the recorded owner is unavailable,
Squadron handles that as an explicit recovery case.

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

Every message to Devin declares how its result will be collected:

| Continuation mode | Caller | Devin behavior when the turn finishes |
| --- | --- | --- |
| `synchronous` | A running Squadron mission | Return structured output to the caller. Do not emit a bridge event. |
| `callback` | The bridge after a cold pause | Emit one completion event using the supplied continuation token. |

Declaring the mode prevents a running mission and the bridge from both starting the next run.

## When Squadron ends the mission

Squadron should not remain open while waiting for a person. Squadron persists crash-recovery state,
but a week-long tool call still depends on a process, network connection, plugin timeout, and model
context remaining usable. A deliberate human wait is therefore a completed, checkpointed run—not
an interrupted tool call.

When Devin reports `needs_human`, Squadron owns the blocking workflow:

1. Validate that the missing information really requires a person.
2. Assign the blocker to the exact lane and session that can interpret the answer.
3. Ask that context-owning session to author the Jira question using the repository's ticket-writing
   skill. Devin supplies the words because it can read the ticket and the co-located guidance;
   Squadron decides that the question may be posted.
4. Confirm the Jira comment exists, then register the blocker with the bridge.
5. Write the current checkpoint, add the configured needs-information label, and end the mission.

The order matters. A label without a visible question leaves a ticket that appears blocked but gives
the reader nothing to answer. A question without a registered blocker cannot reliably wake the
right session.

If any step fails, record the partial state and retry idempotently. Do not create a second question
or a second Devin session to escape an uncertain result.

## What the bridge does

The bridge is delivery infrastructure, not an agent and not an alternate workflow engine. It needs
three conceptual endpoints:

```text
POST /blockers       Squadron registers or revises a human blocker.
POST /webhooks/jira  Jira delivers comments on tickets waiting for information.
POST /events         A callback-mode Devin continuation reports that its turn ended.
```

It also needs a durable outbox for calls to Devin and Squadron. A webhook receiver should persist
an accepted event before returning success, then deliver it asynchronously. This protects the
workflow from process restarts, provider retries, and an unavailable downstream service.

The bridge may validate identities and workflow transitions, but it does not infer the next phase.
Squadron records the callback mission and entry stage when it creates the continuation. The bridge
later invokes exactly that target.

For example, if audit pauses while investigation obtains a human tax decision, the blocker can say
that the completed continuation returns to `rate-fix` at `audit`. Investigation does not decide that
audit is next, and the bridge does not derive it from the result.

## How a human answer resumes work

The cold continuation is:

```text
Squadron registers blocker and exits
                    |
                    | time passes
                    v
Jira answer -> bridge -> recorded Devin session -> completion event
                                                    |
                                                    v
                                    recorded Squadron entry point
```

In detail:

1. Jira sends a comment webhook for a ticket carrying the needs-information label.
2. The bridge finds the active blocker for the ticket and ignores automation-authored comments.
3. The bridge claims the Jira comment for that blocker and sends a callback-mode message to the
   recorded Devin session. The message identifies the Jira comment; Devin reads the answer from
   Jira rather than trusting an unverified copy in the webhook payload.
4. Devin continues its lane. It returns either usable work or another `needs_human` result.
5. Devin emits a completion event with the continuation token. It does not choose a mission or
   register another blocker.
6. The bridge invokes the callback mission and entry stage recorded by Squadron.
7. Squadron reads the session's structured output, updates its checkpoint, and decides whether to
   continue, create a new blocker generation, or close the case.

This means a second human question still belongs to Squadron. Devin only reports what remains
unknown.

## How duplicate resumes are prevented

Jira delivery retries and repeated human discussion are different problems. The bridge therefore
tracks both webhook delivery and the logical blocker.

A blocker is identified by ticket, owning lane, and a monotonically increasing generation:

```yaml
blocker_id: TAX-123/investigation/3
ticket: TAX-123
lane: investigation
generation: 3
owner_session_id: devin-abc123
question_comment_id: "184927"
question_digest: sha256-of-normalized-open-questions
state: waiting
callback_mission: rate-fix
callback_entry_stage: audit
```

The generation advances only when Squadron approves a materially different question set. Receiving
a Jira webhook does not advance it. If a reply is insufficient and the same question remains open,
the bridge returns the same blocker to `waiting` after Squadron reviews the continuation.

At minimum, storage enforces uniqueness for:

```text
Jira webhook identifier
(blocker_id, Jira answer comment ID)
(ticket, lane, blocker generation)
Devin completion event ID
Squadron start event ID
```

Messages sent to Devin carry a stable marker containing the blocker and Jira comment IDs. If a
network failure makes delivery uncertain, the bridge checks the session messages for that marker
before retrying. A completion event similarly carries a stable continuation token so a repeated
callback starts at most one logical Squadron run.

The needs-information label remains until Squadron decides the answer is sufficient. Clearing it as
soon as the first comment arrives can lose a second comment when a person answers in several parts.

## How missions remain coarse-grained

Webhook support does not require one mission per task. The existing phase boundaries are suitable
entry points:

- `rate-triage` owns discovery, investigation, and the initial disposition.
- `rate-fix` owns implementation, ratevariant case authoring, audit, and Bruno handoff.
- `rate-finalize` owns WAI verification, learning capture, and close-out.

Each phase can accept an `entry_stage` plus the checkpoint and session identifiers it needs. Internal
tasks remain ordinary mission tasks and routes. Only the stable phase boundaries need webhook entry
points.

Squadron chooses and records `callback_mission` and `callback_entry_stage` before it exits. The
bridge consequently makes no dynamic routing decision when the continuation finishes. An optional
single webhook-ingress mission could validate and forward events, but it is not required if the
bridge calls the recorded phase webhook directly.

Squadron's documented `max_parallel` behavior skips a webhook-triggered run when the mission is at
capacity rather than queueing it. The bridge outbox must therefore retain the start request until
Squadron accepts it. The mission also deduplicates the supplied start event ID in case acceptance
succeeds but its response is lost.

## What Squadron remembers

Squadron is the only writer of the per-ticket checkpoint. The bridge passes delivery records and
Devin returns structured facts, but neither edits orchestration memory directly. Single ownership
prevents a late callback from overwriting a newer audit decision.

The checkpoint is an index and decision record, not a transcript:

```yaml
ticket: TAX-123
stage: audit
verdict: defect_proven
mechanism: district rate selected from an obsolete effective row
lanes:
  investigation:
    session_id: devin-investigation
    output_revision: 4
  fix:
    session_id: devin-fix
    pr_url: https://github.example/pull/123
    head_sha: abc123
  ratevariant-cases:
    session_id: devin-cases
    head_sha: abc123
audit:
  iteration: 2
  last_result: changes_requested
blocker: null
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
captures the query, execution time, relevant catalog objects, and a small result or summary.

The proof chain remains:

1. Databricks establishes what production data contained.
2. The SQL Server repository establishes which procedure or function consumes that data.
3. The local harness demonstrates baseline and proposed behavior.
4. Bruno captures the settled live-API contract when that coverage is appropriate.

Production observations can explain a result, but they cannot by themselves prove that a stored
procedure change is correct.

## Incremental implementation

The design can be introduced without rewriting every mission at once:

1. Define typed Devin outputs for `needs_human` and callback completion.
2. Replace the free-form resume record with a versioned checkpoint schema.
3. Build blocker registration, the Jira receiver, delivery deduplication, and the durable outbox.
4. Add callback mode to the relevant Devin playbooks and skills.
5. Make the three existing rate phases webhook-entry-capable and accept explicit entry stages.
6. Add the read-only Databricks MCP evidence path independently; it does not depend on the bridge.

Until a phase is migrated, its current blocking behavior remains authoritative. Do not run the old
label-triggered resumption and the bridge callback for the same ticket, because both will believe
they own the next run.
