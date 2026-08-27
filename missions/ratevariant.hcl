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

      %{ if inputs.wai_challenge != "" ~}
      Re-validation context from a prior run:
      ${inputs.wai_challenge}
      Treat this as authoritative input, not as the answer: a previous attempt concluded
      working-as-intended and verify_wai challenged it. Re-derive from the data — the prior
      conclusion may be right and the challenge may be wrong. Also have Devin annotate the
      prior Jira comment(s) as under investigation.
      %{ endif ~}

      %{ if inputs.wip_investigation_session_id != "" ~}
      First check_session(${inputs.wip_investigation_session_id}) — read-only, and Devin
      usually leaves a summary, so the verdict is often already there. Only send_message when
      there is something to do: nudge a stalled session, or prompt the re-validation above.
      You MAY NOT request a new session. If the session is terminated or the id is invalid,
      report failure so a human can correct it or start blank deliberately.
      %{ else ~}
      %{ if inputs.stale_investigation_session_id != "" ~}
      Read ${inputs.stale_investigation_session_id} for context ONLY — it is terminated, so
      you cannot message it. Then start a new read-only code_develop session and brief it with
      what the prior session established, so it re-verifies rather than re-derives from zero.
      %{ else ~}
      Start a code_develop session on ${inputs.repo_url} and have it run the
      !rate_investigation playbook for ${inputs.issue}.
      %{ endif ~}
      %{ endif ~}

      Pass title "${inputs.issue} — rate investigation", tags `${inputs.issue}` and
      `rate-investigation`, and prompt_mode `raw` — the default prompt tells the session to
      branch, test, commit and open a PR, which is the opposite of this stage.

      This session's lane is evidence, not change. Tell it plainly, in the task itself:
      do NOT create a branch, do NOT commit, do NOT open a PR, do NOT edit any file in the
      repo. Its deliverable is the investigation report and the Jira comment. If it offers a
      fix, that is out of lane — the finding is what you want.

      The playbook owns the method. What you must hold it to on return:
      - a verdict that answers the question the ticket actually asked, at the same scope
        (same merchant, product, line, jurisdiction, component, period, execution path);
      - the FIRST expected-versus-actual divergence, not just the wrong end value;
      - a basis for every load-bearing claim, each one measured or traced with its citation;
      - the affected roots (procedures/functions) and, for a data defect, the tables and rows;
      - one remediation disposition: existing data/configuration change, procedure/function
        change, or unsupported at the available granularity;
      - the explicit unknowns.

      Also have it check the repo's `ratevariant-audit/references/limitations.md`, which names the
      mechanism classes this engine structurally cannot express (Jira label `new-rate-engine`).
      A proven match there is a terminal answer: disposition `unsupported at available
      granularity`, no fix, and the mission ends with the limitation stated for the ticket's SMEs.
      It is a short-circuit, not a shortcut — the mechanism still has to be established from data
      at the ticket's scope, because these symptoms routinely resemble a class they don't belong
      to (a wrong CA rate reads as a ZIP+4 boundary patch and is really a sourcing-model
      question). A proven ordinary mechanism is an ordinary fix regardless of the label.

      The playbook emits the routing verdict itself, in its structured output, alongside the
      question-matched verdict it reasons in (`Discrepancy explained` etc.) and the mapping it
      used. Read it from check_session rather than re-deriving one from the prose summary; a
      structured verdict absent from a finished session is a stage failure, not an invitation
      to interpret.

      Verdict, exactly one:
      - DEFECT_PROVEN — the divergence is located and its mechanism is traced. Return the
        affected roots and the disposition; the fix stage will be briefed with them.
      - WORKING_AS_INTENDED — positive data shows the current behavior is correct and the
        ticket is a misunderstanding. This requires the decomposed correct value or the
        precluding condition, never merely the absence of a reproduction.
      - EVIDENCE_INCOMPLETE — you cannot reach either of the above. Do NOT soften this into
        one of them. Set evidence_complete = false and name the exact artifacts that would
        close it (the query, the capture, the transaction id, the authoritative answer needed
        from the ticket's SMEs), then stop: a human decides.

      Have Devin post one product-level comment on the ticket for its SME readers, per the
      sme_writeback skill's format — the customer-facing issue as understood, briefly what was
      found, and what needs confirming. Proc traces and raw queries stay in the session.

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
      # EVIDENCE_INCOMPLETE → no route: the mission completes with the missing
      # evidence named, for a human to supply. Do NOT route it onward.
      #
      # disposition == unsupported at available granularity → no route either. The
      # mechanism is proven and the current engine cannot express the remedy (the
      # new rate engine owns it, and has no authoring process yet), so the
      # limitation IS the deliverable. Routing it to develop buys a clean-looking
      # diff that papers over a modelling gap at state-wide blast radius.
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
        description = "Remediation disposition when a defect is proven: existing data/configuration change | procedure/function change | unsupported at available granularity. The last is terminal — it means the proven mechanism is one this engine cannot express, and no fix follows. Blank otherwise."
        required    = false
      }
      field "first_divergence" {
        type        = "string"
        description = "The first point where expected and actual part ways: the object/symbol, the input that reaches it, and both values."
        required    = false
      }
      field "affected_roots" {
        type        = "string"
        description = "Procedures/functions the defect implicates, and for a data defect the tables/rows — what the fix and the cases must cover."
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
      A defect has been proven for ${inputs.issue} in ${inputs.repo_url}. Implement the fix.

      Start a code_develop session on ${inputs.repo_url} running the !rate-fix playbook, and
      brief it with the investigation's result — the first divergence, the disposition, the
      affected roots, and the evidence behind them — so it implements against an established
      diagnosis instead of re-deriving one. Pass title "${inputs.issue} — rate fix", tags
      `${inputs.issue}` and `rate-fix`, and prompt_mode `raw`: this stage does branch, commit
      and open the PR, but the default prompt also tells it to add tests, which collides with
      the lane below. The playbook owns the branch/commit/PR sequence instead.

      Scope: implement the proven disposition and nothing wider. If the code contradicts the
      diagnosis, stop and report that — do not improvise a different fix, and do not re-open
      the question of whether the ticket is valid; that was settled upstream.

      Lane: the fix only — procedures and functions under output/schema, and data migrations
      under scripts/. It must NEVER touch tests/ratevariant-cases/** (cases or alterations);
      those belong to the case-authoring session, which is a separate session on purpose:
      finding eligible fixture data is a large discovery job with no bearing on the fix, and
      carrying it here degrades both. If the disposition is a data change, the session authors
      the scripts/*.sql migration, not the mirroring alteration YAML.

      Every schema object exists as a prod and a staging copy, in both databases where the
      logic is duplicated. All copies of a changed object must be edited: `ratevariant plan`
      watches the -prod copies, so a staging-only edit gets no A/B, and a prod-only edit leaves
      the mirror stale.

      Then have the session open the PR and add the label that lets A/B testing run, and
      confirm the label landed:
        gh pr edit <pr> --add-label ratevariant
        gh pr view <pr> --json number,url,headRefName,labels

      Return the PR URL, number, head branch, develop_session_id, and a one-line summary of
      what changed. If no PR exists at the end, fail — do not report success without one.
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
      Author the ratevariant tests for the PR (number/branch from develop) on the EXISTING
      branch. Pass title "${inputs.issue} / PR #<n> — ratevariant cases", tags
      `${inputs.issue}` and `rate-cases`, and prompt_mode `raw` — the default prompt would have
      it cut a second branch and open a second PR.

      Have Devin wait for the latest `ratevariant plan` at the head SHA to finish, fetch the
      `<!-- ratevariant-plan -->` comment, and run the !ratevariant-cases playbook covering
      the affected roots it lists under "### Proc changes". Brief the roots, the investigation's
      first divergence, and the shape of the change — then let the playbook and the session's
      own analysis choose the paths, boundaries, and inputs, grounded in the function code, the
      ticket, and staging data, never in the PR's prose.

      The "### Alterations" entry may be absent. If a scripts/*.sql data migration is present
      with no alterations file, also author the alteration YAML so the data change gets tested;
      for targeting, inspect where the altered tables are read and choose jurisdictions,
      products, and inputs from that.

      If the roots list is empty but the PR changed dbo procs/functions, callgraph generation
      failed (permissions or another DB/infra failure) — stop and report instead of authoring
      blind. Empty roots on a data-only PR is expected.

      Push to the existing branch, and stop there: the session must NOT add the
      `ratevariant:run` label or run the harness. Audit owns firing and interpreting the run,
      so the session that wrote the cases is never the one grading them. Then have Devin find
      the fix session's link in the PR description and add this session's link immediately
      after it.

      Lane: tests/ratevariant-cases/** only. It must NOT edit output/schema or scripts/ — the
      fix session owns those. Any PR comment asking for a proc or migration change is out of
      its lane; tell it to ignore such comments rather than act on them.

      Capture cases_session_id from the code_develop response for the audit phase. Return the
      mode, what was pushed, per-root coverage, and any gap with the reason the session gave.
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
      field "pushed" {
        type        = "string"
        description = "What was authored and pushed (cases and/or alteration YAML), with file paths"
        required    = true
      }
      field "roots_covered" {
        type        = "string"
        description = "Each affected root and the case(s)/probe(s) covering it"
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
      Own the A/B verdict for the PR (branch, number, mode from prior outputs). Skip if
      nothing was pushed since the last run.

      Three sessions are open and each owns a lane: investigation_session_id (the evidence),
      develop_session_id (the fix), cases_session_id (the cases). Do ALL Devin work through
      them via send_message and check_session — the A/B run, your staging queries, and every
      routed fix. Never open a new session and never run a code_qa review: your judgment stays
      independent, but the work runs in the session that owns it.

      Anchor your predictions in the investigation's first divergence and required outcome
      plus your own map of the actual PR diff — read the changed proc/fn bodies. Not the PR
      description, which is sometimes wrong about its own change.

      Loop until SATISFACTORY or WORKING_AS_DESIGNED, max 3 iterations:

      1. RUN — have Devin wait for the latest `ratevariant plan` at the head SHA to pass, then
         add the `ratevariant:run` label to fire the run, wait for it, and return the result
         comment for the current SHA (PROC → `<!-- ratevariant-result -->`, DATA →
         `<!-- ratevariant-alter-result -->`). The plan passing proves NOTHING about behavior;
         only the per-case captures validate. The run workflow removes `ratevariant:run` each
         time (the `ratevariant` plan gate persists), so each iteration: wait for the new head
         SHA's plan to pass, then re-add the label.

      2. AUDIT — per the ab_audit and txc_rate_audit skills. Classify every case as primary
         positive or guardrail before you look, prove each value is RIGHT rather than merely
         present, and diagnose every unexpected no-diff (shadowed / unreachable /
         not-exercised / masked) with data before concluding anything.

      Exit on exactly one verdict:
      - SATISFACTORY — intended diffs present, each to the correct value, guardrails flat, all
        paths the change spans in agreement, and every path it actually reaches covered by a
        case that ran. A path counts as not needing coverage only when you have PROVEN the
        change cannot reach it.
      - CASES_INADEQUATE — missing branch/path coverage, an ineffective probe, a guardrail
        gap, or a reachable path left uncovered on a hedge → send_message(cases_session_id)
        with the specific case(s)/probe(s) to add or fix, including the inputs and the values
        they must assert. Loop.
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
      # CASES_INADEQUATE / FIX_OR_TICKET_WRONG loop in-session and never reach a route.
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

      Start a FRESH code_develop session on https://github.com/FedTax/txc-bruno and have it run
      the !bruno-regression playbook for ${inputs.issue} against the fix PR (number/branch from
      develop). Pass title "${inputs.issue} — bruno regression" and tags `${inputs.issue}` and
      `bruno`.

      Brief the session: read the ticket and the txc-sqlserver-database PR, draw a
      representative set of cases from the PR's ratevariant cases and the audit's confirmed
      findings — the scenarios expected to change and the guardrails expected to stay flat —
      and author them under V3/Tax/Regression/${inputs.issue}[-TIC-NNNNN]/, following the
      existing folders.

      The assertions are post-fix values, and every expected value must trace to the ticket's
      authoritative answer (the SME's stated correct figure) or to state-published material —
      cite which, per scenario. Do NOT derive an expected value from current staging behavior,
      and do NOT weaken an assertion to make it pass: if an authoritative value is missing for
      a scenario, leave it out and report it as an open question instead of guessing one.

      Do NOT try to run the tests: Bruno executes against live staging, which requires the fix
      deployed there AND staging API credentials — neither is set up, so the tests genuinely
      CANNOT run, not merely "shouldn't". Author them, push to a branch, open a PR on
      txc-bruno, and stop.

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

      Run a FRESH code_develop session and re-derive from the data independently; do not resume
      the investigation's session, so the check is not anchored on its conclusion. Pass title
      "${inputs.issue} — verify working-as-intended", tags `${inputs.issue}` and `verify-wai`,
      and prompt_mode `raw` (read-only stage). (investigation_session_id is what you pass as
      wip_investigation_session_id if you re-fire.) This session is read-only: no branch, no
      commit, no PR.

      Re-examine the investigation's reasoning against the ticket's reported behavior, grounded
      in the data via read-only staging queries. Decompose the ticket's claimed-wrong value and
      check whether the engine actually produces the correct one, or whether the investigation
      missed a real defect. Confirming requires positive data; an absent reproduction is not
      evidence.

      - WAI_CONFIRMED — the current behavior is correct and the ticket is a misunderstanding.
        Have Devin confirm it on the Jira ticket at product level: plainly why the system is
        behaving correctly and what the ticket misread, with only the minimum basis an SME
        needs.

      - WAI_REFUTED — a real defect the investigation dismissed:
        · If wai_refire_count < 1: re-fire this mission (the self route). Fill the inputs —
          same issue/repo_url/base_branch, wip_investigation_session_id =
          investigation_session_id, wai_refire_count = wai_refire_count + 1, and wai_challenge
          stating the prior WAI reasoning, your rebuttal WITH its supporting data (expected vs
          actual, the rows that prove it), and an instruction to re-validate skeptically — it
          may still be right, this verification may be wrong, determine the truth — and to
          annotate the prior Jira comment as under investigation.
        · If wai_refire_count >= 1: STOP. Two rounds of disagreement is a human decision —
          have Devin post the standoff to the ticket for an SME reader: both positions and what
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
  # audit's WORKING_AS_DESIGNED, and from verify_wai's WAI_CONFIRMED. Most runs
  # record nothing, and that is a valid outcome.
  # ---------------------------------------------------------------------------

  task "record_learnings" {
    objective = <<-EOT
      The case for ${inputs.issue} is closed. Decide whether anything durable was learned, per
      the learnings_capture skill. The default answer is no.

      Consider only what would change how the NEXT case is handled — a trap that produced or
      nearly produced a wrong conclusion, an environment/tooling fact that was expensive to
      discover, or a documented-vs-actual behavior mismatch. The outcome of this ticket is not
      a learning: it already lives on the ticket and the PR.

      When there is one, route it to exactly one destination as a reviewable PR through a
      code_develop session — a repo-specific trap or precedent to that repo's .claude/skills
      (for a rate-audit precedent, an entry in the ratevariant-audit skill's case-law
      reference: symptom, mechanism, and how it was proven, with the ticket key), a workflow
      rule to this config's skills, a data/configuration fact to the owning repo's docs. Pass
      title "${inputs.issue} — record learnings" and tags `${inputs.issue}` and `learnings`. Prefer amending an existing document; keep it to
      the rule plus the one case that demonstrates it.

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
