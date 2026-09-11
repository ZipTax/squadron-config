# How to host the Jira-to-Squadron bridge

This is a design proposal based on the local `terraform-core` and `squadron-config`
checkouts, inspected on September 10, 2026. No live AWS configuration or network
reachability was verified. This plan selects MCP delivery and a single Postgres table
for the first implementation. [Rate-ticket orchestration](rate-ticket-orchestration.md)
provides the broader workflow context; its webhook delivery, same-generation retry,
and callback requirements need reconciliation with the simpler design below.

## Does reaching Squadron require the tailnet?

Not necessarily. AWS hosting alone does not require Tailscale. A bridge can call an
authenticated HTTPS endpoint, or a worker on the Squadron host can fetch pending
deliveries over outbound HTTPS and invoke Squadron locally. Neither design requires
a private route between Azure and AWS.

The configuration provides clues, but does not establish the live route:

- `terraform-core/main.tf` and `versions.tf` configure TaxCloud's Azure infrastructure
  and supporting providers, with Terraform Cloud workspace `taxcloud/global`. There
  is no AWS provider or Squadron host resource in the inspected Terraform files.
- `terraform-core/tailscale.tf` manages Azure subnet routers and split DNS. It says
  access policy is managed separately in the Tailscale console. These routers do not
  establish that Azure workloads can reach a private AWS host.
- `missions/rate-triage.hcl` defines the `/ratevariant` webhook and a secret variable.
  Its comments identify the triage bot and Jira automation as callers. The hostname,
  reverse proxy, TLS configuration, and AWS security groups are not defined here.
- `system.hcl` selects SQLite for Squadron state. That does not supply shared,
  durable storage for a separately deployed bridge.

First obtain the existing caller's destination address and inspect the AWS listener,
authentication, and network rules. Test a harmless health endpoint from the proposed
bridge runtime; a successful laptop connection does not prove the runtime has the
same route. Do not probe a mission-start endpoint merely to test connectivity.

## How does the bridge start and check a run?

Run one hosted Docker service in Azure Container Apps. It receives Jira ready events,
records them in Postgres, and uses an MCP client to call Squadron over authenticated
HTTPS. No language model is involved in these protocol calls.

The documentation bundled with the locally installed Squadron `0.0.82` describes
an HTTP MCP host at `/mcp`, with optional Bearer authentication and these tools:

- `run_mission`: start a named mission with inputs and return its mission ID.
- `get_run_details`: inspect a run and its task summaries.
- `list_runs`: list recent runs, optionally filtered by mission name.

The reference is Squadron's `config/mcp_host.mdx`, extractable with `squadron docs`.
These are documented capabilities, not verified behavior of the AWS installation.
The bridge will require authentication even though Squadron makes it optional.

On a ready event, atomically claim the waiting row and save the dispatch timestamp
before calling `run_mission` with the recorded mission, entry stage, blocker ID,
generation, and stable start-event ID. Save the returned run ID. Roughly one minute
later, call `get_run_details` to check what happened. A recognized running or completed
run confirms the start; a failed run should produce an actionable alert rather than
be mistaken for a missing start. Map the actual response fields during integration.
No custom started-acknowledgement callback or completion callback is required for
this first version.

If the start request times out without returning an ID, try `list_runs` and run
details only if they expose enough input metadata to match the exact start event.
Do not guess from the newest run or the ticket alone. If a match cannot be established,
mark the delivery unconfirmed and ask a person to check. Likewise, a failed status
query means status is unknown, not that the run is dead. Do not automatically resend
an ambiguous start.

## Does MCP need a different network route?

Prefer direct authenticated HTTPS from the bridge to the AWS MCP endpoint. The
triage bot's existing webhook route is a useful lead, but webhook accessibility does
not prove MCP accessibility: the bundled docs describe webhooks at the command center
and MCP on a separate host listener, default port 8090.

Verify the deployed version, MCP enablement, TLS proxy route, and authentication
from the actual bridge runtime using a read-only call. Add narrowly scoped tailnet
access only if that endpoint is private. An outbound worker on the AWS host remains
an alternative if no inbound route is appropriate, but is not part of the initial
service design.

The documented MCP host also exposes configuration operations. Its documentation
does not establish per-tool token permissions, so verify the available access controls
before exposing it. Keep the bridge's allowed calls and mission targets explicit;
use a restricted proxy if broader MCP access must be excluded.

