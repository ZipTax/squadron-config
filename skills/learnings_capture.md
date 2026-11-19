# Capture reusable learning

## Collect proposals from the work sessions

Ask each distinct Devin session that did the work whether it discovered anything worth
preserving for the next maintainer. Request a concise proposal: what to do differently,
when, why, and a supporting evidence reference. “Nothing worth recording” is a complete answer.
Keep the request read-only; use `delegated_session` to follow up and collect responses.

Do not suggest a lesson for the session to endorse or infer one from a PR diff, audit findings,
or ticket outcome. If a session is unavailable, retain only lessons it explicitly proposed in
its recorded report, with attribution. Distinguish an unavailable response from explicit “none.”
If no source proposes a candidate, report that result without starting a writeback.

## Hand proposals to one writeback owner

Use one Devin writeback session for the ticket across repositories. Follow `delegated_session`
to recover or reuse the owner recorded in the checkpoint's `learning-writeback` lane. When
starting one, use `devin_code` with the task-supplied playbook and `prompt_mode: "raw"`;
record its ID in that lane.

Supply:

- Source responses unchanged, or accessible references to their full text, with attribution
  and supporting evidence.
- Destination repositories and base branches keyed by repository.
- This ticket's existing documentation PRs.

Leave usefulness, deduplication, evidence checks, and editing to the writeback playbook.
Do not compose an intermediate “accepted lessons” brief or prescribe entries and destinations.

## Review the amendments

Read the returned diffs as guidance for a maintainer unfamiliar with the ticket. Each amendment
must improve a future action or decision, preserve necessary conditions, and be supported by
evidence. A shorter account of the ticket is not enough.

Check the reported outcome:

- `recorded`: verify the PRs and their actual amendments.
- `already_documented`: verify the cited guidance covers the proposals.
- `not_worth_recording`: accept a supported explanation that no proposal adds useful guidance.
- `blocked`: identify the failed step and what is needed; do not treat failure as no lessons.

Return specific deficiencies to the same owner. Require an amendment to existing guidance
unless its search establishes that no suitable home exists. Request omitted detail only when
its absence makes the instruction wrong or unusable; do not restore code traces, run history,
or broader scope merely because they appeared in a source response. Do not reopen implementation,
acceptance testing, or investigation to manufacture a lesson.

## Report the result

Report the sources asked, response references, explicit “none” or unavailable responses,
and the writeback outcome with any documentation PRs. No worthwhile lesson is a successful outcome.
