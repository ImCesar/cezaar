---
name: invoke-agent
description: Use when you want one fleet persona (researcher, builder, architect, reviewer, runner...) to take a single piece of work in its own Herdr pane, on its own model and effort, with a fresh context, while you keep working. Invoked as /herdr-fleet:invoke-agent <agent> [input]. Symptoms - "have the researcher look into X", "get a builder on this build-spec".
---

# Spawn one Herdr Fleet persona

This skill is a **loader**. The persona's instructions, and the templates for
what it takes and produces, live in a fleet home on disk. Read them; do not
work from a summary, including this one.

Unlike `invoke-team`, your session does not become anyone. It writes a brief,
spawns the persona in its own pane, and stays free while the persona works.
The persona runs on its own `model:` and `effort:`.

## 1. Find the fleet home

Follow section 1 of `<plugin>/skills/invoke-team/SKILL.md`, the sibling of
this file, exactly: the same order (cwd, then `~/.fleet`, then install the
seed), the same check, the same handling of an older fleet home, the same
rule never to overwrite. You are reading
`<plugin>/skills/invoke-agent/SKILL.md`, so you know that path. It is one
procedure kept in one place, because two copies drift.

Say which home you are using, as an absolute path. Below it is `<home>`, and
it goes into every command, since shell state does not survive between your
commands.

## 2. Resolve the persona, and refuse a system one

The agent is `<home>/agents/<agent>.md`.

- If `<home>/system/<agent>.md` exists instead, **refuse**. System personas
  (the curator today) are fleet infrastructure, not something you invoke:
  each has its own verb, and the curator's is `herdr-fleet.sh curate`, run by
  `invoke-team` at the close of a clean run.
- If neither exists, say so and list `<home>/agents/*.md`.

## 3. Check for live workers first

Until per-run state lands (#23), every run shares one manifest, so a persona
spawned here sits beside any team run already in progress, and that run's
`cleanup --all` or `curate` would sweep it up too.

```sh
sh "<home>/scripts/herdr-fleet.sh" status
```

If any worker in it is live, **say so, name them, and ask** before spawning.

## 4. Read the persona, then write the brief

Read `<home>/agents/<agent>.md`, spelling out the path. Its `takes:` lists the
inputs it needs, and every listed type is required. For each one read the
template `<home>/artifacts/<type>.md`, and read the template for each type in
its `produces:` too.

Write the brief by filling in those input templates, from what the invocation
gave you and what the operator tells you. **Ask for anything missing**; do not
invent it. Then:

- tell the persona where to write its `produces` artifact: the template's
  `written_to`, resolved from `<home>`, with `{type}` the artifact type,
  `{id}` the worker id you pick below and `{slug}` a short name for the work,
  unless the operator named another location;
- **end the brief with the literal line `<completion contract>`**, alone, as
  its final line. `spawn --brief` resolves it into the report-path sentence
  `await` waits on. A brief without it produces a worker that finishes and an
  `await` that never returns. `<home>/agents/orchestrator.md` has the full
  rule, under "Every brief must end with its completion contract".

Pick a worker id that is not already in the manifest, such as
`<agent>-<slug>`. Write the brief to a file in your scratchpad.

## 5. Spawn it

```sh
sh "<home>/scripts/herdr-fleet.sh" spawn <id> "<home>/agents/<agent>.md" \
  --brief <brief-file> --cwd <repo-the-work-concerns>
```

Model and effort come from the persona. Add `--model` or `--effort` only if
the operator asks for them. Add `--trust-cwd` when the cwd is one Claude has
not run in before, such as a fresh worktree. A persona that writes code gets a
worktree of its own, as `<home>/agents/orchestrator.md` describes. Ask the
operator before creating one.

There is no team here, so there is no `FLEET_TEAM`, and the persona has no
peers to `tell`.

## 6. Wait in the background

```sh
sh "<home>/scripts/herdr-fleet.sh" await <id>
```

Run it as a background command, so the operator's session stays free while
the persona works; you are notified when it exits. Its exit code is a
contract:

- `0`: the report is written. Its path is on stdout.
- `3`: the worker is blocked, waiting on input. Tell the operator and show the
  pane (`read <id>`); it is not finished.
- `4`: the worker is gone and left no report.

## 7. Report

Read the worker's report and tell the operator where the persona's `produces`
artifact is, with a short summary of what it says, and anything the report
lists as open.

**Do not curate.** The persona appended what it learned to
`<home>/memory/<agent>/decisions.md`, which persists across runs. Curation
happens at the close of a team run, and its brief names the personas of the
workers in the manifest at that moment, so this log is covered while this
worker is still listed there. Do not run `cleanup` either: the pane stays
until the operator says so.
