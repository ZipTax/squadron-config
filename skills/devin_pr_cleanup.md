# Devin PR Cleanup Skill Guide

Use the Devin plugin to clean up a pull request by resolving every open review comment. Devin works through each unresolved thread, applies code fixes and/or posts reply comments, and pushes the changes — fully addressing outstanding items from past reviews and preparing the PR for a clean merge.

This skill does **not** merge the PR. It gets the branch into a merge-ready state and hands off to a human for the final merge decision.

## Workflow

### 1. Run a Cleanup with a Devin Session

Unlike `code_review` and `code_qa`, there is no dedicated wrapper tool for cleanup. Run it as a standard Devin session driven by the structured prompt below. Devin reads the unresolved review threads, addresses each one, pushes commits to the PR branch, and replies on GitHub.

**Required input:**
- `pr_url` — full GitHub pull request URL (e.g. `https://github.com/org/repo/pull/123`)

**Optional input:**
- `instructions` — scope, priorities, or constraints (e.g. "prioritize the security comments", "don't touch the migration files", "reply-only on the architecture thread")

**Prompt template:**
```
Prepare PR {pr_url} for a clean merge by resolving all open review comments.

1. Read every unresolved review thread and comment on the PR.
2. For each comment, decide: apply a code fix, or reply with a clarifying/explanatory comment.
3. Apply fixes on the PR branch and commit with clear messages that reference the comment being addressed.
4. Reply to each thread describing the fix applied or the rationale for no change.
5. Resolve only the threads you have fully addressed. Leave open any thread that needs a human decision.
6. Ensure CI and tests pass and there are no merge conflicts with the base branch.
7. Do NOT merge the PR.
8. Return a summary: fixes applied, replies posted, threads resolved, and any items still needing human input.

Additional instructions: {instructions}
```

**What Devin does:**
- Inventories all open / unresolved review threads on the PR
- Triages each comment into a fix or a reply
- Applies code fixes on the PR branch and commits them with traceable messages
- Posts inline replies explaining what was changed or why no change was made
- Resolves the threads it has fully addressed
- Verifies the branch passes CI and is free of merge conflicts
- Leaves genuinely ambiguous or decision-requiring threads open and surfaces them

**Example:**
```json
{
  "pr_url": "https://github.com/org/repo/pull/123",
  "instructions": "Apply the requested null-check fixes. For the comment about renaming the public API, reply with rationale but do not change it — that needs sign-off."
}
```

The response includes the session ID, status, pull request links, and Devin's cleanup summary. Inline replies and resolved threads are visible on the GitHub PR. The session is archived automatically after completion.

### 2. Retrieve Results with `check_session`

If the cleanup response is missing Devin's summary, use `check_session` with the session ID to retrieve the full results including messages and session insights. This is also useful for monitoring long cleanups on large PRs.

```json
{
  "session_id": "32fee96e7997499ca010301aa50eefce"
}
```

### 3. Interpreting the Cleanup Response

**Devin's Response section** — Devin's overall cleanup summary: which comments were fixed, which got replies, which threads were resolved, and what still needs a human.

**On the GitHub PR** — the actual work lands on the PR page, not in the plugin response:
- New commits on the PR branch for the applied fixes
- Inline replies on each addressed thread
- Resolved status on threads Devin fully closed out

- If the response says "Devin returned an error in messaging", review the session directly at the provided URL
- If the response says "Devin did not return a message", the session completed but produced no message output — check the PR on GitHub for the commits, replies, and resolved threads

**Session Insights** (via `check_session`) — additional analysis including the comments addressed, action items, and a timeline of what Devin changed.

### 4. Final Review and Merge (Human)

Cleanup prepares the PR; it does not merge it. Before merging:
- Review Devin's pushed commits and inline replies
- Confirm the threads left open are acceptable or resolve them yourself
- Confirm CI is green and there are no conflicts
- Merge the PR yourself once satisfied

## Tips for Effective Cleanups

- Use `instructions` to set boundaries — which comments to prioritize, files Devin should not touch, and threads to reply-only rather than fix.
- Tell Devin to **resolve only what it fully addresses**. Anything requiring a judgment call should stay open and be surfaced in the summary, not force-fixed.
- Natural pairing: run `code_review` (or a human review) first, then this cleanup skill to clear the resulting threads. Review → cleanup → merge.
- For large PRs, instruct Devin to work in batches — by file or by comment severity — and use `check_session` to monitor progress.
- Always review Devin's commits before merging. This skill gets the PR merge-ready; the merge itself stays with a human.
- Combine with `code_qa` after cleanup to confirm the fixes didn't break anything before the final merge.
