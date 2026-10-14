# Post to Slack

`builtins.gateway.post` takes a JSON payload:

- `text`: the message, in Slack mrkdwn. `blocks` is optional Block Kit.
- `thread`: a key naming the request, e.g. the Jira key. Use the same key in every mission that
  works the request, so chained and resumed runs land in the same thread.
- `root`: `true` replaces the request's top-level message with this post, or posts it if the
  request has none. Without it, the post is a reply in the thread.
- `desired_channel`: a channel name or ID to open the request's thread in. It only applies to
  the post that opens the thread; once the run or key has a thread, posts stay in that thread's
  channel.

## Post the key before asking

A run's `human.ask` questions only reach its thread once the gateway has linked the run to
it, either because the run was started from `/squadron` or because it has already posted with
`thread`. A run started by routing or by the bridge must post with its key before it asks
anything, or its question opens a second top-level message.

## Rewrite the top-level message's content, not its layout

Each `root` post replaces the whole message. Keep the layout the previous one used and change
only what's new, e.g. the status, or a fuller description once more is known. The gateway adds
its own lines after your text on every rewrite (the mission and the requester), so don't
include them.

A run that asks before it has a thread gets a top-level message of
`*<mission>*: <question summary>`. The question itself is a reply in the thread, so replacing
that message with `root` loses only the summary line.
