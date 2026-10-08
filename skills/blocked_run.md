# Stop and resume work that needs a person

## Your responsibility

Screen a proposed question before interrupting a person, then choose the channel that
owns the decision. Squadron's native ask-human tool handles operator decisions. Jira and
the bridge handle ticket evidence requests that must survive an ended run.

## Check the question before choosing a channel

Apply `question_screen` before arranging a human wait. A `needs_human` result alone does
not prove that evidence was exhausted or that the remaining decision blocks progress.

## Ask the operator for a decision

Use `builtins.human.ask` for an unresolved effective-date choice or other operator decision.
First distinguish a date established by the ticket or applicable authority from a date
that requires a choice; ask only for the latter. Include the ticket, the decision's effect,
the evidence checked, and supported options. Do not delegate this question to Devin for
Jira publication or register a duplicate Jira bridge wait.

Pass the answer to the owning session and preserve its source in that session's report
so later stages do not ask again. An operator's scheduling choice does not establish tax
law. If the tool times out, is cancelled, or returns `[no human available]`, keep the
choice unresolved and report the blocked operator decision; do not invent an answer or
silently move it to Jira. Preserve the session and next entry through `rate_checkpoint`
without claiming a registered Jira blocker.

## Resume from the bridge

Load the bridge skill for the configured ready label. Match the supplied blocker ID and
generation against the current checkpoint before side effects. A mismatch or a completed
event ends this run without routing. An accepted event still marked resume_in_flight is
interrupted work: reconcile its recorded progress rather than discarding it or repeating
finished operations. Record a new event ID and resume_in_flight state through rate_checkpoint
before continuing. A live owner of the same event must not run concurrently; leave it in charge.
The bridge must reconcile run status before starting recovery.

Remove the configured ready label using a label remove operation. Ordinary comments do not trigger a run;
adding the ready label asks the bridge to dispatch the active waiting generation once.

Ask an available Devin session with relevant context to read comments after
blocker.last_processed_comment_id and assess the outstanding questions. Accept the
supported assessment, advance the processed-comment marker, and either continue or refine
the question. Resolve the blocker using the bridge skill only when its dependency is settled.
Preserve unrelated labels with add/remove operations.

## Prepare a Jira evidence wait

After screening, when progress requires evidence or access from ticket participants:

1. Establish the exact questions and context with Devin. Do not invent an answerer.
2. Use sme_writeback to have Devin post the question on Jira. Reuse the existing discussion
   for a refinement, and confirm the comment reference before treating posting as complete.
3. Save the blocker, questions, raising session when known, comment references, and the
   selected resume mission/stage through rate_checkpoint. Advance the blocker generation
   for every new human wait, even if the question is unchanged. A retry of the same
   registration preserves its generation.
4. Register or revise that blocker using the bridge skill and confirm acceptance. Keep its stable
   id and generation so retries update the same blocker instead of creating another.
5. Remove any stale ready label, persist the current state, and end.

The confirmed Jira comment tells the person what to answer; bridge registration tells the
next delivery where to resume. If posting, registration, or a label change is uncertain,
retain partial state and retry that operation without duplicating the question. Do not
report a successfully registered wait until registration is confirmed.

## Distinguish an evidence gap from its next action

Insufficient production evidence may have a concrete Jira question: request data, access,
or the decision needed to proceed. Use the human-wait workflow when that answer is required.
Record insufficient_production_evidence when no supported production conclusion is possible;
that finding does not itself prohibit a useful ticket question. If no actionable request
remains and work ends, use sme_writeback to have Devin explain the gap and stopping reason
on the ticket, then confirm the comment reference. Do not manufacture a question or claim
the behavior is correct.
