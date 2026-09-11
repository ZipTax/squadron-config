memory "rate_case_log" {
  description = "One line per closed rate case, appended by the mission that closed it: ticket, mechanism class, verdict, and where the write-back landed. It is a history, not a source of truth — the proven precedents live in txc-sqlserver-database's ratevariant-audit references, and this log exists so a run can see that the case in front of it is the third of its kind rather than judging in isolation."
}

memory "rate_checkpoint" {
  description = "Squadron's current routing state for one rate ticket, stored as `<TICKET>.yaml`. Read and write it only through the rate_checkpoint skill so schema_version and checkpoint_revision are handled consistently."
}

memory "rate_resume_state" {
  description = "Legacy read-only migration source for pre-checkpoint `<TICKET>.md` records. rate_triage reads this slot only when no rate_checkpoint file exists, converts the current state into schema_version 1 of the checkpoint, then deletes the legacy file. No stage writes new state here, so tickets already waiting are not abandoned during migration."
}
