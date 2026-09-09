# Authorizing the Atlassian MCP

`mcp/atlassian.hcl` gives `session_scout` one Jira read: the **Devin Sessions** field on a ticket,
which is where every session this flow opens registers itself. That field is the session index
triage actually depends on — `find_sessions` is an organization-wide read the Devin service key is
usually refused, so without the field a re-fired ticket cannot see its own history.

The server uses OAuth 2.1, so there is no token in the config and nothing to check into the repo.
It has to be authorized once per Squadron box.

## Which account to approve as

Whichever Atlassian account approves the flow is the identity Squadron reads Jira as. Approve as a
dedicated automation account with a Jira licence and **browse** permission on the DEV project — not
a person's account, which ties the orchestrator's access to that person's employment and licence.

Squadron only reads. The sessions are what write the field, through Devin's own Atlassian
integration, which needs **Edit Issues** on DEV separately.

## The login

The Squadron box is headless, and the OAuth redirect lands on a loopback port there, so forward it
rather than trying to run a browser on the box:

```bash
ssh -L 8080:localhost:8080 <squadron-box>
squadron mcp login atlassian
```

Open the URL it prints in a local browser, approve as the automation account, and the redirect
completes over the forwarded port. Confirm with:

```bash
squadron mcp status     # atlassian -> connected, with an expiry
```

If the printed URL redirects to a port other than 8080, forward that one instead — the port is
chosen by Squadron's loopback listener, not fixed by this document.

## Until it is authorized, the config does not load

Squadron resolves `mcp.atlassian.getJiraIssue` by asking the server for its tool list, so on a box
that has never logged in, every command that loads the config fails with:

```
Error: agent 'session_scout' tools: agents.hcl: Unsupported attribute; This object does not
have an attribute named "getJiraIssue".
```

That is the unauthorized server, not a typo in `agents.hcl` — log in and it resolves. The
alternative, `mcp.atlassian.all`, resolves without a connection but hands the scout every write
tool on the server, including comment-posting, which is the one thing a triage stage must never do.

## Renewal

The access token refreshes itself while the server is in use. The refresh token does not live
forever, and Atlassian's lapse after a period of disuse (on the order of months), so a long quiet
spell means logging in again — the same two commands.

`squadron mcp status` reporting `no token` or `expired` for `atlassian` is the signal. What it looks
like from a mission is a refused field read, which `discover_sessions` treats as history it could
not see rather than a ticket with no history: the run continues on the tag search and the
resume-state file, degraded but not wrong.

## The field id

The field's id is not hardcoded. `variable "jira_sessions_field"` in `variables.hcl` defaults to a
placeholder; set the real one on the box:

```bash
squadron vars set jira_sessions_field customfield_NNNNN
```

Find it as a Jira admin under Settings → Issues → Custom fields (the id is in the field's URL), or
by reading any DEV issue with `fields=*all` and looking for the one named `Devin Sessions`. A wrong
or unset id reads exactly like a ticket with no field on it, which is silent — so check
`squadron vars` after the field is created.
