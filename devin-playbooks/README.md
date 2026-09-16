# Devin playbooks (mirror)

Every `code_develop` session this repo's missions start runs a Devin **playbook**, referenced by
its macro (`!rate_investigation`, `!rate-fix`, `!ratevariant-cases`, `!bruno-regression`). The
playbook is the session's standing procedure; the mission objective supplies only what that
particular run knows. So the two halves have to agree, and the playbooks live in Devin's UI where
nothing tells you when they drift. The running UI text has not been verified against this revision. Apply each changed mirror
and its matching schema together before deploying dependent mission changes.

This directory is a **mirror, not the source of truth.** The running text is whatever is in the
Devin UI; these files exist so a playbook change is reviewable as a diff next to the mission that
calls it, and so a later reader can see what the mission was written against. Change one, change
both — and a disagreement means deployment drift to reconcile, not permission to silently adopt the UI text as the intended design.

| File | Macro | Playbook id | Mission / stage that runs it |
|---|---|---|---|
| `rate-investigation.md` | `!rate_investigation` | `playbook-d0e526165f3b4178856af2650da5464f` | `rate_triage`: `start_investigation`, `confirm_wai`, `continue_investigation`, `forward_investigation` |
| `rate-fix.md` | `!rate-fix` | `playbook-5683e1f25ceb400bb864eefc88d718b1` | `rate_fix`: `develop` |
| `ratevariant-cases.md` | `!ratevariant-cases` | `playbook-0db2e3c790dd493e83d6a747de250fd4` | `rate_fix`: `author_tests` |
| `bruno-regression.md` | `!bruno-regression` | `playbook-1c31b008e5f846d8a0987956e25af2b0` | `rate_fix`: `bruno_tests` |
| `txc-support.md` | `!txc-support` | `playbook-3ec650231e6b4764a4b2254960218566` | none — generic support, and it routes rate tickets *out* to this flow |

## What each playbook owns

These are the invariants the mission is written against. Breaking one is a design change, not an
edit: if a change here contradicts a row, change the mission file that owns that stage (`missions/rate-triage.hcl`, `missions/rate-fix.hcl`, `missions/rate-finalize.hcl`) in the same PR and say
so in the description.

| Playbook | Owns | Must never |
|---|---|---|
| `!rate_investigation` | Proving cause from code and data; the ticket's product-level writeback | Branch, commit, open a PR, or edit a file — a diagnosis from a session that can also fix tends to stop at the first plausible cause |
| `!rate-fix` | `output/schema/**` and `scripts/**`; opening and labelling the fix PR | Re-derive the diagnosis, touch `tests/ratevariant-cases/**`, or interpret the A/B |
| `!ratevariant-cases` | `tests/ratevariant-cases/**`, and the fixture/eligibility discovery behind it | Grade the run it enables, or encode expected outputs in case YAML or metadata |
| `!bruno-regression` | V3 API regression scenarios for the settled behavior | Assert a figure with no authority behind it, or derive one from the system under test |
| `!txc-support` | Generic support: API/app, account, configuration, explaining behavior | Fix anything that changes how tax is calculated — those route into the flow above |

Two splits look redundant and are not. Investigation is separate from the fix because evidence and
implementation fail differently. Cases are separate from the fix because finding an eligible
merchant/transaction/date is a large discovery job with no bearing on the diff, and carrying both
in one session degrades both.

## Changing a playbook

1. **Edit the mirror here first**, in a PR, so the change is reviewable next to the mission that
   depends on it. State which mission stage reads the changed text.
2. **Check the other side.** A playbook change that adds, renames, or re-scopes a returned value
   needs the matching `output` field in the mission file that owns that stage (`missions/rate-triage.hcl`, `missions/rate-fix.hcl`, `missions/rate-finalize.hcl`) and the matching entry in
   `schemas/`. Grep the field name across all three before pushing; a router that reads a field
   nobody sets fails silently, which is the worst failure mode this config has.
3. **Run `squadron verify`** if you touched the mission or a schema field name.
4. **Apply it in the Devin UI** — same text, same macro — and note in the PR that you did. Nothing
   automated syncs this, and an unapplied mirror is a lie a future reader will act on.
5. **Say what evidence prompted the change.** A rule with no case behind it gets deleted by the
   next person who finds it inconvenient; a rule that cites the ticket it came from survives.

### If you are a Devin session writing a learning back here

Only workflow rules belong in this repo. A repo trap (a schema quirk, a query gotcha, a path
convention) belongs in `txc-sqlserver-database/.claude/skills/**`, and a proven rate precedent
belongs in that repo's `ratevariant-audit` references — not here, and not in both. The test is who
needs it: the *session doing the work* (repo skill) or *whoever orchestrates the stages*
(this repo).

