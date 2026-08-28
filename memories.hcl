memory "rate_case_log" {
  description = "One line per closed rate case, appended by the mission that closed it: ticket, mechanism class, verdict, and where the write-back landed. It is a history, not a source of truth — the proven precedents live in txc-sqlserver-database's ratevariant-audit references, and this log exists so a run can see that the case in front of it is the third of its kind rather than judging in isolation."
}
