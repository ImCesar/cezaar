# Rubrics — Overview and Problem-Type Selection Guide

## Choosing the Right Rubric

Four rubrics cover the dominant staff-engineer problem types. Pick exactly one per session; the coach
and examiner load only the rubric in play.

| Rubric | Use when the prompt is… | Key signal |
|---|---|---|
| `greenfield-design.md` | "Design X from scratch" | The system does not exist yet; the candidate owns all architectural choices |
| `architecture-review.md` | "Critique this existing or proposed architecture" | A concrete design is on the table; the candidate's job is to evaluate, find gaps, and recommend changes |
| `trade-off-decision.md` | "Choose between options A and B" or "Should we do X?" | A specific decision with alternatives is in scope; the candidate must commit to a position and own its consequences |
| `strategy-pitch.md` | "Make the case for a technical direction / platform investment to stakeholders" | The candidate must persuade, not just analyze; audience calibration and narrative arc are first-class concerns |

When a prompt blurs two types (e.g., "design X and explain why you chose it over Y"), pick the rubric
whose dimensions dominate — usually `greenfield-design.md` — and note in your session that
`trade-offs-judgment` will be weighted heavily.

---

## Shared Severity-Band Definitions

Every rubric dimension is scored against three severity bands. The examiner applies these definitions
consistently across all problem types.

### `minor`

A gap that is real but carries low operational or organizational cost. Examples: imprecise vocabulary
when the intent is clear, an edge case not mentioned that would be easy to handle after launch, a
stylistic preference about diagram structure. A `minor` finding does not, on its own, change whether
a candidate meets the staff bar.

### `major`

A gap that would cause real incidents, non-trivial cost, or lasting team friction at scale if the
design shipped as described. Examples: no mention of back-pressure on an async pipeline that will be
hammered by bursty writes; a service boundary drawn at a shared database without acknowledging the
deployment coupling; a migration plan that requires a multi-hour maintenance window on a
customer-facing table. The candidate did not have to solve every hard problem — but a staff engineer
is expected to *surface* these risks and explain how they would be approached.

### `critical`

The design fails its core goal, or contains an assumption so wrong that the rest of the reasoning
collapses. Examples: a "distributed" design that introduces a single coordinator as the synchronous
path for every write; consistency guarantees claimed that the chosen storage engine cannot provide;
a cost/benefit argument that omits the dominant cost driver. A single `critical` gap typically means
the candidate does not meet the staff bar on that dimension.

---

## Examiner Posture

**The examiner suppresses `minor` findings by default (high-precision posture).** When asked for
feedback, the examiner reports only `major` and `critical` gaps unless the user has explicitly
requested full commentary. This avoids drowning useful signal in stylistic noise.

**`meets_staff_bar` is judged per dimension**, not as an overall pass/fail. A candidate can meet the
bar on `system-design-scalability` and fall short on `operability-resilience` in the same session.
The per-dimension breakdown is what makes the feedback actionable.
