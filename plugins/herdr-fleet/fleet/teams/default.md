---
name: default
description: Stripped default roster — one orchestrator, five worker roles, and the curator that promotes what they learned.
triage_rules: triage-rules.md
members:
  - persona: orchestrator
    display_name: Orchestrator
  - persona: architect
    display_name: Architect
  - persona: researcher
    display_name: Researcher
  - persona: builder
    display_name: Builder
  - persona: reviewer
    display_name: Reviewer
  - persona: curator
    display_name: Curator
  - persona: runner
    display_name: Runner
peers:
  - [builder, reviewer]
---

The point of contact is derived, not declared here: `orchestrator` is this
team's single point of contact because its own persona file carries
`escalation_authority: orchestrator`. Every other member is `worker` — they
receive work and report back, and none of them can spawn anyone.

**Paths in this file's frontmatter resolve from the repository root**, not from
`teams/`. `triage_rules: triage-rules.md` means `<repo>/triage-rules.md`; there
is no `teams/triage-rules.md` and a loader that looks for a sibling will not
find one.

**Concurrency and isolation live in `agents/orchestrator.md`, not here.** The
worker cap and the worktree requirement are the orchestrator's rules, because
the orchestrator is what spawns. They are deliberately not restated in this
file — for the same reason the point of contact is derived above: a rule
written in two places is a rule that drifts, and the copy nobody edits is the
one that silently becomes wrong.

**Exactly one member of this roster carries `curates_memory: true`** -- here,
`curator`. That persona is the only writer of the per-persona memory indexes,
and the flag is what the wrapper composes the curation duties on. Declaring it
on a second member would put two sessions in one index with the loser's edits
lost; declaring it on none leaves every lesson from a run sitting unpromoted in
the logs, silently. A check refuses both, but the constraint belongs to whoever
is assembling a team, which is why it is written here as well as in
`memory-curation.md`. Reassigning it is fine -- moving the flag to another
persona moves the duty with it.

**Reviewer appears once in this roster but is spawned twice** — validate, then
judge, as two separate sessions. Noted here only because seven entries would
otherwise read as seven concurrent roles; the reason and the procedure are in
`agents/reviewer.md`.

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
not the edge check alone. It does not reach into the judge pass: `agents/orchestrator.md` spawns the
judge with `--no-peers`, which skips both the grant and the composed
instructions regardless of what this file declares, so a persona-level edge
can never cross the line that keeps validation and judgment in separate,
uncoordinated contexts. Whether a team wants a second edge (a
researcher↔builder pair, say) is a decision for whoever assembles that team —
adding one is a line in this list, not a redesign.

Roster names are presentation only. A themed team is a second file in this
directory pointing at the same `persona:` values and the same `triage_rules`,
differing only in `display_name` — a skin over one manifest, not a second
mechanism.
