# Authorizing the Atlassian MCP

`mcp/atlassian.hcl` connects Squadron to Atlassian's hosted MCP server, which is how any agent here
reads or writes Jira. Once a box is authorized, the server's tools are available to whatever agent
is granted them — the login below is a property of the box, not of any one mission.

The server uses OAuth 2.1, so there is no token in the config and nothing to check into the repo.
It has to be authorized once per Squadron box.

## Which account to approve as

Whichever Atlassian account approves the flow is the identity Squadron acts as, on every mission
that uses this server. Approve as a dedicated automation account, not a person's, which would tie
the orchestrator's access to that person's employment and licence. Give it a Jira licence and the
permissions the missions that use it need — reading issues takes **browse** on the project, and
anything granted beyond that is available to any agent holding a write tool.

This account is not the one Devin sessions use. They reach Jira through Devin's own Atlassian
integration and are permissioned separately.

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

Squadron resolves a named tool — `mcp.atlassian.getJiraIssue`, and whatever else an agent is given
later — by asking the server for its tool list, so on a box that has never logged in, every command
that loads the config fails with:

```
Error: agent 'session_scout' tools: agents.hcl: Unsupported attribute; This object does not
have an attribute named "getJiraIssue".
```

That is the unauthorized server, not a typo in `agents.hcl` — log in and it resolves. The
alternative, `mcp.atlassian.all`, resolves without a connection but hands the agent every write
tool on the server, including comment-posting; for a read-only stage like triage that is the one
thing it must never be able to do, so name the tools instead of taking the shortcut.

## Renewal

The access token refreshes itself while the server is in use. The refresh token does not live
forever, and Atlassian's lapse after a period of disuse (on the order of months), so a long quiet
spell means logging in again — the same two commands.

`squadron mcp status` reporting `no token` or `expired` for `atlassian` is the signal. From inside a
mission it looks like a refused Jira call, which a stage should treat as something it could not see
rather than something that is not there — a refusal is not an empty answer.

## The Devin Sessions field

One field is worth documenting here because a mission depends on it and a wrong id fails silently.
`Devin Sessions` is `customfield_11724` on the DEV project, which is `variable
"jira_sessions_field"`'s default. Only override it if the field is ever rebuilt —
`squadron vars set jira_sessions_field customfield_NNNNN` — and note that a wrong id reads exactly
like a ticket with no field on it, silently. To find an id: read any DEV issue with
`fields=["*all"]` and `expand=names`, or look at the field's URL in Settings → Issues → Custom
fields.

It is a **rich text** paragraph field (Jira lists the type as "Text Field (multi-line)"), which
decides how sessions write it: the value is an ADF document, one paragraph per line, and a plain
string is rejected —

```
"customfield_11724": "rate-fix: https://..."
  → Operation value must be an Atlassian Document

"customfield_11724": {"type": "doc", "version": 1, "content": [
    {"type": "paragraph", "content": [{"type": "text", "text": "rate-fix: https://..."}]}]}
  → ok
```

Reads come back as ADF whatever `responseContentFormat` asks for, so the index a stage parses is
the text of those paragraphs, not a newline-separated string.
