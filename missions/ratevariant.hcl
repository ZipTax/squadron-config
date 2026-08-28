mission "ratevariant_ab" {
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

  # Routed graph (Squadron is acyclic — no backward edges):
  #   discover_sessions --router--> start_investigation    (nothing exists yet)
  #                            \--> confirm_wai            (a WAI conclusion is challenged)
  #                            \--> continue_investigation (a messageable session exists)
  #                            \--> forward_investigation (a terminated session exists)
  #   all four    --send_to--> assess_investigation (conditional fan-in)
  #   assess      --router--> develop      (a defect is proven — write the fix, or adopt an
  #                                         existing PR whose session is gone)
  #                      \--> author_tests (a prior run's fix PR exists, owner still live)
  #                      \--> verify_wai   (working-as-intended)
  #                      \--> record_learnings (proven, but the remedy is unsupported)
  #                      \--> (no route: evidence incomplete -> escalate and stop)
  #   develop     --send_to--> author_tests
  #   author_tests --send_to--> audit
  #   audit       --router--> bruno_tests   (SATISFACTORY: lock the settled fix into Bruno)
  #                      \--> record_learnings (WORKING_AS_DESIGNED: the fix was a no-op)
  #   bruno_tests --send_to--> record_learnings
  #   verify_wai  --router--> this mission (WAI refuted, capped) | record_learnings (confirmed)
  #
  # Each task is single-mode; the branch lives in the router, not in objective
  # conditionals — discover_sessions is the only task with no dependency, so a
  # webhook fires one stage, and it decides which entry the case takes. The four
  # entries differ only in how the session is obtained: the brief they give it and
  # the gates its result must pass live once, in the rate_investigation skill, and
  # the verdict schema and downstream routes live once in assess_investigation.
  # The durable know-how lives in skills the stage agents compose —
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
  memories = [memories.rate_case_log]

  agents = [
    agents.session_scout,
    agents.rate_investigator,
    agents.rate_fix_engineer,
    agents.ratevariant_case_author,
    agents.ratevariant_auditor,
    agents.wai_verifier,
    agents.bruno_author,
    agents.learnings_curator
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
    description = "Optional authoritative challenge from a prior run — a working-as-intended conclusion that verify_wai refuted, with the rebuttal and an instruction to re-investigate skeptically and annotate the prior Jira comment. Present = discovery routes to confirm_wai. Blank on a first run."
    default     = ""
  }

  input "wai_refire_count" {
    type        = "number"
    description = "How many times this ticket has been re-fired after a working-as-intended refute. Caps the investigation<->verify standoff: verify_wai will not re-fire once this is >= 1."
    default     = 0
  }

  # Allow triggering via webhook - Triage Bot uses this to auto-attempt rate tickets
  trigger {
    # Set explicitly so the path survives a mission rename: "/ratevariant" is
    # what the triage bot's `squadron:ratevariant` cell posts to.
    webhook_path = "/ratevariant"
    secret       = vars.ratevariant_webhook_secret
  }

  # ---------------------------------------------------------------------------
  # Task — discover_sessions. The mission's only startable task, and the single
  # place the entry mode is decided. It asks what this ticket already has —
  # find_sessions by ticket tag, since every stage tags its sessions with the key
  # — instead of relying on ids being passed in, then routes exactly one of the
  # four investigation entries. Read-only: it creates no session and messages
  # none, which is why it holds no code_develop tool.
  # ---------------------------------------------------------------------------

  task "discover_sessions" {
    objective = <<-EOT
      Decide how the investigation of ${inputs.issue} starts, from what this ticket already has.
      You read only: no session is created, messaged, or briefed in this stage.

      # You do

      1. find_sessions(tags: ["${inputs.issue}"]). Every stage tags its sessions with the ticket
         key, so this is the whole history of the ticket: prior investigations, fix sessions, case
         sessions, verifications. Zero matches is a real answer, not a failure.
      2. check_session on each candidate that could be an investigation (tagged
         `rate-investigation` or `verify-wai`, or titled as one). A search result gives status and
         PR links; only the session itself says whether it reached a verdict, and what of.
      3. Honor the overrides if they are set — they are a human or an automation telling you
         something the search cannot know:
         %{ if inputs.wip_investigation_session_id != "" ~}
         · wip_investigation_session_id = ${inputs.wip_investigation_session_id} — treat this
           session as the one to continue, even if the search surfaced others.
         %{ endif ~}
         %{ if inputs.stale_investigation_session_id != "" ~}
         · stale_investigation_session_id = ${inputs.stale_investigation_session_id} — treat this
           session as terminated context to carry forward, not as resumable.
         %{ endif ~}
         %{ if inputs.wai_challenge != "" ~}
         · A wai_challenge is present, so this run is a re-fire of a refuted working-as-intended
           conclusion. That decides the route: confirm_wai. Carry the challenge text through
           verbatim — it is authoritative input and the confirming stage needs all of it.
         %{ endif ~}
         %{ if inputs.wip_investigation_session_id == "" && inputs.stale_investigation_session_id == "" && inputs.wai_challenge == "" ~}
         · No overrides were passed on this run, so the search is all you have to go on.
         %{ endif ~}

      # What you are deciding

      One entry mode, and the state the chosen entry needs. Distinguish carefully, because each
      wrong answer costs a different way: routing a live session to start_investigation abandons
      work and can produce a second contradictory verdict; routing a terminated one to
      continue_investigation strands the mission on a session that cannot be messaged.

      - No investigation session exists → `start`.
      - A prior investigation concluded working-as-intended and this run is challenging it (a
        wai_challenge, or a verify-wai session that refuted it) → `confirm_wai`.
      - An investigation session exists and can still be messaged — running, waiting on a
        message, or finished-but-resumable → `continue`.
      - An investigation session exists but is terminated, expired or archived, so it can be read
        and not messaged → `forward`.

      A fix PR is not itself an entry mode: it is state. If any session for this ticket already
      opened a fix PR in ${inputs.repo_url}, put it in existing_fix_pr_url and say which session
      opened it — the fix may exist while its A/B coverage does not, and the assessing stage
      routes on that. Confirm it is this ticket's fix and not an unrelated PR the session touched.

      Return the mode, the one session id it applies to, that session's state, whatever verdict
      the read already found, and the prior context worth carrying — what was established, what
      was left open — so no downstream session re-derives what is already known.
    EOT
    agents = [agents.session_scout]

    output {
      field "entry_mode" {
        type        = "string"
        description = "start | confirm_wai | continue | forward. Exactly one; it is what the router acts on."
        required    = true
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
        description = "What prior sessions established and what they left open, with the session each came from — the briefing material that stops a downstream session re-deriving known work. Blank on start."
        required    = false
      }
      field "sessions_found" {
        type        = "string"
        description = "The tagged sessions found for this ticket — id, stage tag, state — and one line on why the chosen one was chosen over the others."
        required    = true
      }
    }

    router {
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
      Nothing has investigated ${inputs.issue} yet. Establish, read-only, whether it is a real
      defect and where it originates. No fix is authored in this stage.

      # You do

      Start a code_develop session on ${inputs.repo_url} running the !rate_investigation playbook
      for ${inputs.issue}.

      - title: "${inputs.issue} — investigate <short description of the reported behavior>" — the
        tags carry the general terms, so the title is where this ticket's actual subject goes; it
        is what a human scans.
      - tags: `${inputs.issue}`, `rate-investigation`
      - prompt_mode: `raw` — the default prompt tells the session to branch, test, commit and open
        a PR, which is the opposite of this stage.

      # Brief the session

      Per the rate_investigation skill, in full: this session knows nothing about the case.

      Return investigation_session_id, the verdict it reached, and its report.
    EOT
    agents  = [agents.rate_investigator]

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
      A prior investigation concluded the system works as intended for ${inputs.issue}, and that
      conclusion is under challenge. Re-establish, read-only and independently, what the system
      actually does.

      %{ if inputs.wai_challenge != "" ~}
      # The challenge

      ${inputs.wai_challenge}
      %{ else ~}
      # The challenge

      Take it from discover_sessions' prior_context: the working-as-intended conclusion, and the
      refutation or dispute that reopened it.
      %{ endif ~}

      This is authoritative input, not the answer. The prior conclusion may be right and the
      challenge wrong; determine the truth rather than picking a side.

      # You do

      Start a FRESH code_develop session — never the one that reached the working-as-intended
      conclusion, which is anchored on it — on ${inputs.repo_url} running the !rate_investigation
      playbook.

      - title: "${inputs.issue} — re-investigate <the disputed behavior>"
      - tags: `${inputs.issue}`, `rate-investigation`, `wai-challenge` — the third one is what makes
        this lane findable later: a search for the ticket's investigations otherwise cannot tell
        the challenged conclusion from the challenge to it.
      - prompt_mode: `raw`

      # Brief the session

      Per the rate_investigation skill, plus:

      - The challenge above, in full, as input to test rather than a conclusion to confirm.
      - Re-derive the behavior from the code and the data. Do not audit the prior session's
        reasoning for internal consistency — that inherits its blind spot.
      - Annotate the prior Jira comment(s) as under investigation, so nobody acts on a conclusion
        that is being re-examined.

      Return investigation_session_id, the verdict it reached, and its report.
    EOT
    agents  = [agents.rate_investigator]

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
      An investigation of ${inputs.issue} is already in flight in the session discover_sessions
      identified. Finish it in THAT session. You may not create a session on this path: a second
      one re-derives context, costs a full investigation, and can reach a different answer for no
      reason other than being asked twice.

      # You do

      check_session on it first, then do only what that read leaves undone:

      - It already reached a verdict → you are done. Return it as reported. Do NOT re-brief it.
      - It is mid-investigation or stalled → send_message with only what is missing, citing what
        it has already established so it does not start over. Repeating the whole brief to a
        session mid-investigation invites exactly that.
      - It turns out to be unmessageable after all → report that as a stage failure rather than
        substituting a new session. discover_sessions routes terminated sessions to
        forward_investigation, and the difference matters; if that call was wrong, say so — name
        what the read showed and what discover_sessions concluded from it. A misroute is a
        learning about the routing rule, and record_learnings can only turn it into one if the
        discrepancy is on the record rather than papered over by carrying on.

      Anything you do send follows the rate_investigation skill's brief — the parts it has not
      already covered — and the re-briefing format in delegated_session.

      Return investigation_session_id, the verdict, and its report.
    EOT
    agents  = [agents.rate_investigator]

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
      A prior investigation of ${inputs.issue} exists in a terminated session — readable, not
      messageable. Carry it forward.

      # You do

      Read it first (check_session on the id discover_sessions identified) and stop there if it
      settled the question: a verdict already established is returned as is. Re-proving a settled
      conclusion costs a session and changes nothing, and a second run of the same question can
      contradict the first.

      Otherwise start a new read-only code_develop session on ${inputs.repo_url} running the
      !rate_investigation playbook.

      - title: "${inputs.issue} — investigate <short description of the reported behavior>"
      - tags: `${inputs.issue}`, `rate-investigation`
      - prompt_mode: `raw`

      # Brief the session

      Per the rate_investigation skill, plus what the terminated session established and what it
      left open (discover_sessions' prior_context), so this session re-verifies rather than
      re-deriving from zero — and treats the inherited findings as claims to check, since it
      cannot see the evidence behind them.

      Return investigation_session_id — the new session's, or the terminated one's when its
      verdict stood — the verdict, and its report.

      When you return the terminated session's id, say so in session_messageable — later stages
      (assess, audit) reach back to the investigation to close a gate gap or ask a follow-up, and
      the delegated_session rules tell them what to do instead once they know they cannot.
    EOT
    agents  = [agents.rate_investigator]

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
      An investigation of ${inputs.issue} has returned. Judge whether it holds, and emit the
      verdict the rest of the mission routes on. You create no session and author no fix.

      # You do

      Read the investigation session's structured output yourself (check_session on
      investigation_session_id) rather than trusting the summary that reached you, then check it
      against the gates in the rate_investigation skill. If a gate fails, send_message that
      session naming the exact gap — a conclusion with no basis is a stage failure, not a verdict
      to derive from prose. Only that session can query; you judge what comes back.

      Unless it cannot be messaged: forward_investigation returns session_messageable = false when
      the verdict it carried forward came from a terminated session. Follow the delegated_session
      rules for that case — here the gap-closing session is a fresh read-only one, and the verdict
      to return when you cannot get the evidence is EVIDENCE_INCOMPLETE, naming it.

      Emit the verdict, disposition, mechanism, evidence and unknowns as its own words support
      them — not upgraded, and not softened. Carry existing_fix_pr_url through if discover_sessions
      or the investigation found a fix PR already open for this ticket.

      # Settle who owns the fix

      On an existing fix PR, one more thing is yours, and no later stage can do it for you: say
      whether that PR still has a live owner. check_session the session that opened it and return
      it in fix_session_id with fix_session_messageable. Audit routes every FIX_OR_TICKET_WRONG
      finding to the session that owns the fix and opens no session itself — so if that owner is
      terminated and nobody noticed here, audit reaches a finding it is structurally unable to act
      on, at the end of a run, with a wrong fix on an open PR. A false flag routes through develop
      instead, which adopts the PR and becomes the owner.
    EOT
    agents = [agents.rate_investigator]

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
        target    = tasks.author_tests
        condition = "verdict == DEFECT_PROVEN and existing_fix_pr_url is not blank and fix_session_messageable == true — a prior run already implemented and opened the fix AND its session is still reachable, so the fix lane has an owner audit can route findings to. Re-running develop would author a second fix for a defect that already has one; what the ticket is missing is A/B coverage of the PR that exists."
      }
      route {
        target    = tasks.develop
        condition = "verdict == DEFECT_PROVEN and evidence_complete == true and disposition != 'unsupported at available granularity' and (existing_fix_pr_url is blank, or fix_session_messageable is false/unknown) — a located, traced defect this system can actually express. Either no fix exists yet and develop writes it, or one exists whose session is gone and develop adopts it: the fix lane must have a session that can still be messaged before audit starts, since audit routes fixes and never opens a session."
      }
      route {
        target    = tasks.verify_wai
        condition = "verdict == WORKING_AS_INTENDED — no defect claimed; send to verify_wai for an independent check of that claim."
      }
      route {
        target    = tasks.record_learnings
        condition = "verdict == DEFECT_PROVEN and disposition == 'unsupported at available granularity' — the mechanism is proven and this engine cannot express the remedy, so the limitation IS the deliverable and belongs in limitations.md under the labelled ticket it instances. A scoped partial fix may still be worth filing separately — what develop must not do is present one as closing the class. Routing it to develop instead buys a clean-looking diff that papers over a modelling gap at state-wide blast radius. The ticket's own writeback (comment, new-rate-engine label, Blocked) is the investigating session's, since it holds the Jira credentials."
      }
      # EVIDENCE_INCOMPLETE → no route: the mission completes with the missing
      # evidence named, for a human to supply. Do NOT route it onward.
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

      # Two ways you get here

      Usually no fix exists and this stage writes it. But when assess_investigation reports an
      existing_fix_pr_url whose fix_session_messageable is false, the fix exists and its session is
      gone, and this stage exists to give that PR a living owner — audit routes corrections to the
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
      develop's, or the one assess_investigation reported in existing_fix_pr_url when a prior run had
      already opened it and its session is still live; in that case read the PR diff for the change
      under test, since no develop stage in this run described it.

      Pass the fix lane's session id through to audit either way — develop_session_id when develop
      ran, otherwise assess's fix_session_id. Audit routes corrections to whichever it is and cannot
      open a session of its own, so a lane id that stops here strands them.

      # You do

      Start a code_develop session running the !ratevariant-cases playbook.

      - title: "${inputs.issue} / PR #<n> — cases for <short description>"
      - tags: `${inputs.issue}`, `rate-cases`
      - prompt_mode: `raw` — the default prompt would cut a second branch and open a second PR.

      Capture cases_session_id for the audit phase.

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
        description = "The session that owns the fix and receives audit's corrections: develop's when develop ran, otherwise the live session assess_investigation identified behind the existing PR."
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
      cases_session_id (the cases). Do ALL Devin work through
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
        target    = tasks.record_learnings
        condition = "verdict == WORKING_AS_DESIGNED — no fix to lock in, but a no-op fix on a proven defect is exactly the kind of trap worth recording. Skip Bruno."
      }
      # CASES_INADEQUATE / FIX_OR_TICKET_WRONG normally loop in-session and never reach a
      # route; on the rare terminal CASES_INADEQUATE the mission exits with the uncoverable
      # paths named, for a human to decide. Do NOT route it onward.
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
      develop).

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

    send_to = [tasks.record_learnings]
  }

  # ---------------------------------------------------------------------------
  # Task — verify_wai. Reached only when the investigation concluded working-as-intended.
  # No PR, nothing to A/B — skeptically re-examine the claim. On a refute, re-fire
  # the mission once (capped by wai_refire_count). Dynamic target (no depends_on).
  # ---------------------------------------------------------------------------

  task "verify_wai" {
    objective = <<-EOT
      The investigation concluded the system is working as intended for ${inputs.issue} (no
      fix, no PR). There is nothing to A/B — your job is to skeptically verify that claim.

      # You do

      Start a FRESH code_develop session — not the investigation's, so the check is not
      anchored on its conclusion.

      - title: "${inputs.issue} — verify working-as-intended"
      - tags: `${inputs.issue}`, `verify-wai`
      - prompt_mode: `raw`

      You hold no data access: every
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
    agents = [agents.wai_verifier]

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

    router {
      route {
        target    = missions.ratevariant_ab
        condition = "verdict == WAI_REFUTED (a real defect exists) AND wai_refire_count < 1. If wai_refire_count >= 1, do NOT take this route — escalate to the SMEs and exit."
      }
      route {
        target    = tasks.record_learnings
        condition = "verdict == WAI_CONFIRMED — the ticket was a misunderstanding; a recurring misunderstanding is worth recording."
      }
    }

  }

  # ---------------------------------------------------------------------------
  # Task — record_learnings. Terminal. Reached from bruno_tests (send_to), from
  # audit's WORKING_AS_DESIGNED, from verify_wai's WAI_CONFIRMED, and from
  # assess_investigation's unsupported disposition. Most runs record nothing, and that is
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

      This run's own misfires count, and they are the ones that can actually be fixed in
      configuration: a stage that reported the entry mode was wrong for the session it got, a
      brief a session read the wrong way, a gate that passed something it should have caught. Those
      are workflow rules, so they land in this config's skills.

      # Ask the sessions first

      You did not do the work and cannot see where it went slowly — a session that spent two hours
      finding out which merchant has an eligibility row knows that, and nothing in its final report
      says so. So ask each session still open on this case (investigation, fix, cases, bruno) in
      these words or close to them, before you decide anything:

      > Please tell me the two most complex, unclear, or difficult things you had to figure out
      > this session that would have saved you time and/or effort. These should be reusable and
      > focused on future effort of a similar nature or having a similar requirement. You do not
      > need to provide any, if you do not think there are any that are relevant or worthwhile.

      Their answers are candidates, not learnings: hold each to the same bar as your own —
      durable, new, citable, and not already written down. A session's frustration with a
      one-off flake is not a rule.

      One entry point is not discretionary: arriving here from the investigation's unsupported
      disposition means a proven instance of a deferred limitation, so it is recorded in the
      ratevariant-audit skill's limitations reference — under the labelled ticket it instances,
      with the data that proved the mechanism is that one. Only tickets carrying `new-rate-engine`
      belong in that file; an unproven mechanism goes to `references/open-theories.md` instead.
      A limitation only known inside a closed session gets re-investigated from scratch next
      quarter. If the class is already there, add the instance and nothing else.

      Otherwise, route it as a reviewable PR through exactly one code_develop session — that
      session may well write to more than one repo, and often should, since a lesson can be both
      a repo trap and a workflow rule. Where each kind goes: a repo-specific trap or precedent
      to that repo's .claude/skills
      (for a rate-audit precedent, an entry in the ratevariant-audit skill's case-law
      reference: symptom, mechanism, and how it was proven, with the ticket key), a workflow
      rule to this config's skills, a data/configuration fact to the owning repo's docs. Pass
      title "${inputs.issue} — record <the learning, in a few words>" and tags `${inputs.issue}`,
      `learnings`. Prefer amending an existing document; keep it to the rule plus the one case
      that demonstrates it.

      Every recorded learning must be citable — the case result, capture, or query that
      establishes it. An uncitable "lesson" is worse than none because it will be trusted.
      Never mutate a source of truth as a "learning": a learning is documentation.

      If nothing qualifies, set recorded = false and say why in one line. Do not manufacture
      something to record.

      # The case log

      Read it before you decide, and append to it after. `file_grep` the `rate_case_log` slot for
      this case's mechanism class first: a mechanism appearing for the second or third time is
      itself the durable finding, and it is the one thing this stage cannot see from the ticket in
      front of it — recurrence is what turns "one odd case" into a precedent worth writing down.
      Cite the prior tickets you found when it does.

      Then `file_create` (append) one line to `rate_case_log`, path `cases.md`, whatever the
      outcome — including recorded = false, since a case that taught nothing is still a case:

      `<date> | ${inputs.issue} | <mechanism class, few words> | <verdict> | <written back where, or none>`

      One line. Anything longer belongs in the reviewable document, not here, and the log is only
      useful while it stays greppable.
    EOT
    agents = [agents.learnings_curator]

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
