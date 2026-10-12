# Record an accepted rate-workflow lesson

Turn the supplied lesson into a focused documentation PR. The brief supplies the ticket,
originating session and evidence, intended future use, destination repository and guidance
files, base branch, and any existing documentation PR. Use that evidence; do not invent a
lesson or reopen the underlying fix to produce one.

## Check the evidence and destination

Read repository instructions, the cited evidence, and relevant existing guidance. Confirm
that the finding is supported and adds useful guidance. If it is already documented, return
`already_documented` with the location instead of creating another entry. If support is
missing or contradictory, return `blocked` with the precise gap; do not choose configuration
values, run a new investigation, or turn an unresolved hypothesis into a rule.

Use the supplied destination when it fits the lesson:

| Lesson | Appropriate guidance |
| --- | --- |
| Repository procedure, query trap, or configuration constraint | Relevant maintained repository skill or reference |
| Workflow boundary, evidence gate, or routing behavior | Corresponding workflow skill |
| Proven rate-audit precedent | SQL repository's `ratevariant-audit/references/case-law.md` |
| Proven limitation with an established new-rate-engine deferral | SQL repository's `ratevariant-audit/references/limitations.md` |

If the destination does not fit, report the mismatch rather than expanding the assignment.
A ticket's disposition alone does not justify an entry or establish an engine deferral.

## Write for the next maintainer

Read a relevant existing entry for style. The DEV-10223 entry in the SQL repository's
`ratevariant-audit/references/case-law.md`, revised in
[PR #288, commit 2c571e6](https://github.com/FedTax/txc-sqlserver-database/commit/2c571e6f1f06539a817f5c3081f4585256ad3249),
illustrates the intended clarity; use its approach, not its tax facts or a fixed template.

- Lead with the reusable finding or action. Explain why it matters and what decision it changes.
- Retain the conditions, period, and case facts needed to understand the evidence. Introduce
  participants before comparing values, and link the supporting ticket, PR, or commit rather
  than reproducing row IDs, endpoint syntax, or session history without a practical reason.
- Preserve uncertainty and unmet requirements. Omitting a test whose expected value lacks
  authority leaves a coverage gap; documenting that omission does not satisfy the requirement.
- Use short, connected paragraphs for distinct findings. Avoid repeating the lesson as an
  introduction, incident narrative, and closing rules list.

Prefer a focused amendment to maintained guidance. Do not create a ticket-specific fix
narrative or commit release status, deployment instructions, run logs, or coordination state.

## Deliver the documentation change

Change only the selected guidance files. Do not edit SQL, migrations, fixtures, tests, or
ticket registration. Those changes can invalidate the evidence supporting the lesson.
Do not post Jira comments, change ticket fields, deploy, or merge.

For new work, branch from the supplied base and open a separate documentation PR. When an
existing documentation PR is supplied, continue its branch without force-pushing or creating
a duplicate. Read its current description and preserve other authors' content when updating it.
Keep implementation PRs as evidence references, not writeback destinations.

Review the diff: a maintainer unfamiliar with the case must be able to explain the finding,
its consequence, applicable conditions, and what remains unproven. Run applicable documentation
checks. Return `recorded` only after the scoped change is pushed to a reviewable PR. Return
`blocked` if the assignment cannot be completed, with the failed step and what is needed.
Use the attached schema and return without waiting for a person.
