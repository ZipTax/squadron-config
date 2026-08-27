# Auditing an A/B run

An A/B harness runs the same inputs against a **baseline** (pre-change) and a **variant**
(post-change) build and diffs the captured output. Your job is not to read the summary line;
it is to decide, per case, whether the observed behavior is what the change *should* have
produced.

## Two things a run never tells you

- **Green is not a pass.** All-matched means nothing diverged — which is failure for a case
  that was supposed to change.
- **A diff is not a pass.** A diff proves the change reached the output. It says nothing
  about whether the new value is *correct*.

A build/plan step succeeding proves less still: it validates mechanics, not behavior.

## Predict before you look

Write the expected per-case outcome **from the change itself** — read the changed code — and
from the requirement in the ticket. Do not predict from the PR description or commit message:
they are frequently wrong about their own change. Then compare each case's actual result to
that prediction.

Classify every case up front:

- **primary positive** — the change is supposed to reach it → must differ, *and* to the value
  you derived independently.
- **guardrail** — the change must not reach it → must match. A guardrail that differs is a
  blast-radius failure.

Treat each "looks fine" as a hypothesis to disprove.

## Diagnosing a primary positive that did not differ

A no-diff is never itself evidence the change is right; it means the change did not reach
the captured output. Determine which of these it is before concluding anything:

- **Shadowed** — the edited branch sits behind an earlier condition that always wins on the
  inputs in play. The code is dead until the ordering changes.
- **Unreachable** — the branch is gated on a condition the system already precludes. This is
  dead code, not missing coverage: report it and stop asking for a case that cannot exist.
- **Not exercised** — the inputs never entered the changed path (out-of-window dates, wrong
  entity, stale fixture). The case is at fault, not the code.
- **Masked** — the diff exists but only in noise columns, or the real columns are identical
  while noise makes it look like something moved.

Distinguish **unreachable** (prove it) from **untested** (fix the case). Guessing between
them is the single most expensive error in this stage.

## Fixtures are evidence, not just plumbing

If the harness supports per-case data fixtures applied to both arms, then "the harness can't
set up state X" is never a valid basis for a verdict: author the fixture or state precisely
why it is infeasible.

But treat the *need* for a fixture as its own signal. If a case only diverges after you
patch the gating data, the branch may be dead on real data — the case is invalid rather than
merely missing. Weigh that before authoring the fixture; "I had to patch the gating table to
get a diff" is the classic opening line of a false working-as-designed conclusion.

## Noise

Per-execution columns — timestamps, generated identities, run ids — are noise and belong in
the capture's ignore list. A case that differs only on those is a no-diff; fix the ignore
list as a separate concern, and remember the underlying no-diff may be hiding a no-op change.

## Scope and consistency

- Every path the change spans must be checked and must **agree**. A change corrected on one
  surface and missed on a parallel one is a worse state than before.
- Data changes must have a blast radius matching the migration exactly: the targeted entity
  diverges, its neighbours do not, and teardown reverts cleanly.
- Correct aggregate, wrong attribution is still a bug. Assert the identifying/classifying
  fields, not only the headline number.

## Exit bar

A satisfactory verdict requires all of: intended diffs present; each to a value you derived
independently and confirmed; guardrails flat; parallel paths in agreement; and every path
the change actually reaches covered by a case that ran. A path counts as not-needing
coverage only when you have *proven* the change cannot reach it — never because a case was
hard to build, and never on a hedge (see `evidence_gate`).
