mission "Ratevariant A-B" {
  commander {
    model = models.anthropic.claude_opus_4_7

    compaction {
      token_limit    = 250000
      turn_retention = 3
    }

    # Sized for the Devin plugin's current tool responses, which include the raw
    # message transcript. Drop to ~32000 once plugins.hcl pins a plugin version
    # that returns structured output + last message + PR links by default (and
    # that accepts the title/tags/prompt_mode arguments the tasks below pass).
    tool_response {
      max_tokens = 250000
    }
  }

  # Routed graph (Squadron is acyclic — no backward edges):
  #   investigate --router--> develop      (a defect is proven, read-only stage ends)
  #                      \--> verify_wai   (working-as-intended)
  #                      \--> (no route: evidence incomplete -> escalate and stop)
  #   develop     --send_to--> author_tests --send_to--> audit
  #   audit       --router--> bruno_tests   (SATISFACTORY: lock the settled fix into Bruno)
  #                      \--> record_learnings (WORKING_AS_DESIGNED: the fix was a no-op)
  #   bruno_tests --send_to--> record_learnings
  #   verify_wai  --router--> this mission (WAI refuted, capped) | record_learnings (confirmed)
  #
  # Each task is single-mode; the branch lives in the router, not in objective
  # conditionals. The durable know-how lives in skills the stage agents compose —
  # these objectives carry only what is specific to THIS case. In-run loops run
  # audit <-> the owning Devin session via send_message. All credentialed I/O (gh,
  # PR/Jira comments, staging queries) is Devin's; secrets stay in Devin.
  #
  # Objective convention, because a stage that misreads who an instruction is for
  # either does the session's job or relays its own constraints as the task:
  #   "You" / "# You do"      -> this Squadron stage. Never touches a repo.
  #   "the session" / "# Brief the session" -> text to put in the Devin task.
  #   "# Hold the session to" -> what to check on return, not text to send.
  # Repo mechanics are NOT restated here: the fix/cases/run/audit steps and their
  # path ownership live in txc-sqlserver-database's ratevariant-testing skill
  # (references/process.md), which the playbooks load. Cite the step; don't copy it.
  agents = [
    agents["Rate Investigator"],
    agents["Rate Fix Engineer"],
    agents["Ratevariant Case Author"],
    agents["Ratevariant Auditor"],
    agents["WAI Verifier"],
    agents["Bruno Author"],
    agents["Learnings Curator"]
  ]

  # ---------------------------------------------------------------------------
  # Inputs — a Slack bot fires this mission with a ticket key.
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
    description = "Optional: an existing in-flight Devin session to resume for the investigate step (an automation already started it, or a prior instance's session being re-validated). Blank = create a new session via code_develop."
    default     = ""
  }

  input "stale_investigation_session_id" {
    type        = "string"
    description = "Optional: an existing, but expired/archived, Devin session that previously investigated this ticket. Read it for context only; a new session does the investigation. Blank = create a new session."
    default     = ""
  }

  input "wai_challenge" {
    type        = "string"
    description = "Optional authoritative challenge from a prior run — a working-as-intended conclusion that verify_wai refuted, with the rebuttal and an instruction to re-investigate skeptically and annotate the prior Jira comment. Blank on a first run."
    default     = ""
  }

  input "wai_refire_count" {
    type        = "number"
    description = "How many times this ticket has been re-fired after a working-as-intended refute. Caps the investigate<->verify standoff: verify_wai will not re-fire once this is >= 1."
    default     = 0
  }

  # Allow triggering via webhook - Triage Bot uses this to auto-attempt rate tickets
  trigger {
    # Set this explicitly. The default path is the mission name, and
    # "Ratevariant A-B" doesn't make a clean URL — "/ratevariant" is what
    # the triage bot's `squadron:ratevariant` cell posts to.
    webhook_path = "/ratevariant"
    secret       = vars.ratevariant_webhook_secret
  }

  # ---------------------------------------------------------------------------
  # Task — investigate. READ-ONLY. Decides whether there is a defect at all, and
  # where it originates, BEFORE any session is incentivized to produce a fix.
  # Startable task (no deps). Routes on the verdict.
  # ---------------------------------------------------------------------------

  task "investigate" {
    objective = <<-EOT
      Establish, read-only, whether ticket ${inputs.issue} in ${inputs.repo_url} is a real
      defect, and if so where it originates. No fix is authored in this stage.

      # Preconditions

      %{ if inputs.wai_challenge != "" ~}
      Re-validation context from a prior run:
      ${inputs.wai_challenge}
      Treat this as authoritative input, not as the answer: a previous attempt concluded
      working-as-intended and verify_wai challenged it. Re-derive from the data — the prior
      conclusion may be right and the challenge may be wrong. Brief the session to annotate the
      prior Jira comment(s) as under investigation.
      %{ endif ~}

      %{ if inputs.wip_investigation_session_id != "" ~}
      A session is already in flight. You call check_session(${inputs.wip_investigation_session_id})
      first — Devin usually leaves a summary, so the verdict is often already there. Only
      send_message when there is something to do: nudge a stalled session, or prompt the
      re-validation above. You MAY NOT request a new session. If the session is terminated or
      the id is invalid, report failure so a human can correct it or start blank deliberately.
      %{ else ~}
      %{ if inputs.stale_investigation_session_id != "" ~}
      You read ${inputs.stale_investigation_session_id} for context ONLY — it is terminated, so
      it cannot be messaged. Then start a new read-only code_develop session and brief it with
      what the prior session established, so it re-verifies rather than re-derives from zero.
      %{ else ~}
      You start a code_develop session on ${inputs.repo_url} running the !rate_investigation
      playbook for ${inputs.issue}.
      %{ endif ~}
      %{ endif ~}

      # You do

      When you create the session, give it title "${inputs.issue} — investigate <short
      description of the reported behavior>" and tags `${inputs.issue}`, `rate-investigation`.
      The tags carry the general terms; the title is what a human scans, so it names this
      ticket's actual subject. Pass prompt_mode `raw` — the default prompt tells the session to
      branch, test, commit and open a PR, which is the opposite of this stage. On the resume
      path there is nothing to title: the brief below goes in a send_message to the session that
      already exists.

      # Brief the session

      Put in the task text, in these words or close to them:

      - Your lane is evidence, not change: do NOT create a branch, commit, open a PR, or edit
        any file. The deliverable is the investigation report plus one Jira comment.
      - Check `ratevariant-audit/references/limitations.md` for the mechanism classes this
        engine structurally cannot express (the ones behind the `new-rate-engine` label). A
        match is only a match once the mechanism is established from data at this ticket's
        scope: the symptom does not tell you the class, and the same wrong CA rate can
        genuinely be a ZIP+4 boundary problem or genuinely be a sourcing-model one. Where it
        is an ordinary mechanism, it is an ordinary fix regardless of the ticket's labels.
      - Emit the routing verdict in your structured output — DEFECT_PROVEN,
        WORKING_AS_INTENDED, or EVIDENCE_INCOMPLETE — alongside the question-matched verdict
        you reason in (`Discrepancy explained` etc.) and the mapping you used.
      - Post one product-level Jira comment per the sme_writeback format. State it at the
        strength the evidence carries: where the load-bearing claims are measured or traced
        and the gates pass, say plainly what the data shows; where any of it is inference,
        hedge and name what would settle it. Proc traces and raw queries stay in the session.
      - If the disposition is that this engine cannot express the remedy, that is the
        deliverable, and it still gets recorded on the ticket: post the comment stating the
        limitation for the SMEs, apply the `new-rate-engine` label, and move the ticket to
        Blocked. Do not author a fix to have something to show.

      # Hold the session to

      On return, check these before you route. A structured verdict absent from a finished
      session is a stage failure, not an invitation to derive one from the prose summary.

      - The verdict answers the question the ticket actually asked, without narrowing the scope
        it was asked at (merchant, product, line, jurisdiction, component, period, execution
        path). Widening is legitimate and often the better answer — "one merchant reported it,
        it is wrong for the whole county / product class" — so long as the reported case is
        still answered. Answering something narrower than the ticket asked is the failure.
      - Every load-bearing claim is measured or traced, with its citation.
      - The mechanism is named — what is wrong and where, which may be several sites in one
        proc rather than a single line.
      - The disposition is one of: data/configuration change, procedure/function change, both,
        or unsupported at available granularity. Both is common and is not a hedge: "the rates
        are wrong AND they are applied wrong" is two changes, and shipping one leaves the
        ticket half-fixed.
      - Unknowns are explicit.

      # Outcomes

      - DEFECT_PROVEN — mechanism traced. Its affected_roots are a briefing hint for the fix,
        not the coverage checklist; the `ratevariant plan` comment derives that empirically
        from the callgraph later.
      - WORKING_AS_INTENDED — positive data shows current behavior is correct and the ticket is
        a misunderstanding. Requires the decomposed correct value or the precluding condition,
        never merely the absence of a reproduction.
      - EVIDENCE_INCOMPLETE — neither of the above is reachable. Do NOT soften it into one of
        them: set evidence_complete = false, name the exact artifacts that would close it (the
        query, the capture, the transaction id, the answer needed from the SMEs), and stop.

      Return investigation_session_id and a one-line summary regardless of verdict.
    EOT
    agents = [agents["Rate Investigator"]]

    router {
      route {
        target    = tasks.develop
        condition = "verdict == DEFECT_PROVEN and evidence_complete == true and disposition != 'unsupported at available granularity' — a located, traced defect this system can actually express, so implement the fix."
      }
      route {
        target    = tasks.verify_wai
        condition = "verdict == WORKING_AS_INTENDED — no defect claimed; send to verify_wai for an independent check of that claim."
      }
      route {
        target    = tasks.record_learnings
        condition = "verdict == DEFECT_PROVEN and disposition == 'unsupported at available granularity' — the mechanism is proven and this engine cannot express the remedy, so the limitation IS the deliverable and belongs in limitations.md as another instance of its class. Routing it to develop instead buys a clean-looking diff that papers over a modelling gap at state-wide blast radius. The ticket's own writeback (comment, new-rate-engine label, Blocked) is the investigating session's, since it holds the Jira credentials."
      }
      # EVIDENCE_INCOMPLETE → no route: the mission completes with the missing
      # evidence named, for a human to supply. Do NOT route it onward.
    }

    output {
      field "verdict" {
        type        = "string"
        description = "DEFECT_PROVEN | WORKING_AS_INTENDED | EVIDENCE_INCOMPLETE"
        required    = true
      }
      field "evidence_complete" {
        type        = "boolean"
        description = "Whether every load-bearing claim is measured or traced with a citation, and the question-match, divergence, and alternative-killed gates pass. False forces escalation."
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
      field "unknowns" {
        type        = "string"
        description = "What remains unproven, and for EVIDENCE_INCOMPLETE the exact artifacts that would close each gap."
        required    = false
      }
      field "limitation_class" {
        type        = "string"
        description = "On the unsupported disposition only: which limitations.md mechanism class the proven mechanism matched, so record_learnings files this ticket as an instance under it rather than as a new class. Blank otherwise."
        required    = false
      }
      field "investigation_session_id" {
        type        = "string"
        description = "Devin session id that ran the investigation, resumed later via send_message rather than recreated."
        required    = true
      }
      field "investigation_summary" {
        type        = "string"
        description = "One-line summary of the verdict and its basis."
        required    = true
      }
    }
  }

  # ---------------------------------------------------------------------------
  # Task — develop. Implementation only. Reached only on a proven defect, so it
  # never has to decide whether there IS a defect. Dynamic target (no
  # depends_on); pushes into author_tests via send_to.
  # ---------------------------------------------------------------------------

  task "develop" {
    objective = <<-EOT
      A defect has been proven for ${inputs.issue} in ${inputs.repo_url}. Implement the fix —
      step 1 of the ratevariant process (ratevariant-testing skill, references/process.md).

      # You do

      Start a code_develop session on ${inputs.repo_url} running the !rate-fix playbook, with
      title "${inputs.issue} — fix <short description of what is being corrected>" and tags
      `${inputs.issue}`, `rate-fix`. The tags carry the general terms; the title names this
      ticket's actual subject, which is often jurisdictions, dates, or a sourcing quirk rather
      than a rate. Pass prompt_mode `raw`: the playbook owns the branch/commit/PR sequence, and
      the default prompt would also tell the session to add tests, which is step 2's lane.

      # Brief the session

      Give it the investigation's result — the mechanism, the disposition, the affected roots,
      and the evidence behind them — so it implements against an established diagnosis instead
      of re-deriving one. Then, in the task text:

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

      # Hold the session to

      If the reported fix does not line up with what the ticket asks for and the session gives
      no sound reason for the difference, push back: ask it to confirm the change actually
      addresses the ticket's ask, and cite the mismatch you see. Take its reasoning if it has
      one — it is reading the code and you are not — and record the disagreement in
      diagnosis_contradicted either way.

      Fail the stage if no PR exists at the end. Do not report success without one.

      Return the PR URL, number, head branch, develop_session_id, and a one-line summary of
      what changed.
    EOT
    agents  = [agents["Rate Fix Engineer"]]
    send_to = [tasks.author_tests]

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
        description = "Devin session id that owns the fix, resumed via send_message during the audit loop."
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
  }

  # ---------------------------------------------------------------------------
  # Task — author_tests. Reached only on the applies path, so it always has real
  # work (no self-skip). Authors the ratevariant cases/alteration, then hands off
  # to audit. Dynamic target (no depends_on); pushes into audit via send_to.
  # ---------------------------------------------------------------------------

  task "author_tests" {
    objective = <<-EOT
      Author the ratevariant cases for the PR (number/branch from develop) on the EXISTING
      branch — step 2 of the ratevariant process (ratevariant-testing skill,
      references/process.md).

      # You do

      Start a code_develop session running the !ratevariant-cases playbook, title
      "${inputs.issue} / PR #<n> — cases for <short description>", tags `${inputs.issue}`,
      `rate-cases`, prompt_mode `raw` — the default prompt would cut a second branch and open a
      second PR. Capture cases_session_id for the audit phase.

      # Brief the session

      The playbook owns which cases to write, and reading the `<!-- ratevariant-plan -->`
      comment at the current head SHA is its own first step. Give it what only this run knows:

      - the investigation's mechanism and disposition, so it knows what the change was meant to
        do;
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
    agents  = [agents["Ratevariant Case Author"]]
    send_to = [tasks.audit]

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
      field "coverage_gaps" {
        type        = "string"
        description = "Roots/paths not coverable on the reporting merchant, with reasons (including reasons Devin gives)"
        required    = false
      }
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
      Own the A/B verdict for the PR (branch, number, mode from prior outputs) — steps 3 and 4
      of the ratevariant process, which are one owner's on purpose so the session that wrote
      the fixtures is never the one grading them. Skip if nothing was pushed since the last run.

      # You do

      Three sessions are open and each owns a lane: investigation_session_id (the evidence),
      develop_session_id (the fix), cases_session_id (the cases). Do ALL Devin work through
      them via send_message and check_session — the run, your staging queries, and every routed
      fix. Never open a new session and never run a code_qa review: your judgment stays
      independent, but the work runs in the session that owns it.

      Anchor your predictions in the investigation's mechanism and required outcome plus your
      own map of the actual PR diff — have a session read out the changed proc/fn bodies. Not
      the PR description, which is sometimes wrong about its own change.

      When you need data — a decomposed rate, a merchant's configuration, whether a row exists
      — you have no database access; ask cases_session_id, which did the fixture discovery and
      has the deepest picture of the snapshot. State the question and the values you need back,
      not the query.

      Loop until SATISFACTORY or WORKING_AS_DESIGNED, max 3 iterations. The iteration count is
      yours for the cap and the summary — the sessions have no use for it, so don't relay it:

      1. RUN — step 3, per the ratevariant-testing skill: have a session fire it and return the
         result comment for the current head SHA (PROC → `<!-- ratevariant-result -->`, DATA →
         `<!-- ratevariant-alter-result -->`). Plan passing proves NOTHING about behavior; only
         the per-case captures validate.

      2. AUDIT — step 4, per the ab_audit and txc_rate_audit skills. Classify every case as
         primary positive or guardrail before you look, prove each value is RIGHT rather than
         merely present, and diagnose every unexpected no-diff (shadowed / unreachable /
         not-exercised / masked) with data before concluding anything.

      # Outcomes

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
        send_message(develop_session_id) with ONLY that fix and its supporting data. If the
        fix changes a scripts/*.sql migration, the mirroring alteration is now stale — also
        send_message(cases_session_id) to re-sync it. Loop.
      - WORKING_AS_DESIGNED — the A/B, grounded in data, shows the fix changes nothing: the
        pre-change behavior was already correct, or the changed branch is provably dead. This
        requires POSITIVE data (the decomposed correct value, or the precluding condition),
        never an absent diff or an inability to construct one. The fix session made the change
        and is best placed to confirm it: send_message(develop_session_id) with the
        data-grounded finding and have it verify in-situ, then post ONE product-level Jira
        comment routing to the SMEs, plus a brief PR note so the reviewer knows it is a no-op.
        It must NOT push code, close the PR, or remove labels. Return the comment URL. Tell
        the cases session to stand down. Don't loop; exit.

      At the cap, exit on the verdict the evidence supports — never upgrade to SATISFACTORY to
      close out the run. Track the iteration count and summarize what changed and why on exit.
    EOT
    agents = [agents["Ratevariant Auditor"]]

    router {
      route {
        target    = tasks.bruno_tests
        condition = "verdict == SATISFACTORY — the fix is settled and correct, so author the Bruno regression suite."
      }
      route {
        target    = tasks.record_learnings
        condition = "verdict == WORKING_AS_DESIGNED — no fix to lock in, but a no-op fix on a proven defect is exactly the kind of trap worth recording. Skip Bruno."
      }
      # CASES_INADEQUATE / FIX_OR_TICKET_WRONG normally loop in-session and never reach a
      # route; on the rare terminal CASES_INADEQUATE the mission exits with the uncoverable
      # paths named, for a human to decide. Do NOT route it onward.
    }

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
  }

  # ---------------------------------------------------------------------------
  # Task — bruno_tests. Reached only on audit's SATISFACTORY verdict, so the
  # red/green API tests are written against a settled, correct fix — never one
  # still looping. Dynamic target (no depends_on); hands off to record_learnings.
  # ---------------------------------------------------------------------------

  task "bruno_tests" {
    objective = <<-EOT
      The fix is settled (audit returned SATISFACTORY). Author Bruno API regression tests that
      lock it in, in FedTax/txc-bruno.

      # You do

      Start a FRESH code_develop session on https://github.com/FedTax/txc-bruno running the
      !bruno-regression playbook for ${inputs.issue} against the fix PR (number/branch from
      develop), title "${inputs.issue} — bruno regression", tags `${inputs.issue}`, `bruno`.

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

      Return bruno_session_id, the PR URL, the scenarios the suite locks in with the authority
      each expected value rests on, and any scenario left unwritten for want of one.
    EOT
    agents  = [agents["Bruno Author"]]
    send_to = [tasks.record_learnings]

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
        description = "Scenarios not authored because no authoritative expected value was available, with what is needed"
        required    = false
      }
    }
  }

  # ---------------------------------------------------------------------------
  # Task — verify_wai. Reached only when investigate concluded working-as-intended.
  # No PR, nothing to A/B — skeptically re-examine the claim. On a refute, re-fire
  # the mission once (capped by wai_refire_count). Dynamic target (no depends_on).
  # ---------------------------------------------------------------------------

  task "verify_wai" {
    objective = <<-EOT
      The investigation concluded the system is working as intended for ${inputs.issue} (no
      fix, no PR). There is nothing to A/B — your job is to skeptically verify that claim.

      # You do

      Start a FRESH code_develop session — not the investigation's, so the check is not
      anchored on its conclusion — with title "${inputs.issue} — verify working-as-intended",
      tags `${inputs.issue}`, `verify-wai`, prompt_mode `raw`. You hold no data access: every
      query, capture, and Jira comment below is that session's work, and you judge what comes
      back. (investigation_session_id is what you pass as wip_investigation_session_id if you
      re-fire.)

      # Brief the session

      Re-derive independently rather than reviewing the investigation's reasoning: decompose the
      ticket's claimed-wrong value from the data and establish whether the engine produces the
      correct one, or whether a real defect was dismissed. Read-only — no branch, no commit, no
      PR. Confirming requires positive data; an absent reproduction is not evidence.

      # Outcomes

      - WAI_CONFIRMED — the current behavior is correct and the ticket is a misunderstanding.
        Have the session post that to the Jira ticket at product level: plainly why the system
        is behaving correctly and what the ticket misread, with only the minimum basis an SME
        needs.

      - WAI_REFUTED — a real defect the investigation dismissed:
        · If wai_refire_count < 1: re-fire this mission (the self route). Fill the inputs —
          same issue/repo_url/base_branch, wip_investigation_session_id =
          investigation_session_id, wai_refire_count = wai_refire_count + 1, and wai_challenge
          stating the prior WAI reasoning, your rebuttal WITH its supporting data (expected vs
          actual, the rows that prove it), and an instruction to re-validate skeptically — it
          may still be right, this verification may be wrong, determine the truth — and to
          annotate the prior Jira comment as under investigation.
        · If wai_refire_count >= 1: STOP. Two rounds of disagreement is a human decision — have
          the session post the standoff to the ticket for an SME reader: both positions and what
          each turns on, with only the minimum basis each side rests on. Do NOT re-fire.
    EOT
    agents = [agents["WAI Verifier"]]

    router {
      route {
        target    = missions["Ratevariant A-B"]
        condition = "verdict == WAI_REFUTED (a real defect exists) AND wai_refire_count < 1. If wai_refire_count >= 1, do NOT take this route — escalate to the SMEs and exit."
      }
      route {
        target    = tasks.record_learnings
        condition = "verdict == WAI_CONFIRMED — the ticket was a misunderstanding; a recurring misunderstanding is worth recording."
      }
    }

    output {
      field "verdict" {
        type        = "string"
        description = "WAI_CONFIRMED | WAI_REFUTED"
        required    = true
      }
      field "refired" {
        type        = "boolean"
        description = "Whether this refuted the claim and re-fired the mission"
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
  }

  # ---------------------------------------------------------------------------
  # Task — record_learnings. Terminal. Reached from bruno_tests (send_to), from
  # audit's WORKING_AS_DESIGNED, from verify_wai's WAI_CONFIRMED, and from
  # investigate's unsupported disposition. Most runs record nothing, and that is
  # a valid outcome.
  # ---------------------------------------------------------------------------

  task "record_learnings" {
    objective = <<-EOT
      The case for ${inputs.issue} is closed. Decide whether anything durable AND new was
      learned, per the learnings_capture skill. The default answer is no — and a rule already
      written down, in any of the places below, is not new: re-stating it in a second place is
      how two sources of truth start disagreeing.

      Consider only what would change how the NEXT case is handled — a trap that produced or
      nearly produced a wrong conclusion, an environment/tooling fact that was expensive to
      discover, or a documented-vs-actual behavior mismatch. The outcome of this ticket is not
      a learning: it already lives on the ticket and the PR.

      One entry point is not discretionary: arriving here from investigate's unsupported
      disposition means a proven instance of a mechanism class the engine cannot express, so it
      is recorded in the ratevariant-audit skill's limitations reference — stated as the class,
      with this ticket as an instance under it, and with the data that proved the class applies.
      A limitation only known inside a closed session gets re-investigated from scratch next
      quarter. If the class is already there, add the instance and nothing else.

      Otherwise, route it as a reviewable PR through exactly one code_develop session — that
      session may well write to more than one repo, and often should, since a lesson can be both
      a repo trap and a workflow rule. Where each kind goes: a repo-specific trap or precedent
      to that repo's .claude/skills
      (for a rate-audit precedent, an entry in the ratevariant-audit skill's case-law
      reference: symptom, mechanism, and how it was proven, with the ticket key), a workflow
      rule to this config's skills, a data/configuration fact to the owning repo's docs. Pass
      title "${inputs.issue} — record <the learning, in a few words>" and tags
      `${inputs.issue}`, `learnings`. Prefer amending an existing document; keep it to the rule
      plus the one case that demonstrates it.

      Every recorded learning must be citable — the case result, capture, or query that
      establishes it. An uncitable "lesson" is worse than none because it will be trusted.
      Never mutate a source of truth as a "learning": a learning is documentation.

      If nothing qualifies, set recorded = false and say why in one line. Do not manufacture
      something to record.
    EOT
    agents = [agents["Learnings Curator"]]

    output {
      field "recorded" {
        type        = "boolean"
        description = "Whether a durable learning was written back"
        required    = true
      }
      field "learning" {
        type        = "string"
        description = "The rule as recorded, with the case that demonstrates it, or one line on why nothing qualified"
        required    = true
      }
      field "destination_pr_url" {
        type        = "string"
        description = "PR URL of the write-back, when one was made"
        required    = false
      }
    }
  }
}
