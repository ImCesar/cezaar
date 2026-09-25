---
name: execution
description: Builds an architecture into reviewed, judged and integrated changes — one orchestrator and six worker roles.
lead: orchestrator
members:
  - persona: builder
    display_name: Builder
  - persona: reviewer
    display_name: Reviewer
  - persona: judge
    display_name: Judge
  - persona: integrator
    display_name: Integrator
  - persona: researcher
    display_name: Researcher
  - persona: runner
    display_name: Runner
takes: [architecture]
produces: [execution-report]
policy: [triage-rules.md, review-bar.md]
# Reserved for #28 (in-team builder/reviewer loop). Empty until that issue
# gives it a shape.
loop: {}
peers:
  - [builder, reviewer]
---

The point of contact is the lead of whichever team was invoked, and
`/herdr-fleet:invoke-team execution` makes the operator's session this team's
`lead`, `orchestrator`. Leading some team is what `escalation_authority:
orchestrator` in a persona file means, and `make check-personas` holds the two
together: every lead declares it and no other persona does. The members
receive work and report back, and none of them spawns anyone. The lead is not
also listed in `members`; it is a separate field so the point of contact is
read from one place rather than declared twice.

**Paths in this file's frontmatter resolve from the repository root**, not from
`teams/`. `policy: [triage-rules.md]` means `<repo>/triage-rules.md`; there is
no `teams/triage-rules.md` and a loader that looks for a sibling will not find
one. `policy` is optional — a team with none names an empty list or omits the
field.

**Concurrency and isolation live in `agents/orchestrator.md`, not here.** The
worker cap and the worktree requirement are the orchestrator's rules, because
the orchestrator is what spawns. They are deliberately not restated in this
file — for the same reason the point of contact is derived above: a rule
written in two places is a rule that drifts, and the copy nobody edits is the
one that silently becomes wrong.

**Memory curation is fleet infrastructure**, handled by `system/curator.md`
through `herdr-fleet.sh curate`, and teams never name it.

**`peers:` declares which personas may message each other directly**, with
`herdr-fleet.sh tell`, instead of round-tripping every leg of an iteration
through the orchestrator's own context. An edge is an unordered pair —
`[builder, reviewer]` licenses either side to message the other, not one
direction only — and this roster declares exactly the one edge the operator
asked for: a builder and the reviewer validating its change can go back and
forth without the orchestrator relaying findings and fixes by hand. An edge
here is authority, not obligation — nothing requires two peers to talk, and a
worker whose persona declares no edge is refused by `tell` itself the moment
it tries: the `Bash(... tell <id>:*)` grant travels with every worker
regardless of what this file says about them (spawn's own `--no-peers` flag is
what withholds it, not the absence of an edge), but the wrapper checks this
file before delivering, so having the command is not having anyone to say
anything to. The grant is also pinned to each worker's own id, so having the
command is not having someone else's identity to say it under, either — this
file's edges answer *which pairs may talk*, the pinned grant answers *who is
allowed to speak as whom*, and it takes both together to be the enforcement,
not the edge check alone. It does not reach the judge:
`agents/orchestrator.md` spawns `judge` with `--no-peers`, which skips both
the grant and the composed instructions regardless of what this file
declares, so a persona-level edge can never cross the line that keeps
validation and judgment in separate, uncoordinated contexts. Whether a team
wants a second edge (a researcher↔builder pair, say) is a decision for
whoever assembles that team — adding one is a line in this list, not a
redesign.

Roster names are presentation only. A themed team is a second file in this
directory pointing at the same `persona:` values and the same `policy`,
differing only in `display_name` — a skin over one manifest, not a second
mechanism.
