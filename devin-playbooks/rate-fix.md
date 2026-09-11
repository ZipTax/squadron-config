# Implement the proven rate fix

Implement the supplied diagnosis in `FedTax/txc-sqlserver-database`. The caller supplies the
ticket, mechanism, disposition, evidence, base branch, and any existing fix PR. The separate
investigation owns diagnosis, and the cases session owns test artifacts, so implementation
must neither expand the remedy nor manufacture its own proof.

## Procedure and lane

Read repository instructions and step 1 of `ratevariant-testing/references/process.md`.
That procedure owns schema copies, migration ownership, and the `ratevariant` opt-in label.
Use `tax-rule-change` for data/migration conventions and the SQL/query skills for read-only
verification. Apply only the implementation portion of those skills: their broader testing
or rollout guidance does not authorize this lane to author cases, run A/B, or deploy.
Register with `registering-on-the-ticket` under `rate-fix`.

Own `output/schema/**` schema objects and `scripts/**` migrations. The cases lane owns
`tests/ratevariant-cases/**`; Bruno owns its separate repository. Report out-of-lane
requests. If a required skill is unavailable or conflicts with this boundary, identify the
conflict before affected work rather than guessing a procedure.

1. Confirm the supplied mechanism against the code. Report a contradiction in
   `diagnosis_contradicted` and stop changing code rather than inventing a different fix.
2. Implement the briefed scope, including both data and code when disposition is `both`.
   An unsupported general remedy is not an implementation task unless the caller has
   explicitly scoped a feasible partial fix.
3. Open the fix PR on the requested base and confirm the `ratevariant` label is present.
   Preserve production verification questions in its review/testing context because a
   snapshot-proven mechanism does not establish today's production rows.
4. Return the attached schema's PR identifiers, branch, label status, summary,
   contradictions, and `target_authority`. A state publication or a tax SME's ruling is
   authority; an unverified ticket expectation is only a proposed target. Missing authority
   may travel to audit and does not itself prevent producing a reviewable proposal.

## Continue or adopt existing work

On adoption, check out the existing PR branch, inspect the diff against the diagnosis, and
report ownership and discrepancies. Do not rewrite, revert, or open another PR. On a later
correction, change only the evidenced finding and push to that same branch without force.
Report migration changes so Squadron can ask the cases owner to update the alteration.
Read the current PR description before editing it and preserve other authors' content.
Session registration belongs on the ticket; do not add process history to the PR body.

Stop after pushing. Do not grade A/B results, run staging-mutating harness commands, or add
`ratevariant:run` on your own initiative. An explicit request to apply the run label is
mechanical delegation, not permission to judge the fix.

Return `outcome: needs_human` and exact question-and-context pairs in `human_questions`
only if implementation cannot safely finish without a person's answer. Otherwise return
`completed` with an empty list and preserve non-blocking questions in the report. Do not
wait. Post a Jira comment only when requested, using `writing-ticket-updates`; Squadron
owns workflow labels, checkpointing, and the next stage.
