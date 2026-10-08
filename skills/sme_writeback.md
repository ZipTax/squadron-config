# Coordinate a ticket update

## Your responsibility

Decide whether readers need a new finding or an answer is needed to continue. A completed
task alone does not require a ticket update. Keep the question relevant to the
reported issue, and preserve the strength of the supporting evidence.

## Work with Devin

Apply `question_screen` before supplying questions for a ticket update. Reuse Devin's
assessment only after the freshness check required by `question_screen`. Before posting,
have Devin check for changes since that assessment and revise or omit questions they settle. If nothing remains to ask or
explain, do not request another comment.

Supply established facts with their evidence basis, each unanswered question, and the scope
of the decision. Ask Devin to use the repository's `writing-ticket-updates` skill as it drafts.
Do not supply a comment body or ask for verbatim publication; the repository skill owns the
wording, and a ready-made body bypasses it. Use delegated_session for the tool interaction.

An access blocker can be raised on the ticket. Have Devin name the needed table or kind of
data, relevant identifiers or period, and why access or supplied data would settle the issue.
There is no assumed separate access-request channel. Keep secrets, raw queries, and lengthy
tool diagnostics in the Devin report.

## Assess the proposed question or finding

- Ask only what remains unanswered. A tax SME's stated ruling counts without requiring
  them to retrieve a statute or bulletin; cite the ruling already present.
- Apply `blocked_run` before publishing a question. Unresolved effective-date choices go
  through Squadron's `builtins.human.ask`, not Devin's Jira comments.
- Remove requests to reconfirm settled facts, perform an available lookup, or approve an
  implementation defect. A missed checkout/import/filing path within the agreed scope needs
  correction, while contradictory scope evidence needs analysis before the remedy changes.
- Do not propose or ask about correcting recorded transactions or filing data. Historical
  data correction is outside the rate fix, so its omission is not an unresolved decision.
- Include the effective period and broader treatment scope when they change the decision.
- Keep implementation choices, speculative scope expansion, and unrelated new-engine behavior
  out of the question. If evidence shows the disputed result came from the new engine,
  report that finding without starting a new investigation of that engine.
- A supported finding can be stated plainly; an inference remains a theory. An A/B pass
  does not authorize a tax treatment, and a proposed change is not yet deployed or resolved.

## Finish or pause

Have Devin post the update and confirm its comment reference. If it revises a prior
conclusion, ask Devin to annotate that earlier comment so readers see the changed status.
For a blocking Jira evidence request, use blocked_run to confirm the comment, save state,
and register the bridge wait. Missing production evidence may need a real ticket question. Ask for the data, access, or
decision that would settle it. If the evidence gap ends the work with no actionable request,
have Devin post a finding explaining what remains unproven and why work stopped, and confirm
the comment reference. Do not invent an answerer or present the missing evidence as proof
of correct behavior.
