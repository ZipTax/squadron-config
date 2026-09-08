memory "rate_case_log" {
  description = "One line per closed rate case, appended by the mission that closed it: ticket, mechanism class, verdict, and where the write-back landed. It is a history, not a source of truth — the proven precedents live in txc-sqlserver-database's ratevariant-audit references, and this log exists so a run can see that the case in front of it is the third of its kind rather than judging in isolation."
}

memory "rate_resume_state" {
  description = "One file per ticket, `<TICKET>.md`, written by the mission that ran out of things it could do without a human: everything the next run needs to pick up where this one stopped — the stage it blocked at (so the resumption re-enters there rather than re-investigating), the verdict and mechanism it may proceed on, pointers to the sessions and PRs that hold the evidence and which are still messageable, branches, the loop counters a resumed stage would otherwise restart at zero, a marker of when it stopped so new ticket replies are distinguishable from old, and the questions it is waiting on. A run ends when it blocks; the next run on the same ticket is the resumption, and this is how it learns what the last one was waiting for instead of re-deriving it. The stage that closes the case deletes the file — a stale resume-state file is worse than none, because a later run will believe it."
}
