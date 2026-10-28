# Record accepted rate-workflow lessons

Own the ticket's learning writeback across all supplied repositories in this session. The brief
supplies accepted findings, originating sessions and evidence, intended future uses, destination
repositories, base branches keyed by repository, and existing documentation PRs. Do not invent
lessons or reopen the underlying fix to produce them.

## Check the evidence and destination

Read repository instructions, the cited evidence, and relevant existing guidance. Confirm
that the finding is supported and adds useful guidance. If it is already documented, return
`already_documented` with the location instead of creating another entry. If support is
missing or contradictory, return `blocked` with the precise gap; do not choose configuration
values, run a new investigation, or turn an unresolved hypothesis into a rule.

Select the relevant maintained guidance in the supplied repositories using these rules:

| Lesson | Appropriate guidance |
| --- | --- |
| Repository procedure, query trap, or configuration constraint | Relevant maintained repository skill or reference |
| Workflow boundary, evidence gate, or routing behavior | Corresponding workflow skill |
| Proven rate-audit precedent | SQL repository's `ratevariant-audit/references/case-law.md` |
| Proven limitation with an established new-rate-engine deferral | SQL repository's `ratevariant-audit/references/limitations.md` |

If a lesson belongs outside the supplied repositories, report the mismatch rather than expanding the assignment.
A ticket's disposition alone does not justify an entry or establish an engine deferral.

## Write for the next maintainer

Read a relevant existing entry for style. The DEV-10223 entry in the SQL repository's
`ratevariant-audit/references/case-law.md`, revised in
[PR #288, commit 2c571e6](https://github.com/FedTax/txc-sqlserver-database/commit/2c571e6f1f06539a817f5c3081f4585256ad3249),
illustrates the intended clarity; use its approach, not its tax facts or a fixed template.

- Verify the brief's claims, counts, and remedies before adopting its wording. Report where
  the evidence does not support the brief.
- Lead with behavior after the fix or a repeatable remedy and its prerequisites. State the scope
  as broadly as the evidence supports, and no broader. Describe behavior and consequences;
  include implementation details when needed to understand or verify them. Check against the final implementation; keep history
  only when it explains the rule.
  Correct related obsolete guidance within scope instead of leaving contradictory instructions.
- For example, write “TX remote sellers use ZIP5 unless a live override covers the ZIP, ZIP+4,
  state, and date,” not “ZIP+4 overrides are ignored and need a code change” after that defect is fixed
  ([SQL PR #304](https://github.com/FedTax/txc-sqlserver-database/pull/304)).
- Retain the conditions, period, and case facts needed to understand the evidence. Introduce
  participants before comparing values, and link the supporting ticket, PR, or commit rather
  than reproducing row IDs, endpoint syntax, timings, run IDs, snapshot-specific permissions,
  or session history without a practical reason.
- Preserve uncertainty and unmet requirements. Omitting a test whose expected value lacks
  authority leaves a coverage gap; documenting that omission does not satisfy the requirement.
  Distinguish observed results from inference. Do not make a successful one-off method mandatory.
- Use short, connected paragraphs for distinct findings. Avoid repeating the lesson as an
  introduction, incident narrative, and closing rules list. Keep mechanics in one canonical
  reference and point other guidance at it.

Prefer a focused amendment to maintained guidance. Do not create a ticket-specific fix
narrative or commit release status, deployment instructions, run logs, or coordination state.

## Deliver the documentation change

Change only the selected guidance files. Do not edit SQL, migrations, fixtures, tests, or
ticket registration. Those changes can invalidate the evidence supporting the lesson.
Do not post Jira comments, change ticket fields, deploy, or merge.

Keep related lessons together in one documentation PR per repository, managed by this session.
For new work, branch from that repository’s supplied base, or its default branch when none is
supplied. When a documentation PR already exists for a repository, continue its branch without
force-pushing or creating a duplicate; if several are supplied for one repository, continue the
oldest open one and report the others. Read the PR's current description and preserve other
authors' content when updating it.
Keep implementation PRs as evidence references, not writeback destinations.

Review each diff using the SQL repository's `review-learning-pr` checklist, reading it from that
repository when it is not checked out: a maintainer unfamiliar with the case must be able to
explain the finding, its consequence, applicable conditions, and what remains unproven. Run applicable documentation
checks. Return every documentation PR URL in `destination_pr_urls`. Return `recorded` only when
all accepted lessons are recorded or already documented and all changes are pushed. Return
`blocked` if the assignment cannot be completed, with the failed step and what is needed.
Use the attached schema and return without waiting for a person.
