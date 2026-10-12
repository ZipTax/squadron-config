# Post a request to Slack

Each request has one top-level Slack message, and everything else about it goes in that
message's thread. `builtins.gateway.post` takes a JSON payload:

- `text`: the message, in Slack mrkdwn. `blocks` is optional Block Kit.
- `thread`: the key that names the request, e.g. the Jira key. Use the same key in every
  mission that works the request, so chained and resumed runs land in the same thread.
- `root`: `true` posts the top-level message, or rewrites it if the request already has one.

## Post the key before asking

A run's `human.ask` questions only reach its thread once the gateway has linked the run to
it, either because the run was started from `/squadron` or because it has already posted with
`thread`. A run started by routing or by the bridge must post with its key before it asks
anything, or its question opens a second top-level message. Make that first post the `root`
update.

## Keep the top-level message current

Rewrite it with `root: true` whenever the request's state changes, so the channel shows
where each request stands without opening its thread. Include the ticket link, the problem
in one line with the states it concerns, the cause once it is known, and the status:

```
*<https://…/browse/DEV-8212|DEV-8212>*
Some rates are wrong in X, Y and Z.
Cause: …
Status: fixing
```

Don't add a requester line. The gateway keeps one on the message.

## Reply for everything else

Post updates, results and links without `root`. They go in the thread and don't tag anyone,
because the requester already follows it.
