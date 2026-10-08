# Decide whether a question needs a person

A question interrupts work and can reopen a decision already made. Ask only when the
answer changes necessary work and cannot be established from available evidence.

## Check the evidence before asking

Use `delegated_session` to ask Devin whether each proposed question is answered by the
full ticket, including its description, latest comments, and attachment contents. Before
reusing an assessment or escalating its questions, have Devin check the current ticket
against the version assessed: description edits, newer or edited comments, and added,
replaced, or updated attachments. Reuse prior findings only for unchanged sources; have
Devin read changed material and reassess which questions remain unanswered. If it cannot
establish whether an attachment changed, have it retrieve the current contents rather
than assume the earlier assessment still applies. Require source references, when the
freshness check was made, and the remaining gap, not a bare assurance that the ticket
was checked.

Attachment retrieval requires token-authenticated Jira API access that the Jira MCP read
tool does not provide. Keep that work in Devin's session rather than duplicating ticket
and attachment review here. An unread attachment is an access or evidence gap, not proof
that the ticket lacks an answer.

Have Devin also identify any relevant code, available data, or published authority that
can settle the question. A missing report field does not establish a human dependency.
Request the missing research before escalating, and use an answer already found instead
of asking a person to confirm it.

For each proposed question, establish:

- The in-scope decision that changes with the answer.
- The sources checked, what they establish, and the precise unresolved point.
- Why further available research cannot settle that point.

An SME's stated ruling settles the treatment without requiring the person to retrieve
its supporting publication. Contradictory evidence still needs analysis; identifying a
real conflict is different from asking someone to repeat an answer.

## Exclude questions that cannot advance the work

Resolve routine engineering choices using the requirements and repository conventions.
An implementation defect within the agreed scope needs correction, not permission to
leave it unfixed. Evidence that changes the scope requires analysis before the remedy
expands. Do not manufacture a decision about out-of-scope work; historical transaction
and filing corrections are outside a rate fix.

Non-blocking uncertainty may remain in a report without becoming a request for action.
An established effective date is a finding. A genuinely unresolved choice of effective
date is a human decision, but it must pass the same evidence check.

## State the remaining dependency

Give the exact question, the decision it affects, the evidence already checked, and why
that evidence cannot answer it. Distinguish an operational choice from a request for
missing facts or access so the question can reach the appropriate channel. Screening a
question does not authorize publishing it or make it a blocker; identify whether useful
work can continue without the answer.
