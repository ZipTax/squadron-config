mission "rate_fix" {
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

  # Second of the three rate missions: rate_triage -> rate_fix -> rate_finalize.
  # Everything that touches the repo lives here — the fix, the A/B cases, the
  # adversarial audit that grades them, and the Bruno suite that locks the
  # result in. It never decides whether there is a defect: rate_triage proved
  # that and passes the diagnosis in as inputs, so no stage here re-derives it.
  #
  # Entered only by route, never by a human: from rate_triage's assessment (a
  # proven defect), or from its discovery when a prior run blocked inside this
  # lane and the case resumes at the stage it stopped at.
  #
  # Routed graph (Squadron is acyclic — no backward edges):
  #   enter_fix   --router--> develop      (write the fix, or adopt a PR whose session died)
  #                      \--> author_tests (a live fix PR only lacks A/B coverage)
  #                      \--> audit        (fix and cases both exist; resume the judgment)
  #                      \--> bruno_tests  (the A/B is settled; only API coverage was outstanding)
  #   develop     --router--> author_tests (completed; needs_human checkpoints and ends)
  #   author_tests --router--> audit       (completed; needs_human checkpoints and ends)
  #   audit       --router--> bruno_tests            (SATISFACTORY: lock the settled fix in)
  #                      \--> missions.rate_finalize (FIX_IS_NO_OP: the fix changes nothing)
  #   bruno_tests --router--> missions.rate_finalize
  #
  # The audit loop is why these four stages are one mission: the correction loop
  # runs audit <-> the Devin session that owns the work via send_message, and the
  # session ids that make it possible (fix, cases) are produced here. Splitting
  # audit out would hand it ids it cannot own.
  #
  # Objective convention (same as rate_triage): "You"/"# You do" is this Squadron
  # stage, "the session"/"# Brief the session" is text for the Devin task,
  # "# Hold the session to" is what to check on return. Repo mechanics are not
  # restated: the fix/cases/run/audit steps live in txc-sqlserver-database's
  # ratevariant-testing skill (references/process.md), which the playbooks load.
  # All credentialed I/O (gh, PR/Jira comments, staging queries) is Devin's.
  #
  # Blocking on a human: the blocked_run skill, both ends. A stage that hits a
  # wall ends the run, writes rate_checkpoint/<TICKET>.yaml naming this lane's
  # stage, and puts the questions on the ticket; the Jira automation fires
  # /ratevariant when the answer lands, and rate_triage's discovery routes the
  # case back here at that stage.
  memories = [memories.rate_checkpoint]

  agents = [
    agents.session_scout,
    agents.taxcloud_legacy_sql_implementer,
    agents.test_authoring_coordinator,
    agents.taxcloud_legacy_sql_reviewer
  ]

  # ---------------------------------------------------------------------------
  # Inputs — the typed handoff from rate_triage. This mission cannot read that
  # one's task outputs, so anything a stage here needs is declared: what is not
  # carried across does not exist.
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
    description = "Repo the fix lands in."
    default     = "https://github.com/FedTax/txc-sqlserver-database"
  }

  input "base_branch" {
    type        = "string"
    description = "Base branch the PR targets. Blank lets Devin use the repo default."
    default     = ""
  }

  input "entry_stage" {
    type        = "string"
    description = "develop | author_tests | audit | bruno_tests — which stage this run starts at. develop on a normal proven defect (or to adopt a PR whose session is gone); author_tests when a live fix PR only lacks coverage; audit or bruno_tests only when resuming a run that blocked there with its state intact."
  }

  input "mechanism" {
    type        = "string"
    description = "The proven mechanism from rate_triage: what is wrong and where expected and actual part ways — the object(s)/symbol(s), the input that reaches them, and both values. Briefing material for the fix and the cases; not to be re-derived here."
    default     = ""
  }

  input "disposition" {
    type        = "string"
    description = "The remediation disposition rate_triage established: data/configuration change | procedure/function change | both. develop implements this and nothing wider."
    default     = ""
  }

  input "affected_roots" {
    type        = "string"
    description = "Procedures/functions the defect implicates, and for a data defect the tables/rows. A briefing hint and a cross-check on coverage — NOT the coverage checklist, which the ratevariant plan comment derives from the callgraph at the head SHA."
    default     = ""
  }

  input "evidence" {
    type        = "string"
    description = "The investigation's evidence chain: each load-bearing claim with its basis (measured|traced) and citation. What the fix is implemented against, and what audit anchors its predictions in."
    default     = ""
  }

  input "production_evidence" {
    type        = "string"
    description = "The investigation's typed governed-production observations, including sufficient | insufficient | unavailable status and any ticket-visible gap outcome. Preserve this in every checkpoint; an empty list means production was not queried, not that production showed nothing."
    default     = "[]"
  }

  input "investigation_session_id" {
    type        = "string"
    description = "The session holding the investigation. Audit reaches back to it for an evidence question; blank when none survives."
    default     = ""
  }

  input "investigation_messageable" {
    type        = "bool"
    description = "Whether investigation_session_id can still be messaged. False means the verdict was carried forward from a terminated session, and the delegated_session rules for an unmessageable session apply — the evidence question goes to the cases session, which has the snapshot."
    default     = false
  }

  input "fix_pr_url" {
    type        = "string"
    description = "A fix PR already open for this ticket, when one is. Blank means develop opens it."
    default     = ""
  }

  input "fix_pr_number" {
    type        = "number"
    description = "That PR's number, when fix_pr_url is set. 0 otherwise."
    default     = 0
  }

  input "fix_branch" {
    type        = "string"
    description = "That PR's head branch — every later session pushes to it. Blank when develop opens the PR."
    default     = ""
  }

  input "fix_session_id" {
    type        = "string"
    description = "The session that owns an existing fix PR and receives audit's corrections. Blank when develop will create the owner."
    default     = ""
  }

  input "fix_session_messageable" {
    type        = "bool"
    description = "Whether fix_session_id can still be messaged. False (or unknown) is why entry_stage is develop rather than author_tests on an existing PR: audit routes fixes to the owning session and cannot create one, so the lane needs a living owner first."
    default     = false
  }

  input "cases_session_id" {
    type        = "string"
    description = "The case-authoring session, when a prior run already produced one. Required to resume at audit or bruno_tests; blank otherwise."
    default     = ""
  }

  input "cases_mode" {
    type        = "string"
    description = "proc | data | both, from a prior run's case authoring. Tells a resumed audit which result comment to read. Blank when author_tests runs in this mission."
    default     = ""
  }

  input "checkpoint" {
    type        = "string"
    description = "The validated rate_checkpoint/<TICKET>.yaml record. Blank on a first pass through this lane, in which case the entry stage owes no blocked_run entry steps."
    default     = ""
  }

  # ---------------------------------------------------------------------------
  # Task — enter_fix. The mission's only startable task, and the only reason it
  # exists is that a cross-mission route starts every dependency-free task: four
  # entry points cannot all be startable, so one stage reads entry_stage and
  # routes. It is cheap and not pointless — it confirms the lane's sessions are
  # actually in the state the handoff claims before a stage commits to them.
  # Read-only: creates no session, sends no message.
  # ---------------------------------------------------------------------------

  task "enter_fix" {
    objective = <<-EOT
      Before routing or side effects, if start event "${inputs.start_event_id}" is nonempty,
      have session_scout apply blocked_run with blocker "${inputs.blocker_id}" and generation
      ${inputs.blocker_generation}. Load the current checkpoint, reject stale or completed
      events, and durably claim this event before continuing interrupted work.

      Confirm the state needed to enter ${inputs.entry_stage} for ${inputs.issue}.

      # Inspect the handoff

      Have the session_scout agent check the supplied Devin ids: fix ${inputs.fix_session_id},
      cases ${inputs.cases_session_id}, and investigation ${inputs.investigation_session_id}.
      Compare reported ownership and resumability with the handoff. Do not create or message
      Devin sessions here.
      %{ if inputs.checkpoint != "" ~}
      This is a resumption. Use blocked_run's trigger-label entry step before routing; the work
      stage assesses new answers. Prior state:
      ${inputs.checkpoint}
      %{ endif ~}

      # Select the entry

      Use the requested entry unless a writing lane needs an owner: a dead fix owner changes
      an author_tests/audit/bruno_tests entry to develop; a dead cases owner changes an
      audit/bruno_tests entry to author_tests. When both are dead, develop comes first because
      cases must cover the adopted fix. These stages adopt existing artifacts rather than recreate
      them. A missing investigation session alone does not prevent audit from asking other
      available Devin sessions for evidence.
    EOT
    agents = [agents.session_scout]

    output {
      field "entry_stage" {
        type        = "string"
        description = "develop | author_tests | audit | bruno_tests — the stage this run actually enters at, which is the input unless a dead session forced a correction: a dead fix session moves the entry to develop, a dead cases session to author_tests."
        required    = true
      }
      field "lane_state" {
        type        = "string"
        description = "Each carried session id with the state check_session reports and whether it can be messaged, plus whether the entry was corrected and why."
        required    = true
      }
      field "handoff_discrepancies" {
        type        = "string"
        description = "Anything the handoff claimed that the read contradicts — a session reported live that is terminated, a PR that is closed, a branch that is gone. Blank when it all lined up."
        required    = false
      }
    }

    router {
      route {
        target    = tasks.develop
        condition = "entry_stage == develop — no fix exists yet and this run writes it, or one exists whose owning session is gone and develop adopts it."
      }
      route {
        target    = tasks.author_tests
        condition = "entry_stage == author_tests — the fix PR exists with a live owner and what is missing is A/B coverage of it, either because no cases were ever written or because the session that wrote them is gone and this stage adopts them."
      }
      route {
        target    = tasks.audit
        condition = "entry_stage == audit — fix and cases both exist AND both sessions can still be messaged, so the run re-enters at the judgment rather than rebuilding what it is judging."
      }
      route {
        target    = tasks.bruno_tests
        condition = "entry_stage == bruno_tests — the A/B is settled and only the API regression coverage was outstanding, usually on an expected value a human had to supply."
      }
    }
  }

  # ---------------------------------------------------------------------------
  # Task — develop. Implementation only. The mission is only entered on a proven
  # defect, so it never has to decide whether there IS a defect. Dynamic target
  # (no depends_on); routes into author_tests only when the lane reports completed.
  # ---------------------------------------------------------------------------

  task "develop" {
    objective = <<-EOT
      Obtain a reviewable fix for ${inputs.issue} in ${inputs.repo_url} from the supplied diagnosis.

      # Delegate to Devin

      Use delegated_session to resume the registered owner. When a new owner is needed, have the
      stage agent call plugins.devin.code_develop with !rate-fix in the task, `prompt_mode: "raw"`,
      and tags `["${inputs.issue}", "rate-fix"]`. Supply base branch ${inputs.base_branch}, existing
      PR ${inputs.fix_pr_url}, branch ${inputs.fix_branch}, mechanism ${inputs.mechanism},
      disposition ${inputs.disposition}, roots ${inputs.affected_roots}, evidence ${inputs.evidence},
      and relevant unanswered questions. An existing PR is an adoption task, not a rewrite.

      # Assess the result

      Collect Devin's result with check_session. Require a PR for completed work and investigate
      any reported contradiction with the diagnosis. Missing target authority may accompany a
      reviewable proposal; implementation alone does not settle the tax treatment.

      # Finish or pause

      Completed work proceeds to case authoring. For needs_human, use blocked_run and
      rate_checkpoint with next entry develop.
    EOT
    agents  = [agents.taxcloud_legacy_sql_implementer]

    output {
      field "outcome" {
        type        = "string"
        description = "completed | needs_human — the fix lane's typed completion state."
        required    = true
      }
      field "human_questions" {
        type        = "string"
        description = "The session's question-and-context pairs. Empty when outcome is completed."
        required    = true
      }
      field "pr_url" {
        type        = "string"
        description = "Full URL of the PR carrying the fix."
        required    = true
      }
      field "pr_number" {
        type        = "number"
        description = "PR number."
        required    = true
      }
      field "branch" {
        type        = "string"
        description = "Exact PR head branch. Every later session pushes to this branch."
        required    = true
      }
      field "applies" {
        type        = "boolean"
        description = "Whether the ratevariant label was applied to the PR (i.e. ratevariant will run)."
        required    = true
      }
      field "develop_session_id" {
        type        = "string"
        description = "Devin session id that owns the fix — the one it wrote, or the existing PR it adopted. author_tests forwards it as fix_session_id, and audit resumes it via send_message during the audit loop."
        required    = true
      }
      field "development_summary" {
        type        = "string"
        description = "What was changed, and where it diverges from the briefed diagnosis if it does."
        required    = true
      }
      field "diagnosis_contradicted" {
        type        = "string"
        description = "Set when the code contradicted the briefed diagnosis: what the session found instead. Blank normally."
        required    = false
      }
      field "target_authority" {
        type        = "string"
        description = "What establishes the value the change now produces — the state-published material or the SME's stated figure. Blank when nothing does, which makes the fix a proposal on a hedged target: author_tests passes it through and audit carries it as an open question, since a SATISFACTORY A/B does not authorize a treatment."
        required    = false
      }
    }

    router {
      route {
        target    = tasks.author_tests
        condition = "outcome == completed"
      }
      # `needs_human` has no route because develop records the blocker before returning.
    }
  }

  # ---------------------------------------------------------------------------
  # Task — author_tests. Reached only on the applies path, so it always has real
  # work (no self-skip). Authors the ratevariant cases/alteration, then hands off
  # to audit. Dynamic target (no depends_on); routes into audit only when the lane reports
  # completed.
  # ---------------------------------------------------------------------------

  task "author_tests" {
    objective = <<-EOT
      Obtain ratevariant coverage for ${inputs.issue} on the existing fix branch.

      # Delegate to Devin

      Use develop's PR and branch when it ran; otherwise use ${inputs.fix_pr_url} and
      ${inputs.fix_branch}. Resume the cases owner ${inputs.cases_session_id} or the checkpoint's
      owner through delegated_session. If a replacement is needed, have the stage agent call
      plugins.devin.code_develop on ${inputs.repo_url}, with !ratevariant-cases in the task,
      `prompt_mode: "raw"`, and tags `["${inputs.issue}", "rate-cases"]`. Ask it to adopt existing cases.

      Supply the PR, mechanism ${inputs.mechanism}, disposition ${inputs.disposition}, prior
      coverage, and outstanding questions. Devin selects situations and investigates fixtures
      using the playbook. Case YAML describes inputs, not expected outputs.

      # Assess the result

      Collect the result with check_session. Require offline validation and coverage or an
      evidenced gap for each affected root. Ask Devin to investigate missing support rather than
      inventing a fixture yourself. Case authoring does not establish target authority.

      # Finish or pause

      Completed coverage proceeds to audit, including justified limits for the auditor to assess.
      For needs_human, use blocked_run and rate_checkpoint with next entry author_tests.
    EOT
    agents  = [agents.test_authoring_coordinator]

    output {
      field "outcome" {
        type        = "string"
        description = "completed | needs_human — the case-authoring lane's typed completion state."
        required    = true
      }
      field "human_questions" {
        type        = "string"
        description = "The session's question-and-context pairs. Empty when outcome is completed."
        required    = true
      }
      field "mode" {
        type        = "string"
        description = "proc | data | both"
        required    = true
      }
      field "cases_session_id" {
        type        = "string"
        description = "Devin session id from the case-authoring run, resumed via send_message in the audit phase to augment cases/probes"
        required    = true
      }
      field "fix_session_id" {
        type        = "string"
        description = "The session that owns the fix and receives audit's corrections: develop's when develop ran, otherwise the live session carried in as the fix_session_id input."
        required    = true
      }
      field "coverage_gaps" {
        type        = "string"
        description = "Roots/paths not coverable on the reporting merchant, with reasons (including reasons Devin gives)"
        required    = false
      }
      field "target_authority" {
        type        = "string"
        description = "Copy target_authority unchanged from develop, or from the checkpoint on resumption. Blank only when neither establishes authority; case authoring does not supply it."
        required    = false
      }
    }

    router {
      route {
        target    = tasks.audit
        condition = "outcome == completed"
      }
      # `needs_human` has no route because author_tests records the blocker before returning.
    }
  }

  # ---------------------------------------------------------------------------
  # Task — audit. Pure A/B. Reached only from author_tests (send_to). Runs the
  # ratevariant A/B, interrogates the captures, and loops precise fixes into the
  # sessions that own them. The audit method lives in the ab_audit /
  # txc_rate_audit / evidence_gate / verdict_loop skills the agent composes —
  # this objective is only this case's parameters. Dynamic target (no
  # depends_on); routes to bruno_tests on SATISFACTORY.
  # ---------------------------------------------------------------------------

  task "audit" {
    objective = <<-EOT
      Judge the ratevariant evidence for ${inputs.issue} and coordinate evidenced corrections.

      # Work with Devin

      Use upstream results or the direct-entry context: PR ${inputs.fix_pr_url}, mode
      ${inputs.cases_mode}, investigation ${inputs.investigation_session_id}, fix
      ${inputs.fix_session_id}, and cases ${inputs.cases_session_id}. Have the stage agent check
      available sessions and use send_message/check_session for bounded evidence requests.
      Do not use code_qa. A missing investigation owner is not a reason to stop: ask an available
      Devin session with relevant context to investigate. Evidence gathering does not change its
      file ownership, and you retain acceptance of the result.

      Use txc_rate_audit to request predictions, captures, and technical analysis. Explicitly ask
      Devin to apply the run label when needed. Route code corrections to the fix owner and case
      corrections to the cases owner. If a migration changes, have the cases owner update its
      alteration too. Use session_lane when a request includes editing shared PR content.

      # Assess the evidence

      Apply evidence_gate, ab_audit, and txc_rate_audit. Obtain predictions before examining results.
      Only accept captures for the current PR head and required modes; reuse a complete applicable
      run on an unchanged head, and request fresh evidence after changes. A successful plan, a
      diff, an absent diff, or an author's assurance is not enough to pass.

      CASES_INADEQUATE calls for an evidenced coverage correction; FIX_OR_TICKET_WRONG calls for
      an implementation correction. Keep expected-output analysis outside case YAML. A
      SATISFACTORY result demonstrates implementation against the target, but any missing target
      authority remains open. FIX_IS_NO_OP requires positive evidence of correct prior behavior
      or a dead changed branch, not just failure to reproduce.

      # Finish or pause

      Use verdict_loop: stop at a supported result, two iterations without a named improvement,
      or 10 iterations. Never upgrade a verdict to exit. On FIX_IS_NO_OP, ask Devin to verify
      read-only, post the product-level finding using writing-ticket-updates, and add a PR note;
      do not close or revert the PR. Stop further case work.

      Terminal CASES_INADEQUATE or FIX_OR_TICKET_WRONG does not proceed. Use blocked_run and
      rate_checkpoint when a human answer is needed. A coverage limit for a reviewer does not
      require inventing a Jira question.
    EOT
    agents = [agents.taxcloud_legacy_sql_reviewer]

    output {
      field "verdict" {
        type        = "string"
        description = "SATISFACTORY | FIX_IS_NO_OP | CASES_INADEQUATE | FIX_OR_TICKET_WRONG at exit. These four are the whole vocabulary; the investigation's DEFECT_PROVEN / WORKING_AS_INTENDED belong to another stage and mean something else."
        required    = true
      }
      field "iterations" {
        type        = "number"
        description = "Run + audit iterations completed"
        required    = true
      }
      field "working_as_designed" {
        type        = "boolean"
        description = "True only when the accepted verdict is FIX_IS_NO_OP. This describes the finding; it does not authorize reverting code."
        required    = true
      }
      field "confirmed_findings" {
        type        = "string"
        description = "Accepted findings with supporting case captures, PR head, and plan/run references. Include bugs, reachability, value discrepancies, blast radius, teardown, and path inconsistencies where applicable."
        required    = true
      }
      field "open_questions" {
        type        = "string"
        description = "Tax-law/eligibility questions for the ticket SMEs and coverage gaps left open. A blank target_authority from the fix lane is one of these however clean the A/B came back — name the authority that would settle the treatment."
        required    = false
      }
      field "final_summary" {
        type        = "string"
        description = "At most 150 words: accepted result, what changed during audit, and any stall or unresolved gap. Include a no-op Jira comment reference when posted; end with the fix PR URL."
        required    = true
      }
    }

    router {
      route {
        target    = tasks.bruno_tests
        condition = "verdict == SATISFACTORY — the fix is settled and correct, so author the Bruno regression suite."
      }
      route {
        target    = missions.rate_finalize
        condition = "verdict == FIX_IS_NO_OP — no fix to lock in, but a no-op fix on a proven defect is exactly the kind of trap worth recording. Skip Bruno. Pass entry_stage = record_learnings, close_reason = 'audit FIX_IS_NO_OP', the audit verdict, confirmed findings, production_evidence, and every session id still open — rate_finalize asks each of them for its own learnings and cannot find them itself."
      }
      # CASES_INADEQUATE / FIX_OR_TICKET_WRONG normally loop in-session and never reach a
      # route; on the rare terminal CASES_INADEQUATE the chain exits here with the uncoverable
      # paths named, for a human to decide. Do NOT route it onward.
    }

  }

  # ---------------------------------------------------------------------------
  # Task — bruno_tests. Reached only on audit's SATISFACTORY verdict, so the
  # red/green API tests are written against a settled, correct fix — never one
  # still looping. Dynamic target (no depends_on); hands the closed case to
  # rate_finalize.
  # ---------------------------------------------------------------------------

  task "bruno_tests" {
    objective = <<-EOT
      Obtain API regression coverage for ${inputs.issue} after a SATISFACTORY audit.

      # Delegate to Devin

      Use the fix PR from develop or ${inputs.fix_pr_url}, branch ${inputs.fix_branch}.
      Resume the checkpoint's Bruno owner through delegated_session. When a new owner is needed,
      have the stage agent call plugins.devin.code_develop with repo_url
      https://github.com/FedTax/txc-bruno, !bruno-regression in the task, `prompt_mode: "raw"`,
      and tags `["${inputs.issue}", "bruno"]`. Ensure Devin can read the SQL repository skills too.

      Supply the ticket, PR, accepted audit findings, target authority, and open questions.
      Devin selects portable API scenarios and authors tests without making live API calls.

      # Assess the result

      Collect Devin's result with check_session. Require cited authority for assertions and an
      explicit reason for unwritten scenarios. Changed scenarios may fail before deployment;
      guardrails can already pass. Do not assume every snapshot case is portable to the API.

      # Finish or pause

      Completed work proceeds to finalization. For needs_human, use blocked_run and
      rate_checkpoint with next entry bruno_tests.
    EOT
    agents  = [agents.test_authoring_coordinator]

    output {
      field "outcome" {
        type        = "string"
        description = "completed | needs_human — the Bruno lane's typed completion state."
        required    = true
      }
      field "human_questions" {
        type        = "string"
        description = "The session's question-and-context pairs. Empty when outcome is completed."
        required    = true
      }
      field "bruno_session_id" {
        type        = "string"
        description = "Devin session id from the Bruno authoring run"
        required    = true
      }
      field "bruno_pr_url" {
        type        = "string"
        description = "URL of the txc-bruno PR with the authored regression tests"
        required    = true
      }
      field "scenarios" {
        type        = "string"
        description = "The scenarios the Bruno suite locks in (should-change + guardrails), each with the authority its expected value traces to"
        required    = true
      }
      field "unwritten_scenarios" {
        type        = "string"
        description = "Scenarios not authored, with what each would need: no authoritative expected value, a merchant other than the fixed 20, or a v1-only surface the suite cannot reach"
        required    = false
      }
    }

    router {
      route {
        target    = missions.rate_finalize
        condition = "outcome == completed. Enter record_learnings; carry the fix and Bruno PRs, audit findings, unresolved questions, production_evidence, and registered session ids from this task, its ancestors, or the checkpoint."
      }
      # `needs_human` has no route because bruno_tests records the blocker before returning.
    }
  }
}
