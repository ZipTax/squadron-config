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
  #   develop     --send_to--> author_tests
  #   author_tests --send_to--> audit
  #   audit       --router--> bruno_tests            (SATISFACTORY: lock the settled fix in)
  #                      \--> missions.rate_finalize (WORKING_AS_DESIGNED: the fix was a no-op)
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
  # wall ends the run, writes rate_resume_state/<TICKET>.md naming this lane's
  # stage, and puts the questions on the ticket; the Jira automation fires
  # /ratevariant when the answer lands, and rate_triage's discovery routes the
  # case back here at that stage.
  memories = [memories.rate_resume_state]

  agents = [
    agents.session_scout,
    agents.rate_fix_engineer,
    agents.ratevariant_case_author,
    agents.ratevariant_auditor,
    agents.bruno_author
  ]

  # ---------------------------------------------------------------------------
  # Inputs — the typed handoff from rate_triage. This mission cannot read that
  # one's task outputs, so anything a stage here needs is declared: what is not
  # carried across does not exist.
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

  input "resume_state" {
    type        = "string"
    description = "What rate_resume_state/<TICKET>.md said this case was waiting on, which stages finished, and the run marker a resumption needs to tell new ticket replies from ones already read. Blank on a first pass through this lane, in which case the entry stage owes no blocked_run entry steps."
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
      This run of the rate-fix lane for ${inputs.issue} starts at `${inputs.entry_stage}`. Confirm
      the state it is starting from is real, then route it. You read only: no session is created,
      messaged, or briefed here.

      # You do

      check_session on every session id the handoff carried — fix_session_id
      ("${inputs.fix_session_id}"), cases_session_id ("${inputs.cases_session_id}"),
      investigation_session_id ("${inputs.investigation_session_id}") — and compare what you find
      to what was claimed. rate_triage read them at assessment time; a session can terminate
      between missions, and a stage that finds out later finds out at the point it needs to send.

      Route on `${inputs.entry_stage}`, with two corrections you are allowed and expected to make.
      Both exist for the same reason: audit routes its findings to the session that owns the lane
      they belong to and never opens one itself, so a lane whose session died strands every finding
      that lands in it — and it strands them at the moment audit has a judgment, which is the worst
      time to discover it.

      - The fix lane. If the entry is author_tests, audit or bruno_tests but fix_session_id can no
        longer be messaged, route to develop instead, which adopts the PR and becomes its owner.
      - The cases lane. If the entry is audit or bruno_tests but cases_session_id can no longer be
        messaged, route to author_tests instead, which adopts the cases already on the branch. Do
        not route a dead cases lane to audit on the argument that the cases exist: CASES_INADEQUATE
        is the most common finding there is, and it has nowhere to go.

      Where both lanes are dead, develop wins — it is the earlier stage, and author_tests reads the
      fix PR's diff, so a lane the fix session must first re-own cannot be covered before it is.
      Say in lane_state which correction you made and why.

      %{ if inputs.resume_state != "" ~}
      This run is a resumption. Prior state:

      ${inputs.resume_state}

      The stage you route to owes the blocked_run entry steps — clearing the `TaxRates:Needs-Info`
      label and judging whatever came back on the ticket — since its session is the first one this
      run briefs and you hold no credentials to do either.
      %{ endif ~}

      Return the entry you settled on, the state of each session, and one line on anything the
      handoff got wrong — a discrepancy is a learning about the routing rule, and rate_finalize can
      only record it if it is on the record.
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
  # (no depends_on); pushes into author_tests via send_to.
  # ---------------------------------------------------------------------------

  task "develop" {
    objective = <<-EOT
      A defect has been proven for ${inputs.issue} in ${inputs.repo_url}. Implement the fix —
      step 1 of the ratevariant process (ratevariant-testing skill, references/process.md).

      # Two ways you get here

      Usually no fix exists and this stage writes it. But when fix_pr_url is set
      ("${inputs.fix_pr_url}") and its owning session cannot be messaged, the fix exists and its
      session is gone, and this stage exists to give that PR a living owner — audit routes corrections to the
      fix session and cannot create one, so an unowned PR strands every finding it reaches.

      In that adopt case the session's job is to take over, not to redo: have it read the PR diff
      and the branch, confirm the change matches the briefed mechanism, and say what it found —
      then stop and hold the lane. It must not re-implement, revert, or widen what is there, and it
      must not open a second PR. If the existing change contradicts the diagnosis, that goes in
      diagnosis_contradicted; correcting it is audit's call, routed back here, not a silent rewrite
      before anyone has run the A/B.

      # You do

      Start a code_develop session on ${inputs.repo_url} running the !rate-fix playbook.

      - title: "${inputs.issue} — fix <short description of what is being corrected>" — the actual
        subject, which is often jurisdictions, dates, or a sourcing quirk rather than a rate.
      - tags: `${inputs.issue}`, `rate-fix`
      - prompt_mode: `raw` — the playbook owns the branch/commit/PR sequence, and the default
        prompt would also tell the session to add tests, which is step 2's lane.

      # Brief the session

      Give it the investigation's result, which rate_triage established and passed in — so it
      implements against a settled diagnosis instead of re-deriving one:

      - mechanism: ${inputs.mechanism}
      - disposition: ${inputs.disposition}
      - affected roots: ${inputs.affected_roots}
      - evidence: ${inputs.evidence}

      Then, in the task text:

      - You own step 1 only: the procedure/function change under output/schema and/or the data
        migration under scripts/. Do NOT add anything under tests/ — case authoring is step 2
        and needs extensive fixture discovery that has no bearing on this fix.
      - Implement the briefed disposition, including both halves when it is both a data and a
        proc change. Nothing wider.
      - Edit every copy of a changed object (prod and staging, both databases where the logic
        is duplicated); `ratevariant plan` only watches the -prod copies.
      - Open the PR, add the `ratevariant` label so plan runs, and confirm it landed:
          gh pr edit <pr> --add-label ratevariant
          gh pr view <pr> --json number,url,headRefName,labels
        Adopting an existing PR: check out its head branch, do not open a PR, and check the label
        rather than assuming — a prior run may or may not have applied it, and plan never ran if it
        did not.

      # Hold the session to

      If the reported fix does not line up with what the ticket asks for and the session gives
      no sound reason for the difference, push back: ask it to confirm the change actually
      addresses the ticket's ask, and cite the mismatch you see. Take its reasoning if it has
      one — it is reading the code and you are not — and record the disagreement in
      diagnosis_contradicted either way.

      Fail the stage if no PR exists at the end. Do not report success without one.

      Return the PR URL, number, head branch, develop_session_id, and a one-line summary of
      what changed — or, when adopting, what the existing change does and that the lane is now
      owned.
    EOT
    agents  = [agents.rate_fix_engineer]

    output {
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
    }

    send_to = [tasks.author_tests]
  }

  # ---------------------------------------------------------------------------
  # Task — author_tests. Reached only on the applies path, so it always has real
  # work (no self-skip). Authors the ratevariant cases/alteration, then hands off
  # to audit. Dynamic target (no depends_on); pushes into audit via send_to.
  # ---------------------------------------------------------------------------

  task "author_tests" {
    objective = <<-EOT
      Author the ratevariant cases on the EXISTING branch of the fix PR — step 2 of the
      ratevariant process (ratevariant-testing skill, references/process.md). The PR is
      develop's, or the one carried in as fix_pr_url ("${inputs.fix_pr_url}", branch
      "${inputs.fix_branch}") when a prior run had already opened it and its session is still live;
      in that case read the PR diff for the change under test, since no develop stage in this run
      described it.

      Pass the fix lane's session id through to audit either way — develop_session_id when develop
      ran, otherwise the fix_session_id input ("${inputs.fix_session_id}"). Audit routes corrections
      to whichever it is and cannot open a session of its own, so a lane id that stops here strands
      them.

      %{ if inputs.cases_session_id != "" ~}
      This run may be adopting cases rather than writing them: cases_session_id
      ("${inputs.cases_session_id}") already authored cases on this branch, and enter_fix routed
      here because that session can no longer be messaged. Then the session you start owns the
      cases lane from now on — have it read what is already committed under
      tests/ratevariant-cases/** and the `<!-- ratevariant-plan -->` comment before adding
      anything, and complete the coverage rather than re-authoring it. Existing cases the prior
      session justified are not yours to delete on taste; a case you believe is wrong is a finding
      to return, the same as any other.
      %{ endif ~}

      # You do

      Start a code_develop session running the !ratevariant-cases playbook.

      - title: "${inputs.issue} / PR #<n> — cases for <short description>"
      - tags: `${inputs.issue}`, `rate-cases`
      - prompt_mode: `raw` — the default prompt would cut a second branch and open a second PR.

      Capture cases_session_id for the audit phase.

      # Brief the session

      The playbook owns which cases to write, and reading the `<!-- ratevariant-plan -->`
      comment at the current head SHA is its own first step. Give it what only this run knows:

      - the mechanism (${inputs.mechanism}) and disposition (${inputs.disposition}) rate_triage
        established, so it knows what the change was meant to do;
      - choose paths, boundaries, and inputs from the function code, the ticket, and staging
        data — never from the PR's prose, which is sometimes wrong about its own change;
      - step 2 ends at pushing to the existing branch: do NOT add `ratevariant:run`, run the
        harness, or read results — steps 3 and 4 are the auditor's, so the session that wrote
        the fixtures is never the one grading them;
      - lane is tests/ratevariant-cases/** only; a PR comment asking for a proc or migration
        change is out of lane, so report it instead of acting on it.

      # Hold the session to

      Two things you actually route on — the rest (what it pushed, per-root coverage, its own
      session link on the PR) is visible in git and on the PR, so trust it and don't ask for it
      back:

      - Empty roots under "### Proc changes" while the PR changed dbo procs/functions means
        callgraph generation failed (permissions or another DB/infra failure). That is a stage
        failure to report, not something to author around. Empty roots on a data-only PR is
        expected and fine.
      - A root left uncovered needs a stated reason, and the reason has to survive the obvious
        objection: fixtures can supply a connection, a merchant/location config, an eligibility
        row, so "the snapshot lacks the data" is only valid where the missing data is something
        a fixture cannot stand in for. Genuinely unconstructable cases happen, rarely; that is
        a coverage finding to return, and a silent omission is a stage failure.
    EOT
    agents  = [agents.ratevariant_case_author]

    output {
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
    }

    send_to = [tasks.audit]
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
      Own the A/B verdict for the PR (branch, number, mode from prior outputs) — steps 3 and 4
      of the ratevariant process, which are one owner's on purpose so the session that wrote
      the fixtures is never the one grading them. Skip if nothing was pushed since the last run.

      # You do

      Three sessions are open and each owns a lane: investigation_session_id (the evidence),
      fix_session_id (the fix — develop's session, or the live one that already owned the PR),
      cases_session_id (the cases). On a run that entered at this stage rather than reaching it
      through author_tests, they are the mission's inputs — investigation "${inputs.investigation_session_id}",
      fix "${inputs.fix_session_id}", cases "${inputs.cases_session_id}", mode "${inputs.cases_mode}",
      PR "${inputs.fix_pr_url}" — and enter_fix's read of them is the current picture. Do ALL Devin work through
      them via send_message and check_session — the run, your staging queries, and every routed
      fix. When session_messageable is false on the first, the delegated_session rules for an
      unmessageable session apply: don't send, and take an evidence question you would have asked
      it to the cases session, which has the snapshot. Never open a
      new session and never run a code_qa review: your judgment stays
      independent, but the work runs in the session that owns it.

      Anchor your predictions in the investigation's mechanism and required outcome plus your
      own map of the actual PR diff — have a session read out the changed proc/fn bodies. Not
      the PR description, which is sometimes wrong about its own change.

      When you need data — a decomposed rate, a merchant's configuration, whether a row exists
      — you have no database access; ask cases_session_id, which did the fixture discovery and
      has the deepest picture of the snapshot. State the question and the values you need back,
      not the query.

      Loop until SATISFACTORY or WORKING_AS_DESIGNED, up to 10 iterations. The cap is a runaway
      guard, not a budget to spend: what actually ends the loop is progress. Keep going while each
      pass closes a specific named gap — a case gained coverage, a wrong value became right, a
      no-diff got diagnosed.

      Two things end it before the cap, and neither is a failure to keep trying. A terminal
      judgment: the evidence settles the question against a further pass — the case genuinely
      cannot be constructed, the fix is wrong in a way another run will only re-demonstrate, the
      ticket asked for behavior that is already correct. And a stall: two consecutive passes change
      nothing you can name, which is a stuck loop, and a fifth identical re-run will not unstick
      it; say what it is stuck on. Either way you exit on the verdict the evidence supports.

      The iteration count is yours for the cap and the summary — the sessions have no use for it,
      so don't relay it:

      1. RUN — step 3, per the ratevariant-testing skill: have a session fire it and return the
         result comment for the current head SHA (PROC → `<!-- ratevariant-result -->`, DATA →
         `<!-- ratevariant-alter-result -->`). Plan passing proves NOTHING about behavior; only
         the per-case captures validate.

      2. AUDIT — step 4, per the ab_audit and txc_rate_audit skills. Classify every case as
         primary positive or guardrail before you look, prove each value is RIGHT rather than
         merely present, and diagnose every unexpected no-diff (shadowed / unreachable /
         not-exercised / masked) with data before concluding anything.

      # Outcomes

      The repo's CLAUDE.md tells a session the PR description is shared state and must be
      read-then-appended; restate it in any message where the session will touch the description
      anyway, per session_lane. This is where descriptions get clobbered, and the earlier stages'
      findings are what disappears.

      Exit on exactly one verdict:
      - SATISFACTORY — intended diffs present, each to the correct value, guardrails flat, all
        paths the change spans in agreement, and every path it actually reaches covered by a
        case that ran. A path counts as not needing coverage only when you have PROVEN the
        change cannot reach it.
      - CASES_INADEQUATE — missing branch/path coverage, an ineffective probe, a guardrail
        gap, or a reachable path left uncovered on a hedge → send_message(cases_session_id)
        with the specific case(s)/probe(s) to add or fix, including the inputs and the values
        they must assert. Loop. Rarely this is terminal instead: where the case genuinely cannot
        be constructed — not "the snapshot lacks it" where a fixture would do — exit on this
        verdict with the uncoverable paths and what a case would need, so a human decides
        whether the fix ships uncovered.
      - FIX_OR_TICKET_WRONG — dead/shadowed branch, wrong resulting value, cart-vs-reports or
        import inconsistency, over-broad blast radius, or an ineffective fix → have Devin post
        a PR comment citing the file plus the case result that proves it, then
        send_message(fix_session_id) with ONLY that fix and its supporting data. If the
        fix changes a scripts/*.sql migration, the mirroring alteration is now stale — also
        send_message(cases_session_id) to re-sync it. Loop.
      - WORKING_AS_DESIGNED — the A/B, grounded in data, shows the fix changes nothing: the
        pre-change behavior was already correct, or the changed branch is provably dead. This
        requires POSITIVE data (the decomposed correct value, or the precluding condition),
        never an absent diff or an inability to construct one. The fix session made the change
        and is best placed to confirm it: send_message(fix_session_id) with the
        data-grounded finding and have it verify in-situ, then post ONE product-level Jira
        comment routing to the SMEs, plus a brief PR note so the reviewer knows it is a no-op.
        It must NOT push code, close the PR, or remove labels. Return the comment URL. Tell
        the cases session to stand down. Don't loop; exit.

      However you exit — terminal judgment, stall, or the cap — exit on the verdict the evidence
      supports; never upgrade to SATISFACTORY to close out the run. Summarize what changed and why,
      and on a stall what the loop could not move.

      A terminal CASES_INADEQUATE, a stall, or the cap ends the chain here — rate_finalize does not
      run after it, so nothing else will close the case out — so close it out yourself per blocked_run (slot `rate_resume_state`, path
      `${inputs.issue}.md`, blocked at audit, the fix session posting). What this stage owes the
      file: the uncoverable paths and why, the fix PR, and what a human has to decide. Skip the
      ticket comment only when the open item is a coverage limit for a reviewer rather than a
      question for a person.
    EOT
    agents = [agents.ratevariant_auditor]

    output {
      field "verdict" {
        type        = "string"
        description = "SATISFACTORY | WORKING_AS_DESIGNED | CASES_INADEQUATE | FIX_OR_TICKET_WRONG at exit"
        required    = true
      }
      field "iterations" {
        type        = "number"
        description = "Run + audit iterations completed"
        required    = true
      }
      field "working_as_designed" {
        type        = "boolean"
        description = "Whether the A/B concluded the fix was unnecessary (pre-change behavior already correct, revert)"
        required    = true
      }
      field "confirmed_findings" {
        type        = "string"
        description = "Confirmed bugs, dead/shadowed branches, wrong-value diffs, blast-radius/teardown issues, and path inconsistencies, each with the case result that demonstrates it"
        required    = true
      }
      field "open_questions" {
        type        = "string"
        description = "Tax-law/eligibility questions for the ticket SMEs and coverage gaps left open"
        required    = false
      }
      field "final_summary" {
        type        = "string"
        description = "End-to-end summary in at most 150 words; ends with the PR URL for human review"
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
        condition = "verdict == WORKING_AS_DESIGNED — no fix to lock in, but a no-op fix on a proven defect is exactly the kind of trap worth recording. Skip Bruno. Pass entry_stage = record_learnings, close_reason = 'audit WORKING_AS_DESIGNED', the audit verdict and confirmed findings, and every session id still open — rate_finalize asks each of them for its own learnings and cannot find them itself."
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
      The fix is settled (audit returned SATISFACTORY). Author Bruno API regression tests that
      lock it in, in FedTax/txc-bruno.

      # You do

      Start a FRESH code_develop session on https://github.com/FedTax/txc-bruno running the
      !bruno-regression playbook for ${inputs.issue} against the fix PR (number/branch from
      develop, or the fix_pr_url/fix_branch inputs — "${inputs.fix_pr_url}",
      "${inputs.fix_branch}" — on a run that entered at this stage).

      - title: "${inputs.issue} — bruno regression"
      - tags: `${inputs.issue}`, `bruno`

      # Brief the session

      The playbook owns how the suite is authored. Give it the ticket, the fix PR, and the
      audit's confirmed findings — which scenarios changed and which guardrails stayed flat —
      as the premises to draw from. The ratevariant cases are premises too, not templates: they
      run against a snapshot with fixtures, and Bruno runs against real staging without them,
      so which of them are portable is the session's call, not yours.

      # Hold the session to

      - These are red-green tests. They will fail until the fix is deployed to staging, and that
        is the intended state — a failing suite here is not a defect to fix, skip, or delete.
      - Every expected value traces to an authority (the SME's stated correct figure, or
        state-published material), never to current staging behavior. A scenario with no
        authoritative value is left unwritten and reported, not guessed and not weakened.
      - Two harness limits will block some scenarios outright, and neither is a reason to weaken
        a test: the suite runs against a fixed merchant (20), so a case that depends on a
        different merchant's configuration needs that configuration added there first; and only
        v3 is covered, so behavior that only exists on the v1 surface — meal tax among it — cannot
        be expressed at all. Either one is a finding: it goes in unwritten_scenarios with what it
        would take, and the session states it in the PR body's testing section so a reviewer does
        not read the gap as coverage.
      - Say how to edit that PR body, per session_lane: fetch the current description, add, put
        the whole thing back.

      Return bruno_session_id, the PR URL, the scenarios the suite locks in with the authority
      each expected value rests on, and any scenario left unwritten for want of one.
    EOT
    agents  = [agents.bruno_author]

    output {
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
        condition = "Always — the lane is finished, so the case closes out. Pass entry_stage = record_learnings, close_reason = 'fix audited SATISFACTORY and bruno regression authored', the fix and bruno PR URLs, the audit's confirmed findings and open questions, any scenario left unwritten for want of an authoritative value, and every session id still open, since rate_finalize asks each session for its own learnings and cannot find them itself."
      }
    }
  }
}
