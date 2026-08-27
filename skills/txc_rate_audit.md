# TaxCloud rate-change audit specifics

Load with `ab_audit`, which holds the general reasoning. This file is only what is specific
to the TaxCloud tax engine, plus the case law that earned each rule.

The acting session should load the repo's own skills — `ratevariant-testing`,
`ratevariant-audit`, `query-staging-snapshot`, `write-taxcloud-sql-query` in
`txc-sqlserver-database/.claude/skills/` — which carry the operational detail. Your copy is
for judging what the session reports back.

## The three surfaces must agree

A rate change can span all three; check each and confirm they produce the same answer:

| Surface | Entry point |
|---|---|
| cart | `spTransactionLookup` / `spTransactionLookup_nonssuta` |
| import | `spImportOfflineTransactions` |
| Reports / filing ETL | `spGenerateTransactionsWideForTx` → `fnGetTaxRatesforTx[_nonssuta]` |

- Imports decide taxability from the **merchant-claimed** rate, the cart from the **computed**
  rate. The same order can split differently, and an import branch can be reachable when the
  cart's is not.
- An ETL-side no-op leaves the cart corrected and the **filing** data wrong. TransactionsWide
  is what gets remitted — always confirm the fix lands there, not only in the cart.
- For non-SSUTA the cart calculation is inline and the ETL recalculation is a separate
  implementation. Logic drift between them is a first-class suspect.

## Assert codes, not just the rate

The filing surface must carry the right tax-area **codes**. Assert TransactionsWide
`CityCode` / `CountyCode` (driven by `TDSData(NonSsuta)` `FIPS_CITY` / `CITY_RPT_CODE` /
`COUNTY_RPT_CODE`). A correct total can still remit under the wrong jurisdiction.

> **DEV-8126.** After the rate was corrected to 9.75%, the override still filed under Pomona
> (C03 / FIPS 58072) instead of unincorporated B47: it nulled `CITY_NAME` but kept the base
> city's FIPS and rpt codes.

## Decompose the expected value against the data

Never accept a diff because it moved. Decompose the expected rate from the data and confirm
the captured value equals it. If the ticket states a target, decompose that too — when the
data contradicts the ticket, the answer is working-as-designed, not a fix to chase.

> **DEV-8126.** The cart correctly moved 10.50% → 7.25%, but the target was 9.75%: the
> override zeroed the entire 3.25% CITY bucket instead of only the 0.75% city portion,
> dropping district tax that should have stayed.

## No-diff diagnosis, with the local shapes

> **DEV-1927 (shadowed).** The shipping `ISNULL(itemPriceTaxable,…)` sat after a
> `WHEN ItemPrice > 0` that always won — dead until the WHENs were reordered.

> **DEV-8126 (not exercised).** The transaction date predated the override's `PeriodStart`,
> so neither arm consulted it — a false no-diff, fixed by patching the date into the window.

> **DEV-7082 (unreachable).** Extending the IL date cutoff in `fnGetTaxSourceAddress_nonssuta`
> was a no-op: `States.UseOriginSourcing = 1` for IL short-circuits the OR before the date
> branch is evaluated. The branch is dead on current data, so the fix changes nothing.

> **DEV-1927 (unreachable, not missing coverage).** "All items exempt → exempt shipping" was
> gated on shipping `Rate > 0`, but follows-cargo already zeroes shipping when all items are
> exempt — mutually exclusive, so the case cannot exist.

> **DEV-7082 (fixture as signal).** Its working-as-intended conclusion began with "I need to
> patch StatesTaxMatrix to get a diff" — the tell that the branch was dead rather than
> untested.

## Noise columns here

`TransactionWideID`, `Created_Date` and other per-execution values belong in the capture's
ignore list. Cases capture the root's full output by default, so a missing capture/column
section is normal, not a coverage gap — the reporting codes above are present without any
override.

> **DEV-1927.** The reports case first surfaced only `Created_Date` / `TransactionWideID`
> while the tax columns were identical — the change had not taken effect at all.

## Ground every taxability claim in the data

`StatesTaxMatrix`, `PostCalculateTICActions`, `TDSData(NonSsuta)`, `SSTIDs`, `Locations` —
never intuition, and never the PR's prose, which is sometimes wrong about its own data.

> **DEV-8126.** The PR asserted city tax was 0.75% in `CITY_SALES_TAX`; the row actually held
> 3.25% with the district lumped in.

Read column meanings from `output/schema`. Have the session query with indexed predicates
(URLID + date), never a scan, via ratebench's `cmd/sqlprobe` rather than scaffolding a
querier.

## Data-change (alteration) PRs

Blast radius must match the migration exactly: the targeted jurisdiction differs, adjacent
ones — neighbouring plus4/zip, other periods — do not, and teardown reverts cleanly. Watch
for jurisdiction **mislabeling**, a retained component filed under the wrong city or district,
even when the total rate is right.
