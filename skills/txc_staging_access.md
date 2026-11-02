# Request TaxCloud data evidence

## Your responsibility

You supply the data question and scope, then judge whether the returned evidence supports
the claim. Production-data access and interpretation belong to the Devin investigation or
fix session through its playbook; Squadron does not need a production connection or tool catalog.

## Work with Devin

Ensure the Devin session uses
`write-taxcloud-sql-query` and `query-staging-snapshot` in the SQL repository. Do not put
credentials, connection settings, SQL templates, or copied query procedures in its brief.

For case data gaps, ask the Devin session authoring cases to use ratevariant-case-data
and find an eligible situation or explain the coverage limit. Let Devin select substitute
merchants and investigate fixture requirements. A substitute must not be presented as the reported production transaction.

Ratevariant tests run against the dated staging snapshot. Production observations can inform a diagnosis
or fix, but they do not establish that the snapshot contains the records a test needs.

## Interpret the evidence

The dated FedTax/Reports snapshot proves facts about that copy. Its date alone does not
invalidate a measured mechanism, but neither matching nor missing rows establish today's
production configuration. Use the production-tool gap procedure when current rows matter;
if the finding itself cannot be supported, retain the evidence gap.

Governed production access, when available, is a separate observation source recorded in
production_evidence. Do not assume it exists, describe staging as the only possible source,
or treat production observations as a substitute for local SQL Server behavior proof.

## Resolve a production-tool gap

1. Have Devin follow `prod-sql-insights` in `FedTax/txc-databricks`: re-list the tools
   and try another formulation or derivable input that returns the needed data.
2. If the tools cannot answer it, have Devin open a PR there adding or extending a
   bounded tool. That repository's skill owns the query and deployment procedure.
3. Once the tool change is ready, use `blocked_run` to ask the operator for deployment
   or access. Include the PR, required capability, and the work it unblocks.
4. Have Devin call the available tool and reassess the evidence before resuming.

## Finish or pause

If access fails, have the Devin session check its environment wiring and report the missing
capability. Secrets remain in Devin's secret mechanism; Squadron handles the resulting
operator dependency through blocked_run. Shared staging mutations run
through the repository's PR workflows, not ad hoc commands from a session.
