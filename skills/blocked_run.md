# Resolve a human dependency

Apply `question_screen` first. Use `rate_case` to save the question, context, and next
entry in `human_wait`, then `case_slack` to show Blocked on question.

## Operator choice

1. Call `builtins.human.ask` with the ticket, decision, evidence checked, and supported
   options. This covers mechanical choices, access coordination, and unresolved date choices.
2. Pass the answer to the owning Devin session. Save its source and assess the returned
   result before restoring the active Slack status. A scheduling choice is not tax authority.
3. On timeout, cancellation, or `[no human available]`, retain pending state and report
   the operator dependency. The next operator-started run resumes the recorded stage and
   mission thread; create a Jira question only when a separate product dependency warrants it.

## Product question or inconsistency

1. Use `sme_writeback` to have Devin post the product question on Jira. Send facts and the
   unresolved decision; Devin owns the wording. Confirm the comment reference.
2. Save that reference in `human_wait` with `channel: jira`. Use `human.ask` to ask
   “Have answers been provided on <Jira comment link>?” with the remaining question's
   context. The Slack gateway posts it in the case thread while the root remains blocked.
3. When the operator says answers are ready, have a context-owning Devin session read the
   current ticket and assess each answer. Save accepted answers and sources. If a gap
   remains, refine the existing Jira discussion and ask about the remaining dependency.
4. If the ask ends without usable answers, save a bridge blocker and register it through
   `bridge`, then end. Keep the root blocked. Register only after the live ask ends, so
   the bridge and an active ask do not compete to resume the case.

The bridge blocker stores its stable ID, generation, questions, raising session when
known, comment references, and next mission/stage. Increment generation for a new wait;
retry an uncertain registration with the same generation. Preserve partial state and
retry only the incomplete operation so a lost response does not duplicate the question.

## Resume through the bridge

1. Match the incoming blocker ID and generation to the checkpoint before side effects.
   Stale or completed events end without routing. Reconcile interrupted `resume_in_flight`
   work; a live owner keeps the event. Record acceptance before continuing.
2. Remove the configured ready label with a label-remove operation to preserve other labels.
3. Have Devin assess comments after `last_processed_comment_id`, using `question_screen`
   for current evidence. Advance the marker and resolve the registered blocker through
   `bridge` when its dependency is settled. Confirm acceptance before proceeding.
4. If the answer remains insufficient, resolve the consumed bridge generation before
   opening a new live ask; a later fallback registers a new generation. Keep the Slack root
   blocked until a supported answer permits work.

## Evidence gaps without an actionable question

Record `insufficient_production_evidence` when production supports no conclusion. If no
useful request remains and work ends, have Devin explain the gap on Jira through
`sme_writeback`, confirm the comment, and post the stopping reason in Slack. Preserve
uncertainty and the saved continuation state.
