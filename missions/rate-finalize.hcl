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

  # Last of the three rate missions: rate_triage -> rate_fix -> rate_finalize.
  # Both terminals live here, because both are the same act — deciding what this
  # case leaves behind. Either the conclusion was "nothing is broken", which gets
  # verified independently before anyone believes it, or the case is closed and
  # what it taught (if anything) gets written somewhere the next case reads.
  #
  # Entered only by route: from rate_triage (working-as-intended, or a proven
  # defect this engine cannot express) or from rate_fix (the A/B settled, with or
  # without Bruno coverage behind it).
  #
  # Routed graph (Squadron is acyclic — no backward edges):
  #   enter_finalize --router--> verify_wai       (a working-as-intended claim to check)
  #                         \--> record_learnings (ask work sessions for worthwhile lessons)
  #   verify_wai     --router--> missions.rate_triage (WAI refuted, capped at one re-fire)
  #                         \--> tasks.record_learnings (WAI confirmed)
  #
  # Objective convention (same as the other two): "You"/"# You do" is this
  # Squadron stage, "the session"/"# Brief the session" is text for the Devin
  # task. Every Jira comment, query and write-back PR here is a Devin session's
  # work; the sentinel label is the stage's own, per blocked_run.
  memories = [memories.rate_case_log, memories.rate_checkpoint]

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
    description = "verify_wai | record_learnings — which terminal this case needs. verify_wai only on an unverified working-as-intended conclusion; record_learnings for every other close-out, including a confirmed one."
  }

  input "close_reason" {
    type        = "string"
    description = "Why the case arrived here, in a phrase: 'fix audited SATISFACTORY and bruno regression authored', 'audit FIX_IS_NO_OP', 'proven but unsupported at available granularity', 'working as intended', or the stage a prior run blocked at. Context for asking the work sessions about their discoveries; no disposition by itself requires a learning writeback."
  }

  input "verdict" {
    type        = "string"
    description = "The verdict this case ends on, in the vocabulary of whichever mission sent it: DEFECT_PROVEN, WORKING_AS_INTENDED (rate_triage), SATISFACTORY, FIX_IS_NO_OP (rate_fix's audit)."
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
  }

  input "production_evidence" {
    type        = "string"
    description = "Typed governed-production observations carried from investigation. Preserve these in a retained checkpoint so a later run does not reinterpret an unavailable or incomplete read as proof of absence."
    default     = "[]"
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
    description = "The Bruno authoring session, for the learnings ask. Blank when Bruno did not run."
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
      Before routing or side effects, if start event "${inputs.start_event_id}" is nonempty,
      have session_scout apply blocked_run with blocker "${inputs.blocker_id}" and generation
      ${inputs.blocker_generation}. Load the current checkpoint, reject stale or completed
      events, and durably claim this event before continuing interrupted work.
      If that check rejects the event, end this run without selecting a downstream route.

      Choose the remaining close-out work for ${inputs.issue}, entering at ${inputs.entry_stage}
      because ${inputs.close_reason}.

      # Inspect the handoff

      Have session_scout check supplied Devin ids: investigation ${inputs.investigation_session_id},
      fix ${inputs.fix_session_id}, cases ${inputs.cases_session_id}, and Bruno ${inputs.bruno_session_id}.
      Use delegated_session's discovery guidance if an id is missing for known work. An unavailable
      session still contributes its report; it cannot answer follow-up questions. Do not create
      or message sessions here.

      # Select the entry

      Choose verify_wai for a working-as-intended claim not yet independently checked; otherwise
      choose record_learnings. Do not repeat a completed verification.
    EOT
    agents = [agents.session_scout]

    output {
      field "entry_stage" {
        type        = "string"
        description = "verify_wai | record_learnings — the terminal this case takes."
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
      Independently assess the working-as-intended conclusion for ${inputs.issue}.
      Repository: ${inputs.repo_url}; base branch: ${inputs.base_branch}.

      # Delegate to Devin

      Have the stage agent create a fresh read-only Devin session through plugins.devin.code_develop
      on ${inputs.repo_url}, with `prompt_mode: "raw"`, title ${inputs.issue} — verify working-as-intended,
      and tags `["${inputs.issue}", "verify-wai"]`. Have Devin use the repository's investigate-tax-behavior
      skill to check the ticket's disputed value against data independently of the earlier reasoning.
      Use delegated_session for registration and follow-ups.

      # Assess the result

      Collect evidence with check_session and apply evidence_gate. Confirmation requires positive
      proof of correct behavior, not an absent reproduction. Refutation requires evidence of the
      missed defect. Ask Devin to investigate any gap rather than choosing a side without support.

      # Finish or pause

      On WAI_CONFIRMED, ask Devin to explain the finding on Jira using writing-ticket-updates.
      On WAI_REFUTED, allow the declared triage route only when ${inputs.wai_refire_count} < 1.
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
        condition = "verdict == WAI_REFUTED AND wai_refire_count < 1 — return to triage for an independent re-investigation. Set wai_challenge to the prior reasoning and cited rebuttal, and increment wai_refire_count. Map the investigation owner to wip_investigation_session_id if messageable, or stale_investigation_session_id otherwise."
      }
      # A repeated WAI refutation ends in the human-wait workflow described above.
      route {
        target    = tasks.record_learnings
        condition = "verdict == WAI_CONFIRMED — the ticket was a misunderstanding; a recurring misunderstanding is worth recording."
      }
    }

  }

  # ---------------------------------------------------------------------------
  # Task — record_learnings. The chain's terminal. Reached from enter_finalize
  # (rate_fix's completed lane or FIX_IS_NO_OP, rate_triage's unsupported
  # disposition) and from verify_wai's WAI_CONFIRMED. Most cases record nothing,
  # and that is a valid outcome.
  # ---------------------------------------------------------------------------

  task "record_learnings" {
    objective = <<-EOT
      Ask the Devin sessions that worked on ${inputs.issue} whether they discovered anything
      difficult to discover and worthwhile to record for future work. Use delegated_session
      to contact each distinct reachable work session and collect its answer. Tell each session
      this is a read-only request for lessons from its own work. “Nothing worth recording” is
      a complete answer; do not request a quota of lessons.

      # Context

      The following is context for your requests. Do not infer lessons from it yourself.
      Ask the Devin sessions for their own findings.

      Result: ${inputs.verdict}
      Close reason: ${inputs.close_reason}
      Mechanism: ${inputs.mechanism}
      Fix PR: ${inputs.fix_pr_url}
      Audit findings: ${inputs.audit_findings}
      Disposition: ${inputs.disposition}

      # Collect and assess the answers

      Use enter_finalize's reachable_sessions. For unavailable sessions, retain only lessons
      explicitly proposed in their recorded reports, with attribution. Record unavailable
      responses separately from “nothing worth recording.” Do not start a new investigation
      to manufacture lessons.

      Apply learnings_capture to the returned proposals. Ask Devin what made each discovery
      difficult, what evidence supports it, what future decision it changes, and whether existing
      guidance already covers it. Check rate_case_log for duplication or supporting cases.
      Record only proposals that meet those criteria. A limitation class such as
      ${inputs.limitation_class} does not by itself require a writeback.

      # Record qualifying lessons

      For an accepted proposal, use delegated_session and devin_code to start a separate
      documentation-only Devin session with `prompt_mode: "raw"`. Supply the source finding,
      evidence, repository, and selected guidance files. Use title ${inputs.issue} — record
      <lesson> and tags `["${inputs.issue}", "learnings"]`. Continue an existing documentation
      assignment instead of creating a duplicate. Review the resulting PR against the proposal.
      Do not request implementation changes, new tests, or a ticket-specific fix narrative.

      # Finish

      Append one line to rate_case_log/cases.md using mission file tools, even if nothing qualified:
      <date> | ${inputs.issue} | <mechanism> | <verdict> | <writeback destination or none>
      Report unavailable storage rather than committing the log to a repository.

      Use rate_checkpoint for ${inputs.issue}.yaml. If a response reveals a technical correctness
      or acceptance gap, report it and retain the checkpoint and source evidence. Do not resolve
      it here or mark the case closed. Set next_entry to rate_fix/audit for an existing fix needing
      review, or rate_triage/assess_investigation for a diagnosis needing reconsideration.
      Apply question_screen before treating an unresolved item as a human dependency. Use
      blocked_run for genuine closure-blocking human questions, including any in
      ${inputs.open_questions}. Delete the checkpoint only when nothing remains.
    EOT
    agents = [agents.learnings_curator]

    output {
      field "session_findings" {
        type        = "string"
        description = "Each distinct work session asked and its response reference, proposed lessons or explicit none, and any unavailable response. Attribute proposals recovered from recorded reports."
        required    = true
      }
      field "recorded" {
        type        = "boolean"
        description = "Whether an accepted session-proposed lesson was written back in a reviewable PR."
        required    = true
      }
      field "learning" {
        type        = "string"
        description = "The accepted session-proposed rule with its supporting case, or why the returned proposals did not qualify. Do not infer a lesson to fill this field."
        required    = true
      }
      field "destination_pr_url" {
        type        = "string"
        description = "PR URL of the write-back, when one was made"
        required    = false
      }
      field "checkpoint" {
        type        = "string"
        description = "The ticket's current checkpoint, or 'none — file deleted' when the case closed."
        required    = true
      }
    }
  }
}
