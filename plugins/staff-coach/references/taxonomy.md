# Staff-Coach Topic Taxonomy

This is the intellectual backbone of the staff-coach tool. It defines the eight dimensions used to
assess staff-engineer competence, steers problem generation, and provides the vocabulary for rubric
scoring, progress tracking, and coaching probes.

**These dimension ids are a hard contract.** They are used verbatim as keys in `progress.json`, in
per-problem-type rubrics, and by the examiner agent. Do not rename or reorder them.

---

## Canonical Dimension IDs

```
system-design-scalability
architecture-boundaries
operability-resilience
data-consistency
trade-offs-judgment
cross-cutting-concerns
platform-leverage
influence-communication
```

---

## Table of Contents

1. [System Design & Scalability](#1-system-design--scalability)
2. [Architecture & Boundaries](#2-architecture--boundaries)
3. [Operability & Resilience](#3-operability--resilience)
4. [Data & Consistency](#4-data--consistency)
5. [Trade-offs & Judgment](#5-trade-offs--judgment)
6. [Cross-Cutting Concerns](#6-cross-cutting-concerns)
7. [Platform & Leverage (Hohpe)](#7-platform--leverage-hohpe)
8. [Influence & Communication (StaffEng)](#8-influence--communication-staffeng)

---

## 1. System Design & Scalability

**Dimension id:** `system-design-scalability`

A staff engineer doesn't wait to be asked about scale — they surface load characteristics, state
distribution, and bottleneck topology as first-class design concerns before anyone raises an outage
story. What distinguishes staff-level thinking here is the ability to reason about *where* in the
system a 10x traffic increase breaks first, and to design not just for current volume but for the
operational cost of the design at higher load (read amplification, fan-out, hotspot partitions). The
staff engineer can also articulate *why* a simpler design is correct when scale doesn't yet demand
the complexity — YAGNI is a load argument, not just a taste preference.

**Sub-topics:**
- Load characterization and traffic modeling (reads vs. writes, fan-out ratios, peak vs. sustained)
- Stateless vs. stateful service design and the cost of session/state affinity
- Horizontal partitioning strategies: sharding, consistent hashing, range vs. hash partitions, hotspot mitigation
- Caching layers: cache placement (CDN, edge, app-tier, DB-tier), invalidation strategies, stampede protection
- Async processing and queue design: back-pressure, consumer scaling, at-least-once vs. exactly-once, dead-letter handling
- Consistency/availability trade-offs under partition: when to favor one over the other and at which tier

---

## 2. Architecture & Boundaries

**Dimension id:** `architecture-boundaries`

Staff engineers are expected to articulate *why* a boundary exists — what it protects and what it
costs — not just draw boxes on a diagram. Good boundaries minimize coupling along change axes: the
right split is the one where each side can evolve independently without negotiating schema or
deployment with the other. The staff engineer reasons through Conway's Law implications proactively,
asks which teams own which services, and flags when a proposed boundary will create a tight
operational or contractual coupling that the org isn't staffed to manage.

**Sub-topics:**
- Coupling/cohesion analysis: temporal coupling, runtime coupling, deployment coupling, data coupling
- Service boundary heuristics: domain seams, change-rate alignment, team topology, the strangler-fig vs. big-bang migration
- API and contract design: versioning strategy, backward vs. forward compatibility, Postel's Law, explicit vs. implicit contracts
- Evolvability and schema evolution: anti-corruption layers, tolerant reader pattern, how to absorb upstream changes without re-deploying downstream
- Conway's Law: alignment (or deliberate misalignment) between org structure and system architecture
- Abstraction altitude: when to expose implementation detail vs. hide it, leaky abstraction detection

---

## 3. Operability & Resilience

**Dimension id:** `operability-resilience`

A design is not done until the on-call engineer can understand, diagnose, and recover from failures
without the original author. Staff engineers frame operability as a first-class design outcome: they
ask "how will we know it's broken?" before the system ships, define SLOs as design constraints (not
post-hoc metrics), and build degradation modes into the happy path, not as afterthoughts. The
distinction between staff and senior here is that the staff engineer reasons about the *operational
cost* of a design — alert fatigue, manual intervention steps, blast radius — before a failure
happens.

**Sub-topics:**
- Observability design: structured logging, distributed tracing, metrics cardinality, the three-pillars model and where it breaks down
- Failure mode analysis: cascade failure, partial failure semantics, bulkheads, circuit breakers, timeout/retry budgets
- Graceful degradation: feature flagging for shedding load, read-only fallbacks, partial result serving, shed-vs-queue decisions
- Rollout and rollback: blue/green, canary, progressive delivery, feature toggles, what makes a rollback *fast* vs. *possible*
- SLO/SLA design: error budget framing, burn-rate alerting, the tension between SLO tightness and release velocity
- On-call burden as a design metric: runbook coverage, alarm-to-action ratio, mean-time-to-understand vs. mean-time-to-recover

---

## 4. Data & Consistency

**Dimension id:** `data-consistency`

Staff engineers reason about data not just as a storage choice but as a consistency contract: what
guarantees does the system offer to callers, and what happens when those guarantees are violated?
The staff engineer is expected to identify the consistency model a design *actually* provides (vs.
the one it claims), flag schema evolution as a deployment risk, and design migrations so they don't
require coordinated downtime. A particularly common staff-level gap is failing to reason about
idempotency across async boundaries — treating double-delivery as a deployment concern rather than
a data-integrity concern.

**Sub-topics:**
- CAP posture: CP vs. AP trade-offs in practice, what "eventual consistency" actually means operationally, partition behavior under network split
- Storage engine selection: OLTP vs. OLAP, document vs. relational vs. graph, when polyglot persistence is justified vs. complexity for its own sake
- Schema evolution and backward compatibility: additive vs. breaking changes, how to deploy schema changes safely (expand/contract, dual-write)
- Migration strategy: online vs. offline migrations, shadow writes, data backfill patterns, verifying migration correctness without downtime
- Idempotency design: idempotency keys, deduplication at the consumer layer, safe retry semantics across async message boundaries
- Read vs. write consistency: read-after-write consistency, stale reads in replicated systems, where to accept lag and where it's dangerous

---

## 5. Trade-offs & Judgment

**Dimension id:** `trade-offs-judgment`

The ability to make and *articulate* trade-offs is the defining staff-engineer competency — more
than any single technical domain. A junior engineer treats decisions as having right answers; a staff
engineer treats them as cost/risk trades with an explicit rationale that should survive scrutiny
from a skeptical VP or a future team. The key staff-level tell is *reversibility reasoning*: the
engineer distinguishes one-way doors (hard to undo without pain) from two-way doors (easy to reverse
if wrong) and applies proportionally more rigor to the irreversible ones. The trade-off is also
*owned*: the staff engineer doesn't hedge with "it depends" — they commit to a position and own its
consequences.

**Sub-topics:**
- Reversibility classification: one-way vs. two-way doors, how reversibility changes the required confidence before commitment
- Build vs. buy analysis: total cost of ownership (not just licensing), maintenance burden, lock-in risk, exit cost
- Technical debt framing: planned vs. accidental debt, debt as a deliberate financing instrument, when paying it down is and isn't worth it
- YAGNI and scope discipline: how to reason about features not yet needed, the cost of premature generalization
- Cost/complexity/speed triangle: how to make explicit what is being traded, and against what timeline
- Decision documentation: how to write an ADR that surfaces the alternatives considered and the reasoning, not just the outcome

---

## 6. Cross-Cutting Concerns

**Dimension id:** `cross-cutting-concerns`

Security, privacy, multi-tenancy, and compliance are not "someone else's layer" at the staff level —
they are design inputs that constrain architecture choices before implementation begins. A staff
engineer is expected to ask "what's the blast radius if this credential is compromised?" or "what
does data residency mean for our partitioning model?" without being prompted. The defining gap here
is treating these as checklist items at the end of a design rather than as constraints that shape
the design from the start — particularly around trust boundaries, data classification, and tenant
isolation model.

**Sub-topics:**
- Trust boundary design: where authentication and authorization decisions live in the architecture, token propagation, service-to-service trust
- Data classification and handling: PII/sensitive data tagging, encryption at rest vs. in transit, key management, deletion/retention obligations
- Multi-tenancy models: shared schema vs. shared DB vs. siloed, tenant isolation guarantees, blast radius of a tenant misconfiguration
- Threat modeling basics: STRIDE or equivalent, what surfaces attack exposure, how to reason about the cost of a control vs. the risk it mitigates
- Compliance as design constraint: GDPR/CCPA data residency and portability requirements, SOC 2 audit surface reduction, right-to-erasure implementation
- Supply chain and dependency risk: third-party library exposure, SBOMs, how to reason about transitive dependencies in a security context

---

## 7. Platform & Leverage (Hohpe)

**Dimension id:** `platform-leverage`

Inspired by Gregor Hohpe's *The Software Architect Elevator*, this dimension captures whether the
engineer thinks in terms of *leverage* — building capabilities that multiply the output of feature
teams — or only in terms of solving the immediate problem in front of them. The staff engineer asks:
"should this be a platform capability or a feature?" and can articulate the answer in terms of
adoption cost, standardization benefit, and the difference between a *paved road* (genuinely reduces
friction) and a *golden cage* (forces adoption at cost of team autonomy). The "elevator" framing is
about operating at multiple altitudes simultaneously: connecting exec strategy to engine-room
reality without distorting either.

**Sub-topics:**
- Platform vs. feature distinction: how to identify when solving a problem in a feature creates a platform need, and when building a platform is premature
- Paved road design: what makes an internal platform *actually* adopted (low onboarding cost, escape hatch design, visible success stories) vs. mandated and resented
- Internal API and abstraction design: how to expose platform capabilities without leaking implementation, versioning for internal consumers
- The architect elevator (Hohpe): operating effectively at the exec strategy layer and the engine-room technical layer — translation without distortion
- Org-level technical vision: how to write a technical strategy document that is specific enough to be actionable and stable enough to be a north star
- Make-vs.-buy-vs.-adopt at the platform layer: open-source foundation, internal fork, buy SaaS, build from scratch — and the adoption and migration costs of each path

---

## 8. Influence & Communication (StaffEng)

**Dimension id:** `influence-communication`

Inspired by *Staff Engineer: Leadership Beyond the Management Track*, this dimension covers the work
that happens outside the IDE: driving alignment across teams, pitching technical positions to
non-technical stakeholders, and translating between engineering detail and business consequence. A
staff engineer operates without formal authority — influence is the only lever available for
cross-team decisions. The key staff-level bar is *altitude calibration*: the ability to pitch the
same decision at the right level of abstraction for the audience (board room vs. engineering review)
without losing accuracy or credibility. This is also where the staff engineer creates *written
artifacts* (RFCs, architecture decision records, technical visions) that outlast any one meeting.

**Sub-topics:**
- Altitude calibration: how to frame a technical argument for an executive vs. an engineering review vs. a product team — same substance, different vocabulary
- RFC and design doc craft: what makes a proposal persuasive (clear problem statement, explicit alternatives, honest trade-off table, unambiguous recommendation)
- Cross-team alignment: how to drive a decision that requires multiple teams to change behavior — without authority, using influence, written artifacts, and working groups
- Technical vision documents: scope, time horizon, specificity threshold, how to make a technical vision durable and revisable as the org learns
- Communicating risk: how to present a technical risk to a non-technical stakeholder in a way that enables a real decision (not paralysis, not false comfort)
- Giving and receiving architecture feedback: how to structure a code/design review that surfaces real problems without being noise, and how to respond to criticism of your own designs constructively
