## Overview

Orchestrate an evidence-only investigation of a TaxCloud rate, exemption, TIC,
jurisdiction, nexus, or transaction question. Preserve the user's exact desired outcome,
run the investigation/query skills in order, obtain missing current data without guessing,
and produce separate engineering and support-facing deliverables.

This playbook coordinates the work; reusable investigation mechanics belong in:

1. `investigate-tax-behavior`
2. `write-taxcloud-sql-query`
3. `query-staging-snapshot`

Do not implement a change unless the user separately asks for one. When a fix is warranted,
`!rate-fix` implements it in a separate session, from your result — so the result has to stand on
its own without you in the room to explain it.

Before reaching for an unfamiliar mechanism, read the known limits and the proven precedents:
`.claude/skills/ratevariant-audit/references/limitations.md` and `references/case-law.md` in
`txc-sqlserver-database`. Each limitations entry is a *mechanism class* the legacy model cannot
express, with tickets listed as instances of it — so a match is a hypothesis to prove from this
ticket's data, never a shortcut past cause analysis, and the ticket in front of you may share a
symptom with an entry while having an ordinary, fixable cause.

## What's Needed From User

- The exact question or decision, including expected versus actual behavior.
- The expected rate/component breakdown, its source, and the actual observed result.
- Full source context: Jira description/comments, linked HelpScout conversation, and every
  attachment. Attachments define the reported cases that must remain in scope; only
  state-published material establishes rate authority.
- Known identifiers: merchant or URL ID, transaction/order ID, certificate ID, state,
  address/ZIP, product/TIC, and transaction period/date.
- Whether mixed-product transactions or different execution surfaces are possible.
- Whether dated snapshot evidence is sufficient; current configuration requires current
  production evidence.
- Intended deliverable: engineering verdict, customer-service response, Jira update, or a
  combination.

Start with available evidence while requesting non-blocking context. Stop when a missing
identifier is required to distinguish the reported subject from a broader population.

## Procedure

1. **Load the complete source context.**
   - Read the full Jira description and comments.
   - Read the linked HelpScout conversation when present.
   - Download and inspect every relevant attachment.
   - Preserve every explicitly reported state, transaction, product, rate component, and
     expected behavior; do not select a convenient subset or guess the "real issue."
   - Treat a ticket-provided rate as the investigation target, not authoritative evidence.

2. **Classify the request.**
   - Continue for current-behavior, rate-production, rate-discrepancy, and support
     questions.
   - Continue when a ticket asks for a fix but the cause and viable remediation are not
     proven.
   - Invoke `tax-rule-change` only after the discrepancy and disposition are known and the
     user asks to implement the validated change.
   - Record whether the issue concerns cart, imported orders, Reports/ETL, filing, or
     multiple surfaces.

3. **Invoke `investigate-tax-behavior`.**
   - Pass the original request, attachment cases, expected versus actual behavior, known
     identifiers, environment/date requirements, and final question unchanged.
   - Require its selected proof outcomes, complete path trace, jurisdiction-component
     equation and first divergence when applicable, invalidation-gate result, matched
     verdict, and remediation disposition when requested.

4. **Invoke the SQL skills for each database proof.**
   - Invoke `write-taxcloud-sql-query` before composing or delivering SQL.
   - Invoke `query-staging-snapshot` only after the query is schema-verified, indexed,
     bounded, read-only, and scoped to an explicit dated `PROBE_DB`.
   - If decisive current rows may postdate the snapshot, ask for the narrowest safe
     production query/result; do not substitute another merchant, product, certificate,
     or period.

5. **Prepare separate deliverables.**
   - Engineering artifact: retain the frozen question, evidence outcomes, cited code,
     exact query evidence, component equation/first divergence, limitations, verdict, and
     disposition.
   - Support/Jira response: state why the observed result differs and whether the expected
     result requires a data/configuration change, procedure/function change, or is
     unsupported at the available granularity—without SQL, schema paths, query output, or
     process narration.
   - Keep possible implementations or workarounds after and separate from the current
     behavior verdict.

6. **Validate against the source request.**
   - Re-read the original request and attachments.
   - Confirm every explicit case is answered or labeled blocked.
   - Confirm no qualifier, execution path, tax component, product scope, or period was
     dropped.
   - Confirm the actual rate is reconciled and the first divergence or exact missing
     expected detail is named.
   - Confirm every material statement is a code fact, dated snapshot fact, current
     production fact, ticket expectation, state-published authority, inference, or unknown.
   - Reject any workaround whose blast radius exceeds the requested outcome.

## Delegated (orchestrated) mode

When an orchestrator invokes you rather than a human — the squadron `ratevariant_ab` mission does
— these overrides apply, and nothing else changes:

