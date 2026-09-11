# Work through Devin

## Your responsibility

Delegate the assigned work, preserve session ownership, and assess the returned evidence.
Send Devin the relevant context; it does not automatically see your mission objective,
other agents' conversations, or the task output schema. Distinguish what Devin reported
from what you have independently established.

## Choose the appropriate interaction

Use the tool and companion skill appropriate to the assignment:

| Assignment | Tool | Skill |
| --- | --- | --- |
| Development or a new playbook-driven task | `plugins.devin.code_develop` | `devin_code` |
| QA | `plugins.devin.code_qa` | `devin_qa` |
| PR review | `plugins.devin.code_review` | `devin_review` |
| Review cleanup | Follow `devin_pr_cleanup` | `devin_pr_cleanup` |
| Follow-up to an existing session | `plugins.devin.send_message` | This skill |
| Collect or confirm a result | `plugins.devin.check_session` | This skill |

Honor the task's choice of review method and session independence. A tool that creates a
session is not a substitute for sending a follow-up to an existing owner.

For a playbook-driven `code_develop` call, supply `repo_url` and put the literal macro in
`task` alongside the assignment, for example:

```text
Use playbook !rate-fix for DEV-1234. Implement the supplied mechanism on the existing PR
branch. [Case evidence and relevant constraints follow.]
```

The macro is a Devin playbook reference, not a tool you invoke locally. Use
`prompt_mode: "raw"` when the default development workflow would conflict with the
assignment; `devin_code` explains that wrapper. Do not assume other tools have that option.

Name repository skills relevant to the work. Devin indexes skills across connected repos
before cloning, and a cloned repo can override indexed skills with its branch's version.
Cloning solely to make a skill available is not required. See
[Devin skills](https://docs.devin.ai/product-guides/skills).

For published prose, provide facts and purpose rather than a drafted body. Use
`sme_writeback` for ticket updates and `session_lane` for shared PR edits.

## Find and continue existing work

Use the recorded owner or explicit override first. Otherwise inspect the ticket's session
index, with tagged session search as a fallback. A refused read is not an empty history.
Use `check_session` to confirm actual work, artifact ownership, and resumability; status
or a recent timestamp alone does not establish that a session can continue.

Among unassigned candidates, prefer a messageable session with relevant completed work;
otherwise retain the best supported report. Attribute disagreements rather than combining
conflicting conclusions. A session that only posted a comment is not the owner of the
investigation or implementation it described.

Capture session ids as soon as returned. For ticket work, ask Devin to register using
`registering-on-the-ticket` under the assigned tag. A comment-only session uses `writeback`,
so discovery does not mistake it for a work owner. Follow the skill's registration procedure
rather than copying its field-editing mechanics into your message.

Continue with `send_message` and collect the result with `check_session`. When an owner
cannot be messaged, retain its report with attribution and choose an explicit replacement
or ask another available session a bounded question, within the mission's constraints.
Do not silently replace file ownership or claim the inherited evidence was rechecked.

## Assess results and follow up

An empty tool message or uncertain send is not proof that the work failed. Check the
session before retrying, creating a replacement, or asking it to repeat a side effect.
Apply `evidence_gate`; a plausible summary cannot substitute for missing support.

A correction request supplies the finding, its supporting evidence, and the location or
artifact to change. Include only the relevant lane boundary and existing branch. A question
request supplies the unknown and context, leaving Devin to investigate rather than dictating
a query or a conclusion.

Finish when the reported work meets the assignment, or identify the specific remaining
dependency. Use `blocked_run` when a human answer is needed instead of keeping the call open.
