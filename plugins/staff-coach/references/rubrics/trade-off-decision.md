# Rubric: Trade-off Decision

Use this rubric when the prompt asks the candidate to choose between options or make a specific
technical decision (e.g., "should we use event sourcing or CRUD?", "SQL or NoSQL for this
workload?", "build or buy?").

---

## Dimension: `trade-offs-judgment`

**What a strong staff answer surfaces.**

The staff engineer commits to a position and owns it. They structure the decision along explicit
axes — cost, complexity, reversibility, team capability, time-to-value — and state which axis is
*actually* dominant for this context. A strong answer distinguishes one-way doors from two-way
doors: choosing a public API contract or a storage engine is harder to undo than choosing a library
or a caching strategy, and the rigor applied to each should reflect that asymmetry.

They also handle the cost of the alternative seriously. "Option B has these downsides" should be
as specific as the case for Option A — otherwise the comparison is not a trade-off, it's a
preference dressed up as analysis. The staff engineer also surfaces what would change their mind:
if a stated assumption turns out to be false, which direction does the decision flip, and how
quickly?

**Major/critical gap examples.**

- The candidate presents two options with a thorough pro/con list but ends without a
  recommendation, saying the choice "depends on the team's preferences." At the staff level,
  declining to own a decision when the context is sufficiently specified is a judgment failure,
  not appropriate humility. `major`.
- The candidate chooses an event-sourcing architecture for a use case where the dominant query
  pattern is "give me the current state of a record," without acknowledging that rebuilding
  projections at query time is costly or that CQRS complexity is now mandatory. The
  cost of the chosen option is underweighted. `major`.

---

## Dimension: `data-consistency`

**What a strong staff answer surfaces.**

Many trade-off decisions hinge on what consistency guarantees the system needs to provide, and a
staff engineer makes this explicit. When comparing storage engines, they reason about which
consistency model each provides under partition, not just the headline feature comparison. When
choosing between synchronous and asynchronous communication, they name what happens to data
integrity when the async consumer crashes: is the at-least-once delivery semantics handled, or is
a double-apply a bug waiting to happen?

They also reason about migration: if the decision involves switching from the current approach to
the new one, what is the migration path? A decision that requires a coordinated multi-day migration
on a live customer-facing table is a different kind of commitment than one that can be deployed
incrementally.

**Major/critical gap examples.**

- The candidate recommends switching from a relational store to a document store for a system with
  multi-entity transactions, without addressing how referential integrity and atomic multi-document
  updates will be maintained in the new model. The consistency requirement was not carried through
  the decision. `major`.
- The candidate proposes dual-writing to old and new systems during migration but never addresses
  what happens when the two writes are not atomic: a partial failure leaves the system in an
  inconsistent state. `major`.

---

## Dimension: `system-design-scalability`

**What a strong staff answer surfaces.**

When scale is a driver of the decision, the staff engineer quantifies it. "The NoSQL option scales
better" is not a trade-off argument; "at our projected 50K writes/second, Postgres single-primary
hits its ceiling and we'd need sharding anyway — at which point operational cost exceeds the NoSQL
migration cost" is. They also distinguish scaling bottlenecks: the decision that solves the write
throughput problem may not solve the read fan-out problem, and a strong answer names both.

When scale is *not* a driver, the staff engineer says so explicitly, which is itself a judgment
call — one that prevents premature optimization from driving a complexity choice.

**Major/critical gap examples.**

- The candidate recommends a distributed consensus-based approach (e.g., Zookeeper for
  coordination) for a system currently handling dozens of requests per second, without acknowledging
  that the operability cost of that infrastructure is not justified at current or near-term load.
  `major`.

---

## Dimension: `operability-resilience`

**What a strong staff answer surfaces.**

Trade-off decisions have operational consequences that are easy to underweight in a comparison
table. A staff engineer asks: which option is easier to debug when it goes wrong, which has a
faster rollback path if the migration fails, and which creates less on-call burden at steady
state? A decision that saves two weeks of engineering time but adds a permanent increase in incident
response complexity is not obviously the right call.

**Major/critical gap examples.**

- The candidate recommends adopting a new message broker to replace direct HTTP calls, citing
  resilience, but does not address how the engineering team will gain operational expertise in
  the new system before it carries production traffic. The resilience gain is real, but the
  mean-time-to-understand during the first incident is much worse than the baseline. Not surfacing
  this is a `major` gap.

---

## Dimension: `influence-communication`

**What a strong staff answer surfaces.**

A trade-off decision often needs to be communicated to stakeholders who do not share the technical
context. A staff engineer can summarize their reasoning in two sentences for an engineering manager
and in one sentence for a VP — without losing the honest assessment of risk. They also anticipate
the counterargument: what will the skeptic say, and how do they address it in the writeup?

**Major/critical gap examples.**

- The candidate produces a technically thorough decision document but frames it entirely in
  implementation terms. A VP reading it cannot determine what the business risk of each option is
  or which decision they should want. `major` in contexts where stakeholder alignment is needed.
