# Briefing and judging a rate investigation

Four stages start or resume a rate investigation, and one stage judges what comes back. They
share this brief and these gates, so a verdict means the same thing whichever entry the case
came in through. What differs per stage is only *how the session is obtained* — that stays in
the objective.

## The brief — put this in the session's task text

In these words or close to them:

- Your lane is evidence, not change: do NOT create a branch, commit, open a PR, or edit any
  file. The deliverable is the investigation report plus one Jira comment.
- Check `ratevariant-audit/references/limitations.md`: the tickets carrying the
  `new-rate-engine` label, whose general remedy was deferred to the new engine. A match is only
  a match once the mechanism is established from data at this ticket's scope: the symptom does
  not tell you which entry applies, and the same wrong CA rate can genuinely be a boundary-data
  problem or genuinely be a mixed-sourcing one. Where it is an ordinary mechanism, it is an
  ordinary fix regardless of the ticket's labels, and even on a match a scoped partial fix stays
  legitimate — this is best-effort work. Unproven hypotheses live in
  `references/open-theories.md` and are not limitations.
- Emit the routing verdict in your structured output — DEFECT_PROVEN, WORKING_AS_INTENDED, or
  EVIDENCE_INCOMPLETE — alongside the question-matched verdict you reason in (`Discrepancy
  explained` etc.) and the mapping you used.
- Post one product-level Jira comment per the sme_writeback format. State it at the strength the
  evidence carries: where the load-bearing claims are measured or traced and the gates pass, say
  plainly what the data shows; where any of it is inference, hedge and name what would settle it.
  Proc traces and raw queries stay in the session.
- If the disposition is that this engine cannot express the general remedy, that is the
  deliverable, and it still gets recorded on the ticket: post the comment stating the limitation
  for the SMEs, apply the `new-rate-engine` label, and move the ticket to Blocked. Do not author
  a fix to have something to show — but do say whether a scoped partial fix would help, since
  deferring the class does not forbid patching a case.

A session that is being *continued* gets only the part it has not already done. Repeating the
whole brief to a session mid-investigation invites it to start over.

## The gates — check these on return, before anything routes

A structured verdict absent from a finished session is a stage failure, not an invitation to
derive one from the prose summary.

- The verdict answers the question the ticket actually asked, without narrowing the scope it was
  asked at (merchant, product, line, jurisdiction, component, period, execution path). Widening
  is legitimate and often the better answer — "one merchant reported it, it is wrong for the
  whole county / product class" — so long as the reported case is still answered. Answering
  something narrower than the ticket asked is the failure.
- Every load-bearing claim is measured or traced, with its citation.
- The mechanism is named — what is wrong and where, which may be several sites in one proc
  rather than a single line.
- The disposition is one of: data/configuration change, procedure/function change, both, or
  unsupported at available granularity (the general remedy deferred to the new engine). Both is
  common and is not a hedge: "the rates are wrong AND they are applied wrong" is two changes,
  and shipping one leaves the ticket half-fixed.
- Unknowns are explicit.

## The three verdicts

- **DEFECT_PROVEN** — mechanism traced. Its affected roots are a briefing hint for the fix, not
  the coverage checklist; the `ratevariant plan` comment derives that empirically from the
  callgraph later.
- **WORKING_AS_INTENDED** — positive data shows current behavior is correct and the ticket is a
  misunderstanding. Requires the decomposed correct value or the precluding condition, never
  merely the absence of a reproduction.
- **EVIDENCE_INCOMPLETE** — neither of the above is reachable. Do NOT soften it into one of them:
  set evidence_complete = false, name the exact artifacts that would close it (the query, the
  capture, the transaction id, the answer needed from the SMEs), and stop.
