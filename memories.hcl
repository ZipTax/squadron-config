memory "rate_case_log" {
  description = "One line per closed rate case, appended by the mission that closed it: ticket, mechanism class, verdict, and where the write-back landed. It is a history, not a source of truth — the proven precedents live in txc-sqlserver-database's ratevariant-audit references, and this log exists so a run can see that the case in front of it is the third of its kind rather than judging in isolation."
}

memory "rate_open_items" {
  description = "One file per ticket, `<TICKET>.md`, written by the mission that ran out of things it could do without a human: the questions it is waiting on, which stage it blocked at (so the next run re-enters there rather than re-investigating), which stages already completed and where their PRs are, and what remains. A run ends when it blocks; the next run on the same ticket is the resumption, and this is how it learns what the last one was waiting for instead of re-deriving it. The stage that closes the case deletes the file — a stale open-items file is worse than none, because a later run will believe it."
}
