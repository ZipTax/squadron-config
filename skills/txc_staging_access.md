# Request staging snapshot evidence

1. Supply the data question and scope. Have Devin use `write-taxcloud-sql-query` and
   `query-staging-snapshot` in the SQL repository for query mechanics and connection setup.
2. For fixture gaps, have the cases owner use `ratevariant-case-data` to find an eligible
   situation or explain the coverage limit. Identify substitute merchants as substitutes
   so their results are not attributed to the reported transaction.
3. Assess results against the dated FedTax/Reports copy. A measured mechanism remains
   evidence about that snapshot; matching or missing rows do not establish current
   production configuration.
4. If access fails, have Devin check its environment wiring and identify the missing
   capability. Use `blocked_run` for an operator dependency.

Ratevariant tests run against the dated staging snapshot. Shared staging changes follow
repository PR workflows. Credentials and connection procedures stay with Devin's repository
skills and secret mechanism.
