# Rubric: Greenfield Design

Use this rubric when the prompt asks the candidate to design a system from scratch.

---

## Dimension: `system-design-scalability`

**What a strong staff answer surfaces.**

Before drawing a single box, the staff engineer characterizes load: read/write ratio, peak vs.
sustained throughput, fan-out behavior, and which component hits its ceiling first at 10x current
volume. They don't just name horizontal scaling — they reason about *where state lives* and what
that costs: a stateless API tier scales cheaply; a stateful session store or a hot partition on a
write-heavy table is where the design breaks. They can also argue *against* premature complexity:
if the load doesn't justify Kafka, a staff engineer says so and explains what traffic signal would
change that call.

A strong answer also treats caching as a consistency decision, not just a performance lever. It
names where invalidation happens and who owns it.

**Major/critical gap examples.**

- The candidate proposes a fan-out-on-write notification system for a social graph and never
  mentions that a celebrity account with 10M followers makes every write a 10M-row scatter. This
  is a `critical` gap: the core scaling assumption is broken for the dominant use case.
- The candidate scales out the API tier but routes all reads through a single-replica relational
  database with no read replicas or caching. At interview-volume traffic this works; at stated
  production load it is a bottleneck that causes cascading latency. `major`.

---

## Dimension: `data-consistency`

**What a strong staff answer surfaces.**

The staff engineer names the consistency contract the design offers callers — not just the storage
engine. "We use Postgres" is not a consistency model; "we offer read-after-write consistency within
a session and accept stale reads across sessions for feed data" is. They reason about what happens
to in-flight writes during a failover, and they design async pipelines with idempotency built in
(not bolted on after the first duplicate-delivery incident).

Schema evolution gets explicit treatment: a staff engineer does not propose a migration that requires
taking the table offline. They know the expand/contract pattern and can explain which step is
deployable independently.

**Major/critical gap examples.**

- The candidate designs an event-sourced system with downstream projections but never addresses
  what happens when the consumer crashes mid-batch. The projection can now be arbitrarily stale or
  partially applied with no recovery path. `major`.
- The candidate claims "strong consistency" while proposing an eventually-consistent multi-region
  active-active write model with no conflict resolution strategy. The guarantee stated cannot be
  delivered by the architecture described. `critical`.

---

## Dimension: `operability-resilience`

**What a strong staff answer surfaces.**

A staff engineer treats operability as a design outcome, not a deployment concern. Before the
session ends, a strong answer has named: what the on-call engineer sees when something goes wrong
(which alerts fire, which dashboard tells the story), how the system degrades gracefully under
partial failure, and how a rollout is reversed quickly. They frame SLOs as design inputs — "our
error budget is 0.1% over 30 days, so a cache miss storm that spikes error rate above 0.5% for 10
minutes burns a week's budget" — rather than as metrics added after launch.

Circuit breakers and bulkheads get mentioned when they are warranted, but more importantly the
engineer explains *what failure they are protecting against*: a circuit breaker without a named
cascade scenario is just jargon.

**Major/critical gap examples.**

- The candidate designs a synchronous dependency chain (API → payment service → fraud service →
  shipping service) with no timeout budget, no retry limits, and no degraded mode. A single slow
  downstream cascades into full availability loss. `major`.
- The design has no logging or tracing beyond "we'll add metrics later." An on-call engineer cannot
  determine root cause of an incident in a system with no structured signals. `major`.

---

## Dimension: `trade-offs-judgment`

**What a strong staff answer surfaces.**

The staff engineer owns their choices. When asked "why a message queue over a direct call?" they give
a cost/risk answer, not a list of features: "async decoupling buys us independent scaling and
back-pressure, at the cost of at-least-once delivery complexity and a harder debugging story — that's
worth it here because writes are bursty and the consumer can afford lag." They distinguish one-way
doors (chosen storage engine, wire protocol, public API shape) from two-way doors (internal service
split, caching strategy) and apply more rigor to the irreversible ones.

They also know when simplicity wins. Proposing a microservices mesh for a team of four is a
trade-off judgment failure — not a failure of technical knowledge.

**Major/critical gap examples.**

- The candidate consistently answers "it depends" and describes options without committing to one.
  At the staff level, equivocation is a judgment gap, not intellectual humility. `major`.
- The candidate selects a distributed consensus protocol (Raft/Paxos) for a use case where a
  single primary with standby failover is sufficient, without articulating what the added
  operational complexity buys. The cost/benefit math is not done. `major`.

---

## Dimension: `architecture-boundaries`

**What a strong staff answer surfaces.**

Even in greenfield design, the staff engineer explains *why* the service split (or lack of one) is
correct — what each boundary protects and what organizational structure it assumes. They surface
Conway's Law implications: a boundary that cuts across a single team's domain usually creates more
coordination cost than value. They also reason about what happens when the boundary is wrong: can
you merge two services later without a rewrite, or have you committed to the split by putting
divergent schemas on each side?

**Major/critical gap examples.**

- The candidate splits a monolith into 12 microservices on day one for a new product, with all 12
  sharing a single database. The deployment boundary was drawn without the data boundary, creating
  tight coupling at the persistence layer. `major`.
- No mention of API versioning strategy for a public-facing service. A breaking change in month 3
  becomes a coordinated migration with all callers. `major`.
