# Atlassian's hosted MCP: Jira for any agent granted its tools. The server
# carries write tools as well as reads, including comment-posting, so grant
# tools by name rather than `.all` and give a stage only what it should be
# able to do.
#
# `editJiraIssue` is granted where a stage owns the `TaxRates:Needs-Info` label
# and nothing else on the ticket: the same tool would edit any field, so the
# limit lives in the role text and in `blocked_run`. The comment stays a
# session's to write even though this server could post it — the rules for
# wording one are skills in the acting repo, and an orchestrator that drafts a
# body drafts what it holds, which is a status report for us.
#
# OAuth 2.1, no token in this file. Authorize once per box — see
# docs/atlassian-mcp-login.md for the flow and for which account to approve as.
# Note the bootstrap there: until the login lands, no command can load a config
# that names a tool on this server, `squadron mcp` included, so the first login
# has to be run against this directory alone.
mcp "atlassian" {
  url = "https://mcp.atlassian.com/v1/mcp"
}
