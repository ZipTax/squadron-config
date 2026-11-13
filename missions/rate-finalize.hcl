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
      1. Validate the start event.
      2. Restore the case and Slack root.
      3. Inspect the handoff.
      4. Select the entry.

      # 1. Validate the start event

      Before routing or side effects, if start event "${inputs.start_event_id}" is nonempty,
      apply blocked_run with blocker "${inputs.blocker_id}" and generation
      ${inputs.blocker_generation}. Load the current checkpoint, reject stale or completed
      events, and durably claim this event before continuing interrupted work.
      If that check rejects the event, end this run without selecting a downstream route.

      # 2. Restore the case and Slack root

      Use `squadron-rates` as the initial channel supplied to case_slack when creating
      the case root. An existing Slack conversation remains the destination.

      Apply rate_case for ${inputs.issue}: load the shared case, use case_slack for status,
      retaining the recorded status until the selected work stage publishes its own.
      Use case_slack to publish the recorded root status and confirm the gateway succeeded.
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

      Resume review_followup when the checkpoint records an unfinished review. Otherwise
      select verify_wai for an unverified WAI claim, or record_learnings for accepted work.
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
      1. Restore the case and publish the stage status.
      2. Delegate to Devin.
      3. Assess the result.
      4. Finish or pause.

      # 1. Restore the case and publish the stage status

      Apply rate_case for ${inputs.issue} at `verify_wai`. Use case_slack with status ":mag: Verifying working-as-intended".
      Publish the root status using case_slack and confirm the gateway succeeded before continuing.

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

      # 3. Assess the result

      Collect evidence with check_session and apply evidence_gate. Confirmation requires positive
      proof of correct behavior, not an absent reproduction. Refutation requires evidence of the
      missed defect. Ask Devin to investigate any gap rather than choosing a side without support.

      # 4. Finish or pause

      On WAI_CONFIRMED, ask Devin to explain the finding on Jira using writing-ticket-updates.
      On WAI_REFUTED, allow the declared triage route only when the stored wai_refire_count < 1.
      Preserve the prior reasoning and evidenced rebuttal as a challenge, not a predetermined
      answer. Ask Devin to annotate the prior comment as under investigation. At a repeated
      standoff, use blocked_run and rate_checkpoint to ask for the decision with both positions
      and their evidence, rather than re-firing. Use the same pause workflow if the verification
      itself needs a human answer; do not manufacture confirmation or refutation.
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
      1. Restore the case and publish the stage status.
      2. Read the accepted findings.
      3. Gather and record worthwhile lessons.
      4. Finish.

      # 1. Restore the case and publish the stage status

      Apply rate_case for ${inputs.issue} at `record_learnings`. Use case_slack with status ":memo: Recording lessons".
      Publish the root status using case_slack and confirm the gateway succeeded before continuing.

      Ask the Devin sessions that worked on ${inputs.issue} for difficult-to-discover,
      worthwhile lessons, following learnings_capture for the requests, assessment, and writeback.

      # 2. Read the accepted findings

      Read the verdict, close reason, diagnosis, complete findings, audit findings, and PRs
      from the case. Ask sessions for lessons from their work.
      Recover missing report context through delegated_session before drawing on it.

      # 3. Gather and record worthwhile lessons

      Use enter_finalize's reachable_sessions to request worthwhile, reusable lessons from each
      distinct Devin session through learnings_capture. Check rate_case_log for duplication or
      supporting cases when assessing their proposals.

      Use `!rate-learning-writeback` as the writeback playbook. Supply base branches as an object
      keyed by repository URL: {"${inputs.repo_url}": "${inputs.base_branch}"} plus any other
      destination repository; a blank or missing entry means that repository's default branch.
      Use one writeback session for all accepted lessons across repositories, reusing the owner in
      the checkpoint's learning-writeback lane. Title a new session "${inputs.issue} — record learnings"
      and tag it with `["${inputs.issue}", "learnings"]`.
      Record that owner so operator review can direct later documentation corrections to it.

      # 4. Finish

      Append one line to rate_case_log/cases.md using mission file tools, even if nothing qualified:
      <date> | ${inputs.issue} | <mechanism> | <verdict> | <writeback destination or none>
      Report unavailable storage rather than committing the log to a repository.

      If a failure prevents completion or a returned finding calls close-out into question,
      apply question_screen, then use builtins.human.ask when an operator decision is needed.
      Explain the failure, available evidence, and the decision needed to proceed. Follow
      blocked_run's operator-wait handling; do not turn learning-step failures into Jira questions
      or automatically restart investigation or audit. No qualifying lessons is a successful outcome.

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
      1. Collect current work and wait.
      2. Assess feedback and direct corrections.
      3. Verify a reported staging deployment.
      4. Finish or recover.

      Repeat the feedback steps as needed; staging verification follows an operator-reported deployment.

      Keep ${inputs.issue} available for operator feedback, re-audit, and corrections until
      its PRs merge and requested checks are settled, or the operator ends review.
      Use rate_case for context, rate_checkpoint for progress, and case_slack for updates.

      # 1. Collect current work and wait

      1. Collect current PR states, heads, and session results through
         delegated_session, including lessons PRs. On resume, reconcile the saved pending
         action before resending work. If the completion criteria below are met, finish.
      2. Save progress and next entry rate_finalize/review_followup before each wait or
         session request. Use case_slack to publish root status ":eyes: Awaiting review"
         and confirm the gateway succeeded before asking for feedback.
      3. Call builtins.human.ask without timeout_seconds: "What should I review or change?
         Tell me when staging is deployed or the PRs are merged." Offer re-audit, staging
         verification, merge check, and end review, with free text for detailed feedback.
         Wait in this task; an interrupted ask retains active case state for resumption.

      # 2. Assess feedback and direct corrections

      1. Save feedback and collect affected session results and PR heads, including changes
         the operator requested directly from Devin. Ask for any unrecorded feedback.
      2. Direct investigation, fix, case, Bruno, and lesson changes to their recorded owners
         through delegated_session, preserving each owner's file lane.
      3. Use case_slack to publish root status ":microscope: Auditing" and confirm the gateway
         succeeded before re-auditing. Use evidence_gate, ab_audit, and txc_rate_audit to re-audit
         changed work with fresh captures. Have the Bruno owner review automatic staging CI:
         should-change tests fail before deployment and pass afterward; guardrails pass throughout.
         Record assessed heads and evidence so an earlier pass cannot approve a later commit.
      4. Use verdict_loop to continue corrections while progress is being made. If progress
         stalls or more information is needed, ask the operator with the unresolved findings
         and evidence. Preserve review history, post results in Slack, and return to the ask.

      Use blocked_run for an operator or product dependency, then resume this review task.
      Merge and deployment decisions remain with the operator.

      # 3. Verify a reported staging deployment

      1. When the operator confirms this case's fix is deployed to staging, use case_slack
         to publish root status ":test_tube: Verifying in staging" and confirm the gateway succeeded.
         Then have the Bruno owner review a CI run made after that deployment. Keep verification pending if
         fresh evidence is unavailable.
      2. Compare results with the pre-deployment run. Both should-change tests and guardrails
         should now pass. Investigate unchanged failures, new failures, or an unexpected lack
         of change even when the SQL A/B audit was satisfactory.
      3. Send discrepancies and CI evidence to the appropriate existing owners and re-audit
         their corrections. A correction needing deployment waits for the operator's next
         manual deployment before its post-deployment check.
      4. Save the staging deployment confirmation, CI evidence, and pending work. Report results and
         delegated follow-ups in Slack. Keep review open while verification or corrections remain.

      # 4. Finish or recover

      On a merge check, confirm every case PR's state through the sessions. Report remaining
      open PRs and return to the ask; obtain operator disposition for closed-unmerged PRs.
      Close when all PRs are merged and requested checks and corrections are settled, or when
      a no-PR case has an accepted disposition and no pending work. On explicit end review,
      record remaining work and close by operator choice. An interruption leaves this stage
      as the next entry rather than completing review.
    EOT
    agents = [agents.taxcloud_legacy_sql_reviewer]

    output {
      field "outcome" {
        type        = "string"
        description = "merged | closed_by_operator | no_prs | interrupted. interrupted retains active case state and review_followup as the next entry."
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
