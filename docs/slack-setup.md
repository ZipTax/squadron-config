# Configure Slack

1. Create and install the Slack app using the gateway's
   [setup instructions](https://github.com/mlund01/squadron-gateway-slack#setup).
2. Set `slack_bot_token`, `slack_app_token`, and `default_slack_channel_id` in Squadron's
   variable store. Invite the bot to each channel it will use.
3. Set `mcp_host_secret`. The gateway connects to Squadron at `http://localhost:8090/mcp`
   using this secret to list and start missions.
4. Restart Squadron; it installs the pinned gateway release automatically. Start a mission
   with `/squadron`.

## Choose a channel

A mission started with `/squadron` uses the channel or DM where it was started.
For other starts, `default_slack_channel_id` is the fallback. A mission can choose another
channel by supplying `channel` on its first gateway post, before asking a question.
A first notification can also select the channel through its notification configuration.

Once a mission thread has a Slack conversation, related missions post there even if a
later post supplies another channel. A channel override selects where a conversation
starts; it does not move an existing conversation. A separate conversation needs a separate
mission thread. Channel names require the gateway's channel-read scopes; IDs avoid that lookup.

Gateway payloads and message-ID behavior are documented in the
[gateway reference](https://github.com/mlund01/squadron-gateway-slack/blob/main/docs/technical-reference.md).
