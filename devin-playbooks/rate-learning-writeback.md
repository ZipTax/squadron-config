# Record accepted rate-workflow lessons

Own the ticket's learning writeback across all supplied repositories in this session. The brief
supplies accepted findings, originating sessions and evidence, intended future uses, destination
repositories, base branches keyed by repository, and this ticket's existing documentation PRs.
Do not invent lessons or reopen the underlying fix to produce them.

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
| Case or alteration authoring step | SQL repository's `ratevariant-case-data` or `ratevariant-testing` skill |
| Reusable coordination or evidence acceptance procedure | Corresponding Squadron skill |
| Task-specific work, acceptance criteria, or routing decision | Owning mission task objective or route |
| Reusable rate-audit precedent not already covered by maintained guidance | SQL repository's `ratevariant-audit/references/case-law.md` |
| Proven limitation with an established new-rate-engine deferral | SQL repository's `ratevariant-audit/references/limitations.md` |

If a lesson belongs outside the supplied repositories, report the mismatch rather than expanding the assignment.
A ticket's disposition alone does not justify an entry or establish an engine deferral.

Evaluate a destination, format, or wording suggested by the brief against these rules, and
report material departures in `reason`.

Find the durable part before writing: state in a sentence or two what a future session should do
differently. Keep historical details only when they explain a reusable check, remedy, or
constraint. What remains is often narrower than the brief.

## Write for the next maintainer

Amend the closest existing instruction. Lead with what a future session should do, when, and
why. Keep only details needed to make that decision; link the evidence instead of retelling it.
A clearer account of the ticket is not a useful writeback by itself.

- Check behavior after the fix, or a repeatable remedy and its prerequisites. Correct obsolete
  guidance directly; do not append an exception while leaving the contradictory rule intact.
- Separate observed results from guarantees. A snapshot, failed credential, denied query, or
  successful workaround does not establish a permanent restriction or mandatory procedure.
- Preserve what the evidence does not prove. Matching A/B totals do not verify attribution or
  an absolute rate; an omitted test is still a coverage gap. Do not turn an unobservable result
  into “never test this” or an unresolved defect into expected behavior.
- Keep one canonical instruction. If it already covers the action, return `already_documented`;
  another ticket example does not require another case-law entry. Add mechanics only where they
  affect use of that instruction. Leave run counts, snapshot inventories, and open work in the PR.

These examples illustrate edits, not a required template:

| Bad | Better |
| --- | --- |
| “Two runs matched; the third exposed the filing difference.” | “When totals match but jurisdictions differ, capture Reports jurisdiction codes; matching totals alone do not verify attribution.” |
| “Merchant 20 returned zero in three states. Skip those tests.” | “Verify the control for the address, date and merchant. Resolve an unexpected zero or use a verified alternative before deriving assertions from it.” |
| “We added the missing TIC to the cart list; mirror it in ETL.” | “Check each path's list semantics before editing: one list may grant an exemption while another excludes it.” |

Use the smallest amendment that carries the lesson, usually a sentence or short paragraph.
Do not repeat it as an introduction, incident narrative, and closing checklist. Keep qualifications
beside their claims. Do not commit release status, deployment instructions, or coordination state.

## Deliver the documentation change

Change only the selected guidance files. Do not edit SQL, migrations, fixtures, tests, or
ticket registration. Those changes can invalidate the evidence supporting the lesson.
Do not post Jira comments, change ticket fields, deploy, or merge.

Keep related lessons together in one documentation PR per repository, managed by this session.
For new work, branch from that repository’s supplied base, or its default branch when none is
supplied. Consider only documentation PRs for the current ticket; never add lessons to another
ticket's PR. When this ticket already has a documentation PR in a repository, continue its branch
without force-pushing or creating a duplicate; if it has several there, continue the oldest open
one and report the others. Read the PR's current description and preserve other
authors' content when updating it.
Keep implementation PRs as evidence references, not writeback destinations.
Never put a GitHub closing keyword (close, closes, closed, fix, fixes, fixed, resolve, resolves,
resolved), with or without a colon, directly before a PR or issue reference in a PR title,
description, or commit message; merging the PR closes the referenced item. Write `Related: #359`.

Review each diff using the SQL repository's `review-learning-pr` checklist, reading it from that
repository when it is not checked out: a maintainer unfamiliar with the case must be able to
explain the finding, its consequence, applicable conditions, and what remains unproven. Run applicable documentation
checks. Return every documentation PR URL in `destination_pr_urls`. Return `recorded` only when
all accepted lessons are recorded or already documented and all changes are pushed. Return
`blocked` if the assignment cannot be completed, with the failed step and what is needed.
Use the attached schema and return without waiting for a person.
