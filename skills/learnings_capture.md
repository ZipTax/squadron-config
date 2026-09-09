# Capturing learnings

Most cases teach nothing durable and should end without a write-back. A learning is worth
recording only when it is both durable and new: it would change how the *next* case is
handled, and it is not already written down. Grep the destination first — a rule restated in
a second place is two sources of truth waiting to disagree, and an entry already present takes
at most this ticket added as another instance.

## Is it generalizable?

Record it when it is a **rule about the system or the process**, restated so it applies
beyond this case:

- a trap that produced a wrong conclusion and would again (a shadowing pattern, an index
  requirement, a surface that must be checked in parallel with another);
- a fact about the environment or tooling that was expensive to discover;
- a place where the documented behavior and the actual behavior differ.

Do not record: the outcome of this ticket (that lives on the ticket and the PR), a restatement
of existing documentation, or anything you could not cite (`evidence_gate` applies —
speculative "lessons" are worse than none, because they get trusted).

## Where it goes

Route through one session, which may legitimately write to several repos — a lesson is often
both a repo trap and a workflow rule. Route each part by what kind of thing it is:

| Kind of learning | Destination |
|---|---|
| How to work in a repo — a trap, a procedure, a tool invocation | that repo's skill/docs directory, as a PR |
| How to run this workflow — a stage boundary, a verdict rule, a gate | the corresponding skill here, as a PR |
| A fact about the system's data or configuration | the owning repo's reference docs |
| A rate-audit precedent (symptom → mechanism → how it was proven) | `ratevariant-audit/references/case-law.md` in `txc-sqlserver-database` |
| A proven instance of a `new-rate-engine`-labelled deferral | `ratevariant-audit/references/limitations.md`, under the labelled ticket it instances |
| An unproven mechanism hypothesis for an open ticket | `ratevariant-audit/references/open-theories.md`, labelled as a hypothesis |

Every destination above is a file in a repo, reached by a PR. There is deliberately no "general
knowledge base" row: a delegated session cannot write org knowledge notes, so routing a
learning there means it is silently lost. Cross-repo context goes to the repo whose sessions
need it most, and a human promotes it further if it deserves it.

Prefer amending an existing document over adding a new one, and keep it short: a rule plus
the one case that demonstrates it. Case law earns its keep by being cited, not by being long.

## How

Propose the write-back through the session that holds the evidence and the credentials, as a
normal reviewable change. Never write to a durable store silently, and never edit history or
a data source that is the system's source of truth as a "learning" — a learning is
documentation, not a mutation.

State plainly when nothing is worth recording. That is the common case.

## The case log is not one of those destinations

The per-run log of what each case was and where it was written back lives in the `rate_case_log`
memory, and the finalize stage writes it itself with its own file tools. It is orchestrator state:
it is never delegated to a session, and it is never a file in a repo — a committed `cases.md` is
this line being ignored, or the memory slot failing to attach.

The repo's `case-law.md` is the other half of the pair and holds only what generalizes. One is a
ledger of runs, the other a set of precedents; keeping them apart is what stops the precedents from
drowning in entries that taught nothing.
