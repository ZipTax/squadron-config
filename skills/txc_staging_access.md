# TaxCloud staging data access

Staging is a **dated copy** of the two production databases (`FedTax-<yyyymmdd>` /
`Reports-<yyyymmdd>`). The connection settings and credentials live in the Devin environment
(`RATEBENCH_*`) — they are not yours to hold or to paste. Never put a host, user, or password
in an objective, a prompt, or a ticket comment.

## The snapshot is the best available data — and it is dated

The dated databases are the freshest data a session can query. There is no newer source it can
reach, so do not instruct one to go looking for one, and **do not discount a finding on the
grounds that the snapshot is stale or incomplete**. That discount is a common route to a false
working-as-designed verdict.

What the discount is protecting against is a different, narrower thing, and the distinction
matters on every route you take:

- A snapshot row **establishes behavior in that dated copy** — a legitimate, citable
  `measured` fact, labeled with the copy's date.
- A snapshot row does **not** establish current production configuration. Where the verdict
  turns on config that may have changed since the snapshot date (a rate row, an enrollment, a
  certificate), that step needs a current-production fact, which only a human can supply.
- The absence of a row in the snapshot is not proof of absence in production.

So: never let a session dismiss a snapshot finding as stale, and never let it promote a
snapshot row into a claim about today's production config. Both are gate failures under
`evidence_gate`; the second returns `EVIDENCE_INCOMPLETE` naming the production query needed.

If the merchant or transaction a case needs is absent from the snapshot, push for a comparable
substitute. Only when that is genuinely impossible is it a coverage gap — and then it is
reported as a gap, not smoothed over.

## When a session cannot reach staging

Older sessions may predate the environment wiring. Do not preemptively hand out variables or
request a password. Wait until the session reports it cannot reach the database, then have it
check its `.env` for the `RATEBENCH_*` settings, and if a secret is genuinely missing have the
session request it from a human through Devin's secret request — the value never passes
through you.

## Querying

Read-only, bounded, indexed — but none of the how is yours. The repo owns it: have the session
load `write-taxcloud-sql-query` (produces the scoped query) and `query-staging-snapshot`
(executes it with ratebench's `cmd/sqlprobe`, and documents the date/index traps) rather than
improvising SQL or scaffolding a querier. Relaying query advice from here produces stale SQL.

The session's login is read-only and cannot reach the canonical databases the ratevariant
deploy/run/cleanup commands default to. Those mutate shared staging and are driven through the
PR labels, never from a session.
