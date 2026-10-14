# Ask a question in Slack

`builtins.human.ask` questions go in the run's request thread. A run that wasn't started from
`/squadron` must post with its key first (see `slack_thread`), or its question opens a top-level
message of its own.

- `short_summary` shows only when the question is posted top-level, as its heading. In a
  thread it isn't shown, so write `question` to read on its own.
- `choices` become buttons, or a dropdown with `multi_select`, followed by an Other… button
  that opens a text box for an answer that isn't listed. With `multi_select`, a typed answer
  comes back as a one-item JSON array. With no choices, the question gets an Answer button that
  opens a text box.
- Once answered, the gateway edits the question: struck through, then the answer and who gave
  it. Don't post the answer again.
