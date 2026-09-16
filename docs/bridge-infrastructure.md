# Deploy the Jira-to-Squadron bridge

The bridge is an Azure Container App with Postgres delivery state. It receives public Jira
webhooks and calls Squadron over authenticated MCP. The
[orchestration contract](rate-ticket-orchestration.md) defines generations and recovery;
the [bridge skill](../skills/bridge.md) defines registration and resolution.

## Network and authentication

Coordinate tailnet connectivity with the administrators. Configure an HTTPS Squadron MCP
address, potentially `squadron.zip.tax`, and verify DNS, routing, TLS, and access from the
actual bridge runtime. A DNS name alone does not establish a route. Squadron must also reach
the bridge registration address. Jira still needs public ingress through Front Door even
if the bridge-to-Squadron leg uses the tailnet.

Set Squadron's `mcp_host_secret` and the matching bridge `SQUADRON_MCP_TOKEN`; set its
`bridge_url` (not secret) and `bridge_registration_token` matching `BRIDGE_REGISTRATION_TOKEN`.
Configure `prod_squadron_bridge_mcp_url` in Terraform. Confirm MCP tool schemas, mission names,
run status, capacity responses, and start-event correlation on the deployed version.

## Infrastructure and database

The production Terraform branch provisions the database, Container App, identities, Key Vault
placeholders, Front Door, and deployment permissions. The initial `squadron-bridge:latest`
image and deployment bootstrap are already prepared. After apply, approve the Front Door
private-link connection and replace the four Key Vault placeholders: database password,
MCP token, registration token, and Jira webhook token.

Provision the `squadron-bridge` login and grants, and apply versioned table DDL through a
migration owner. The service role should operate the bridge tables; it need not own schema
changes. The implementation needs durable unique event identities, atomic generation claims,
run IDs, timestamps, status, and last errors. The current service skeleton has none of this;
its healthy probes only establish that the HTTP server runs.

## Rollout order

1. Agree on tailnet routing, DNS, and the public Jira ingress address with administrators.
2. Apply infrastructure, approve private link, populate secrets, and provision database access.
3. Ship bridge endpoints, migrations, MCP dispatch/status/reconciliation, and meaningful readiness.
4. Merge the SQL skill updates and apply Devin playbook text and schemas together.
5. Configure Squadron bridge variables and MCP credentials, then deploy the matching missions.
6. Exercise one new test ticket through block, ready, resume, re-block with a new generation,
   and resolution. Include duplicate delivery, capacity rejection, lost response, and restart.
7. Enable the Jira ready-label webhook for new-process tickets only. Existing tickets stay on
   the old process; do not let both triggers own the same ticket.

No Slack notification integration, manual-retry UI, or bulk old-ticket migration is required.
Read-only Databricks access is a separate follow-up.
