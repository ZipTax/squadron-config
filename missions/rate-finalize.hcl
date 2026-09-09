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
  #                         \--> record_learnings (a closed case to write up)
  #   verify_wai     --router--> missions.rate_triage (WAI refuted, capped at one re-fire)
  #                         \--> tasks.record_learnings (WAI confirmed)
  #
  # Objective convention (same as the other two): "You"/"# You do" is this
  # Squadron stage, "the session"/"# Brief the session" is text for the Devin
  # task. Every Jira comment, query and write-back PR here is a Devin session's
  # work; the sentinel label is the stage's own, per blocked_run.
  memories = [memories.rate_case_log, memories.rate_resume_state]

  agents = [
    agents.session_scout,
    agents.wai_verifier,
    agents.learnings_curator
  ]

  # ---------------------------------------------------------------------------
  # Inputs — the typed handoff from rate_triage or rate_fix. Task outputs do not
  # cross a mission boundary, so the close-out's material is declared here.
  # ---------------------------------------------------------------------------

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
    description = "Why the case arrived here, in a phrase: 'fix audited SATISFACTORY and bruno regression authored', 'audit FIX_IS_NO_OP', 'proven but unsupported at available granularity', 'working as intended', or the stage a prior run blocked at. record_learnings routes on it — the unsupported entry is the one where recording is not discretionary."
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

  input "audit_findings" {
    type        = "string"
    description = "From rate_fix: the confirmed bugs, dead/shadowed branches, wrong-value diffs and path inconsistencies, each with the case result that demonstrated it. Blank when no A/B ran."
    default     = ""
  }

  input "open_questions" {
    type        = "string"
    description = "Anything left outstanding by the fix lane: tax-law questions for the SMEs, coverage gaps, bruno scenarios unwritten for want of an authoritative figure. Non-blank means the case is not really closed and the resume-state file gets written rather than deleted."
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
    description = "The session holding the investigation. verify_wai passes it back as wip_investigation_session_id if it re-fires; record_learnings asks it for its own two learnings. Blank when none survives."
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

  input "resume_state" {
    type        = "string"
    description = "What rate_resume_state/<TICKET>.md said this case was waiting on and which stages finished, plus the run marker a resumption needs. Blank when there was no such file."
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
      The case for ${inputs.issue} has reached its close-out, at `${inputs.entry_stage}`, because:
      ${inputs.close_reason}. Establish what is still reachable, then route. You read only: no
      session is created, messaged, or briefed here.

      # You do

      check_session on each session this case produced — investigation
      ("${inputs.investigation_session_id}"), fix ("${inputs.fix_session_id}"), cases
      ("${inputs.cases_session_id}"), bruno ("${inputs.bruno_session_id}") — and say which can
      still be messaged. Both terminals need that answer and neither should discover it by
      sending: record_learnings asks every open session for its own two learnings, and verify_wai
      passes the investigation id back if it re-fires. find_sessions(tags: ["${inputs.issue}"]) if
      an id is missing but a lane clearly ran; a session the handoff dropped is still findable by
      tag.

      Route on `${inputs.entry_stage}` — verify_wai only when a working-as-intended claim has not
      yet been independently checked, record_learnings for every other close-out. Do not re-verify
      a claim verify_wai already confirmed.

      Return the routed terminal and the reachable sessions.
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
        condition = "entry_stage == record_learnings — the case is closed (fixed and audited, a no-op fix, a proven-but-unsupported mechanism, or a confirmed working-as-intended), so what is left is deciding what it leaves behind."
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
        · If wai_refire_count (${inputs.wai_refire_count}) < 1: re-fire the chain at rate_triage.
          Fill its inputs — same issue/repo_url/base_branch, wip_investigation_session_id =
          investigation_session_id, wai_refire_count = ${inputs.wai_refire_count} + 1, and wai_challenge
          stating the prior WAI reasoning, your rebuttal WITH its supporting data (expected vs
          actual, the rows that prove it), and an instruction to re-validate skeptically — it
          may still be right, this verification may be wrong, determine the truth — and to
          annotate the prior Jira comment as under investigation.
        · If wai_refire_count (${inputs.wai_refire_count}) >= 1: STOP. Two rounds of disagreement is a human decision — have
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
        condition = "verdict == WAI_REFUTED (a real defect exists) AND wai_refire_count < 1 — the case goes back to triage with the challenge, which routes it to confirm_wai for an independent re-investigation. Pass wai_challenge (the prior reasoning, your rebuttal with its data, and the instruction to re-validate skeptically), wip_investigation_session_id = investigation_session_id, and wai_refire_count + 1. If wai_refire_count >= 1, do NOT take this route — escalate to the SMEs and exit."
      }
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
      The case for ${inputs.issue} is closed. Decide whether anything durable AND new was
      learned, per the learnings_capture skill. The default answer is no — and a rule already
      written down, in any of the places below, is not new: re-stating it in a second place is
      how two sources of truth start disagreeing.

      What this case ended on: ${inputs.verdict} — ${inputs.close_reason}. The mechanism was
      ${inputs.mechanism}. The fix PR, if there was one, is ${inputs.fix_pr_url}, and the audit's
      confirmed findings were: ${inputs.audit_findings}

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

      Which sessions those are, and which can still be messaged, is enter_finalize's
      reachable_sessions. An unmessageable one contributes its report and nothing more, per
      delegated_session.

      Their answers are candidates, not learnings: hold each to the same bar as your own —
      durable, new, citable, and not already written down. A session's frustration with a
      one-off flake is not a rule.

      One entry point is not discretionary: a disposition of "unsupported at available
      granularity" (this case: ${inputs.disposition}) means a proven instance of a deferred
      limitation, and limitation_class ("${inputs.limitation_class}") names the entry it instances, so it is recorded in the
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

      This one is yours, not a session's: you read and write it with your own file tools, and it
      never becomes a file in a repo — if the slot won't attach, say so and record nothing rather
      than asking a session to commit it somewhere.

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

      # Resume state

      Last, settle the ticket's `rate_resume_state` file, path `${inputs.issue}.md`:

      - Anything still outstanding (the lane reported: ${inputs.open_questions}) — an unanswered
        question, a bruno scenario left unwritten for
        want of an authoritative figure, a coverage gap nobody could close, a WAI still contested
        — means the case is not really closed. Write the file: what is outstanding, who has to
        answer it, which stages finished and their PRs, and where the next run resumes — the full
        contents blocked_run specifies, including the run marker a resumption needs to tell new
        ticket replies from the ones already read. Overwrite any existing file; it is current
        state, not history.
      - Nothing outstanding: `file_delete` it if it exists. A stale resume-state file makes the next
        run resume a case that already closed, and it will believe the file over the ticket.

      When something outstanding needs a person, the ticket side of blocked_run applies here too:
      your session posts the questions and you set the label yourself with `editJiraIssue`, as an
      add on labels rather than a write of the whole list. This is the normal closure path, not the
      only one — a stage that ends the run before reaching you does its own close-out.

      Hand it over as what is undecided, not what the chain got done. A lane that finished tempts a
      completion report — the change built, the A/B clean, the paths agreeing — and that reads on the
      ticket as approved, which is the opposite of asking. What reaches this audience is per
      sme_writeback and the session's own writing skill; the run's work is already on the PR, which
      is where the person who cares about it looks.
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
      field "resume_state" {
        type        = "string"
        description = "What was left outstanding and therefore written to rate_resume_state/<TICKET>.md, or 'none — file deleted' when the case closed clean. Never blank: silence here is indistinguishable from a stale file."
        required    = true
      }
    }
  }
}