- **Never block.** There is no interactive user, so a question you would have asked goes in
  `blocking_question` and you proceed on what the evidence supports. A question that genuinely
  cannot be answered without a human makes the verdict `EVIDENCE_INCOMPLETE`, which the
  orchestrator escalates — it is a result, not a stall.
- **Read-only, whatever the session prompt says.** No branch, no commit, no PR, no file edits.
  A fix session implements from your report; if you implement here, the mission has a diff nobody
  briefed and no A/B coverage for it.
- **Emit the routing verdict as well as your own.** Keep the question-matched verdict as your
  finding and map it:

  | Question-matched verdict | Routing verdict |
  |---|---|
  | `Not supported`, `Discrepancy explained`, `Explained` (behavior is wrong) | `DEFECT_PROVEN` |
  | `Supported`, `No discrepancy reproduced`, `Explained` (behavior is correct as designed) | `WORKING_AS_INTENDED` |
  | any `Unknown from available evidence`, `Partially explained` | `EVIDENCE_INCOMPLETE` |

  Label every load-bearing claim `measured`, `traced`, `inferred`, or `hedge`. `DEFECT_PROVEN` and
  `WORKING_AS_INTENDED` both require the divergence to be measured or traced and the disposition
  known; an inferred chain, however plausible, is `EVIDENCE_INCOMPLETE` with `unknowns` naming the
  exact artifact that would close each gap. Do not upgrade a verdict because a stage downstream is
  waiting on it.
- **Three entry modes, told to you by the caller.** A fresh investigation is the usual one. A
  *gap-closing* follow-up gives you a prior report and the specific missing evidence: close that
  gap, and revise the verdict only if the new evidence moves it. A *WAI challenge* gives you a
  prior `WORKING_AS_INTENDED` conclusion plus the rebuttal and evidence against it — investigate
  the question fresh, from the code and data, and neither defer to the prior conclusion nor
  assume the challenge is right; you exist because two readings disagree.
- **One product-level ticket comment, if the caller asks for it.** You hold the Jira
  credentials, so the writeback is yours. A couple of sentences in product language for a
  merchant-facing reader, opening with the automated-review attribution line, plus the PR link
  when one exists and the one thing a human must confirm. No SQL, schema paths, query output,
  checklists, or process narration; engineering detail lives in your structured output and on the
  PR. The caller states how strongly the evidence reads and you write at that strength — a traced,
  evidence-complete finding may read as a finding, an inferred one still reads as a theory. When
  the gap is something the SMEs hold, ask for the specific artifacts by name (the transaction
  ids, the expected rate and its published authority, the period), not for generic confirmation.

## Specifications

### Required deliverables

- A question-matched verdict:
  - behavior: `Supported`, `Not supported`, or `Unknown from available evidence`;
  - production: `Explained`, `Partially explained`, or
    `Unknown from available evidence`;
  - discrepancy: `Discrepancy explained`, `No discrepancy reproduced`, or
    `Unknown from available evidence`.
- The shortest evidence chain sufficient to support that verdict.
- For a discrepancy, the actual component equation and first divergence—or the exact
  missing expected detail needed to locate it.
- When remediation is requested, a disposition: `data/configuration change`,
  `procedure/function change`, `both`, or `unsupported at available granularity`. `both` is common
  and is not a hedge — rate rows that are wrong *and* applied wrongly need the migration and the
  proc change, and naming one ships half a fix.
- On `unsupported at available granularity`: which limitations.md mechanism class the proven
  mechanism instances, and whether a narrower partial fix is **feasible and accurate** — accurate
  meaning correct for every address it would cover, not merely for the one in the ticket. A ZIP+4
  override for a California address can be both while leaving the district-boundary class
  unsolved, which is worth filing separately and never worth presenting as closing the class.
- Exact limitations, including snapshot date and missing current-production evidence.
- A support-facing response when requested.
- No implementation, PR, data update, Jira comment, or production action unless the user
  explicitly requests it.

### Success criteria

- All attachment cases and original qualifiers remain in scope.
- Capability, activation/configuration, and observed behavior are separate.
- The actual rate is reconciled from jurisdiction components and transformations.
- Cart, Reports/import, and filing paths are distinguished where applicable.
- Product/TIC, line/transaction, jurisdiction-component, merchant/certificate, and period
  scope are proven when relevant.
- Snapshot evidence is labeled with the dated database.
- Unknowns remain unknown rather than becoming guesses.

### Forbidden actions

- Never silently reframe, broaden, narrow, or subset the reported issue.
- Never infer current production absence from a stale snapshot.
- Never equate a generic calculation branch with wired support.
- Never treat current engine output as proof that the ticket expectation is wrong.
- Never label a non-state source as authoritative for a rate or tax treatment.
- Never treat a total rate as an explanation without component provenance.
- Never recommend configuration or data changes without blast-radius proof.
- Never mutate staging or production during the investigation.