Then keep it small: amend an existing paragraph rather than adding a section, and add the one case
that demonstrates the rule. These files are read in full by every session that runs the playbook,
so length is a real cost — a playbook that grew a section per incident stops being followed.

## Structured output

Start with the [worked result examples](examples/README.md) for every attached schema,
including partial work and human blockers.

`schemas/<macro>.json` holds each playbook's `structured_output_schema` — the contract for
Devin's lane report. Squadron's commander assesses that report and submits the mission task's
own output. Route conditions such as `verdict == DEFECT_PROVEN` are instructions for the
commander's choice, not executable comparisons. The runtime validates the chosen target;
it does not establish the truth of the underlying verdict. See
[Squadron routing](https://docs.squadron.sh/missions/routing).

The task's output schema already tells its commander which fields to submit, so the objective
does not need a second field list. Keep the work and acceptance criteria in the objective or
skills, and the field meaning and source in the output description. See the
[mission authoring guidance](../docs/rate-ticket-orchestration.md#what-belongs-in-a-task-objective-versus-its-output).

Field names line up with the mission's task `output` blocks in the mission file that owns that stage (`missions/rate-triage.hcl`, `missions/rate-fix.hcl`, `missions/rate-finalize.hcl`) —
`verdict`, `evidence_complete`, `working_as_intended`, `disposition`, `mechanism`, `affected_roots`,
`limitation_class`, `outcome`, `human_questions`, `production_evidence`, `coverage_gaps`, and so on.
When you rename or add one, change it in the
schema, in the mission's `output` block, and in the playbook prose that tells the session to return
it — all three, in the same commit.

The production-evidence fields in `rate_investigation.json` intentionally duplicate
`docs/schemas/production-evidence.schema.json`. A Devin playbook attachment must be self-contained;
it cannot rely on this repository being available to resolve an external `$ref`. Keep the property
names, required fields, and enum values identical. The checkpoint schema can reference the canonical
file because both checkpoint schemas are read together from this repository.

One thing worth a 15-minute check before relying on this: whether a playbook-attached schema
populates `structured_output` for **plugin-created** sessions. If it doesn't, the fallback is a
required fenced-json final message using the same field names, and the schemas here become that
block's spec rather than a UI setting.

## Who handles a human wait

Devin returns a typed result and exact questions without waiting. Squadron uses
[blocked_run](../skills/blocked_run.md) and [rate_checkpoint](../skills/rate_checkpoint.md)
to choose a context-owning question author, confirm the Jira comment, save the next entry,
and end the mission. On resumption, the selected session interprets the new answer and
Squadron decides the route. Playbooks must not tell Devin to load those Squadron-only skills.
The [orchestration plan](../docs/rate-ticket-orchestration.md) defines the bridge delivery contract assumed by the blocking instructions;
editing a playbook does not deploy the bridge or wire its tools and event inputs.

## How to avoid a second procedure

A playbook is a lane adapter, not a standalone engineering manual. Keep repository mechanics
in the owning repository skill and keep returned fields in the attached schema. A mission
supplies the ticket, artifacts, established evidence, and the remaining task. It should not
repeat the playbook or prescribe a calculation, fixture, or ticket paragraph.

Repository instructions govern mechanics within the delegated lane. They do not implicitly
expand the lane into implementation, deployment, or live test execution. Explicitly name any
scoped adaptation in the playbook; an unanticipated conflict or missing skill must be reported
before the affected work. Do not add a blanket “playbook wins” rule that hides future drift.

These mirrors repeat short lane/return/registration rules because each is pasted independently
into Devin. They do not depend on this README being available in a Devin checkout. A shared
playbook include would only reduce runtime duplication if the publishing mechanism actually
expanded it; no such mechanism is configured here.

## Upstream follow-ups before rollout

The coordinated SQL repository change adds `author-tax-migration`, permits combined data/code
remedies and optional production observations, separates harness retrieval from audit acceptance,
and allows actionable production-evidence requests on Jira. Merge [SQL PR #240](https://github.com/FedTax/txc-sqlserver-database/pull/240) before
publishing these mirrors so Devin can resolve `author-tax-migration` in its checkout.

The Bruno playbook retains its authoring procedure until a dedicated repository skill exists;
extracting it is not a rollout requirement. Databricks integration is a separate follow-up.

Review a change by checking lane paths, authority sources, allowed side effects, human-wait
behavior, and schema fields against the named upstream skills. Preserve the separate WAI check
and the existing route contracts unless intentionally changing them. Existing sessions stay on the previous process unless explicitly adopted.
