# Devin playbooks (mirror)

Every `code_develop` session this repo's missions start runs a Devin **playbook**, referenced by
its macro (`!rate_investigation`, `!rate-fix`, `!ratevariant-cases`, `!bruno-regression`). The
playbook is the session's standing procedure; the mission objective supplies only what that
particular run knows. So the two halves have to agree, and the playbooks live in Devin's UI where
nothing tells you when they drift.

This directory is a **mirror, not the source of truth.** The running text is whatever is in the
Devin UI; these files exist so a playbook change is reviewable as a diff next to the mission that
calls it, and so a later reader can see what the mission was written against. Change one, change
both — and if you find a mirror that disagrees with the UI, the UI won.

| File | Macro | Playbook id | Stage that runs it |
|---|---|---|---|
| `rate-investigation.md` | `!rate_investigation` | `playbook-d0e526165f3b4178856af2650da5464f` | `start_investigation`, `confirm_wai`, `continue_investigation`, `forward_investigation` |
| `rate-fix.md` | `!rate-fix` | *new — to be created* | `develop` |
| `ratevariant-cases.md` | `!ratevariant-cases` | `playbook-0db2e3c790dd493e83d6a747de250fd4` | `author_tests` |
| `bruno-regression.md` | `!bruno-regression` | `playbook-1c31b008e5f846d8a0987956e25af2b0` | `bruno_tests` |
| `txc-support.md` | `!txc-support` | `playbook-3ec650231e6b4764a4b2254960218566` | none — generic support, and it routes rate tickets *out* to this flow |

## What each playbook owns

These are the invariants the mission is written against. Breaking one is a design change, not an
edit: if a change here contradicts a row, change `missions/ratevariant.hcl` in the same PR and say
so in the description.

| Playbook | Owns | Must never |
|---|---|---|
| `!rate_investigation` | Proving cause from code and data; the ticket's product-level writeback | Branch, commit, open a PR, or edit a file — a diagnosis from a session that can also fix tends to stop at the first plausible cause |
| `!rate-fix` | `output/schema/**` and `scripts/**`; opening and labelling the fix PR | Re-derive the diagnosis, touch `tests/ratevariant-cases/**`, or interpret the A/B |
| `!ratevariant-cases` | `tests/ratevariant-cases/**`, and the fixture/eligibility discovery behind it | Grade the run it enables, or encode a rate/amount/expected outcome anywhere |
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
   needs the matching `output` field in `missions/ratevariant.hcl` and the matching entry in
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

`schemas/<macro>.json` holds each playbook's `structured_output_schema` — the contract the
mission's routers read. A router condition is a scalar test (`verdict == DEFECT_PROVEN`,
`evidence_complete == true`); with no schema attached, the commander is inferring those scalars
from prose in a transcript. Attaching the schema binds the session itself, not just the prompt.

Field names line up with the mission's task `output` blocks in `missions/ratevariant.hcl` —
`verdict`, `evidence_complete`, `working_as_intended`, `disposition`, `mechanism`, `affected_roots`,
`limitation_class`, `coverage_gaps`, and so on. When you rename or add one, change it in the
schema, in the mission's `output` block, and in the playbook prose that tells the session to return
it — all three, in the same commit.

One thing worth a 15-minute check before relying on this: whether a playbook-attached schema
populates `structured_output` for **plugin-created** sessions. If it doesn't, the fallback is a
required fenced-json final message using the same field names, and the schemas here become that
block's spec rather than a UI setting.

## When a run stops on a human

No stage waits for an answer. A session that needs something only a person has names it precisely
and returns; the mission records what is outstanding against the ticket
(`rate_open_items/<TICKET>.md`) and the run ends. The **next** `/ratevariant` fire on that ticket is
the resumption: `discover_sessions` reads that file and finds the ticket's sessions by tag, so live
sessions are continued in place rather than restarted. What makes this work is precision — "needs
confirmation" cannot be resumed; "need the June rate for Cook County and its published source" can.

Two halves, and both are required. The **ticket** is where the questions go — all of them, in one
comment, since nobody who can answer reads a session's structured output — and the blocking stage
labels it `ratevariant:awaiting-info`, which is the sentinel a Jira automation fires `/ratevariant`
on when a new comment lands. The **memory file** is for the next run, not the human. The entry
session removes the label before doing anything else, so an ordinary ticket discussion doesn't spawn
a mission per message, and it reads the comments since the last run to say which questions came back
usable — a general "yes that looks wrong" leaves the question open rather than licensing a guess.
