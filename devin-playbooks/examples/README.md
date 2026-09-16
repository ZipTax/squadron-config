# Read example Devin results

These are illustrative payloads for the schemas in `../schemas/`, not real session results.
DEMO tickets, procedure names, observations, tax values, and `example.invalid` links are
fictional. Do not use them as tax authority, runnable cases, or evidence of a deployment.

Each JSON file contains the result itself, without a `structured_output` wrapper. Optional
fields are included when they help explain the case. These are Devin results, not the
mission commander's synthesized output: similarly named fields can differ between the two.

## Investigation: proven mechanism or missing evidence

[Completed investigation](rate-investigation.completed.json): DEMO-100 reports duplicate
records after replaying one request. A local capture and code trace establish the mechanism,
so the result is `completed` and `DEFECT_PROVEN`. Production impact remains in `unknowns`;
that does not erase the local proof. `production_evidence: []` means no production observations
were collected, not that production contains no matching records.

[Investigation needing a person](rate-investigation.needs-human.json): the order identifier
and date are absent. The result is `needs_human` and `EVIDENCE_INCOMPLETE`, with no invented
mechanism. Its production record says `unavailable` and `ticket_gap_outcome: needs_human`
because a concrete request for the missing identifiers can settle the gap. This illustrates
why an evidence gap can still require a Jira question.

## Fix: proposal delivered or implementation blocked

[Completed fix](rate-fix.completed.json): the request lookup moves before the insert. The
result identifies the existing branch and changed files, without claiming test execution.

[Fix needing a person](rate-fix.needs-human.json): handling the same identifier with a
changed payload is undecided, so no implementation or PR exists. Empty artifact fields and
`change_type: none` describe that state without inventing a deliverable.

The current fix schema has no `target_authority` field. This example does not add one;
any mission requiring that value must collect it separately or extend the schema in a
coordinated change. Likewise, schema fields are not a guarantee that every playbook prose
request has a corresponding structured field.

## Ratevariant: coverage delivered or an input missing

[Completed cases](ratevariant-cases.completed.json): one replay case and one new-request
guardrail cover the same root. The report separates their classifications; the actual case
YAML still contains inputs only. Offline validation passed and cases were pushed, but no
run was requested. A report may repeat a root for different case classifications.

[Cases needing a person](ratevariant-cases.needs-human.json): the required payload attachment
is unreadable, so the result reports zero cases for that root and asks for a usable payload.
`offline_validation_passed: false` means validation has not passed; here it was not attempted
because no cases were authored. It does not imply that a loader test was run and failed.

## Bruno: justified omission or a required assertion missing

[Completed Bruno suite](bruno-regression.completed.json): fictional DEMO-200 establishes
an exemption and a taxable neighbor. Both API assertions have stated authority. Filing-code
attribution remains deliberately unwritten because the endpoint does not expose it; that
is a coverage decision, not a human blocker. The unchanged guardrail can already pass.

[Bruno needing a person](bruno-regression.needs-human.json): the exemption assertion exists
in a PR, but its required before-date boundary assertion lacks authority. The result retains
the partial PR and authored scenario, lists the unwritten scenario, and asks the exact question.
`needs_human` does not mean all prior work disappears.

## Support: configuration finding or rate handoff

[Support finding](txc-support.completed.json): a disabled connection explains the rejection.
No code PR exists, and the question is whether the connection should be enabled.

[Support rate handoff](txc-support.rate-handoff.json): the report concerns tax calculation,
so support stops without a fix PR and identifies the rate workflow as the destination.

The support schema has no `outcome` or `human_questions`; it uses `routed_to_rate_flow` and
`open_questions`. Its examples intentionally retain that contract rather than pretending
all five schemas are identical.
