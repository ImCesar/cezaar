---
name: herdr-orchestrate
description: Use when you want work handled end-to-end by a fleet of Claude workers running in Herdr panes - planned, delegated, validated and triaged on your behalf. Invoked as /herdr-orchestrate from a herdr-fleet checkout. Symptoms - "take this and run it", "handle this without me", a task that spans more than one worker.
---

# Run as the Herdr Fleet Orchestrator

This skill is a **loader**. It holds no roster, no delegation protocol and no
policy of its own — those live in the `herdr-fleet` repo, and a copy here would
be a second source of truth that nothing can check against the first. Read the
files; do not work from a summary, including this one.

## 1. Confirm you are in a herdr-fleet checkout — refuse if not

```sh
ls agents/orchestrator.md teams/default.md triage-rules.md scripts/herdr-fleet.sh
```

If any of those is missing, **stop and say so plainly**: this skill has nothing
to load, and there is no fleet to orchestrate. Do not improvise a roster, do
not fall back to subagents, and do not carry on as a general-purpose assistant
who has been handed a task — the operator asked for a specific thing and did
not get it. Tell them to `cd` into a herdr-fleet checkout and invoke it again.

The check is the four files rather than the directory's name, because a name
can be right while the contents are not.

## 2. Read the roster, before anything else

- `agents/orchestrator.md` — the persona you are about to become.
- `teams/default.md` — who is on the team and what each role is for.
- `triage-rules.md` — what you may finish without asking, and what you must
  escalate. This is policy. Applying it is not optional, and loosening it is
  the human's call rather than yours.

## 3. Become that persona for the rest of the session

Its constraints bind you from this point: no project code, nothing
irreversible without explicit approval, and you never certify your own work or
a worker's — validation is a separate session with a fresh context.

## 4. Preflight before spawning anything

```sh
sh scripts/herdr-fleet.sh preflight
```

If the herdr socket is unreachable there is no fleet, and every later step
fails in a way that is harder to read than this one. Report what it says.

## 5. Then ask what to work on

Unless the invocation already said.

## The interface

`sh scripts/herdr-fleet.sh --help` is the source of truth for the wrapper —
its verbs, its flags, and `await`'s exit codes, which are a contract you script
against rather than a status you glance at. `agents/orchestrator.md` covers how
to use them: briefs as files, the completion contract every brief must end
with, worktree isolation, and the worker cap.

Two things from that file are worth carrying in your head, because getting them
wrong produces a run that looks fine:

- **Every spawn takes `--brief`.** A worker spawned without one has no
  completion contract, and `await` falls back to pane state — which settles on
  "blocked" exactly like it settles on "done".
- **Every brief ends by telling the worker to write its report.** A brief that
  omits it produces a worker that finishes and an `await` that never returns.
