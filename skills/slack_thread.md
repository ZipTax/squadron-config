# Post to Slack

`builtins.gateway.post` takes a JSON payload:

- `text`: the message, in Slack mrkdwn. `blocks` is optional Block Kit.
- `thread`: a key naming the request, e.g. the Jira key. Use the same key in every mission that
  works the request, so chained and resumed runs land in the same thread.
- `root`: `true` replaces the request's top-level message with this post, or posts it if the
  request has none. Without it, the post is a reply in the thread.

## Post the key before asking

A run's `human.ask` questions only reach its thread once the gateway has linked the run to
it, either because the run was started from `/squadron` or because it has already posted with
`thread`. A run started by routing or by the bridge must post with its key before it asks
anything, or its question opens a second top-level message.

The gateway keeps a requester line on the top-level message, so don't add one. Replies don't
need to tag anyone, because the requester already follows the thread.
