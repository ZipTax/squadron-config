# TaxCloud rate-change audit: what to demand back

Load with `ab_audit`, which holds the general reasoning. The audit procedure and the case law
that earned each rule live **in the repo**, where the acting session can load them:

- `txc-sqlserver-database/.claude/skills/ratevariant-audit/SKILL.md` — the procedure.
- `.../ratevariant-audit/references/case-law.md` — proven precedents, grep-able by symptom.
- `.../ratevariant-audit/references/limitations.md` — tickets deferred to the new rate engine
  (Jira label `new-rate-engine`), plus open tickets whose mechanism is still a claim.
- `ratevariant-testing`, `query-staging-snapshot`, `write-taxcloud-sql-query` — mechanics.

Instruct the auditing session to load `ratevariant-audit` and to grep the case law by symptom
before diagnosing. Do not relay the procedure as prose; it will be stale and lossy.

A `new-rate-engine` ticket has no correct fix in the legacy repo, so a clean-looking diff against
one is the failure mode to watch for: the remedy belongs to the new rate engine, there is no
authoring process there yet, and the honest terminal output is the limitation — treat it as a
complete answer, not an escalation, and do not route it to `develop`.

Demand the analysis anyway. A limitation is a short-circuit, not a shortcut past root cause: the
session must prove the mechanism from data at the ticket's scope and show it is one of the classes
that file names, because these symptoms routinely resemble a class they don't belong to (a wrong CA
rate reads as a ZIP+4 boundary patch and is really a sourcing-model question). A proven ordinary
mechanism is an ordinary fix regardless of the label.

You hold no data, so your job is judging what comes back. Refuse a verdict that doesn't
answer these:

1. **Which paths?** cart (`spTransactionLookup[_nonssuta]`), offline import, and filing ETL
   (`spGenerateTransactionsWideForTx` → `fnGetTaxRatesforTx[_nonssuta]`, FedTax *and* Reports
   copies) are separate implementations. "Fixed in one copy of four" is this repo's most
   repeated defect. An ETL no-op leaves the cart right and the **filing** wrong.
2. **Which value, decomposed?** A diff is not a pass. The variant value must equal the
   authoritative expected value, decomposed against `StatesTaxMatrix` / `TDSData(NonSsuta)`
   — not against the PR description, which is sometimes wrong about its own data.
3. **Filing codes too?** `TransactionsWide` `CityCode`/`CountyCode`, not only the total; a
   right total remitted under the wrong jurisdiction is still a filing defect.
4. **Every case classified?** primary positive (must differ, to the right number) vs guardrail
   (must stay flat). A run with no guardrails was observed, not audited.
5. **Every unexpected match diagnosed by mechanism?** shadowed / unreachable / not exercised /
   masked — each has a different remedy, and "it needs a fixture" is a conclusion, not a
   starting assumption. Fixtures apply to both arms, so a fixture can never create a diff.
6. **Blast radius, in rows?** for a data change: what `apply` touches, what teardown removes,
   who else reads those rows.
7. **Was anything upgraded?** `failed` is a hard blocker and an incomplete run stays
   incomplete. Never accept a pass that closes the loop over a run that didn't prove it.

Diffs consisting only of `Created_Date` / `TransactionWideID` / execution ids are not diffs.
A merchant- or ZIP-scoped change can only diff for that member, so "1 of N differ" is the
expected shape rather than thin coverage.
