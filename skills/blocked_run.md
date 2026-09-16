# Stop and resume work that needs a person

## Your responsibility

End the run when progress needs a person's answer. Keep the question on Jira and the
continuation state in the checkpoint so the bridge can restart the recorded work without
repeating completed stages. These instructions assume the bridge delivery contract.

## Resume from the bridge

Load the bridge skill for the configured ready label. Match the supplied blocker ID and
generation against the current checkpoint before side effects. A mismatch or a completed
event ends this run without routing. An accepted event still marked resume_in_flight is
interrupted work: reconcile its recorded progress rather than discarding it or repeating
finished operations. Record a new event ID and resume_in_flight state through rate_checkpoint
before continuing. A live owner of the same event must not run concurrently; leave it in charge.
The bridge must reconcile run status before starting recovery.

Remove the configured ready-for-Squadron label using a label remove operation. Keep
TaxRates:Needs-Info until the answer is accepted. Ordinary comments do not trigger a run;
adding the ready label asks the bridge to dispatch the active waiting generation once.

Ask an available Devin session with relevant context to read comments after
blocker.last_processed_comment_id and assess the outstanding questions. Accept the
supported assessment, advance the processed-comment marker, and either continue or refine
the question. Resolve the blocker using the bridge skill and remove the needs-information label
only when its dependency is settled. Preserve unrelated labels with add/remove operations.

## Prepare a human wait

When progress requires a human answer, including access to production evidence:

1. Establish the exact questions and context with Devin. Do not invent an answerer.
2. Use sme_writeback to have Devin post the question on Jira. Reuse the existing discussion
   for a refinement, and confirm the comment reference before treating posting as complete.
3. Save the blocker, questions, raising session when known, comment references, and the
   selected resume mission/stage through rate_checkpoint. Advance the blocker generation
   for every new human wait, even if the question is unchanged. A retry of the same
   registration preserves its generation.
4. Register or revise that blocker using the bridge skill and confirm acceptance. Keep its stable
   id and generation so retries update the same blocker instead of creating another.
5. Add TaxRates:Needs-Info, remove any stale ready label, persist the current state, and end.

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
