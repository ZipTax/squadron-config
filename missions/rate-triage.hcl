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

  # First of the three rate missions: rate_triage -> rate_fix -> rate_finalize.
  # This one answers two questions and nothing else — what does this ticket
  # already have, and is there a defect — then hands the case to the mission
  # that acts on the answer. Implementation, A/B and close-out are the other
  # two missions, so a verdict crosses a mission boundary as declared inputs
  # rather than as prose a downstream stage has to re-derive.
  #
  # Routed graph (Squadron is acyclic — no backward edges):
  #   discover_sessions --router--> start_investigation    (nothing exists yet)
  #                            \--> confirm_wai            (a WAI conclusion is challenged)
  #                            \--> continue_investigation (a messageable session exists)
  #                            \--> forward_investigation  (a terminated session exists)
  #                            \--> missions.rate_fix | missions.rate_finalize
  #                                 (a prior run blocked past assessment with its verdict and
  #                                  fix PR intact — resume there, don't investigate again)
  #   all four    --send_to--> assess_investigation (conditional fan-in)
  #   assess      --router--> missions.rate_fix      (a defect is proven — write the fix, or adopt
  #                                                   an existing PR whose session is gone; also
  #                                                   the entry when a live fix PR only lacks cases)
  #                      \--> missions.rate_finalize (working-as-intended -> verification;
  #                                                   or proven-but-unsupported -> learnings)
  #                      \--> (no route: evidence incomplete -> escalate and stop)
  #
  # Each task is single-mode; the branch lives in the router, not in objective
  # conditionals — discover_sessions is the only task with no dependency, so a
  # webhook fires one stage, and it decides which entry the case takes. The four
  # entries differ only in how the session is obtained: the brief they give it and
  # the gates its result must pass live once, in the rate_investigation skill, and
  # the verdict schema and downstream routes live once in assess_investigation.
  # The durable know-how lives in skills the stage agents compose —
  # these objectives carry only what is specific to THIS case. All credentialed
  # I/O (gh, PR/Jira comments, staging queries) is Devin's; secrets stay in Devin.
  #
  # Objective convention, because a stage that misreads who an instruction is for
  # either does the session's job or relays its own constraints as the task:
  #   "You" / "# You do"      -> this Squadron stage. Never touches a repo.
  #   "the session" / "# Brief the session" -> text to put in the Devin task.
  #   "# Hold the session to" -> what to check on return, not text to send.
  # Repo mechanics are NOT restated here: the fix/cases/run/audit steps and their
  # path ownership live in txc-sqlserver-database's ratevariant-testing skill
  # (references/process.md), which the playbooks load. Cite the step; don't copy it.
  #
  # Blocking on a human, and resuming:
  #   The mechanics are the blocked_run skill, both ends of them — the entry
  #   steps for whichever stage a run starts at, and the close-out (end rather
  #   than wait, write the resume-state record, put the questions on the ticket)
  #   for whichever stage hits the wall.
  #   What is specific to this chain: the resume-state slot is rate_resume_state,
  #   path <TICKET>.md; a Jira automation fires /ratevariant when a comment lands
  #   on a labelled ticket, so the answer arriving is the trigger; and the
  #   resumption is not a re-do — discover_sessions reads that file and finds the
  #   ticket's sessions by tag, so a live investigation or fix session is
  #   continued in place and the case re-enters at the mission and stage that
  #   blocked. A human can still force a lane with wai_challenge or a session-id
  #   override.
  memories = [memories.rate_resume_state]

  agents = [
    agents.session_scout,
    agents.rate_investigator
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
    # Jira automation fires on a comment to a TaxRates:Needs-Info ticket.
    webhook_path = "/ratevariant"
    secret       = vars.ratevariant_webhook_secret
  }

  task "discover_sessions" {
    objective = <<-EOT
      Decide how the investigation of ${inputs.issue} starts, from what this ticket already has.
      You read only: no session is created, messaged, or briefed in this stage.

      # You do

      1. `file_read` the `rate_resume_state` slot, path `${inputs.issue}.md`. If it exists, a prior
         run on this ticket stopped on something a human had to supply, and that file says what:
         the questions outstanding, which stages already finished, and their PRs. This run is the
         resumption of that one. Absent file means either a first run or a case that closed.
      2. find_sessions(tags: ["${inputs.issue}"]). Every stage tags its sessions with the ticket
         key, so this is the whole history of the ticket: prior investigations, fix sessions, case
         sessions, verifications. Zero matches is a real answer, not a failure.
      3. check_session on each candidate that could be an investigation (tagged
         `rate-investigation` or `verify-wai`, or titled as one). A search result gives status and
         PR links; only the session itself says whether it reached a verdict, and what of.
      4. Honor the overrides if they are set — they are a human or an automation telling you
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

      # If the session API refuses you

      An authorization failure on find_sessions or check_session — a 403, a permissions error — is
      not an answer about this ticket's history; it means you cannot see the history, which is a
      different thing from there being none. Do not read it as zero matches, and do not end the run
      on it either. Instead:

      - Fall back to the ids the resume-state file records. It names the sessions a prior run opened
        and whether each was messageable, which is what the search would have told you, so a
        resumption survives the search being unavailable. Try check_session on those ids; where that
        is refused too, take the file's account of each session's state and say that is where it
        came from. The stage you route to finds out for certain when it sends: a refused send is the
        correction, so state a belief downstream rather than a fact. Set history_provenance to
        `recorded` and name the call that was refused, so downstream reads those states as the
        file's account rather than as something you confirmed.
      - With no resume-state file and no readable history, route `start` and set history_provenance
        to `none`, naming what was refused. That reading is safe for this case and only this case: no run
        of this flow got far enough to write a state file, so there is no lane of ours to abandon.
        What it does not rule out is a session someone opened by hand, or one predating the state
        file, so a collision the search would have caught can still be live — which is why every
        stage downstream is told the start was blind.
      - Never infer any mode other than `start` from a failed read, and never report a ticket as
        having no history when what happened is that you were refused. On the ordinary path, where
        both calls answered, history_provenance is `read` — it is stated on every run, so a reader
        never has to infer from its absence that the history was seen.

      # What you are deciding

      First, whether this run re-enters the flow past the investigation at all. The resume-state file
      records which stage the last run blocked at, and a ticket that stopped in case authoring or
      bruno does not need another investigation — re-running one wastes the expensive stage and
      risks a second verdict that disagrees with the one the fix was built on. So if the file names
      a blocked stage downstream of assessment, and the verdict and fix PR it records are intact,
      set resume_stage to that stage and carry its state (fix PR, session ids, what was
      outstanding). Say in resume_state that the stage you route to is this run's entry, so its
      session does the blocked_run entry steps — clearing the label is the entry's job wherever the
      run re-enters, and you hold no credentials to do it yourself.

      Anything unclear — no verdict recorded, the PR gone, the file contradicting the sessions you
      found — is not a resume: leave resume_stage blank and pick an entry mode, since re-deriving is
      recoverable and resuming on a wrong premise is not.

      Otherwise, one entry mode, and the state the chosen entry needs. Distinguish carefully,
      because each wrong answer costs a different way: routing a live session to start_investigation
      abandons work and can produce a second contradictory verdict; routing a terminated one to
      continue_investigation strands the mission on a session that cannot be messaged.

      - No investigation session exists → `start`.
      - A prior investigation concluded working-as-intended and this run is challenging it (a
        wai_challenge, or a verify-wai session that refuted it) → `confirm_wai`.
      - An investigation session exists and can still be messaged — running, waiting on a
        message, or finished-but-resumable → `continue`.
      - An investigation session exists but is terminated, expired or archived, so it can be read
        and not messaged → `forward`.

      Expect more than one match — a re-fired ticket accumulates them — and pick per
      delegated_session's order: a messageable session beats a closed one even when the closed one
      got further, because `continue` keeps a lane you can still question while `forward` inherits
      a report you cannot. So two investigation sessions where one is live and one is terminated is
      `continue` on the live one, with the terminated one's conclusion carried in prior_context as
      a second opinion — attributed, not blended into one account. Name the sessions you passed
      over in sessions_found: the stage you route to inherits this choice without re-searching.

      A fix PR is not itself an entry mode: it is state. If any session for this ticket already
      opened a fix PR in ${inputs.repo_url}, put it in existing_fix_pr_url and say which session
      opened it — the fix may exist while its A/B coverage does not, and the assessing stage
      routes on that. Confirm it is this ticket's fix and not an unrelated PR the session touched.

      Return the mode, the one session id it applies to, that session's state, whatever verdict
      the read already found, and the prior context worth carrying — what was established, what
      was left open — so no downstream session re-derives what is already known.

      Carry the resume-state file forward verbatim in resume_state when there is one. Downstream
      stages route on it: work a prior run finished is not re-done, and a question already answered
      is not asked again.

      You cannot read the ticket — no Atlassian credentials here — so you do not judge whether the
      open questions were answered. Hand them to whichever stage you route to as questions to check,
      and the session it briefs (which can read the comments) makes that call per blocked_run. A
      resumption where nothing came back usable is an escalation, not a failure: that stage ends the
      run again, with the questions sharpened.
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
        description = "author_tests | audit | bruno_tests | record_learnings, when the resume-state file says the last run blocked at that stage AND the verdict and fix PR it records are intact — the flow re-enters there instead of investigating again. Blank otherwise, which is the default: a doubt about the recorded state is a reason to leave it blank."
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
        description = "What prior sessions established and what they left open, with the session each came from — the briefing material that stops a downstream session re-deriving known work. Blank on start."
        required    = false
      }
      field "resume_state" {
        type        = "string"
        description = "What rate_resume_state/<TICKET>.md said a prior run was waiting on and which stages it had already finished, plus which of those questions this run's inputs answer, and — when there was a file — that the routed stage is this run's entry and owes the blocked_run entry steps. Blank when there is no such file: a first run, or a closed case."
        required    = false
      }
      field "sessions_found" {
        type        = "string"
        description = "The tagged sessions found for this ticket — id, stage tag, state — and one line on why the chosen one was chosen over the others. Where the search was refused rather than empty, say so instead of reporting no history."
        required    = true
      }
      field "history_provenance" {
        type        = "string"
        description = "How you came to know this ticket's session history, always stated: read (the search and the session reads answered), recorded (a call was refused — name which — and you fell back to the resume-state file's ids and states), or none (refused with no state file to fall back on, so the mode is start and was chosen blind). Downstream needs this, because a verdict reached without knowing whether another session is already on the ticket carries that caveat, and it is an operational fact about our run rather than a finding about the tax behavior."
        required    = true
      }
    }

    router {
      route {
        target    = missions.rate_fix
        condition = "resume_stage is author_tests, audit or bruno_tests — a prior run proved the defect and shipped the fix PR, and blocked somewhere in the implementation/A-B lane. The investigation is done; re-running it risks contradicting the verdict this fix was built on. Pass entry_stage = that stage, and fill every fix-lane input from the resume-state file and the sessions you found: the PR, the branch, the fix and cases session ids and whether each is messageable. rate_fix cannot query this ticket's history — what you do not carry across, it does not have."
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

      If discover_sessions reported history_provenance as anything but `read`, this `start` was
      chosen without being able to see whether anyone is already on the ticket. Say so in the brief,
      so the session knows its verdict may be a second opinion rather than the only one, and returns
      that in its structured output — which, with this stage's result, is where a human sees that a
      blind start happened.

      Tell it that plainly and leave it there: this is an operational fact about our run, and the
      brief is not a source of ticket copy. It reaches the ticket, if at all, only as the hedging its
      own writing skill already requires of an unconfirmed finding. A brief that instructs the
      session to state a refused lookup on the ticket gets a comment opening on our tooling, in front
      of a reader who can do nothing with it.

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

      # When the run stops here

      EVIDENCE_INCOMPLETE has no route: the gap needs a human, and this run ends. Close it out per
      blocked_run — resume-state slot `rate_resume_state`, path `${inputs.issue}.md`, blocked at this
      stage — and the session that gets told to post is the investigation session, or the fresh
      read-only one you opened to close gaps if that one cannot be messaged.

      What this stage specifically owes the file: the exact artifacts that would close each gap
      (whose transaction ids, which published rate and period), not a restatement that evidence was
      incomplete.

      Split those artifacts by who can supply them before you send anything. A tax or product call
      is a ticket question; a read-out of production is an engineer's, so it goes in this task's
      output and stays off the ticket. Then send the questions themselves — a comment body you
      drafted is followed over the session's own writing skill, and yours is built from the verdict
      name, the mechanism and the queries you wanted run.
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
        condition = "verdict == DEFECT_PROVEN and evidence_complete == true and disposition != 'unsupported at available granularity' — a located, traced defect this system can actually express. Set entry_stage: author_tests when existing_fix_pr_url is not blank AND fix_session_messageable == true (a prior run already implemented the fix and its session is still reachable, so the fix lane has an owner audit can route findings to — what the ticket is missing is A/B coverage of the PR that exists); develop otherwise, whether no fix exists yet or one exists whose session is gone and develop must adopt it. The fix lane must have a session that can still be messaged before audit starts, since audit routes fixes and never opens a session. Fill mechanism, disposition, affected_roots and evidence from this task's output verbatim: rate_fix has no access to it and must not re-derive the diagnosis."
      }
      route {
        target    = missions.rate_finalize
        condition = "verdict == WORKING_AS_INTENDED (entry_stage = verify_wai — no defect claimed, so the claim gets an independent check) OR verdict == DEFECT_PROVEN with disposition == 'unsupported at available granularity' (entry_stage = record_learnings — the mechanism is proven and this engine cannot express the remedy, so the limitation IS the deliverable and belongs in limitations.md under the labelled ticket it instances. A scoped partial fix may still be worth filing separately — what develop must not do is present one as closing the class. Routing it to rate_fix instead buys a clean-looking diff that papers over a modelling gap at state-wide blast radius. The ticket's own writeback (comment, new-rate-engine label, Blocked) is the investigating session's, since it holds the Jira credentials). Carry limitation_class, mechanism and evidence across; on the WAI lane carry wai_refire_count so the standoff stays capped."
      }
      # EVIDENCE_INCOMPLETE → no route: the mission completes with the missing
      # evidence named, for a human to supply. Do NOT route it onward.
    }
  }
}
