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

Review the two commits separately: the first mirrors the four playbooks **as they exist today,
unedited**, so the second is a clean diff of what is actually being proposed.

| File | Macro | Playbook id | Stage that runs it |
|---|---|---|---|
| `rate-investigation.md` | `!rate_investigation` | `playbook-d0e526165f3b4178856af2650da5464f` | `start_investigation`, `confirm_wai`, `continue_investigation` |
| `rate-fix.md` | `!rate-fix` | *new — to be created* | `develop` |
| `ratevariant-cases.md` | `!ratevariant-cases` | `playbook-0db2e3c790dd493e83d6a747de250fd4` | `author_tests` |
| `bruno-regression.md` | `!bruno-regression` | `playbook-1c31b008e5f846d8a0987956e25af2b0` | `bruno_tests` |
| `txc-support.md` | `!txc-support` | `playbook-3ec650231e6b4764a4b2254960218566` | none — generic support, and it routes rate tickets *out* to this flow |

## What each proposed change is for

- **`rate-investigation.md`** — a delegated mode. The playbook was written for a human in the
  chat, so today it can block on a question no one will answer, and it emits its own verdict
  vocabulary rather than the one the mission's routers read. The new section maps the two, forbids
  a terminal verdict on inferred evidence, states the three entry modes (fresh, gap-closing, WAI
  challenge) and keeps the session read-only.
- **`rate-fix.md`** — new, and the reason `!txc-support` can go back to being generic. It
  implements a diagnosis it is handed and refuses to derive one, stays out of
  `tests/ratevariant-cases/**`, and never fires the A/B. It also covers adoption: taking ownership
  of a fix PR whose session is gone, so the audit stage has somewhere to send a correction.
- **`ratevariant-cases.md`** — stops at authoring. Today it says "push and run", which makes the
  session that chose the fixtures the one grading them; the run and its interpretation move to the
  audit stage. Also points at the repo skills instead of restating merchant eligibility and field
  traps, and drops the reference to the deleted `.claude/commands/ratevariant-cases.md`.
- **`bruno-regression.md`** — authority instead of "the ticket wins". Every asserted figure traces
  to the ticket's stated correct value or to state-published material, named per scenario; a
  scenario with no authority is reported unwritten rather than asserted approximately. Never from
  current staging output or the A/B's variant arm — that is the thing under test.
- **`txc-support.md`** — a routing gate. Wrong rates, reporting/filing figures, TIC behavior,
  imported-order rates and the rate/exemption data behind them stop at diagnosis here and hand off
  to this flow, because their fixes need an evidence-gated cause and A/B coverage that one
  diagnose-and-fix session cannot produce. The API/app, account, configuration and
  explain-the-behavior work stays.

## Structured output

`schemas/<macro>.json` holds each playbook's proposed `structured_output_schema` — the contract the
mission's routers read. This is the highest-leverage part and needs no plugin work: a router
condition is a scalar test (`verdict == DEFECT_PROVEN`, `evidence_complete == true`), and with no
schema attached the commander is inferring those scalars from prose in a transcript. Attaching the
schema binds the session itself, not just the prompt.

Field names line up with the mission's task `output` blocks in `missions/ratevariant.hcl` —
`verdict`, `evidence_complete`, `working_as_intended`, `disposition`, `affected_roots`,
`coverage_gaps`, and so on. When you change one side, change the other, or the route silently reads
a field nobody sets.

One thing worth a 15-minute check before relying on this: whether a playbook-attached schema
populates `structured_output` for **plugin-created** sessions. If it doesn't, the fallback is a
required fenced-json final message using the same field names, and the schemas here become that
block's spec rather than a UI setting.
