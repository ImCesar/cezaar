---
name: herdr-orchestrate
description: Use when you want work handled end-to-end by a fleet of Claude workers running in Herdr panes - planned, delegated, validated and triaged on your behalf. Invoked as /herdr-orchestrate from a herdr-fleet checkout. Symptoms - "take this and run it", "handle this without me", a task that spans more than one worker.
---

# Run as the Herdr Fleet Orchestrator

This skill is a **loader**. It holds no roster, no delegation protocol and no
policy of its own — those live in the `herdr-fleet` repo, and a copy here would
be a second source of truth that nothing can check against the first. Read the
files; do not work from a summary, including this one.

## 1. Find the fleet home — cwd first, then `~/.fleet`, else refuse

```sh
for d in . ~/.fleet; do
  if [ -f "$d/agents/orchestrator.md" ] && [ -f "$d/teams/default.md" ] \
     && [ -f "$d/triage-rules.md" ] && [ -f "$d/scripts/herdr-fleet.sh" ]; then
    echo "fleet home: $d"; break
  fi
done
```

**Say which one you are using** — the operator cannot tell by looking, and
"which roster am I running" is the first thing that goes wrong silently.

The current directory wins when it qualifies, so a checkout you are working in
overrides the installed one: that is how you test a change to the roster
without touching `~/.fleet`. It matches the precedence the skills themselves
follow, where a local copy beats a global one.

`~/.fleet` is normally a symlink to a herdr-fleet checkout. Everything below —
the roster paths and the wrapper — is relative to whichever home you resolved,
so run them as `$d/...` rather than assuming the current directory.

**If neither qualifies, stop and say so plainly**, naming both places you
looked and the four files you needed. Do not improvise a roster, do not fall
back to subagents, and do not carry on as a general-purpose assistant who has
been handed a task — the operator asked for a specific thing and did not get
it. Tell them to `cd` into a checkout, or point `~/.fleet` at one:

```sh
ln -s /path/to/herdr-fleet ~/.fleet
```

The check is the four files rather than a directory's name, because a name can
be right while the contents are not.

**The fleet home is where the roster lives, not where the work happens.** A
worker is spawned with its own `--cwd` against whatever repository the task
concerns, so you can orchestrate work on any project from anywhere once
`~/.fleet` resolves.

## 2. Read the roster, before anything else

Read these from the fleet home you just resolved (`$d` above — spell the path
out when you read them, so the transcript shows which roster you loaded):

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
sh "$d/scripts/herdr-fleet.sh" preflight     # $d being the fleet home you resolved
```

If the herdr socket is unreachable there is no fleet, and every later step
fails in a way that is harder to read than this one. Report what it says.

## 5. Then ask what to work on

Unless the invocation already said.

## The interface

`sh "$d/scripts/herdr-fleet.sh" --help` is the source of truth for the wrapper —
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
