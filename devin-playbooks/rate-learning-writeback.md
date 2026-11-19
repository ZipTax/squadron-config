# Select and record useful rate-workflow lessons

Own the ticket's learning writeback across the supplied repositories. The handoff contains
work-session responses, source references, destination
repositories, base branches, and this ticket's documentation PRs. These are candidates and
evidence, not accepted wording or a quota. Do not reopen the fix to manufacture lessons.

## Check usefulness, evidence, and destination

Think as the next maintainer, who has a different ticket and none of this session's context:
what decision or action would this instruction improve, under what conditions, and what mistake
would it prevent? Keep a proposal only when the supplied evidence supports that answer and
existing guidance does not already provide it. Reject routine observations, incident recaps,
and unresolved defects presented as expected behavior. Explain exclusions briefly in `reason`.

Read repository instructions, cited evidence, and related guidance. Select and combine overlapping
proposals by the future action they support, not by ticket or source-session headings. If existing
guidance covers all useful proposals, return `already_documented`. If none is worth preserving,
return `not_worth_recording` without a PR. Missing evidence that prevents assessment is `blocked`,
not proof that no lesson exists. Do not choose unresolved implementation values or run a fresh
investigation.

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

Amend the closest existing instruction. Add a new section, file, or case-law entry only after
thoroughly searching related skills and references with multiple related terms, synonyms, and
affected objects—not just the ticket number or proposed heading. Read the nearest matches.
If guidance partly covers the lesson, amend it; if it fully covers it, add nothing. A new section
requires explaining in `reason` the terms searched, closest guidance found, and why none can
carry the amendment. No search, no new section.

Lead with what a future session should do, when, and why. Keep only details needed to make that
decision; link the evidence instead of retelling it. A clearer ticket narrative is not a lesson.
The brief's technical detail is evidence to verify, not wording to retain: carry a detail into
guidance only when the reader needs it to act.

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

### Worked edit: preserve the action, remove the incident

Original, verbatim from [SQL #388 before review](https://github.com/FedTax/txc-sqlserver-database/blob/5dc64ec93571196a4d26da2d9c5971d4eb93c80f/.claude/skills/ratevariant-case-data/SKILL.md):

> - **An origin override also changes the ZIP+4 as a destination.** A live TX ZIP+4 override
>   is read by remote-seller destination lookups as well as origin lookups. When it and the ZIP5
>   row have the same total but different local jurisdictions, cart and import cases can match
>   while the Reports ETL attributes the tax to another jurisdiction. Include a Reports ETL
>   remote-seller case that captures jurisdiction codes, and describe matching cart and import
>   cases as masked. For DEV-10657, the 78665-5697 override kept the remote-seller total at 8.25%
>   but moved its 2% from Round Rock (`63500`) to ESD 9 (`5246692`)
>   ([PR #387 results](https://github.com/FedTax/txc-sqlserver-database/pull/387#issuecomment-6958889326)).

**Why it is bad:** the address, rates, and district IDs retell the incident without changing
what to test. “Describe matching cases as masked” also overstates the limitation: they can
verify unchanged totals, just not jurisdiction attribution.

**Edit:**

> **Test origin and destination uses of an override.** A TX ZIP+4 override used for origin
> sourcing can also affect remote-seller destination lookups. Test both uses. When totals match
> but jurisdictions differ, include a Reports ETL case capturing jurisdiction codes; matching
> cart/import totals alone do not verify attribution
> ([evidence](https://github.com/FedTax/txc-sqlserver-database/pull/387#issuecomment-6958889326)).

**Why it is better:** it names the action, its scope, and the limit of the evidence. The link
retains the supporting case without copying it. This belongs beside existing override coverage
instructions, not in another ticket-named section. Search “override,” “destination,” “equal
totals,” and “jurisdiction attribution” before choosing that location; merge into an existing
bullet if it already covers both uses.

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
all proposals have been assessed, useful amendments are pushed, and exclusions are explained. Return
`blocked` if the assignment cannot be completed, with the failed step and what is needed.
Use the attached schema and return without waiting for a person.
