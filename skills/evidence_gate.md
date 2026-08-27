# Evidence gate

Applies to every claim you make, relay, or accept from a delegated session. A claim is
**load-bearing** if a verdict, route, fix, or hand-off depends on it.

## Every load-bearing claim carries a basis

| Basis | Meaning | Can support a terminal verdict? |
|---|---|---|
| `measured` | A run, capture, probe, or query produced this value in this case. Cite the artifact and the value. | yes |
| `traced` | Read directly out of the source at a named location. Cite file + symbol/line. | yes |
| `inferred` | Derived from the above by reasoning that was not itself executed. | **no** |
| `hedge` | Expectation, convention, analogy, or "should be" with nothing behind it. | **no** |

A claim without a basis is a `hedge`. Say so rather than letting it pass unlabeled.

Hedge language to catch in your own output and in a session's report: *presumably, should
be, expected to, likely uses the same, indirect evidence is strong, no access so I assumed,
consistent with, appears to*.

## Gates

Before emitting a terminal verdict, state each gate as `pass` / `fail` / `n/a` with the
citation that decides it:

1. **Question match** — the verdict answers the question that was asked, at the same scope
   (same entity, period, path, component). A different-but-related answer is a `fail`.
2. **Basis** — every load-bearing claim is `measured` or `traced`.
3. **Divergence located** — for a disputed value, the *first* point where expected and
   actual part ways is named, not just the end result.
4. **Alternative killed** — the competing explanation you considered is disproven by cited
   evidence, not left unmentioned.
5. **Scope stated** — what this does NOT cover is written down.

Any `fail` means the verdict is not terminal. Downgrade to *incomplete* and emit exactly
what evidence would close the gate — the specific query, capture, or file to read — rather
than a softened conclusion.

## Unknown is a valid, cheap answer

`Unknown from available evidence` plus the named missing artifact ends a stage cleanly.
An inferred verdict that turns out wrong costs a full extra round. Prefer the former.

## When you hold no credentials

You cannot measure anything yourself; you reason over what a delegated session returns. So
the gate applies to what you *accept*: if a session reports a conclusion without a basis,
that is a gate failure on the session, and the correct move is to send it back for the
missing evidence — not to relay it upward with your own confidence attached.