## What does the single table remember?

Use one bridge table on existing Postgres, with one row per `(blocker_id, generation)`.
Give a dedicated `squadron-bridge` database role access to this table; migrations own
schema changes. Suggested columns are:

| Fields | Purpose |
| --- | --- |
| Blocker ID, generation, Jira issue | Identify one round of waiting for human input. |
| Resume mission, entry stage, inputs | Preserve Squadron's routing decision. |
| Ready-event ID, start-event ID | Recognize repeated delivery of the same signal. |
| Status, sent time, run ID, last checked time, last error | Track dispatch and its observed outcome. |
| Attempt count, notification time, Slack channel/message IDs | Support manual retry and update one alert instead of repeatedly pinging. |

Statuses can distinguish waiting, dispatching, started, completed, failed, and
unconfirmed. The row itself is the durable pending-work record, so no separate queue
or outbox table is needed. Commit the ready event before acknowledging Jira; claim
it with a conditional database update so repeated webhooks cannot both dispatch it.
A process restart that finds an interrupted dispatch should reconcile it or flag it
as unconfirmed, not blindly send again.

Each generation gets one automatic dispatch. If Squadron resumes and still needs
human input, it registers the next generation, even when the question is unchanged.
Here, generation means a round of waiting, not a materially different question.
This removes the need for a separate re-block or completion signal to unlock the
next generation. Reject ready signals for superseded generations.

For example, generation 3 resumes after a person supplies an answer. Squadron finds
that more information is needed and registers generation 4. The next ready signal
can start generation 4; another delivery of generation 3's signal cannot restart it.

## How does a person handle an unconfirmed start?

After approximately one minute, check Squadron before notifying the Jira assignee
in Slack. For an unconfirmed start, include the ticket, known run link if available,
and a “Retry resume” button. If the assignee cannot be mapped to a Slack user, use a
configured fallback channel. Persist notification metadata and update that message
when later checks establish the outcome.

A button click performs another status check before retrying. Refuse a retry when a
run is known to have started or the generation has been superseded. Otherwise, let
the person explicitly resend the same generation and restart the timer. Authenticate
Slack interactions and conditionally claim the retry to prevent double clicks from
sending twice. If the original run cannot be found, explain that its outcome is
unknown and ask the person to check Squadron before retrying. This intentionally
accepts a small duplicate-run risk rather than requiring exactly-once execution.

## What belongs in Terraform?

Add environment-specific `squadron_bridge.tf` resources in `terraform-core` once the
application artifact and MCP route are known. Reuse the existing registry, identity,
Key Vault, deployment-role, and monitoring patterns. Configure a single active service
instance with a background polling loop, plus health checks and automatic restart.
Database claims still protect dispatch during deployment overlap.

Use the VNet-integrated Container Apps environment to reach private Postgres and the
established Front Door pattern for public HTTPS ingress from Jira and Slack. An
internal environment does not become public merely by enabling external app ingress;
see Microsoft's [ingress documentation](https://learn.microsoft.com/en-us/azure/container-apps/ingress-overview).
Squadron must also be able to reach the blocker-registration API.

Keep database credentials, MCP Bearer credentials, and Jira/Slack integration secrets
in Key Vault using the repository's placeholder-secret convention. Keep staging and
production targets and credentials separate. Provision the database role and table
through the existing database administration/migration process. No new Postgres
server, Service Bus queue, SQLite volume, or VM is proposed.

Monitor service health and old unconfirmed deliveries. A quiet bridge with no pending
work is healthy. The one-minute interval is a workflow preference, not a deadline
that proves a run failed.

## What remains before implementation?

Verify the AWS MCP endpoint and installed version, tool schemas, returned run ID,
status fields, capacity behavior, and whether run details expose correlation inputs.
MCP starts should address the configured mission names directly; additional phase
webhooks are unnecessary. Ensure phase inputs accept the resume metadata.

Reconcile the broader orchestration document and mission instructions with the
one-dispatch-per-generation rule before implementation. That work is separate from
this infrastructure-plan edit because those files may be changing concurrently.

Exercise duplicate Jira delivery, capacity rejection, lost start responses, late
status results, service restart, manual retry, and a new blocker generation against
a staging target. Replace the old Jira trigger when enabling the bridge so both
paths do not resume the same ticket. Follow the Terraform repository's PR and plan
workflow for deployment; this document does not change live infrastructure.
