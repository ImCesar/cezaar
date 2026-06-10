# Rubric: Architecture Review

Use this rubric when the prompt asks the candidate to critique an existing or proposed architecture.

---

## Dimension: `architecture-boundaries`

**What a strong staff answer surfaces.**

The staff engineer does not just list problems — they diagnose *why* a boundary is wrong. They ask
what each service or module boundary is protecting, whether the split aligns with team ownership,
and whether the boundary is enforced at the right layer (deploy-time, schema, API contract, or only
by convention). A strong review names the specific coupling — temporal, runtime, data — and explains
what failure mode it creates before proposing a remedy.

They also reason about the cost of the current structure versus the cost of changing it. A legacy
shared database is a serious coupling problem, but recommending an immediate strangler-fig migration
without acknowledging the migration cost is not a staff-level review — it's wishful thinking with
a diagram.

**Major/critical gap examples.**

- Two services share a mutable database table with no agreed contract on schema changes. The
  candidate identifies this as a smell but does not explain *when* it will cause a problem: any
  schema migration now requires coordinated deployment of both services. `major` gap if not surfaced.
- The candidate recommends splitting a service to reduce coupling but proposes a synchronous
  request/response dependency between the two halves at runtime. The deployment boundary moved;
  the runtime coupling did not. `critical` if the whole motivation for the split was to reduce
  availability blast radius.

---

## Dimension: `operability-resilience`

**What a strong staff answer surfaces.**

In a review, the staff engineer asks: does this architecture make the on-call engineer's life better
or worse than what it replaces? They look for whether failure modes are named and handled
(timeouts, circuit breakers, fallback paths), whether the observability story is coherent across
service boundaries (distributed trace IDs propagated, correlation between service-level metrics
and user-facing SLO), and whether the rollout strategy has a fast rollback path.

A strong reviewer also distinguishes between resilience that is *designed in* versus resilience that
is *assumed*. "The cloud provider handles this" is an operability assumption — the staff engineer
asks which failure scenarios that actually covers and which ones it doesn't.

**Major/critical gap examples.**

- A proposed architecture introduces a synchronous call from a low-latency read path into a
  high-latency third-party enrichment service with no timeout, no circuit breaker, and no cached
  fallback. The candidate reviews the functional correctness but does not surface the latency
  tail risk. `major`.
- The architecture spans three services with no distributed tracing strategy. When a user
  complaint arrives, there is no way to reconstruct the request path across service boundaries.
  The candidate does not flag this as an operational gap. `major`.

---

## Dimension: `cross-cutting-concerns`

**What a strong staff answer surfaces.**

A staff-level architecture review treats security, privacy, and multi-tenancy as design constraints
that should have shaped the architecture from the start — not checklist items to add before launch.
The reviewer asks: where are trust boundaries enforced, what is the blast radius of a credential
compromise, and does the tenant isolation model actually hold under the described data access
patterns?

Data classification also gets explicit treatment: if PII flows through a component, the reviewer
names it and asks whether encryption, retention, and deletion requirements are met. They don't
require the candidate to be a security expert, but they expect the candidate to have *asked the
right questions* at design time.

**Major/critical gap examples.**

- An internal service is exposed via a public load balancer with no authentication requirement,
  justified as "it's only reachable from inside the VPC." The candidate does not surface that
  lateral movement from any compromised internal service now has direct access. `major`.
- A multi-tenant system stores all tenant data in a single shared table partitioned only by a
  `tenant_id` column, with no row-level security or query-layer enforcement. A bug in any query
  that omits the `WHERE tenant_id = ?` clause leaks cross-tenant data. The candidate does not
  identify this as a trust boundary gap. `critical`.

---

## Dimension: `trade-offs-judgment`

**What a strong staff answer surfaces.**

Reviewing an architecture is itself a trade-off exercise: the staff engineer distinguishes problems
worth fixing now from problems that can be deferred — and explains the reasoning. They rank findings
by blast radius and cost-to-fix, not just by elegance. A strong reviewer also gives credit where
the architecture made a reasonable call under real constraints: "this looks over-engineered for
current scale, but if the team was planning for 50x growth at the time, this was defensible."

They own a recommendation. "Both approaches have merit" is not a staff-level review conclusion.

**Major/critical gap examples.**

- The candidate identifies five architectural problems of roughly equal severity and proposes
  fixing all of them simultaneously. At scale, a parallel migration of five components with
  interleaved dependencies is a recipe for prolonged instability. A staff-level reviewer
  sequences the work by risk and dependency order. `major` if this sequencing is absent.
- The candidate recommends replacing a battle-tested but messy monolith with a greenfield
  microservices rewrite, citing maintainability, without quantifying migration cost, team
  disruption, or the feature-freeze period during the rewrite. `major`.

---

## Dimension: `system-design-scalability`

**What a strong staff answer surfaces.**

Even in a review context, the staff engineer checks whether the described architecture can reach
the stated scale targets. They look for unacknowledged bottlenecks: a single-writer database for
a write-heavy workload, a fan-out design without back-pressure, a caching layer without an
invalidation strategy. They also flag when the architecture is over-engineered for actual load —
unnecessary complexity carries an operability cost that the review should name.

**Major/critical gap examples.**

- The candidate reviews a search indexing pipeline that uses synchronous writes to the index for
  every document update, with no queue. At high ingest volume this is an unbounded latency source
  and a cascading failure risk. The candidate does not flag the missing async decoupling. `major`.
