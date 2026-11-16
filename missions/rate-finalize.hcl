mission "rate_finalize" {
  commander {
    model = models.anthropic.claude_opus_4_7

    compaction {
      token_limit    = 250000
      turn_retention = 3
    }

    tool_response {
      max_tokens = 32000
    }
  }

  # Finalization verifies WAI claims, records lessons, and keeps operator review open.
  # Enter from triage for an unverified WAI claim or supported-but-unimplementable defect,
  # or from rate_fix after Bruno completion or an audit no-op. Saved work can resume review.
  #   enter_finalize -> verify_wai | record_learnings | review_followup
  #   verify_wai -> rate_triage (refuted, at most one re-fire) | record_learnings (confirmed)
  #   record_learnings -> review_followup
  # Review directs existing Devin sessions within the task, rather than routing backward.
  # See docs/rate-ticket-orchestration.md for interactions across all rate missions.
  memories = [memories.rate_case_log, memories.rate_checkpoint]

  # Cross-mission routes select the entry and supply accepted context; rate_case also retains
  # that context for continuation and recovery.

  agents = [
    agents.session_scout,
    agents.taxcloud_legacy_sql_reviewer,
    agents.learnings_curator
  ]

  # ---------------------------------------------------------------------------
  # Inputs — the typed handoff from rate_triage or rate_fix. Task outputs do not
  # cross a mission boundary, so the close-out's material is declared here.
  # ---------------------------------------------------------------------------

  input "start_event_id" {
    type = "string"
    default = ""
    description = "Stable bridge start identity; empty for ordinary mission starts."
  }
  input "blocker_id" {
    type = "string"
    default = ""
  }
  input "blocker_generation" {
    type = "number"
    default = 0
  }
  input "issue" {
    type        = "string"
    description = "Ticket key for the rate fix (e.g. DEV-7282)."
  }

  input "repo_url" {
    type        = "string"
    description = "Repo the fix landed in (or would have)."
    default     = "https://github.com/FedTax/txc-sqlserver-database"
  }

  input "base_branch" {
    type        = "string"
    description = "Base branch a write-back PR targets. Blank lets Devin use the repo default."
    default     = ""
  }

  input "entry_stage" {
    type        = "string"
    description = "verify_wai | record_learnings | review_followup. verify_wai checks an unverified working-as-intended claim; record_learnings follows accepted work, including a confirmed WAI claim, unsupported remedy, or completed fix audit; review_followup resumes operator review after lessons."
  }

  input "close_reason" {
    type        = "string"
    description = "Why the case arrived here, in a phrase: 'fix audited SATISFACTORY and bruno regression authored', 'audit FIX_IS_NO_OP', 'proven but unsupported at available granularity', 'working as intended', or the stage a prior run blocked at. Context for asking the work sessions about their discoveries; no disposition by itself requires a learning writeback."
    default     = ""
  }

  input "verdict" {
    type        = "string"
    description = "The verdict this case ends on, in the vocabulary of whichever mission sent it: DEFECT_PROVEN, WORKING_AS_INTENDED (rate_triage), SATISFACTORY, FIX_IS_NO_OP (rate_fix's audit)."
    default     = ""
  }

  input "mechanism" {
    type        = "string"
    description = "What was wrong and where expected and actual parted ways. The mechanism class is what the case log is keyed on and what recurrence is judged against."
    default     = ""
  }

  input "disposition" {
    type        = "string"
    description = "The remediation disposition: data/configuration change | procedure/function change | both | unsupported at available granularity. The last one makes recording mandatory."
    default     = ""
  }

  input "limitation_class" {
    type        = "string"
    description = "On the unsupported disposition only: which limitations.md entry (a ticket carrying the new-rate-engine label) the proven mechanism matched, so this ticket is filed as an instance under it rather than as a new class. Blank otherwise."
    default     = ""
  }

  input "evidence" {
    type        = "string"
    description = "The evidence chain behind the verdict — each load-bearing claim with its basis and citation. What makes a recorded learning citable; an uncitable one is worse than none."
    default     = ""
  }

  input "production_evidence" {
    type        = "string"
    description = "Typed governed-production observations carried from investigation. Preserve these in a retained checkpoint so a later run does not reinterpret an unavailable or incomplete read as proof of absence."
    default     = "[]"
  }

  input "findings" {
    type        = "string"
    description = "Accepted per-issue investigation findings as JSON; recover from the recorded report on older resumptions."
    default     = ""
  }

  input "audit_findings" {
    type        = "string"
    description = "From rate_fix: the confirmed bugs, dead/shadowed branches, wrong-value diffs and path inconsistencies, each with the case result that demonstrated it. Blank when no A/B ran."
    default     = ""
  }

  input "open_questions" {
    type        = "string"
    description = "Outstanding questions and coverage limits from the upstream work. Finalization distinguishes a closure-blocking human question from a non-blocking follow-up or an intentionally unwritten scenario before deciding whether to retain a blocker."
    default     = ""
  }

  input "fix_pr_url" {
    type        = "string"
    description = "The fix PR, when one exists. Blank on a working-as-intended or unsupported close-out."
    default     = ""
  }

  input "bruno_pr_url" {
    type        = "string"
    description = "The txc-bruno regression PR, when one was authored. Blank otherwise."
    default     = ""
  }

  input "investigation_session_id" {
    type        = "string"
    description = "The session holding the investigation. verify_wai passes it back as wip_investigation_session_id if it re-fires; record_learnings requests any supported reusable findings. Blank when none survives."
    default     = ""
  }

  input "investigation_messageable" {
    type        = "bool"
    description = "Whether investigation_session_id can still be messaged. False means work from its report instead of sending to a dead id, per delegated_session."
    default     = false
  }

  input "fix_session_id" {
    type        = "string"
    description = "The session that owned the fix, for the learnings ask. Blank when no fix was written."
    default     = ""
  }

  input "cases_session_id" {
    type        = "string"
    description = "The case-authoring session, for the learnings ask. Blank when no cases were authored."
    default     = ""
  }

  input "bruno_session_id" {
    type        = "string"
    description = "The Bruno session, for the learnings ask. Blank when Bruno did not run."
    default     = ""
  }

  input "wai_refire_count" {
    type        = "number"
    description = "How many times this ticket has already been re-fired after a working-as-intended refute. verify_wai will not re-fire once this is >= 1: two rounds of disagreement is a human decision, and this counter is the only thing that ends the standoff."
    default     = 0
  }

  input "checkpoint" {
    type        = "string"
    description = "The validated rate_checkpoint/<TICKET>.yaml record. Blank when there was no checkpoint."
    default     = ""
  }

  # ---------------------------------------------------------------------------
  # Task — enter_finalize. The mission's only startable task: a cross-mission
  # route starts every dependency-free task, so the two terminals cannot both be
  # startable — one stage reads entry_stage and routes. It also establishes which
  # sessions are still reachable, which is exactly what record_learnings' ask and
  # verify_wai's re-fire both depend on. Read-only.
  # ---------------------------------------------------------------------------

  task "enter_finalize" {
    objective = <<-EOT
      # 1. Validate the start event

      Before routing or side effects, if start event "${inputs.start_event_id}" is nonempty,
      apply blocked_run with blocker "${inputs.blocker_id}" and generation
      ${inputs.blocker_generation}. Load the current checkpoint, reject stale or completed
      events, and durably claim this event before continuing interrupted work.
      If that check rejects the event, end this run without selecting a downstream route.

      # 2. Restore the case and Slack root

      Use `squadron-rates` as the initial channel when creating the root.

      Apply rate_case for ${inputs.issue}. Use case_slack with the recorded status for this handoff.
      Save accepted state before routing. Use legacy inputs only to recover missing fields.

      Choose the remaining close-out work for ${inputs.issue}, entering at ${inputs.entry_stage}
      using the saved close reason.

      # 3. Inspect the handoff

      Check the investigation, fix, cases, and Bruno owners recorded in lanes.
      Use delegated_session's discovery guidance if an id is missing for known work. An unavailable
      session still contributes its report; it cannot answer follow-up questions. Do not create
      or message sessions here.

      Read context.findings from the case.
      If they are missing, the selected work stage recovers the report through delegated_session.

      # 4. Select the entry

      Select the first applicable entry:
      - Unfinished review in the checkpoint: resume review_followup.
      - Unverified WAI claim: select verify_wai for an independent check.
      - Accepted work: select record_learnings.
      Save the selected entry and accepted state before routing.
    EOT
    agents = [agents.session_scout]

    output {
      field "entry_stage" {
        type        = "string"
        description = "verify_wai | record_learnings | review_followup - the next finalization stage."
        required    = true
      }
      field "reachable_sessions" {
        type        = "string"
        description = "Each session for this ticket — id, lane, state, and whether it can still be messaged. This is what the terminal stage's asks are addressed to."
        required    = true
      }
    }

    router {
      route {
        target    = tasks.review_followup
        condition = "entry_stage == review_followup - resume operator review using the saved feedback and current session results."
      }
      route {
        target    = tasks.verify_wai
        condition = "entry_stage == verify_wai — the investigation concluded the system is already correct and nobody has checked that independently yet."
      }
      route {
        target    = tasks.record_learnings
        condition = "entry_stage == record_learnings — the case is closed (fixed and audited, a no-op fix, a proven-but-unsupported mechanism, or a confirmed working-as-intended), so ask its work sessions whether they have worthwhile discoveries to preserve."
      }
    }
  }

  # ---------------------------------------------------------------------------
  # Task — verify_wai. Reached only when the investigation concluded working-as-intended.
  # No PR, nothing to A/B — skeptically re-examine the claim. On a refute, re-fire
  # the chain at rate_triage once (capped by wai_refire_count). Dynamic target
  # (no depends_on).
  # ---------------------------------------------------------------------------

  task "verify_wai" {
    objective = <<-EOT
      # 1. Restore the case and publish the stage status

      Apply rate_case for ${inputs.issue} at `verify_wai`.
      Use case_slack to publish root status ":mag: Verifying working-as-intended".

      Independently assess the working-as-intended conclusion for ${inputs.issue}.
      Repository: ${inputs.repo_url}; base branch: ${inputs.base_branch}.

      # 2. Delegate to Devin

      Create a fresh read-only Devin session through plugins.devin.code_develop
      on ${inputs.repo_url}, with `prompt_mode: "raw"`, title ${inputs.issue} — verify working-as-intended,
      and tags `["${inputs.issue}", "verify-wai"]`. Have Devin use the repository's investigate-tax-behavior
      skill to check the ticket's disputed value against data independently of the earlier reasoning.
      Use delegated_session for registration and follow-ups; record this owner in lanes.verification.

      Have the independent Devin session use the issue scopes in context.findings to
      re-derive the disputed behavior rather than treating prior conclusions as proof.

      # 3. Establish a supported verdict

      Collect evidence with check_session and apply evidence_gate.
      - Positive proof of correct behavior: accept WAI_CONFIRMED.
      - Positive evidence of a missed defect: accept WAI_REFUTED.
      - Missing support: ask the independent session to investigate and reassess in this task.
        If a human answer is needed, use blocked_run and rate_checkpoint; do not manufacture
        a verdict from an absent reproduction.

      # 4. Publish the finding and take its route

      Update the root Cause using case_slack, then follow the accepted verdict:
      - WAI_CONFIRMED: ask Devin to explain the finding on Jira using writing-ticket-updates.
        Route to record_learnings; no thread post is needed.
      - WAI_REFUTED: preserve the prior reasoning and evidenced rebuttal as a challenge,
        not a predetermined answer. Ask Devin to annotate the prior Jira comment as under
        investigation. If the stored wai_refire_count < 1, select the declared triage route.
        Otherwise use blocked_run and rate_checkpoint to ask for a decision with both
        positions and evidence; do not re-fire investigation.

      For WAI_REFUTED, post a concise correction with the Jira link and actual next action
      through case_slack. Example when routing to investigation: "Verification found that
      the state exemption incorrectly removes local tax. The case is returning to investigation.
      <jira-url|Findings>." When the refire cap applies, say a decision is needed instead.
    EOT
    agents = [agents.taxcloud_legacy_sql_reviewer]

    output {
      field "verdict" {
        type        = "string"
        description = "WAI_CONFIRMED | WAI_REFUTED"
        required    = true
      }
      field "refired" {
        type        = "boolean"
        description = "Whether this refuted the claim and re-fired the chain at rate_triage"
        required    = true
      }
      field "basis" {
        type        = "string"
        description = "The data basis for confirming or refuting, with the values that prove it"
        required    = true
      }
      field "final_summary" {
        type        = "string"
        description = "Summary in at most 150 words; ends with the ticket link for human review"
        required    = true
      }
    }

    router {
      route {
        target    = missions.rate_triage
        condition = <<-EOT
          verdict == WAI_REFUTED AND the pre-increment stored wai_refire_count < 1 - return
          to triage for an independent re-investigation. Set wai_challenge to the prior
          reasoning and cited rebuttal, preserving both positions rather than a predetermined
          answer. Increment wai_refire_count once and persist the challenge and accepted
          findings through rate_case. Supply the challenge and updated counter in triage's
          inputs. Map the investigation owner to wip_investigation_session_id if messageable,
          or stale_investigation_session_id otherwise; the challenged claim still requires
          an independent session rather than continuation of that owner's conclusion.
        EOT
      }
      # A repeated WAI refutation ends in the human-wait workflow described above.
      route {
        target    = tasks.record_learnings
        condition = "verdict == WAI_CONFIRMED — the ticket was a misunderstanding; a recurring misunderstanding is worth recording."
      }
    }

  }

  # ---------------------------------------------------------------------------
  # Task — record_learnings. Prepares accepted lessons before final operator review. Reached from enter_finalize
  # (rate_fix's completed lane or FIX_IS_NO_OP, rate_triage's unsupported
  # disposition) and from verify_wai's WAI_CONFIRMED. Most cases record nothing,
  # and that is a valid outcome.
  # ---------------------------------------------------------------------------

  task "record_learnings" {
    objective = <<-EOT
      # 1. Restore the case and publish the stage status

      Apply rate_case for ${inputs.issue} at `record_learnings`.
      Use case_slack to publish root status ":memo: Recording lessons".

      # 2. Collect and accept lesson proposals

      1. Read the verdict, close reason, diagnosis, per-issue findings, audit findings, and
         PRs from the case. Recover missing report context through delegated_session.
      2. Use enter_finalize's reachable_sessions and learnings_capture to ask each distinct
         work session for difficult-to-discover, reusable lessons. Check rate_case_log for
         duplicates and supporting cases when assessing its proposals.
      3. Resolve support gaps through learnings_capture. Accept only supported lessons;
         when none qualifies, skip writeback and proceed to step 4.

      # 3. Complete the accepted writeback

      1. Follow learnings_capture to reuse or create one writeback session for all accepted
         lessons across repositories. Use !rate-learning-writeback with title
         "${inputs.issue} — record learnings" and tags `["${inputs.issue}", "learnings"]`.
         Supply base branches keyed by repository URL:
         {"${inputs.repo_url}": "${inputs.base_branch}"} plus other destination repositories;
         missing or blank entries use the repository default branch.
      2. Record the owner in the learning-writeback lane so final review can direct later
         documentation corrections to the same session.
      3. Assess the returned diff through learnings_capture. Return deficiencies to that
         owner and reassess within this task until the writeback is settled or blocked.

      # 4. Complete the handoff or resolve a blocker

      Append one line to rate_case_log/cases.md using mission file tools, even if nothing qualified:
      <date> | ${inputs.issue} | <mechanism> | <verdict> | <writeback destination or none>
      Report unavailable storage rather than committing the log to a repository.

      If a failure prevents completion or a returned finding calls close-out into question,
      apply question_screen, then use builtins.human.ask when an operator decision is needed.
      Explain the failure, available evidence, and the decision needed to proceed. Follow
      blocked_run's operator-wait handling; do not turn learning-step failures into Jira questions
      or automatically restart investigation or audit. No qualifying lessons is a successful outcome.

      Add accepted lessons PRs as labeled links in the root using case_slack.

      Save the lessons outcome and all confirmed PRs through rate_checkpoint. When this
      work is settled, leave the case active and hand it to review_followup.
    EOT
    agents = [agents.learnings_curator]

    output {
      field "ready_for_review" {
        type        = "boolean"
        description = "True when lesson assessment/writeback is settled, including no qualifying lessons, and no unresolved dependency prevents review."
        required    = true
      }
      field "session_findings" {
        type        = "string"
        description = "Each distinct work session asked and its response reference, proposed lessons or explicit none, and any unavailable response. Attribute proposals recovered from recorded reports."
        required    = true
      }
      field "recorded" {
        type        = "boolean"
        description = "True only when the assessed rate-learning-writeback outcome is recorded and every returned documentation PR is verified."
        required    = true
      }
      field "learning" {
        type        = "string"
        description = "The accepted session-proposed rule with its supporting case, or why the returned proposals did not qualify. Do not infer a lesson to fill this field."
        required    = true
      }
      field "writeback_outcome" {
        type        = "string"
        description = "recorded | already_documented | blocked from the assessed rate-learning-writeback result, or not_requested when no proposal qualified. A blocked writeback is not a no-lessons result."
        required    = true
      }
      field "destination_pr_urls" {
        type        = "string"
        description = "All documentation PR URLs returned by the ticket's single writeback session, as a JSON array."
        required    = true
      }
      field "destination_pr_url" {
        type        = "string"
        description = "First documentation PR URL, retained for compatibility; use destination_pr_urls for the full set."
        required    = false
      }
      field "checkpoint" {
        type        = "string"
        description = "The retained case checkpoint and its active or closed state."
        required    = true
      }
    }
    router {
      route {
        target    = tasks.review_followup
        condition = "ready_for_review == true - keep the case active for operator feedback and merge checks."
      }
    }
  }

  task "review_followup" {
    objective = <<-EOT
      Keep ${inputs.issue} available for feedback until its PRs merge or the operator ends
      review. Perform the numbered steps below; all returns stay inside this task.
      Use rate_case for context, rate_checkpoint for progress, and case_slack for Slack updates.

      Delegate tool work to the task agent. Its human-ask, Slack, and Devin tools remain
      available even though they are absent from the commander's tool list. Skills guide
      that agent's tool use. Obtain its tool error or unavailable-tool details before
      concluding that a missing capability prevents continuation.

      # 1. Restore current work and check completion

      Collect current PR states, heads, and session results through delegated_session,
      including lessons PRs. On resume, reconcile the saved pending action before resending work.
      - At least one case PR exists and all case PRs are merged: go to step 6.
      - No PRs exist, and the case has an accepted disposition with no pending work: go to step 6.
      - Otherwise: continue to step 2. If any PR is closed without merging, include the
        disposition needed in that question.

      # 2. Ask for the next action and wait

      1. Save next entry rate_finalize/review_followup and set root status ":eyes: Awaiting review"
         through case_slack. Prepare the question before delegating the human ask:
         - Initial review: summarize readiness with labeled PR links, the accepted A/B outcome,
           Bruno's results before staging deployment, and material limits or open decisions.
           Ask "What should I review or change? Please follow up when the fix is deployed to
           staging. If applicable, provide any relevant deployment details so I can verify
           the fix. Let me know when the PRs are merged."
         - Follow-up: briefly address the last request and ask "What's next?" If staging
           deployment is still needed, ask the operator to confirm when it is done.
         Apply case_slack to the whole prompt, including additional_context.
      2. Offer "Re-audit", "Verify staging (deployment done)", "Merge check", and "End review",
         with free text for feedback. Delegate builtins.human.ask without timeout_seconds.
      3. Wait for the answer through the task agent. EVERY open iteration must reach this
         wait so the operator can direct the next correction or confirm staging deployment.
         Saving a continuation alone does not keep the mission running; keep the ask active
         instead of submitting interrupted and calling task_complete.
         If the wait is actually interrupted, retain active case state and this task as the
         next entry for resumption. On an answer, continue to step 3.

      # 3. Select the requested action

      Save the answer and select the applicable action:
      - Feedback, requested changes, or "Re-audit": go to step 4.
      - Confirmed staging deployment or "Verify staging (deployment done)": go to step 5.
      - Reported merges or "Merge check": return to step 1 to verify PR states and either
        close or identify remaining PRs in the next question.
      - "End review": go to step 6 and close by operator choice.
      - Missing information needed to act: return to step 2 with the specific question.
      If the answer requests multiple actions, perform corrections before verifying the
      corrected work. Request new staging confirmation when those corrections need deployment.

      # 4. Direct corrections and assess the revised work

      1. Collect affected session results and current PR heads, including changes requested
         directly from Devin. Ask for unrecorded feedback when needed to assess the work.
      2. Direct investigation, fix, case, Bruno, and lesson changes to their recorded owners
         through delegated_session, preserving each owner's file lane.
      3. Set root status ":microscope: Auditing" through case_slack and apply evidence_gate
         to the affected work:
         - Fix or A/B cases: use ab_audit and txc_rate_audit with fresh captures.
         - Bruno tests: have the owner assess automatic staging CI. Should-change tests fail
           before staging deployment and pass after it; guardrails normally pass in both states.
           Include any accepted pre-staging guardrail limitation in the checks still required.
         - Lessons: check the revised guidance against the accepted lesson and its evidence.
         Record assessed heads and evidence so an earlier pass cannot approve a later commit.
      4. If corrections are needed, use verdict_loop and repeat steps 4.2-4.3 while making
         progress. For an operator or product dependency, use blocked_run and retain this
         review task as the continuation.
      5. If the answer also requested staging verification and the confirmed deployment still
         covers the corrected fix, continue to step 5. Otherwise return to step 1.
         When failures are expected until staging deployment, the next step 2 question must
         hold the task open for deployment confirmation; "known to fail until deploy" is
         not completion. Only step 6 closes without that check.

      # 5. Verify the confirmed staging deployment

      1. Set root status ":test_tube: Verifying in staging" through case_slack. Send the existing
         Bruno session the current Bruno PR, saved baseline attempt link, and staging cutoff:
         the reported staging deployment time or the confirmation's receipt time.
         Manual staging deployment does not move the PR head, so ask the session to follow
         !bruno-regression's staging-verification steps: reuse a qualifying attempt or rerun
         all jobs of the latest pull_request API Tests run at that head. Require at most one
         new attempt and wait for an in-progress attempt; use neither workflow_dispatch nor
         a trigger commit so verification remains on the existing PR checks.
      2. Compare the returned result with the baseline from before staging deployment.
         Require both should-change tests and guardrails to pass. Investigate unchanged or
         new failures even if A/B was satisfactory: A/B assessed directional correctness
         and regressions; Bruno checks the behavior actually deployed to staging.
      3. Save the staging confirmation, both attempt-specific CI links, tested revisions,
         and assessed results. If the run cannot start or finish, retain verification as
         pending and use blocked_run for any required operator action.
      4. Select the continuation:
         - Corrections required: send discrepancies and CI evidence to the existing owners
           through step 4. If corrections need deployment, retain staging verification as
           pending for the next step 2 question; the earlier deployment lacks the fix.
         - Results accepted, or verification pending without a correction to make: return
           to step 1. A passing staging check returns to review while PRs remain open;
           it does not automatically merge or finish the work.

      # 6. Close the case

      Close only for step 1's completion criteria or the operator's explicit "End review".
      Retain remaining work or unperformed staging checks without claiming they passed.
      Merged PRs end this workflow; production checks require an explicit request.
      Set root status ":white_check_mark: Closed" through case_slack and complete the task.
    EOT
    agents = [agents.taxcloud_legacy_sql_reviewer]

    output {
      field "outcome" {
        type        = "string"
        description = "merged | closed_by_operator | no_prs | interrupted. interrupted is for an actual interrupted wait or an evidenced failure preventing continuation, not an unanswered active ask or the commander's lack of direct tool access; retain active case state and review_followup as the next entry."
        required    = true
      }
      field "summary" {
        type        = "string"
        description = "Accepted review outcome, assessed PR heads, evidence references, and any remaining work."
        required    = true
      }
    }
  }
}
