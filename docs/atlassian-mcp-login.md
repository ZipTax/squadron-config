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

## The login is a chicken and egg, so point it at `mcp/` alone

Squadron resolves a named tool — `mcp.atlassian.getJiraIssue`, and whatever else an agent is given
later — by asking the server for its tool list, so until the server is authorized the config cannot
load. `squadron verify` says so plainly:

```
Error: agent 'session_scout' tools: agents.hcl: Unsupported attribute; This object does not
have an attribute named "getJiraIssue".
```

The `mcp` commands hit the same wall less plainly. They load the whole config to find the `mcp`
blocks, so on an unauthorized box they report every server as absent — including linear, which has
nothing to do with it:

```
$ squadron mcp status
No mcp servers configured.
$ squadron mcp login atlassian
Error: mcp "atlassian": not found in config
```

That is not a missing block. Point the command at the directory holding the `mcp` blocks and
nothing else, and it loads them without ever reaching `agents.hcl`. Pass `--squadron-home`
explicitly, because `-c` moves the vault's default location and a token written to `mcp/.squadron`
is one the running Squadron will never read:

```bash
squadron mcp login atlassian -c mcp --squadron-home /root/squadron/config/.squadron
```

Once the token is in the vault, the config loads and plain `squadron mcp status` works again.

## The login

The box is headless and the OAuth redirect lands on a loopback port there, so the browser part
happens on your Mac over a forwarded port. The port is chosen per run, not fixed, so read it out of
the printed url rather than guessing:

```bash
ssh <squadron-box>
squadron mcp login atlassian -c mcp --squadron-home /root/squadron/config/.squadron
#   ... redirect_uri=http%3A%2F%2F127.0.0.1%3A38753%2Fcallback ...   <- 38753 here
```

Leave that running, and from a second local terminal forward the port it printed:

```bash
ssh -L 38753:localhost:38753 <squadron-box>
```

Then open the printed url in your browser, approve as the automation account, and the redirect
completes over the forwarded port. Confirm with:

```bash
squadron mcp status     # atlassian -> connected, with an expiry
```

The shortcut that avoids all of this — `mcp.atlassian.all` — resolves without a connection, but it
hands the agent every write tool on the server, including comment-posting, which is exactly what a
read-only stage must not be able to do. Name the tools and do the login.

## Renewal

The access token refreshes itself while the server is in use. The refresh token does not live
forever, and Atlassian's lapse after a period of disuse (on the order of months), so a long quiet
spell means logging in again — the same command, and without the `-c mcp` dance, since a config
that has been authorized once still loads.

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
