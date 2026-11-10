# Project documentation

These documents explain configuration and workflow concerns that are useful to maintainers but are
not part of Squadron's general repository overview.

- [Atlassian MCP login](atlassian-mcp-login.md) explains how to authorize the Atlassian integration
  used by agents that read or update Jira.
- [Slack rate workflow](slack-rate-workflow.md) covers progress updates, operator questions,
  Jira answers, and review follow-up.
- [Slack setup](slack-setup.md) covers credentials, mission starts, and channel selection.
- [Rate-ticket orchestration](rate-ticket-orchestration.md) defines ownership and handoffs across the
  workflow, with links to the skills and schemas that own each procedure.
- [Bridge infrastructure](bridge-infrastructure.md) covers bridge hosting, authentication, and delivery.
- [Rate-ticket checkpoint schema](schemas/rate-ticket-checkpoint.schema.json) defines Squadron's
  versioned per-ticket state.
- [Production-evidence schema](schemas/production-evidence.schema.json) prevents missing, denied,
  incomplete, and empty production observations from being treated as the same result.
