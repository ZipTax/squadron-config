# Coordinate production evidence

Supply the data question and scope to the Devin owner and assess the returned evidence.
Production query mechanics belong to `prod-sql-insights` in `FedTax/txc-databricks`.

## Resolve a tool or data gap

1. Have Devin re-list available tools and try another formulation or derivable input
   that answers the question.
2. If the tools cannot answer it, have Devin follow `prod-sql-insights` to open a PR
   adding or extending a bounded tool.
3. When that change is ready, use `blocked_run` to ask the operator for deployment or
   access. Include the PR, required capability, and the work it unblocks.
4. Have Devin use the available tool and reassess the evidence before continuing.

Retain source references and limitations in `production_evidence`. Distinguish missing rows,
incomplete history, and denied access so an evidence gap cannot become a domain conclusion.
Production observations inform investigation and fixes; they do not prove snapshot fixture
availability or replace local SQL Server behavior tests.
