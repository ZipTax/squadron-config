# Devin playbooks (mirror)

Every `code_develop` session this repo's missions start runs a Devin **playbook**, referenced by
its macro (`!rate_investigation`, `!rate-fix`, `!ratevariant-cases`, `!bruno-regression`). The
playbook is the session's standing procedure; the mission objective only supplies what that
particular run knows. So the two halves have to agree, and the playbooks live in Devin's UI where
nothing shows you when they drift.

This directory is a **mirror, not the source of truth.** The running text is whatever is in the
Devin UI; these files exist so a change to a playbook is reviewable as a diff next to the mission
that calls it, and so a later reader can see what the mission was written against. When you change
one, change both — and if you find a mirror that disagrees with the UI, the UI won.

| File | Macro | Playbook id | Stage that runs it |
|---|---|---|---|
| `rate-investigation.md` | `!rate_investigation` | `playbook-d0e526165f3b4178856af2650da5464f` | `start_investigation`, `confirm_wai`, `continue_investigation` |
| `rate-fix.md` | `!rate-fix` | *(to be created)* | `develop` |
| `ratevariant-cases.md` | `!ratevariant-cases` | `playbook-0db2e3c790dd493e83d6a747de250fd4` | `author_tests` |
| `bruno-regression.md` | `!bruno-regression` | `playbook-1c31b008e5f846d8a0987956e25af2b0` | `bruno_tests` |
| `txc-support.md` | `!txc-support` | `playbook-3ec650231e6b4764a4b2254960218566` | none — general support work, and it routes rate tickets *out* to this flow |

Each file's `structured_output_schema` — the contract the mission's routers read — is in
`schemas/<macro>.json` beside it. A stage routes on scalar fields, so a playbook that emits prose
instead leaves the commander guessing from a transcript.
