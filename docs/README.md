# Project documentation

These documents explain configuration and workflow concerns that are useful to maintainers but are
not part of Squadron's general repository overview.

- [Atlassian MCP login](atlassian-mcp-login.md) explains how to authorize the Atlassian integration
  used by agents that read or update Jira.
- [Rate-ticket orchestration](rate-ticket-orchestration.md) explains the event-driven target for
  long-running rate work across Squadron, Devin, Jira, and a bridge service, including which
  contracts are already defined and which infrastructure remains to be built.
- [Bridge infrastructure](bridge-infrastructure.md) proposes hosting and reliable delivery options,
  including when the AWS Squadron host would need tailnet connectivity.
- [Rate-ticket checkpoint schema](schemas/rate-ticket-checkpoint.schema.json) defines Squadron's
  versioned per-ticket state.
- [Production-evidence schema](schemas/production-evidence.schema.json) prevents missing, denied,
  incomplete, and empty production observations from being treated as the same result.
