skill "devin_code" {
  description  = "Load when you use the code_develop tool in the Devin plugin"
  instructions = load("./skills/devin_code.md")
}

skill "devin_qa" {
  description  = "Load when you use the code_qa tool in the Devin plugin"
  instructions = load("./skills/devin_qa.md")
}

skill "devin_review" {
  description  = "Load when you use the code_review tool in the Devin plugin"
  instructions = load("./skills/devin_review.md")

}

skill "devin_txc_playbook" {
  description  = "Load when given a Jira ticket for a TaxCloud customer support issue. Delegates to Devin to diagnose root cause, implement a fix, create a PR, and post a structured summary back to Jira."
  instructions = load("./skills/devin_txc_support.md")
}

# ---------------------------------------------------------------------------
# Generic, composable skills. No repo, product, or domain assumptions — usable
# by any mission that delegates work to sessions and gates on their verdicts.
# ---------------------------------------------------------------------------

skill "evidence_gate" {
  description  = "Load whenever you make, relay, or accept a claim that a verdict, route, fix, or hand-off depends on. Defines the measured/traced/inferred/hedge basis labels, the gates a terminal verdict must pass, and why 'unknown' beats an inferred conclusion."
  instructions = load("./skills/evidence_gate.md")
}

skill "delegated_session" {
  description  = "Load when you do your work through a Devin session rather than yourself — you hold no credentials. Covers create-once/resume-after (code_develop then send_message, never a second session), reading results with check_session, and the finding/evidence/location re-brief format."
  instructions = load("./skills/delegated_session.md")
}

skill "session_lane" {
  description  = "Load when more than one session works the same change. Defines file lanes, routing a finding to the lane that owns it, ignoring out-of-lane PR comments, pushing to the existing branch, and keeping coupled artifacts in sync."
  instructions = load("./skills/session_lane.md")
}

skill "ab_audit" {
  description  = "Load when interpreting an A/B (baseline vs variant) run. Green is not a pass and a diff is not a pass: covers predicting from the diff rather than the PR prose, primary positives vs guardrails, diagnosing no-diffs as shadowed/unreachable/not-exercised/masked, fixtures as evidence, noise columns, blast radius, and the exit bar."
  instructions = load("./skills/ab_audit.md")
}

skill "verdict_loop" {
  description  = "Load when a stage can send work back to an earlier lane. Covers emitting one routable scalar verdict, bounding the loop, requiring new evidence per iteration, never laundering a failure into a pass at the cap, and handling stage-vs-stage disagreement."
  instructions = load("./skills/verdict_loop.md")
}

skill "blocked_run" {
  description  = "Load at both ends of a blocked case: when you are the first stage of a run (clear the sentinel label once, read the ticket's answers and judge whether each is enough to act on) and when you cannot finish without something only a human can supply (end rather than wait, the resume-state record for the next run versus the ticket comment for the human, what that index must contain, and the label that restarts the run)."
  instructions = load("./skills/blocked_run.md")
}

skill "sme_writeback" {
  description  = "Load when writing back to a ticket read by support, product, or subject-matter experts. One product-level comment, domain points framed as questions, engineering detail left on the PR and in the session."
  instructions = load("./skills/sme_writeback.md")
}

skill "learnings_capture" {
  description  = "Load at the end of a case to decide whether anything durable was learned and where it belongs. Most cases record nothing; generalizable traps go to the owning repo's skills/docs as a reviewable PR."
  instructions = load("./skills/learnings_capture.md")
}

# ---------------------------------------------------------------------------
# TaxCloud-specific layer. Thin: only what the generic skills above cannot
# know. Operational detail lives in the target repo's own skills.
# ---------------------------------------------------------------------------

skill "txc_rate_audit" {
  description  = "Load with ab_audit when auditing a TaxCloud tax-rate change. What to demand back from the auditing session — cart/import/Reports-ETL agreement, TransactionsWide filing codes not just the rate, decomposed expected values — plus a pointer to the repo's ratevariant-audit skill and its case-law index, which hold the procedure and the precedents."
  instructions = load("./skills/txc_rate_audit.md")
}

skill "rate_investigation" {
  description  = "Load when starting, continuing, or judging a tax-rate investigation. The brief every investigating session gets — read-only lane, limitations check, routing verdict, Jira writeback — and the gates its result must pass before anything routes on it."
  instructions = load("./skills/rate_investigation.md")
}

skill "txc_staging_access" {
  description  = "Load when a stage needs TaxCloud staging data. The dated snapshot is authoritative and must not be discounted as stale, credentials stay in the Devin environment, and queries go through the repo's query skills and ratebench sqlprobe."
  instructions = load("./skills/txc_staging_access.md")
}