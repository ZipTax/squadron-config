# Stop and resume work that needs a person

## Your responsibility

End the run when progress needs a person's answer. Keep the question on Jira and the
continuation state in the checkpoint so the bridge can restart the recorded work without
repeating completed stages. These instructions assume the bridge delivery contract.

## Resume from the bridge

Read the checkpoint and supplied start event. Ignore an already processed event or a stale
blocker generation. For an accepted event, record its id and resume-in-flight state through
rate_checkpoint before side effects. A retry of interrupted work continues from that state;
an already completed event must not repeat its effects.

Remove the configured ready-for-Squadron label using a label remove operation. Keep
TaxRates:Needs-Info until the answer is accepted. Ordinary comments do not trigger a run;
adding the ready label asks the bridge to deliver another review attempt.

Ask an available Devin session with relevant context to read comments after
blocker.last_processed_comment_id and assess the outstanding questions. Accept the
supported assessment, advance the processed-comment marker, and either continue or refine
the question. Resolve the blocker through the bridge and remove the needs-information label
only when its dependency is settled. Preserve unrelated labels with add/remove operations.

## Prepare a human wait

When progress requires a human answer, including access to production evidence:

1. Establish the exact questions and context with Devin. Do not invent an answerer.
2. Use sme_writeback to have Devin post the question on Jira. Reuse the existing discussion
   for a refinement, and confirm the comment reference before treating posting as complete.
3. Save the blocker, questions, raising session when known, comment references, and the
   selected resume mission/stage through rate_checkpoint. Advance the blocker generation
   only for a materially changed question set, not for a new reply or delivery retry.
4. Register or revise that blocker through the bridge integration (`POST /blockers`) and confirm acceptance. Keep its stable
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
remains, explain the gap without manufacturing a question or claiming the behavior is correct.
