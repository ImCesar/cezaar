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

Roster names are presentation only. A themed team is a second file in this
directory pointing at the same `persona:` values and the same `triage_rules`,
differing only in `display_name` — a skin over one manifest, not a second
mechanism.
