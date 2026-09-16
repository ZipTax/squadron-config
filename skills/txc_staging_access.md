# Request TaxCloud data evidence

## Your responsibility

You supply the data question and scope, then judge whether the returned evidence supports
the claim.

## Work with Devin

Ensure the Devin session uses
`write-taxcloud-sql-query` and `query-staging-snapshot` in the SQL repository. Do not put
credentials, connection settings, SQL templates, or copied query procedures in its brief.

For case data gaps, ask the Devin session authoring cases to use ratevariant-case-data
and find an eligible situation or explain the coverage limit. Let Devin select substitute
merchants and investigate fixture requirements. A substitute must not be presented as the reported production transaction.

## Interpret the evidence

The dated FedTax/Reports snapshot proves facts about that copy. Its date alone does not
invalidate a measured mechanism, but neither matching nor missing rows establish today's
production configuration. Preserve a bounded production verification request when current
rows matter; if the finding itself cannot be supported, retain the evidence gap.

Governed production access, when available, is a separate observation source recorded in
production_evidence. Do not assume it exists, describe staging as the only possible source,
or treat production observations as a substitute for local SQL Server behavior proof.

## Finish or pause

If access fails, have the Devin session check its environment wiring and report the missing
capability. Secrets remain in Devin's secret mechanism; a required human dependency returns
through blocked_run rather than keeping the mission open. Shared staging mutations run
through the repository's PR workflows, not ad hoc commands from a session.
