mission "Ratevariant A-B" {
  commander {
    model = models.anthropic.claude_opus_4_7

    compaction {
      token_limit    = 250000
      turn_retention = 3
    }

    tool_response {
      max_tokens = 250000
    }
  }

  # Routed graph (Squadron is acyclic — no backward edges):
  #   develop --router--> author_tests (a fix landed)         --send_to--> audit
  #                  \--> verify_wai   (working-as-intended)  --router--> this mission
  #                                                                       (new instance, capped)
  #   audit   --router--> bruno_tests  (verdict SATISFACTORY: lock the settled fix into Bruno)
  # Each task is single-mode; the branch lives in the router, not in objective conditionals.
  # The in-run loop is audit <-> Devin via send_message; verify_wai re-fires the mission once
  # (capped), and bruno_tests is a one-shot leaf. All credentialed I/O (gh, PR/Jira comments,
  # staging queries) is Devin's; secrets stay in Devin.
  agents = [
    agents["TaxCloud Support Engineer"],
    agents.CodeGen,
    agents["Quality Assurance"]
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

  input "wip_develop_session_id" {
    type        = "string"
    description = "Optional: an existing in-flight Devin session to resume for the develop step (an automation already started it, or a prior instance's session being re-validated). Blank = create a new session via code_develop."
    default     = ""
  }

  input "stale_develop_session_id" {
    type        = "string"
    description = "Optional: an existing, but expired/archived, Devin session that previously ran the develop step. Blank = create a new session via code_develop."
    default     = ""
  }

  input "wai_challenge" {
    type        = "string"
    description = "Optional authoritative challenge from a prior run — a working-as-intended conclusion that verify_wai refuted, with the rebuttal and an instruction to re-validate skeptically and annotate the prior Jira comment. Blank on a first run."
    default     = ""
  }

  input "wai_refire_count" {
    type        = "number"
    description = "How many times this ticket has been re-fired after a working-as-intended refute. Caps the develop<->audit standoff: verify_wai will not re-fire once this is >= 1."
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
  # Task — develop. Resolve the ticket via the !txc-support playbook, label the PR
  # so ratevariant can run, and route on the outcome: a labeled PR -> author_tests,
  # working-as-intended (no PR) -> verify_wai. Startable task (no deps).
  # ---------------------------------------------------------------------------

  task "develop" {
    objective = <<-EOT
      Resolve ticket ${inputs.issue} in ${inputs.repo_url} with the TaxCloud
      Support Engineer agent via the !txc-support playbook. The playbook owns the
      fix and the PR — trust it. You hold no GitHub credentials: Devin runs every gh
      command below; you only instruct the session and relay what it returns.

      Do NOT suggest using any sort of "testing skill" or "write-back". Devin does not
      have any "testing skills" so it tries authoring worthless md files.

      %{ if inputs.wai_challenge != "" ~}
      Re-validation context from a prior run:
      ${inputs.wai_challenge}
      Treat this as authoritative: a previous attempt concluded working-as-intended and
      verify_wai challenged it. Re-validate your original assessment against that
      counter-evidence — be skeptical of the prior conclusion, but the WAI challenge may
      also be wrong; determine the truth from the data, don't simply defer to either.
      Also have Devin annotate the prior Jira comment(s) as under investigation and/or
      potentially erroneous.
      %{ endif ~}

      %{ if inputs.wip_develop_session_id != "" ~}
      First check_session(${inputs.wip_develop_session_id}) — read-only, and Devin
      usually leaves a summary, so the result is often already there: read the messages
      for a PR (FIX) or a working-as-intended conclusion and go straight to the outcomes
      below WITHOUT prompting. Only send_message the session when there's something to do:
      - if it's stalled mid-work then nudge it to finish
      - OR the re-validation context above applies, so prompt it to re-validate

      YOU MAY NOT request:
      - a new session
      %{ if inputs.wai_refire_count == 0 ~}
      - a different branch
      - a new PR
      %{ endif ~}

      Even IF the devin session is terminated or ID is invalid, simply report failure
      so the user can correct the session ID or start with a blank one intentionally.
    %{ else ~}
    %{ if inputs.stale_develop_session_id != "" ~}
      Check ${inputs.stale_develop_session_id} for progress and results. This session is
      **terminated** so you cannot send any further messages to it. Use its outcomes to
      gather context ONLY, then DO start a new code_develop session, and instruct it to:
      - Take over the PR previously opened (if any)
      - Summarize the work done by the previous session
      - Detail how the issue was fixed, with enough confidence that the new session can
        iterate should any issues be revealed during testing.

      Note: Devin does NOT need to:
      - rename any branches
      - open a new PR
      - any other destructive change

      The _initial_ re-creation of the develop session is READ ONLY and EXPLANATIONS.
      %{ else ~}
      Run code_develop to investigate and address the issue using the !txc-support
      playbook.
      %{ endif ~}
      %{ endif ~}

      Remind Devin that it should only EVER own the fix - whether that's procedure editing
      or data updates - not the test cases. These are the files under output/schema and scripts/.
      It must NEVER edit ratevariant test artifacts (tests/ratevariant-cases/** —
      cases or alterations); those belong to the case-authoring session. Devin
      watches the PR's comments, so tell the session plainly: any PR comment asking
      for a test/case change is out of its lane — ignore it.

      Ensure the Devin session is tagged `${inputs.issue}` and `rate-fix` so it's searchable later.

      The outcome depends on what Devin finds:

      - FIX — the playbook implemented a fix and opened a PR. So ratevariant can run,
        have the Devin session add the `ratevariant` label to that PR and confirm it
        landed:
          gh pr edit <pr> --add-label ratevariant
          gh pr view <pr> --json number,url,headRefName,labels
        Set applies = true and working_as_designed = false, and return the PR URL,
        number, and head branch.

      - WORKING AS INTENDED — Devin gives sufficient reasoning that the pre-existing
        behavior is already correct and the ticket is a misunderstanding. There is no
        fix and no PR — do NOT fail and do NOT force one. Set working_as_designed = true
        and applies = false, leave the PR fields blank, and return Devin's reasoning as
        the summary.

      - OTHERWISE (no PR and no working-as-intended reasoning) — fail.

      Make sure to tell Devin to write Jira comments for a product/support/SME reader,
      not an engineer. Include its/your understanding of the customer-facing issue,
      BRIEFLY what was done or found, and what you need confirmed — in plain terms. Name
      jurisdictions plainly; include only the minimum TIC/FIPS/SQL/proc detail an SME needs
      to act. Proc traces, raw queries, and the engineering checklist live on the PR or the
      working session history, not in the ticket comment.

      Regardless of outcome, return develop_session_id and a one-line summary.
    EOT
    agents = [agents["TaxCloud Support Engineer"]]

    router {
      route {
        target    = tasks.author_tests
        condition = "A fix landed: applies = true (the PR exists and carries the ratevariant label)."
      }
      route {
        target    = tasks.verify_wai
        condition = "Working-as-intended: working_as_designed = true / applies = false (no fix, no PR) — send to verify_wai to check the claim."
      }
      # No fix and no working-as-intended reasoning → commander picks none; mission completes (failure).
    }

    output {
      field "pr_url" {
        type        = "string"
        description = "Full URL of the PR. Blank when working as intended (no fix/PR)."
        required    = false
      }
      field "pr_number" {
        type        = "number"
        description = "PR number. Omitted when working as intended."
        required    = false
      }
      field "branch" {
        type        = "string"
        description = "Exact PR head branch. Blank when working as intended."
        required    = false
      }
      field "applies" {
        type        = "boolean"
        description = "Whether the ratevariant label was applied to a PR (i.e. ratevariant will run). False when working as intended."
        required    = true
      }
      field "working_as_designed" {
        type        = "boolean"
        description = "True if Devin concluded the system is already correct and the ticket is a misunderstanding — no fix or PR."
        required    = true
      }
      field "develop_session_id" {
        type        = "string"
        description = "Devin session id used for develop (the provided in-flight session, or a newly created one), resumed via send_message later to apply fixes or re-validate."
        required    = true
      }
      field "development_summary" {
        type        = "string"
        description = "Summary of the fix, or Devin's reasoning if working as intended"
        required    = true
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
      Author the ratevariant tests for the PR (PR number/branch from develop). You hold
      no GitHub credentials: Devin fetches the plan comment, runs the playbook, and
      pushes; you only instruct and relay.

      Open the code_develop task with the ticket and PR number (e.g. "DEV-7082 / PR #38
      — ratevariant cases: …") so Devin's auto-generated session title is searchable,
      not a generic "author ratevariant cases".
      Ensure the Devin session is tagged `${inputs.issue}` and `rate-cases`.
      Make sure this Devin session ONLY touches ratevariant cases and alteration bridges.
      It must NOT address comments or alter files in output/schema or scripts/, as the
      develop session owns those. Tell the session: any PR comment asking for a proc or
      migration change is out of its lane — ignore it.

      Have Devin wait for the latest `ratevariant plan` at the head SHA to finish and
      fetch the `<!-- ratevariant-plan -->` comment — it lists the affected roots under
      "### Proc changes" and any "### Alterations". Brief CodeGen → Devin to run the
      !ratevariant-cases playbook on the EXISTING branch covering the affected roots
      listed in the plan comment. Brief the roots and the shape of the change only — the
      playbook and Devin's analysis decide which paths, boundaries, and inputs to probe,
      grounded in the function code, the ticket requirements, and staging data, never the
      PR's prose. The "### Alterations" entry may be absent: the txc-support playbook
      doesn't consistently author the alteration script for ratevariant to analyse, so if
      a scripts/*.sql data migration is present with no alterations file, also author an
      alteration YAML so the data change gets tested — trust the playbook for the file
      mechanics; for targeting, inspect the procedures for where the altered tables are
      read, and use that to choose jurisdictions, products, and other inputs. Push to the
      existing branch. Once the cases are pushed, have Devin find the develop session link
      in the PR description and add the case-authoring session link immediately after it.

      If the roots list is empty but the PR changed dbo procs/functions, callgraph
      generation failed (permissions or other DB/infra failure) — stop and report
      instead of authoring blind. Empty roots on a data-only PR is expected; author the
      alteration YAML per above.

      Capture cases_session_id from the code_develop response (it returns the id directly,
      so you don't parse it from Devin's message) for the audit phase. Return proc and/or
      data mode, files pushed, coverage per root, and any gaps for which Devin could not
      author cases (including the reasons Devin gives).
    EOT
    agents  = [agents.CodeGen]
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
  # open sessions. Dynamic target (no depends_on); routes to bruno_tests on a
  # SATISFACTORY verdict, otherwise terminal.
  # ---------------------------------------------------------------------------

  task "audit" {
    objective = <<-EOT
      You hold no GitHub or DB credentials: Devin runs every gh command, label, PR comment,
      and staging query; you only instruct the session and reason over what it returns.

      Drive the run + audit loop for the PR (branch, PR number, mode from prior outputs).
      Skip if nothing was pushed since the last run. Two open sessions to work through:
      develop_session_id (the fix) and cases_session_id (the cases). Do ALL your Devin work
      through those two via send_message and check_session — the A/B run (label/fetch), your
      staging queries, and every routed fix. Never open a new session and never run a code_qa
      review: your judgment stays independent, but the work runs in the session that owns it —
      a bad fix goes back to develop_session_id, missing or weak coverage to cases_session_id.

      Note that a pre-existing `develop_session_id` **MAY** not have staging database credentials
      loaded, as those were added in the middle of developing this workflow. Have Devin check `.env`
      for these definitions if the sqlprobe commands fail. ***IF*** `develop` says it cannot access
      the staging database, then it requires these variables:
      - RATEBENCH_DB_HOST=qa4mi.public.e1c3101cc0f3.database.windows.net
      - RATEBENCH_DB_PORT=3342
      - RATEBENCH_DB_NAME=FedTax-20260521
      - RATEBENCH_FEDTAX_DB=FedTax-20260521
      - RATEBENCH_REPORTS_DB=Reports-20260521
      - RATEBENCH_DB_USER=devin_review
      - RATEBENCH_DB_PASSWORD (provided via human, using a secret request from Devin)

      Do NOT preemptively have Devin request a password; wait for it to say it cannot access staging
      before sending the variables/password secret request instructions.

      The `20260521` databases ARE the current, fresh, data available to us. Do not ask for
      newer datasources, there are not any. Treat that data as authoritative: do not discount
      a finding based on the grounds that this snapshot is stale or incomplete. If merchants
      or transactions are missing, push Devin to find comparable substitutes. Only if that is
      genuinely not possible, should you report that as a gap.

      Loop until SATISFACTORY or WORKING_AS_DESIGNED, max 3 iterations:
      1. RUN — have Devin wait for the latest `ratevariant plan` at the head SHA to pass,
         then add the `ratevariant:run` label to fire the run. Wait for it and return the
         result comment for the current SHA (PROC → `<!-- ratevariant-result -->`, DATA →
         `<!-- ratevariant-alter-result -->`). The plan passing proves NOTHING about
         behavior — it only shows mechanical name/DB rewrites. Only the run's per-case
         captures validate. Note the run workflow removes the `ratevariant:run` label
         each time (the `ratevariant` plan gate persists); each iteration you must wait
         for the new head SHA's plan to pass, then re-add `ratevariant:run` to re-fire.

      2. AUDIT — green is not a pass, and a diff is not a pass. Anchor predictions in the
         TICKET's required outcome and your map of the actual PR diff (read the changed
         proc/fn bodies) — NOT the PR description, which is sometimes wrong about its own
         change. For EVERY case, compare the actual result to what the ticket and that code
         map predict, and prove the number is RIGHT, not just present. Treat every "looks
         fine" as a hypothesis to disprove:
         a. Primary positives must differ AND to the correct value. Decompose the expected
            rate against the data and confirm the captured value equals it — a diff to the
            WRONG number reads as success but is a bug. (e.g. DEV-8126: cart correctly
            differed 10.50%→7.25%, but the target was 9.75% — the override zeroed the whole
            3.25% CITY bucket instead of only the 0.75% city portion, dropping district tax
            that should have stayed.) If the ticket states a target outcome, decompose THAT
            against the data too — if the data contradicts it, that's WORKING_AS_DESIGNED,
            not a fix to chase.
         b. A primary positive that does NOT differ means the change didn't reach that path.
            Two prime suspects, verify reachability (have Devin query staging) before
            concluding:
              · Shadowed branch — the change sits in the else/tail of a CASE whose leading
                WHEN already catches the normal input. (e.g. DEV-1927 reports: the shipping
                `ISNULL(itemPriceTaxable,…)` sat after a `WHEN ItemPrice>0` that always won
                — dead until the WHENs were reordered.)
              · The probe didn't exercise the change — stale/out-of-window inputs, not the
                code. (e.g. DEV-8126 reports: the tx date predated the override's
                PeriodStart, so neither arm consulted it → false no-diff; fixed by patching
                the date into the window.)
            A no-diff is never by itself evidence the fix is correct — it means the change
            didn't reach the captured output; diagnose which. The harness DOES support data
            overrides via case fixtures (apply/teardown on both arms), so "the harness can't
            mock table X" is never a valid basis for a verdict: if reaching the branch needs
            altered data, author the fixture or state precisely why it's infeasible. But
            treat the NEED for a fixture as its own signal — if a case only diffs after you
            patch a gating table, the branch may be dead on current data (the case is
            invalid), not merely untested (see c); weigh that before authoring the fixture.
            DEV-7082's WAI conclusion began exactly there — "I need to patch StatesTaxMatrix
            to get a diff."
         c. Distinguish UNREACHABLE from UNTESTED. A branch gated on a condition the engine
            already precludes is dead code, not a missing case — flag it, don't ask for a
            case that can't exist. (e.g. DEV-1927: "all items exempt → exempt shipping"
            gated on shipping `Rate>0`, but follows-cargo already zeroes shipping when all
            items are exempt — mutually exclusive. e.g. DEV-7082: extending the IL date
            cutoff in fnGetTaxSourceAddress_nonssuta was a no-op because
            States.UseOriginSourcing=1 for IL short-circuits the OR before the date branch
            is ever evaluated — the branch is dead on the current data, so the fix changes
            nothing.)
         d. Trace every path the change spans and confirm they AGREE: cart
            (spTransactionLookup), import (spImportOfflineTransactions), and Reports/filing
            ETL (spGenerateTransactionsWideForTx → fnGetTaxRatesforTx[_nonssuta]). Watch for:
              · imports decide taxability from the MERCHANT-CLAIMED rate, the cart from the
                computed rate — same order can split differently, and an import branch can
                be reachable when the cart's isn't.
              · an ETL-side no-op leaves the cart corrected but the FILING data wrong. The
                filing surface (TransactionsWide) is what gets remitted — always confirm the
                fix lands there, not just in the cart.
              · the filing surface must carry the right tax-area CODES, not just the
                right rate. Assert on TransactionsWide CityCode/CountyCode (driven by
                TDSData(NonSsuta) FIPS_CITY / CITY_RPT_CODE / COUNTY_RPT_CODE) — a
                correct total can still remit under the wrong jurisdiction. (DEV-8126:
                after the rate was right at 9.75%, the override still filed under Pomona
                — C03 / FIPS 58072 — not Unincorporated B47, because it nulled CITY_NAME
                but kept the base city's FIPS + rpt codes. The reports probe must capture
                and assert these codes, not just the rate.)
         e. DATA changes: the blast radius must match the migration exactly — the targeted
            jurisdiction differs, adjacent ones (neighboring plus4/zip, other periods) do
            NOT, and the teardown reverts cleanly. Watch for jurisdiction MISLABELING (a
            retained component filed under the wrong city/district) even when the total rate
            is correct.
         f. Separate noise from signal: per-execution columns — timestamps, identity IDs
            (TransactionWideID, Created_Date) — are noise and belong in the capture's Ignore
            list. A case that "differs" only on those is a no-diff (fix the Ignore list
            separately), and that no-diff may be MASKING a no-op change. (e.g. DEV-1927
            reports first surfaced only Created_Date/TransactionWideID while the tax columns
            were identical — the change hadn't taken effect.) Cases capture the root's full
            output by default (no explicit capture or column-filter section is needed) — the
            reporting codes from (d) are present without any override, so a missing capture
            section is normal, not a coverage gap.
         g. Ground every taxability claim in the data — StatesTaxMatrix, PostCalculateTICActions,
            TDSData(NonSsuta), SSTIDs, Locations — never intuition or the PR's prose, which is
            sometimes wrong about its own data. (e.g. DEV-8126 asserted city tax was 0.75% in
            CITY_SALES_TAX; the row actually held 3.25% with district lumped in.) Read columns
            from output/schema; have Devin query with indexed predicates (URLID + date), never
            scan — use ratebench's `cmd/sqlprobe` (go run ./cmd/sqlprobe with the query as an
            arg or on stdin) rather than scaffolding a querier.

      Verdict:
      - SATISFACTORY — intended diffs present, each to the CORRECT value, scope holds, no
        path divergence, and every path the change actually reaches has a case that ran.
        Whether a path is reached is decided by TRACING the code (per d), not assumed — a
        path goes uncovered only when you've PROVEN the change can't reach it (per c, e.g.
        the ETL never consults the changed table), never because a case was hard to build.
        Exit.
      - CASES_INADEQUATE — missing branch/path coverage, an ineffective probe (inputs
        don't reach the change), or a guardrail gap — including a reachable path left
        uncovered on a HEDGE ("no txid", "no staging access", "the ETL is expected to use
        the same lookup", "indirect evidence is strong") rather than proven not-applicable
        → send_message(cases_session_id) with the specific case(s)/probe(s) to add or fix
        (query or fixture the inputs per the playbook), including the inputs and expected
        values they must assert. Loop. Devin may need a reminder on how to access the
        staging database or generate fixtures.
      - FIX_OR_TICKET_WRONG — dead/shadowed branch, wrong resulting value, cart-vs-reports/
        import inconsistency, over-broad blast radius, or an ineffective fix → have Devin
        post a PR comment citing the file + the empirical case result that proves it, then
        send_message(develop_session_id) with ONLY that fix plus its supporting data. If the
        fix changes a scripts/*.sql migration, the mirroring alteration is now stale — also
        send_message(cases_session_id) to re-sync it to the new migration (develop's charter
        keeps it out of the alteration). Loop.
      - WORKING_AS_DESIGNED — the A/B, grounded in data, shows the fix changes nothing:
        either the pre-change behavior was already correct, or the changed branch is provably
        dead/unreachable (per c). WAI requires POSITIVE data (the decomposed correct value, or
        the precluding condition that kills the branch) — never merely an absent diff or an
        inability to construct one. The develop session made the change and is best placed to
        confirm it, so send_message(develop_session_id) with the data-grounded finding and
        have it: verify the finding in-situ against what it changed, then post a SINGLE
        SME-routing comment on the Jira ticket — product-level, for an SME reader: plainly why
        the fix is a no-op and what to confirm, with only the minimum data/SST basis (e.g.
        States.UseOriginSourcing=1 short-circuits the IL date branch); proc traces and raw
        queries stay on the PR / in the session. Leave a brief PR note so the reviewer knows
        it's a no-op. It must NOT push code, close the PR, or remove labels. Return the
        comment URL. Tell the cases session to stand down. Don't loop; exit.

      Resuming a session: pass ONLY the specific finding WITH its supporting data — the
      file/line, the case capture (expected vs actual values), and the data rows that prove
      it (e.g. the StatesTaxMatrix / override values you decomposed). A file reference alone
      is insufficient — the session should have a clear picture of the issue from what you
      provide without more than a handful of supplementary queries. Push to the existing
      branch; don't re-implement or open a new code_develop. Frame tax-law points as
      questions for the SMEs, not assertions. check_session after each run; track the
      iteration count and summarize what changed and why on exit.

    EOT
    agents = [agents["Quality Assurance"]]

    router {
      route {
        target    = tasks.bruno_tests
        condition = "verdict == SATISFACTORY — the fix is settled and correct, so author the Bruno regression suite. Do NOT route on WORKING_AS_DESIGNED (no fix to test); the in-session CASES_INADEQUATE / FIX_OR_TICKET_WRONG loops never reach here."
      }
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
      field "confirmed_findings" {
        type        = "string"
        description = "Confirmed bugs, dead/shadowed branches, wrong-value diffs, blast-radius/teardown issues, and path inconsistencies, each with the case result that demonstrates it"
        required    = true
      }
      field "working_as_designed" {
        type        = "boolean"
        description = "Whether the A/B concluded the fix was unnecessary (pre-change behavior already correct, revert)"
        required    = true
      }
      field "open_questions" {
        type        = "string"
        description = "Tax-law/eligibility questions for the ticket SMEs and coverage gaps left open"
        required    = false
      }
      field "final_summary" {
        type        = "string"
        description = "End-to-end summary; ends with the PR URL for human review"
        required    = true
      }
    }
  }

  # ---------------------------------------------------------------------------
  # Task — bruno_tests. Reached only on audit's SATISFACTORY verdict, so the
  # red/green API tests are written against a settled, correct fix — never one
  # still looping. Authors Bruno regression tests in txc-bruno via the
  # !bruno-regression playbook. Dynamic target (no depends_on); terminal.
  # ---------------------------------------------------------------------------

  task "bruno_tests" {
    objective = <<-EOT
      The fix is settled (audit returned SATISFACTORY). Author Bruno API regression tests
      that lock it in, in FedTax/txc-bruno. You hold no GitHub credentials: Devin clones,
      authors, and pushes; you only instruct and relay.

      Start a FRESH code_develop session on https://github.com/FedTax/txc-bruno and have
      CodeGen → Devin run the !bruno-regression playbook for ticket ${inputs.issue} against
      the fix PR (number/branch from develop). Open its task with the ticket
      (e.g. "${inputs.issue} — bruno regression: …") so the session title is searchable.
      Ensure the Devin session is tagged `${inputs.issue}` and `bruno`.

      Brief the session: read the ticket and the txc-sqlserver-database PR, draw a
      representative set of cases from the PR's test cases — the scenarios expected to
      change and the guardrails expected to stay flat — and author them under
      V3/Tax/Regression/${inputs.issue}[-TIC-NNNNN]/, following the existing folders. The
      tests assert the corrected rate/amount. Do NOT try to run them: Bruno executes against
      live staging, which requires the fix deployed there AND staging API credentials —
      neither is set up yet, so the tests genuinely CANNOT run, not merely "shouldn't." Author
      them and stop; running is a separate, future phase. Push to a branch and open a PR on
      txc-bruno.

      Capture bruno_session_id from the code_develop response. Summarize the scenarios the
      suite locks in — not a file list, the diff shows the files — and return the txc-bruno
      PR URL.
    EOT
    agents = [agents.CodeGen]

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
        description = "The scenarios the Bruno suite locks in (should-change + guardrails)"
        required    = true
      }
    }
  }

  # ---------------------------------------------------------------------------
  # Task — verify_wai. Reached only when develop concluded working-as-intended.
  # No PR, nothing to A/B — skeptically re-examine the claim. On a refute, re-fire
  # the mission once (capped by wai_refire_count) to get the fix made. Dynamic
  # target (no depends_on); carries a self-mission router.
  # ---------------------------------------------------------------------------

  task "verify_wai" {
    objective = <<-EOT
      Develop concluded the system is working as intended (no fix, no PR). There is
      nothing to A/B-run — your job is to skeptically verify that claim. You hold no
      credentials: Devin runs every staging query and Jira comment; you only instruct
      and reason.

      Run a FRESH Devin session for this check (a new code_develop) and re-derive from
      the data independently — don't resume develop's session, so the verification isn't
      anchored on its conclusion.
      Ensure the Devin session is tagged `${inputs.issue}` and `verify-wai`.
      (develop_session_id is still what you pass as wip_develop_session_id if you re-fire.)

      Note that the `20260521` databases ARE authoritative and reasonably fresh; do not tell
      Devin to go looking for newer data. Treat the data in them as accurate — don't discount
      a finding on the grounds the snapshot is stale or incomplete.

      Re-examine develop's reasoning (from the develop summary) against the ticket's
      reported behavior. Ground it in the data — StatesTaxMatrix, PostCalculateTICActions,
      TDSData(NonSsuta), SSTIDs, Locations — via Devin read-only staging queries (use
      ratebench's cmd/sqlprobe; indexed predicates: URLID + date, never scan), not
      intuition, develop's prose, or the ticket's own claim. Decompose the ticket's
      claimed-wrong rate and check whether the engine actually produces the correct value,
      or whether develop missed a real bug.

      - WAI_CONFIRMED — the pre-change behavior is correct and the ticket is a
        misunderstanding. Have Devin confirm the working-as-intended conclusion on the
        Jira ticket at product level — plainly why the system is behaving correctly and
        what the ticket misread, with only the minimum data/SST basis an SME needs
        (no proc traces or raw queries, those are in the session if someone needs them).

      - WAI_REFUTED — you find a real bug develop dismissed:
        · If wai_refire_count < 1: re-fire this mission (the self route) to get it fixed.
          Fill the inputs — same issue/repo_url/base_branch, wip_develop_session_id =
          develop_session_id (resume the investigation session), wai_refire_count =
          wai_refire_count + 1, and wai_challenge stating develop's prior WAI reasoning,
          your rebuttal WITH its supporting data (expected vs actual values, the data rows
          that prove it), and an instruction to re-validate skeptically — it may still be
          right, this verification may be wrong, determine the truth — and to annotate the
          prior Jira comment as under investigation.
        · If wai_refire_count >= 1: STOP. develop and this verification disagree twice —
          have Devin post the standoff to the ticket for an SME reader: both positions and
          what each turns on, in plain terms, with only the minimum data/SST basis each side
          rests on (proc traces and raw queries stay in the sessions). Route to the SMEs and
          exit. Do NOT re-fire.
    EOT
    agents = [agents["Quality Assurance"]]

    router {
      route {
        target    = missions["Ratevariant A-B"]
        condition = "You refuted develop's working-as-intended claim (a real bug exists) AND wai_refire_count < 1. If wai_refire_count >= 1, do NOT take this route — escalate to the SMEs and exit."
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
        description = "The data/SST basis for confirming or refuting, with the values that prove it"
        required    = true
      }
      field "final_summary" {
        type        = "string"
        description = "Summary; ends with the ticket link for human review"
        required    = true
      }
    }
  }
}