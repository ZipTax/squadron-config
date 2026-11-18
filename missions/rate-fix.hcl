mission "rate_fix" {
  max_parallel = 10

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
  # that and persists the diagnosis in shared case memory.
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
  # Task commanders assign work to the configured Squadron agent, assess its evidence,
  # and select routes. The agent coordinates Devin sessions using the named playbooks.
  # Repo mechanics live in txc-sqlserver-database's ratevariant-testing skill
  # (references/process.md), which the playbooks load.
  # Repository edits and database queries are Devin's; Squadron agents handle case coordination.
  #
  # Blocking on a human: the blocked_run skill, both ends. A stage that hits a
  # dependency first screens it and selects native ask-human for operator
  # decisions or a Jira bridge wait for ticket evidence. A Jira wait records this
  # lane's next stage so rate_triage can resume without repeating finished work.
  memories = [memories.rate_checkpoint]

  # Cross-mission routes select the entry and supply accepted context; rate_case also retains
  # that context for continuation and recovery.

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
    description = "Base branch the PR targets."
    default     = "main"
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

  input "findings" {
    type        = "string"
    description = "Devin’s per-issue findings array as JSON. Recover from the accepted investigation report on resume."
    default     = ""
  }

  input "target_authority" {
    type        = "string"
    description = "Legacy resume input only. Preserve it with the prior report for Devin to convert into scoped findings; it is not a replacement for findings."
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

  input "existing_pr" {
    type        = "string"
    description = "Existing fix PR URL carried from triage's existing_pr output or the checkpoint's artifacts.fix_pr.url. A known PR is adopted even if its branch or owner is not yet known. Blank means no existing PR was supplied."
    default     = ""
  }

  input "fix_pr_number" {
    type        = "number"
    description = "That PR's number, when existing_pr is set. 0 when unknown."
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

      Confirm the state needed to enter ${inputs.entry_stage} for ${inputs.issue}.
      Repository: ${inputs.repo_url}; base branch: ${inputs.base_branch}.

      Read the diagnosis, complete findings, and cited evidence from the maintained case.

      # 3. Inspect the handoff

      Check the investigation, fix, and cases owners recorded in lanes.
      Compare reported ownership and resumability with the handoff. Do not create or message
      Devin sessions here.
      %{ if inputs.checkpoint != "" ~}
      This is a resumption. Use blocked_run's trigger-label entry step before routing; the work
      stage assesses new answers. Prior state:
      ${inputs.checkpoint}
      %{ endif ~}

      # 4. Select the entry

      Select the entry in this order:
      1. If the requested entry is author_tests, audit, or bruno_tests and the fix owner is
         absent or confirmed unable to continue, select develop to adopt the existing fix.
      2. Otherwise, if the requested entry is audit or bruno_tests and the cases owner is
         absent or confirmed unable to continue, select author_tests to adopt the existing cases.
      3. Otherwise retain the requested entry. A missing investigation session alone does
         not prevent audit from asking another available Devin session for evidence.
      A failed status read does not establish that an owner cannot continue; recover its
      state through delegated_session before selecting replacement work.
      When both writing owners need replacement, recover the fix first so cases cover the
      adopted implementation. Flag missing findings for report recovery through delegated_session
      in the selected stage before it acts; preserve legacy authority. Save the entry before routing.
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
      # 1. Restore the case and publish the stage status

      Apply rate_case for ${inputs.issue} at `develop`.
      Use case_slack to publish root status ":hammer: Fixing".

      Obtain a reviewable fix for ${inputs.issue} in ${inputs.repo_url} from the supplied diagnosis.

      # 2. Brief the existing owner or create a replacement

      Use delegated_session to resume the registered owner. When a new owner is needed, call
      plugins.devin.code_develop with !rate-fix in the task, `prompt_mode: "raw"`,
      and tags `["${inputs.issue}", "rate-fix"]`. Supply the case diagnosis, complete findings,
      cited evidence, and relevant unresolved gaps. Recover missing or empty findings
      through delegated_session before implementing a scoped change.

      Base branch: ${inputs.base_branch}
      Existing PR: `artifacts.fix_pr.url` from the case
      Fix branch: `artifacts.fix_pr.branch` from the case

      An existing PR is an adoption task, not a rewrite.
      If its branch is unknown, have Devin resolve it from that PR before making changes.

      # 3. Assess the result and resolve gaps

      1. Collect the result with check_session and require a PR before accepting completion.
      2. Check reported contradictions or missing support against the diagnosis. Return
         gaps and missed applicable paths to the fix owner for correction, then reassess
         in this task. A path already required by the diagnosis is not an operator decision.
      3. Assess the fix owner's impact_radius and test recommendation from the actual diff
         and maintained PR Impact radius section. Accept supported coverage or return the
         specific gap to the owner before proceeding.

      # 4. Complete the stage or retain its pending work

      When the fix PR is ready, add its labeled link to the root's PR list using case_slack.
      If findings need revision, have the investigation session assess them before changing
      the accepted Cause.

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
      field "impact_radius" {
        type        = "string"
        description = "Accepted fix-owner impact_radius assessment and test recommendation as JSON. Recover from the maintained PR Impact radius section when resuming an older report."
        required    = false
      }
      field "diagnosis_contradicted" {
        type        = "string"
        description = "Set when the code contradicted the briefed diagnosis: what the session found instead. Blank normally."
        required    = false
      }
      field "findings" {
        type        = "string"
        description = "Devin’s per-issue findings array, serialized as JSON and preserved unchanged from the accepted report; recover from that report on resume."
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
      # 1. Restore the case and publish the stage status

      Apply rate_case for ${inputs.issue} at `author_tests`.
      Use case_slack to publish root status ":test_tube: Testing".

      Obtain ratevariant coverage for ${inputs.issue} on the existing fix branch.

      # 2. Brief the existing owner or create a replacement

      Read the fix PR/branch from artifacts and resume the cases owner in lanes through
      delegated_session. If a replacement is needed, call
      plugins.devin.code_develop on ${inputs.repo_url}, with !ratevariant-cases in the task,
      `prompt_mode: "raw"`, and tags `["${inputs.issue}", "rate-cases"]`. Ask it to adopt existing cases.

      Supply the PR, prior coverage, outstanding questions, diagnosis, and latest accepted
      per-issue findings. Recover missing report context through delegated_session.

      Devin selects situations and investigates fixtures using the playbook. Case YAML describes
      inputs, not expected outputs.

      # 3. Assess the result and resolve gaps

      Collect the result with check_session. For each affected root, require offline validation
      and either coverage or an evidenced gap. If support is missing, ask the cases owner to
      investigate and reassess its response in this task. Preserve the accepted per-issue
      requirements; do not invent a fixture to fill missing evidence.

      # 4. Complete the stage or retain its pending work

      Keep the root's PR links current using case_slack.

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
      field "findings" {
        type        = "string"
        description = "Copy findings unchanged from develop, or recover the accepted report on resumption. Case authoring does not revise investigation findings."
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
      # 1. Restore the case and publish the stage status

      Apply rate_case for ${inputs.issue} at `audit`.
      Use case_slack to publish root status ":microscope: Auditing".

      Judge the ratevariant evidence for ${inputs.issue} and coordinate evidenced corrections.

      # 2. Obtain predictions and run evidence

      Read the fix PR, cases mode, lane owners, and accepted per-issue findings from the case.
      Recover missing findings through delegated_session. Check available sessions
      and use send_message/check_session for bounded evidence requests.
      Do not use code_qa. A missing investigation owner is not a reason to stop: ask an available
      Devin session with relevant context to investigate. Evidence gathering does not change its
      file ownership, and you retain acceptance of the result.

      Use txc_rate_audit to assess the fix owner’s maintained Impact radius section and
      impact_radius report, accepting or rejecting its test recommendation. Recover an older
      report’s missing assessment from the fix owner. Request predictions, captures, and
      technical analysis for the accepted coverage. Delegate the workflow trigger using the
      repository’s ratevariant-testing dispatch instructions.
      Route code corrections to the fix owner and case corrections to the cases owner.
      When a correction changes the assessed impact, have the fix owner update its assessment
      and recommendation. If a migration changes, have the cases owner update its alteration
      too. Use session_lane when a request includes editing shared PR content.

      # 3. Select the verdict and perform its required action

      Apply evidence_gate, ab_audit, and txc_rate_audit to captures for each required mode,
      using run details from the automatic GitHub result comment. Obtain predictions before
      examining results. A plan, diff, absent diff, or author assurance is not sufficient evidence.

      - CASES_INADEQUATE: request an evidenced coverage correction from the cases owner.
      - FIX_OR_TICKET_WRONG: request an implementation correction from the fix owner.
      - SATISFACTORY: accept only with support for the findings' treatment and dates as well
        as the A/B outcome. Return missing support to the appropriate owner before accepting.
      - FIX_IS_NO_OP: require positive proof of correct prior behavior or a dead changed
        branch. Ask Devin to verify read-only, post the product-level finding using
        writing-ticket-updates, and add a PR note. Stop case work; do not close or revert the PR.

      For corrections, use verdict_loop and repeat steps 2-3 in this task while making progress.
      Keep expected-output analysis outside case YAML.

      # 4. Complete the stage or retain its pending work

      Use case_slack for root status updates and any blocker requiring attention.

      Route SATISFACTORY to Bruno authoring or FIX_IS_NO_OP to finalization as declared below.
      If corrections stall or need a human answer, use blocked_run and rate_checkpoint,
      retaining the supported verdict and pending work. Terminal CASES_INADEQUATE or
      FIX_OR_TICKET_WRONG does not proceed. A coverage limit alone does not require a Jira question.
    EOT
    agents = [agents.taxcloud_legacy_sql_reviewer]

    output {
      field "findings" {
        type        = "string"
        description = "Latest accepted per-issue findings as JSON, preserved from Devin's report for downstream work."
        required    = false
      }

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
        description = "Accepted findings with supporting case captures, PR head, and plan/run references. Include bugs, reachability, value discrepancies, blast radius, and path inconsistencies where applicable."
        required    = true
      }
      field "open_questions" {
        type        = "string"
        description = "Unresolved questions and coverage gaps associated with the affected finding, including the evidence checked and what remains needed."
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
        condition = <<-EOT
          verdict == FIX_IS_NO_OP — skip Bruno and enter record_learnings.
          Set close_reason = 'audit FIX_IS_NO_OP' and use this audit's verdict. Map
          confirmed_findings to audit_findings; include its citations alongside the investigation
          evidence, with each conclusion attributed. Carry complete findings unchanged.
          Preserve the latest artifacts, Devin session owners, and open questions from completed
          work or resumed state through rate_case and populate the destination inputs.
          Map existing_pr to fix_pr_url when develop did not run.
        EOT
      }
      # CASES_INADEQUATE / FIX_OR_TICKET_WRONG normally loop in-session and never reach a
      # route; on the rare terminal CASES_INADEQUATE the chain exits here with the uncoverable
      # paths named, for a human to decide. Do NOT route it onward.
    }

  }

  # ---------------------------------------------------------------------------
  # Task — bruno_tests. Reached only on audit's SATISFACTORY verdict, so the
  # red/green API tests are written against a settled, correct fix — never one
  # still looping. Dynamic target (no depends_on); hands the accepted work to
  # rate_finalize.
  # ---------------------------------------------------------------------------

  task "bruno_tests" {
    objective = <<-EOT
      # 1. Restore the case and publish the stage status

      Apply rate_case for ${inputs.issue} at `bruno_tests`.
      Use case_slack to publish root status ":writing_hand: Authoring Bruno tests".

      Obtain API regression coverage for ${inputs.issue} after a SATISFACTORY audit.

      # 2. Brief the existing owner or create a replacement

      Read the fix PR and branch from artifacts.fix_pr.
      Resume the checkpoint's Bruno owner through delegated_session. When a new owner is needed,
      call plugins.devin.code_develop with repo_url
      https://github.com/FedTax/txc-bruno, !bruno-regression in the task, `prompt_mode: "raw"`,
      and tags `["${inputs.issue}", "bruno"]`. Ensure Devin can read the SQL repository skills too.

      Supply the ticket, PR, accepted audit results, latest per-issue investigation findings,
      and open questions. Recover missing report context through delegated_session.
      Devin authors and reviews the regressions following !bruno-regression; CI runs them in staging.

      # 3. Assess the result and resolve gaps

      1. Collect the result with check_session. Require cited authority for assertions and
         an explicit reason for each unwritten scenario.
      2. Assess CI against staging deployment state: should-change tests fail before the fix
         is deployed to staging and pass afterward; guardrails pass in both states.
         Send unexpected results to the appropriate owners for correction and reassess
         in this task while progress is being made.
      3. Save the assessed attempt-specific CI link as the baseline before staging deployment;
         a run-level link changes its displayed result when CI is rerun.

      # 4. Complete the stage or retain its pending work

      Add the Bruno PR's labeled link to the root using case_slack.

      - Authored tests and assessed CI match the staging state: complete this stage and route
        to finalization. Expected failures before staging deployment demonstrate the regression;
        the final review task waits for staging deployment and verifies the deployed fix.
      - Corrections stall or need information: ask the operator with the remaining failures
        and evidence. Use blocked_run and rate_checkpoint for needs_human, retaining
        bruno_tests as the next entry for failed or blocked work.
    EOT
    agents  = [agents.test_authoring_coordinator]

    output {
      field "findings" {
        type        = "string"
        description = "Latest accepted per-issue findings as JSON, preserved from Devin's report for downstream work."
        required    = false
      }

      field "outcome" {
        type        = "string"
        description = "completed | failed | needs_human - completed means authored tests and reviewed CI results match deployment state; expected pre-deployment failures are successful completion."
        required    = true
      }
      field "human_questions" {
        type        = "string"
        description = "The session's question-and-context pairs. Empty when outcome is completed."
        required    = true
      }
      field "bruno_session_id" {
        type        = "string"
        description = "Devin session id that authored the regressions and reviewed CI results"
        required    = true
      }
      field "bruno_pr_url" {
        type        = "string"
        description = "URL of the txc-bruno PR with the authored regression tests"
        required    = true
      }
      field "validation" {
        type        = "string"
        description = "Bruno CI results as JSON: staging deployment state, should-change results, guardrail results, and evidence reference."
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
        condition = <<-EOT
          outcome == completed — enter record_learnings with close_reason = 'fix audited
          SATISFACTORY and Bruno CI results match deployment state' and verdict = SATISFACTORY.
          Use the latest accepted outputs or resumed state. Map audit.confirmed_findings to
          audit_findings and retain its citations alongside the investigation evidence.
          Carry complete findings unchanged. Combine audit.open_questions and this task's
          unwritten_scenarios into open_questions, preserving which are deliberate coverage
          limits rather than human blockers. Save the current PRs, CI results, and Devin
          session owners through rate_case and populate the destination inputs; map
          existing_pr to fix_pr_url when develop did not run.
        EOT
      }
      # Failed or blocked work retains bruno_tests as its next entry; expected pre-deployment failures allow completion.
    }
  }
}
