# Learning Resources

Reference for surfacing targeted reading and materials. Read this whenever the question of resources
comes up during or after a session.

---

## Timing — protect the Socratic loop

Materials surface in exactly two places: **after the examiner reveal** (at the end of a session,
once the verdict and reconciliation are done) and **in the `progress` report** (when the user asks
about their learning history).

If the user asks for resources mid-loop — "what should I read about this?" — the coach bookmarks it:
"Good question; I'll include that in the post-session recommendations." Nothing is shared until after
the reveal.

The reason is the same as for withholding answers: a resource recommendation mid-loop is a soft
answer. It points the user at exactly the gap the coach just noticed, which tells them where to look
and what to think. That information reaches them before the examiner grades, which changes what they
say in the remaining turns and corrupts the signal. The Socratic discipline only holds if the user
is reasoning from their own understanding during the session.

---

## Source — hybrid, no hallucinated links

Resources come from two places:

1. The curated map below, keyed to dimension ids. These are anchors with known provenance that can
   be cited confidently without a web fetch.
2. Live web search to supplement, freshen, or find something more targeted than the curated anchors
   can provide.

**Hard rule: never cite a URL that was not actually retrieved.** If a web search is the right tool
and the search doesn't produce a usable result, say so — do not invent a plausible-sounding link. A
hallucinated citation teaches nothing and destroys trust in the recommendations. When in doubt,
point to the book or the known resource by name without a URL rather than fabricate one.

---

## Format

Each recommendation is 1–3 targeted pointers, ordered "start here → go deeper." Each pointer gets
a one-liner that explains why it maps to the specific gap — not a generic description of the book,
but a direct connection to what the session revealed.

Example (for a `data-consistency` gap around idempotency across async boundaries):

> 1. *Designing Data-Intensive Applications*, Kleppmann — ch. 11 (stream processing) covers exactly
>    the at-least-once delivery and idempotency-key patterns your pipeline was missing. Start here.
> 2. The "exactly-once semantics" section of the Kafka documentation (retrieved) — concrete API for
>    the pattern in the specific queue you chose.

The goal is a pointer that the user can act on immediately, not a reading list that defers the work.

---

## Curated anchor map

These resources are well-established and can be cited by name without a live fetch. Map them to the
relevant dimension(s) when surfacing recommendations.

### `system-design-scalability` / `data-consistency`

**Martin Kleppmann, *Designing Data-Intensive Applications* (O'Reilly, 2017)**
The canonical reference for distributed systems reasoning at the staff level. Covers consistency
models, replication, partitioning, stream processing, and the operational consequences of each
design choice. Chapter-level targeting is easy — send the user to the chapter that matches the gap,
not the whole book.

### `platform-leverage` / `influence-communication`

**Gregor Hohpe, *The Software Architect Elevator* (O'Reilly, 2020)**
The primary inspiration for the `platform-leverage` dimension. Directly addresses the architect's
job of operating at multiple altitudes simultaneously — translating between exec strategy and
engine-room reality — and the distinction between paved roads and golden cages.

### `influence-communication`

**Will Larson, *Staff Engineer: Leadership Beyond the Management Track* (Larson, 2021)**
The primary inspiration for the `influence-communication` dimension. Covers influence without
authority, RFC craft, technical vision documents, and altitude calibration across audiences. Most
useful when the session revealed gaps in how the user articulates trade-offs or drives alignment.

### `architecture-boundaries`

**Sam Newman, *Building Microservices* (O'Reilly, 2nd ed., 2021)**
Covers service boundary heuristics, coupling analysis, contract design, and the operational cost of
a boundary decision. Most useful when the session revealed gaps in how the user reasons about where
to draw lines and what each line costs.

### `operability-resilience`

**Betsy Beyer et al. (eds.), *Site Reliability Engineering* (Google / O'Reilly, 2016)**
The foundational text for SLO design, error budgets, and operational thinking as a first-class
design discipline. Available free online at sre.google/sre-book/table-of-contents/. Most useful
when the session revealed gaps in observability design, failure mode reasoning, or on-call burden.

### `trade-offs-judgment`

**Michael Nygard, *Release It!* (Pragmatic Bookshelf, 2nd ed., 2018)**
Stability patterns — circuit breakers, bulkheads, timeouts, back-pressure — framed as deliberate
design choices with explicit trade-offs. Most useful when the session revealed that the user treated
resilience as an afterthought rather than a design input.

### `cross-cutting-concerns`

**OWASP Threat Modeling (owasp.org/www-community/Threat_Modeling)**
The practical starting point for threat modeling at the design level. Use when the session revealed
that the user treated security as a checklist rather than a design constraint. Cite by name; fetch
the current URL at recommendation time rather than hardcoding it here.

---

## Supplement with web search

For gaps that the curated map doesn't cover well — specific technologies, recent patterns, papers on
a particular consistency model — use web search to find a targeted resource. Apply the no-uncited-link
rule: retrieve it, confirm it answers the gap, then cite it with enough context for the user to
evaluate whether it's worth their time.
