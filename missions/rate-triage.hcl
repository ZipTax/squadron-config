mission "rate_triage" {
  commander {
    model = models.anthropic.claude_opus_4_7

    compaction {
      token_limit    = 250000
      turn_retention = 3
    }

    # A stage result is structured output + Devin's last message + PR links, not
    # the raw transcript, so it is small. Raise this only if the devin plugin is
    # configured with raw_messages = "true" (see plugins.hcl).
    tool_response {
      max_tokens = 32000
    }
  }

  # Discovery and assessment precede implementation so a fix starts from an explicit verdict.
  # Session lifecycle, human waits, and checkpoint rules live in the attached skills.
  # See docs/rate-ticket-orchestration.md for phase ownership and bridge rollout.
  memories = [memories.rate_checkpoint, memories.rate_resume_state]

  agents = [
    agents.session_scout,
    agents.taxcloud_legacy_sql_investigator
  ]

  # ---------------------------------------------------------------------------
  # Inputs — a Slack bot or the Jira automation fires this mission with a ticket
  # key. This is the chain's front door; rate_fix and rate_finalize are entered
  # by route with the case state filled in, not by a human.
  # ---------------------------------------------------------------------------

  input "issue" {
    type        = "string"
    description = "Ticket key for the rate fix (e.g. DEV-7282)."
  }

  input "repo_url" {
    type        = "string"
    description = "Repo the fix lands in."
    default     = "https://github.com/FedTax/txc-sqlserver-database"
  }

  input "base_branch" {
    type        = "string"
    description = "Base branch the PR targets. Blank lets Devin use the repo default."
    default     = ""
  }

  input "wip_investigation_session_id" {
    type        = "string"
    description = "Optional override: an in-flight Devin session discover_sessions must treat as the one to continue, when a human or an automation knows something the ticket-tag search cannot. Blank = discovery decides from the tagged sessions it finds."
    default     = ""
  }

  input "stale_investigation_session_id" {
    type        = "string"
    description = "Optional override: an expired/archived Devin session discover_sessions must treat as terminated context to carry forward rather than as resumable. Blank = discovery decides from the tagged sessions it finds."
    default     = ""
  }

  input "wai_challenge" {
    type        = "string"
    description = "Optional authoritative challenge from a prior run — a working-as-intended conclusion that rate_finalize's verify_wai refuted, with the rebuttal and an instruction to re-investigate skeptically and annotate the prior Jira comment. Present = discovery routes to confirm_wai. Blank on a first run."
    default     = ""
  }

  input "wai_refire_count" {
    type        = "number"
    description = "How many times this ticket has been re-fired after a working-as-intended refute. Caps the investigation<->verify standoff: rate_finalize's verify_wai will not re-fire once this is >= 1, so it is carried across the boundary rather than recomputed."
    default     = 0
  }

  # Allow triggering via webhook - Triage Bot uses this to auto-attempt rate tickets
  trigger {
    # Set explicitly so the path survives a mission rename: "/ratevariant" is
    # what the triage bot's `squadron:ratevariant` cell posts to, and what the
    # Bridge delivery replaces the legacy Jira comment trigger at rollout.
    webhook_path = "/ratevariant"
    secret       = vars.ratevariant_webhook_secret
  }

  task "discover_sessions" {
    objective = <<-EOT
      Choose the entry for ${inputs.issue}; do not create/message a session or investigate tax
      behavior.

      # Inspect existing work

      Have session_scout read or migrate the checkpoint using rate_checkpoint and apply
      delegated_session for candidate validation, resumability, and provenance.
      Read the Jira Devin Sessions field ${vars.jira_sessions_field} using getJiraIssue with
      cloudId "${vars.jira_cloud_id}". Extract its tag/URL lines from the ADF paragraphs. Only
      if that field is empty, absent, or refused, fall back to find_sessions(tags: ["${inputs.issue}"]).
      Check candidate sessions for actual lane work and verdicts; a writeback-only session is
      never an investigation owner. A refused read is not evidence that no session exists.

      # Assess ownership

      Honor explicit inputs: live override "${inputs.wip_investigation_session_id}", terminated
      context override "${inputs.stale_investigation_session_id}", WAI challenge "${inputs.wai_challenge}".
      Otherwise keep the checkpoint's exact lane owner; discovery ranking is only for a lane
      without recorded ownership. Record other candidates and disagreements without blending
      reports. If indexes fail, check recorded ids and label unverified checkpoint facts recorded;
      only with no usable history or checkpoint may you start blind, history_provenance none.

      # Finish discovery

      Apply blocked_run's trigger-label entry step using editJiraIssue label removal only.
      The selected work stage delegates interpretation of new answers; discovery does not decide
      whether a tax or product question is settled.

      Prefer the checkpoint's downstream resume stage (author_tests, audit, bruno_tests, or
      record_learnings) when its verdict and required artifacts remain valid. Carry its state
      and selected entry forward. If contradictory or incomplete, leave resume_stage blank and
      explain why investigation must reconsider the premise. Otherwise select one entry mode:

      - confirm_wai: a WAI challenge is present or a prior verify-wai result refuted WAI; preserve
        the rebuttal and evidence in prior_context.
      - continue: the chosen investigation owner is messageable.
      - forward: its report is readable but the owner is terminated/expired; preserve attribution.
      - start: no investigation owner is known.

      Leave the answer assessment to the routed stage. Do not mine PR descriptions for
      workflow state; use artifact links and returned session evidence to identify the fix.
    EOT
    agents = [agents.session_scout]

    output {
      field "entry_mode" {
        type        = "string"
        description = "start | confirm_wai | continue | forward. Exactly one; it is what the router acts on when resume_stage is blank."
        required    = true
      }
      field "resume_stage" {
        type        = "string"
        description = "author_tests | audit | bruno_tests | record_learnings, when the checkpoint says the last run blocked at that stage AND the verdict and fix PR it records are intact — the flow re-enters there instead of investigating again. Blank otherwise, which is the default: a doubt about the recorded state is a reason to leave it blank."
        required    = false
      }
      field "investigation_session_id" {
        type        = "string"
        description = "The one session the chosen mode applies to: to continue, or to read for context. Blank on start."
        required    = false
      }
      field "session_state" {
        type        = "string"
        description = "That session's state as check_session reports it, and whether it can still be messaged — this is what separates continue from forward. Blank on start."
        required    = false
      }
      field "prior_verdict" {
        type        = "string"
        description = "A verdict the read already found in that session, if it reached one, so the assessing stage can take it rather than re-running an investigation that is already done. Blank when none."
        required    = false
      }
      field "existing_fix_pr_url" {
        type        = "string"
        description = "A fix PR for THIS ticket that some prior session already opened. State, not a mode: the fix exists and its A/B coverage may not. Blank when there is none."
        required    = false
      }
      field "prior_context" {
        type        = "string"
        description = "Established findings and remaining questions attributed to each source session; include any WAI challenge and its evidence without weakening it. Blank when no prior context exists."
        required    = false
      }
      field "checkpoint" {
        type        = "string"
        description = "The validated rate_checkpoint/<TICKET>.yaml record verbatim, or blank if absent. The routed stage owns answer assessment; discovery does not add domain conclusions to this record."
        required    = false
      }
      field "sessions_found" {
        type        = "string"
        description = "The sessions found for this ticket — id, stage tag, state, and which source named it (the ticket's Devin Sessions field or the tag search) — and one line on why the chosen one was chosen over the others. Where a read was refused rather than empty, say so instead of reporting no history."
        required    = true
      }
      field "history_provenance" {
        type        = "string"
        description = "How you came to know this ticket's session history, always stated: read (a source answered — the ticket's sessions field, the tag search, or both — and the session reads went through; name which, since a field-only read cannot see sessions that predate it), recorded (every source was refused and you fell back to the checkpoint's ids and states — name what was refused), or none (refused with no checkpoint to fall back on, so the mode is start and was chosen blind). Downstream needs this, because a verdict reached without knowing whether another session is already on the ticket carries that caveat, and it is an operational fact about our run rather than a finding about the tax behavior."
        required    = true
      }
    }

    router {
      route {
        target    = missions.rate_fix
        condition = "resume_stage is author_tests, audit or bruno_tests — a prior run proved the defect and shipped the fix PR, and blocked somewhere in the implementation/A-B lane. The investigation is done; re-running it risks contradicting the verdict this fix was built on. Pass entry_stage = that stage, and fill every fix-lane input from the checkpoint and the sessions you found: the PR, the branch, the fix and cases session ids and whether each is messageable. rate_fix cannot query this ticket's history — what you do not carry across, it does not have."
      }
      route {
        target    = missions.rate_finalize
        condition = "resume_stage == record_learnings — every stage finished and only the close-out was outstanding. Pass entry_stage = record_learnings, close_reason naming the prior run's outcome, and the session ids and PRs the close-out asks its sessions about."
      }
      route {
        target    = tasks.confirm_wai
        condition = "entry_mode == confirm_wai — a prior working-as-intended conclusion is under challenge, so it gets an independent re-investigation rather than a resumption of the session that reached it."
      }
      route {
        target    = tasks.continue_investigation
        condition = "entry_mode == continue — a messageable investigation session exists for this ticket, so it continues in that session; a new one would re-derive its context and may answer differently."
      }
      route {
        target    = tasks.forward_investigation
        condition = "entry_mode == forward — an investigation session exists but is terminated/archived, so its findings are carried into a fresh session instead of being re-derived from zero."
      }
      route {
        target    = tasks.start_investigation
        condition = "entry_mode == start — nothing has investigated this ticket, so start fresh."
      }
    }

  }

  # ---------------------------------------------------------------------------
  # Tasks — the four investigation entries. Dynamic targets (no depends_on), so
  # only the one discover_sessions routes to runs. They differ ONLY in how the
  # session is obtained; the brief they give it and the gates its result must
  # pass are shared, and live in the rate_investigation skill. Each pushes into
  # assess_investigation, which owns the verdict and the routing — conditional
  # fan-in, so the verdict schema and the four downstream routes exist once
  # instead of four times drifting apart.
  # ---------------------------------------------------------------------------

  task "start_investigation" {
    objective = <<-EOT
      Establish a read-only investigation of ${inputs.issue} using the rate_investigation skill.

      # Delegate to Devin

      Have the stage agent call plugins.devin.code_develop on ${inputs.repo_url}, with
      !rate_investigation in the task, prompt_mode raw, and tags ${inputs.issue}, rate-investigation.
      Supply the ticket, reported scope, and any evidence from discovery. Use a title naming the
      reported behavior. If discovery could not establish prior history, tell Devin that existing
      work may be unknown; do not turn this operational caveat into a requested ticket update.

      # Assess and finish

      Collect the result through check_session. Apply rate_investigation's evidence and completion
      criteria; ask for any missing support. Assessment handles the accepted verdict and next route.
    EOT
    agents  = [agents.taxcloud_legacy_sql_investigator]

    output {
      field "investigation_session_id" {
        type        = "string"
        description = "Devin session id that ran the investigation, resumed later via send_message rather than recreated."
        required    = true
      }
      field "result" {
        type        = "string"
        description = "What the session reported: its verdict, the mechanism, the evidence behind each load-bearing claim, and its explicit unknowns. The assessing stage judges this against the gates."
        required    = true
      }
    }

    send_to = [tasks.assess_investigation]
  }

  task "confirm_wai" {
    objective = <<-EOT
      Re-examine the challenged working-as-intended conclusion for ${inputs.issue} independently.

      # Delegate to Devin

      Have the stage agent create a fresh session through plugins.devin.code_develop on
      ${inputs.repo_url}, with !rate_investigation in the task, prompt_mode raw, and tags
      ${inputs.issue}, rate-investigation, wai-challenge. Use a title naming the disputed behavior.
      Supply the ticket, prior conclusion, and rebuttal as claims to test against code and data:
      %{ if inputs.wai_challenge != "" ~}
      ${inputs.wai_challenge}
      %{ else ~}
      Use the challenge and evidence in discover_sessions' prior_context.
      %{ endif ~}
      Ask for read-only investigation using rate_investigation's brief. Do not assume either
      account is correct. Ask Devin to annotate the prior Jira conclusion as under investigation
      using writing-ticket-updates, so readers do not mistake it for a settled answer.

      # Assess and finish

      Collect the result with check_session and apply rate_investigation's acceptance criteria.
      Assessment handles the supported verdict and routing.
    EOT
    agents  = [agents.taxcloud_legacy_sql_investigator]

    output {
      field "investigation_session_id" {
        type        = "string"
        description = "Devin session id of the fresh re-investigation — not the challenged session."
        required    = true
      }
      field "result" {
        type        = "string"
        description = "What the session reported: its verdict, the mechanism, the evidence behind each load-bearing claim, and whether the challenged conclusion survived."
        required    = true
      }
    }

    send_to = [tasks.assess_investigation]
  }

  task "continue_investigation" {
    objective = <<-EOT
      Finish the investigation of ${inputs.issue} in the Devin session selected by discovery.

      # Work with Devin

      Have the stage agent check_session first. If work remains, send_message with only the
      unanswered question and new evidence, following rate_investigation and delegated_session.
      Do not repeat the full investigation brief. If the selected session is no longer messageable,
      report the discovery discrepancy rather than silently replacing it on this continuation path.

      # Assess and finish

      Reuse an already supported result without restarting work. Otherwise collect the follow-up
      and apply rate_investigation's acceptance criteria before handing it to assessment.
    EOT
    agents  = [agents.taxcloud_legacy_sql_investigator]

    output {
      field "investigation_session_id" {
        type        = "string"
        description = "The session that was continued — the same id discover_sessions identified, never a new one."
        required    = true
      }
      field "result" {
        type        = "string"
        description = "What the session concluded: verdict, mechanism, evidence, unknowns — whether it was already there on the read or came from the follow-up."
        required    = true
      }
    }

    send_to = [tasks.assess_investigation]
  }

  task "forward_investigation" {
    objective = <<-EOT
      Use the prior investigation of ${inputs.issue} without losing its findings when the original
      Devin session can no longer be messaged.

      # Work with Devin

      Have the stage agent read the selected report with check_session. Reuse it when its cited
      evidence settles the question. If gaps remain, create a read-only session through
      plugins.devin.code_develop on ${inputs.repo_url}, with !rate_investigation in the task,
      prompt_mode raw, and tags ${inputs.issue}, rate-investigation. Supply the attributed report
      and the specific gaps, following rate_investigation; do not ask for a restart from zero.

      # Assess and finish

      Apply rate_investigation's acceptance criteria. Keep inherited claims attributed until
      Devin checks their evidence. Hand the result to assessment with the actual session ownership
      and resumability described by the output contract.
    EOT
    agents  = [agents.taxcloud_legacy_sql_investigator]

    output {
      field "investigation_session_id" {
        type        = "string"
        description = "The session whose verdict is being returned: the new one, or the terminated one when its conclusion already settled the question."
        required    = true
      }
      field "session_messageable" {
        type        = "boolean"
        description = "Whether the returned session can still be messaged. False when the terminated session's verdict stood and its id is what is being returned — downstream stages must then treat the report as the whole record instead of sending to a dead session."
        required    = true
      }
      field "result" {
        type        = "string"
        description = "The verdict, mechanism, evidence and unknowns, and which of them are inherited from the terminated session versus established by the new one."
        required    = true
      }
    }

    send_to = [tasks.assess_investigation]
  }

  # ---------------------------------------------------------------------------
  # Task — assess_investigation. Conditional fan-in from whichever entry ran, so
  # the gates, the verdict schema and the downstream routes exist exactly once —
  # a verdict means the same thing regardless of how the case came in. Judges an
  # investigation it did not run; no session is created here either.
  # ---------------------------------------------------------------------------

  task "assess_investigation" {
    objective = <<-EOT
      Decide whether the investigation of ${inputs.issue} supports a disposition.

      # Obtain and assess evidence

      Have the stage agent retrieve the Devin result with check_session and apply rate_investigation.
      Confirm the selected session actually investigated: a comment-only session is a discovery
      error, not evidence that an investigation found nothing. Ask Devin bounded questions for
      missing or contradictory support. Use delegated_session when the original session cannot
      answer; do not infer a verdict from a summary.

      For an existing fix PR, also check its owner's resumability so implementation can adopt the
      PR if needed. Preserve the strength of the findings and all outstanding questions.

      # Finish or pause

      Use the declared routes for a supported result. A proven unsupported disposition needs the
      limitation writeback described in rate_investigation. EVIDENCE_INCOMPLETE does not proceed.
      For needs_human, use blocked_run and rate_checkpoint. For a production gap no person can
      resolve, record insufficient_production_evidence without inventing a question.
    EOT
    agents = [agents.taxcloud_legacy_sql_investigator]

    output {
      field "outcome" {
        type        = "string"
        description = "completed | needs_human — copied from the Devin result after applying the distinction between a blocking human dependency and a non-blocking follow-up."
        required    = true
      }
      field "human_questions" {
        type        = "string"
        description = "The session's question-and-context pairs. Empty when outcome is completed."
        required    = true
      }
      field "verdict" {
        type        = "string"
        description = "DEFECT_PROVEN | WORKING_AS_INTENDED | EVIDENCE_INCOMPLETE"
        required    = true
      }
      field "evidence_complete" {
        type        = "boolean"
        description = "Whether every load-bearing claim is measured or traced with a citation, and the question-match, mechanism-located, and alternative-killed gates pass. False forces escalation."
        required    = true
      }
      field "working_as_intended" {
        type        = "boolean"
        description = "True if the investigation concluded the current behavior is already correct."
        required    = true
      }
      field "disposition" {
        type        = "string"
        description = "Remediation disposition when a defect is proven: data/configuration change | procedure/function change | both | unsupported at available granularity. 'Both' is common — wrong rates that are also applied wrongly need a migration AND a proc change. The last is terminal: the proven mechanism is one this engine cannot express, so no fix follows and the ticket is labelled new-rate-engine and blocked. Blank otherwise."
        required    = false
      }
      field "mechanism" {
        type        = "string"
        description = "What is wrong and where expected and actual part ways — the object(s)/symbol(s), the input that reaches them, and both values. May legitimately be several sites in one object rather than a single line."
        required    = false
      }
      field "affected_roots" {
        type        = "string"
        description = "Procedures/functions the defect appears to implicate, and for a data defect the tables/rows. A briefing hint for the fix and a cross-check on coverage — NOT the coverage checklist, which the ratevariant plan comment derives from the callgraph at the head SHA."
        required    = false
      }
      field "evidence" {
        type        = "string"
        description = "The evidence chain: each load-bearing claim with its basis (measured|traced) and citation (file+symbol, or query+values)."
        required    = true
      }
      field "production_evidence" {
        type        = "string"
        description = "The typed production observations: status, ticket gap outcome, bounded scope/query, result summary, and limitations. Empty list when production was not queried."
        required    = true
      }
      field "unknowns" {
        type        = "string"
        description = "What remains unproven, and for EVIDENCE_INCOMPLETE the exact artifacts that would close each gap."
        required    = false
      }
      field "limitation_class" {
        type        = "string"
        description = "On the unsupported disposition only: which limitations.md entry (a ticket carrying the new-rate-engine label) the proven mechanism matched, so record_learnings files this ticket as an instance under it. Blank otherwise."
        required    = false
      }
      field "existing_fix_pr_url" {
        type        = "string"
        description = "A fix PR a prior session already opened for this ticket. With a live owning session the mission continues at case authoring instead of develop — the fix exists, the A/B coverage does not; with a dead one it goes through develop to adopt the PR. Blank when there is no such PR."
        required    = false
      }
      field "fix_session_id" {
        type        = "string"
        description = "On an existing fix PR only: the session that opened it. Blank when there is no such PR, or when its session cannot be identified."
        required    = false
      }
      field "fix_session_messageable" {
        type        = "boolean"
        description = "On an existing fix PR only: whether fix_session_id can still be messaged. False (or unknown) sends the mission through develop to adopt that PR, because audit routes fixes to the owning session and cannot create one."
        required    = false
      }
      field "investigation_session_id" {
        type        = "string"
        description = "Devin session id that holds the investigation, resumed later via send_message rather than recreated."
        required    = true
      }
      field "session_messageable" {
        type        = "boolean"
        description = "Whether investigation_session_id can still be messaged. False when the verdict was carried forward from a terminated session: audit and record_learnings must then work from its report, or start a session of their own, rather than sending to a dead id."
        required    = true
      }
      field "investigation_summary" {
        type        = "string"
        description = "One-line summary of the verdict and its basis."
        required    = true
      }
    }

    router {
      route {
        target    = missions.rate_fix
        condition = "outcome == completed AND verdict == DEFECT_PROVEN AND evidence_complete == true AND disposition != 'unsupported at available granularity'"
      }
      route {
        target    = missions.rate_finalize
        condition = "outcome == completed AND (verdict == WORKING_AS_INTENDED OR (verdict == DEFECT_PROVEN AND disposition == 'unsupported at available granularity'))"
      }
      # `needs_human` and EVIDENCE_INCOMPLETE are terminal because this stage records their state.
    }
  }
}
