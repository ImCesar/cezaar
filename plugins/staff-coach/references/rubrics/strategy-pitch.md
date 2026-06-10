# Rubric: Strategy Pitch

Use this rubric when the prompt asks the candidate to make the case for a technical direction,
platform investment, or architectural change to stakeholders — where persuasion, narrative, and
audience calibration are first-class concerns alongside technical rigor.

---

## Dimension: `platform-leverage`

**What a strong staff answer surfaces.**

A strategy pitch for a platform investment lives or dies on whether the candidate can articulate
the *leverage* case: why building this capability multiplies the output of other teams rather than
just solving one team's problem. The staff engineer explains the difference between a paved road
(lowers friction, enables faster shipping for feature teams, has a visible escape hatch) and a
golden cage (forces adoption, increases platform team's roadmap authority at the expense of feature
team autonomy). The pitch should name who benefits, by how much, and on what timeline — not just
describe the platform's technical capabilities.

They also address adoption: a platform that is technically correct but takes six months to onboard
a new team is not a leverage play. The staff engineer names the onboarding friction and explains
how the design reduces it.

**Major/critical gap examples.**

- The candidate pitches a shared infrastructure platform by describing its technical architecture
  in detail without stating how many teams would use it, what they currently do instead, or what
  the estimated time-to-value is per team. The leverage case is absent. `major`.
- The candidate proposes mandating adoption of the new platform across all teams without an
  escape hatch or migration period, assuming org authority that they do not have as a staff
  engineer without management sponsorship. The pitch conflates technical merit with adoption
  strategy. `major`.

---

## Dimension: `influence-communication`

**What a strong staff answer surfaces.**

This is the dimension where strategy-pitch problems are most differentiated from design problems.
The staff engineer demonstrates altitude calibration: the same technical direction is pitched
differently to a VP of Engineering (business risk, cost, timeline, team impact) than to an
engineering review panel (technical trade-offs, migration path, failure modes). A strong pitch
identifies the audience and adjusts vocabulary, level of abstraction, and the framing of trade-offs
accordingly — without changing what is actually being recommended.

The staff engineer also structures the narrative: problem statement first (why does this matter
now?), then the proposed direction, then honest acknowledgment of the costs and risks, then a clear
ask. A pitch that buries the recommendation in technical detail or treats all options as equally
valid does not meet the staff bar.

They anticipate the strongest counterargument and address it directly. "This seems expensive" and
"we could just keep the current approach" are predictable objections; a strong pitch has answers
for both, with evidence.

**Major/critical gap examples.**

- The candidate frames the entire pitch for a VP audience in terms of technical architecture
  ("we'll migrate from a monolith to microservices using a strangler-fig pattern"). The VP cannot
  make a resource allocation decision from this framing. A staff engineer translates: "this reduces
  our per-feature release risk from monthly deploys to daily deploys, at a cost of X engineer-months
  of migration work." `major`.
- The candidate presents a comprehensive technical analysis but ends with "these are the options,
  the team should decide." A strategy pitch that defers the recommendation to the audience is not a
  pitch — it is a status update. `major`.

---

## Dimension: `trade-offs-judgment`

**What a strong staff answer surfaces.**

A pitch that ignores the cost of the proposed direction is not credible to a skeptical audience.
The staff engineer names the genuine downsides — migration effort, team disruption, new operational
complexity, opportunity cost — and explains why the benefit outweighs them in this context. They
also classify the decision's reversibility: if the pitch is for adopting a new data platform, the
audience needs to understand that this is a multi-year commitment, not a sprint-level experiment.

A strong pitch also sets the conditions under which the recommendation would change: "if our
traffic projections are off by more than 5x, a different storage model would be more appropriate."
This signals calibrated judgment, not advocacy.

**Major/critical gap examples.**

- The candidate builds a compelling case for the new direction but does not acknowledge the
  status quo's strengths. A skeptic in the room immediately questions the one-sided analysis, and
  the candidate has no prepared response. `major`.
- The candidate pitches a platform rebuild as a "quick win" or "low-risk investment" without
  quantifying migration cost, team capacity impact, or the period during which existing teams
  are blocked on the new platform's stability. Minimizing real costs to make a pitch easier is a
  credibility risk and a judgment failure. `major`.

---

## Dimension: `architecture-boundaries`

**What a strong staff answer surfaces.**

Strategy pitches often propose changes to service ownership, platform scope, or team topology.
A staff engineer reasons about whether the proposed boundaries align with the org's actual team
structure, and flags where a technically appealing boundary will create coordination overhead that
the org is not staffed to manage. Conway's Law is a pitch risk: if the proposed architecture
requires a team structure that doesn't exist, the pitch should either address how the team
structure will change or explain why the architecture is viable without it.

**Major/critical gap examples.**

- The candidate proposes centralizing data ownership in a new platform team but does not address
  how the existing domain teams will coordinate schema changes, or who resolves conflicts when two
  teams need incompatible changes. The governance model is absent. `major`.

---

## Dimension: `platform-leverage` (Paved Road vs. Golden Cage — extended)

**What a strong answer includes that weaker answers miss.**

The strongest strategy pitches show that the candidate has thought about the platform's *lifecycle*,
not just its launch. How does the platform stay relevant as teams' needs evolve? What is the
deprecation and versioning story for teams that have built on an earlier version of the platform?
What is the feedback loop between platform consumers and the platform roadmap?

These questions are not hypothetical at the staff level — they are the difference between a
platform that grows organically because it solves real problems and a platform that is mandated from
above and slowly abandoned by teams who work around it.
