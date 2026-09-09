# Jira, read-only in practice: the missions use it for one thing, the ticket's
# Devin Sessions field, which is the session index that survives the Devin API
# refusing an organization-wide session list.
#
# OAuth 2.1, no token in this file. Authorize once per box — see
# docs/atlassian-mcp-login.md for the flow and for which account to approve as.
mcp "atlassian" {
  url = "https://mcp.atlassian.com/v1/mcp"
}
