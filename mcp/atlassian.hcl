# Atlassian's hosted MCP: Jira for any agent granted its tools. Read-only in
# practice today — rate_triage reads the ticket's Devin Sessions field, the
# session index that survives the Devin API refusing an org-wide session list —
# but the server carries write tools too, so grant tools by name, never `.all`.
#
# OAuth 2.1, no token in this file. Authorize once per box — see
# docs/atlassian-mcp-login.md for the flow and for which account to approve as.
mcp "atlassian" {
  url = "https://mcp.atlassian.com/v1/mcp"
}
