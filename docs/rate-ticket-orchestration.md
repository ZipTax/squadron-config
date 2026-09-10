# Rate-ticket orchestration

This document proposes how Squadron, Devin, Jira, and a small bridge service should cooperate on
long-running rate tickets. These tickets may pause for days while a tax or product question is
answered. Keeping an agent call open during that pause is fragile, while restarting from the ticket
alone causes the next run to repeat investigation and sometimes reach a different conclusion.

The design therefore separates active work from durable coordination:

- Devin holds the working context for one engineering lane.
- Squadron owns decisions, routing, and the current case checkpoint.
- Jira is where people receive and answer product-level questions.
- The bridge reliably wakes Squadron when Jira has new information; it does not decide what work
  happens next or select a Devin session.
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

The checkpoint records each lane's exact owner. When new information arrives, Squadron chooses
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
5. Write the current checkpoint, add the configured needs-information label, and end the mission.

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
POST /webhooks/jira  Jira delivers comments on tickets waiting for information.
```

It also needs a durable outbox for calls to Squadron. A webhook receiver should persist an accepted
event before returning success, then deliver it asynchronously. This protects the workflow from
process restarts, Jira retries, and an unavailable Squadron instance. Because the bridge does not
message Devin, it does not need a Devin API key.

The bridge may validate webhook identity and blocker generation, but it does not infer the next
phase or whether a comment answers the question. Squadron records a resume mission and entry stage
when it registers the blocker. The bridge later invokes exactly that target with the new Jira
comment ID.

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
Jira update -> bridge -> recorded Squadron entry point
                                      |
                                      v
                         selected Devin session(s)
```

In detail:

1. Jira sends a comment webhook for a ticket carrying the needs-information label.
2. The bridge finds the active blocker for the ticket and ignores automation-authored comments.
3. The bridge claims the Jira comment for that blocker and invokes the recorded Squadron mission
   and entry stage. Its payload identifies the blocker generation and new comment; it does not
   claim that the comment is a sufficient answer.
4. Squadron reads the checkpoint and the new Jira discussion. It may decide that the comment is
   irrelevant or incomplete without waking Devin.
5. If engineering interpretation is needed, Squadron selects the appropriate registered lane and
   sends that session a bounded request to read the Jira update. This may be different from the
   session that raised or authored the question.
6. Squadron receives the normal Devin result, checks the session as it would in any live mission,
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
(blocker_id, Jira answer comment ID)
(blocker_id, blocker generation)
Squadron start event ID
```

The Squadron start request carries a stable event ID derived from the blocker generation and Jira
comment ID. Both the bridge and the mission deduplicate it. This covers the case where Squadron
accepts a start but the response is lost before the bridge records success.

Only one resume may be in flight for a blocker. If several human replies arrive close together, the
bridge records all of their IDs but starts one mission. Squadron reads the Jira discussion after
`last_processed_comment_id`, so it sees the answer as a whole instead of evaluating fragments in
parallel. When the mission finishes, the bridge starts another run only if newer, unprocessed human
comments remain and the blocker is still open.

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

1. Define a typed Devin output for `needs_human`.
2. Replace the free-form resume record with a versioned checkpoint schema.
3. Build blocker registration, the Jira receiver, delivery deduplication, and the durable outbox.
4. Make the three existing rate phases webhook-entry-capable and accept explicit entry stages.
5. Add the read-only Databricks MCP evidence path independently; it does not depend on the bridge.

Until a phase is migrated, its current blocking behavior remains authoritative. Do not run the old
label-triggered resumption and the bridge webhook for the same ticket, because both will believe
they own the next run.
