# herdr-fleet

Hands-off orchestration for Claude Code, running on [Herdr](https://github.com/herdrdev/herdr).

You describe a task once. An orchestrator plans it, spawns Claude workers into
real Herdr panes, drives them through a file-based brief/report contract,
validates the result with a second worker that did not write it, and decides —
by a policy file you control — whether the change is finished or whether it
needs you. Every worker is a visible pane you can watch or take the wheel of.

This plugin is **two skills and nothing else**. The personas, the team roster,
the autonomy policy and the wrapper script that talks to Herdr all live in a
separate repository — the *fleet home* — and the skills load them at
invocation. That split is deliberate: a copy bundled into the plugin would be a
second source of truth that drifts from the first in silence.

---

## Requirements

Read this before installing — the plugin on its own does nothing.

| You need | Why |
|---|---|
| A **herdr-fleet checkout** on disk | The roster the skills load. Without one, both skills refuse (see [Fleet home](#the-fleet-home)). |
| **herdr** on `PATH`, and a running server | Every worker is a Herdr pane. Verified against herdr 0.8.0, server protocol 19. |
| **claude** on `PATH` | Workers are Claude Code sessions. |
| **python3** | The wrapper and the permission installer. No Node, no jq. |
| POSIX `sh` | Both scripts are `sh`. Windows needs Git Bash or a port; that is not claimed to work. |

**The roster repository is not currently published to a public host.** If you
installed this plugin from the marketplace and do not already have a
herdr-fleet checkout, ask the plugin's author for access — the skills will
refuse cleanly until you have one, and they will tell you exactly which files
they wanted.

---

## Install

```sh
claude plugin marketplace add ImCesar/cezaar
claude plugin install herdr-fleet@cezaar
```

`install` enables the plugin as well; `claude plugin list` shows it as
`herdr-fleet@cezaar … enabled`. To try it without installing anything:

```sh
claude --plugin-dir /path/to/cezaar/plugins/herdr-fleet
```

### The fleet home

Both skills resolve a fleet home before doing anything: **the current directory
first, then `~/.fleet`.** Point `~/.fleet` at your checkout once:

```sh
ln -s /path/to/herdr-fleet ~/.fleet
```

Use a symlink, not a copy — a copy is a second roster with nothing to compare
it against. The current directory winning is deliberate: a checkout you are
editing overrides the installed one, so a change to a persona can be tried
before it is installed.

Each skill **says which home it resolved**, because "which roster answered" is
otherwise invisible. If neither place qualifies, it refuses and names both
places it looked and the files it wanted — that refusal is the design working,
not a failure. It is what stops the session from quietly becoming a
general-purpose assistant holding your task.

---

## Use

Two entry points. Both work by their bare name and by the namespaced form:

```
/herdr-orchestrate            /herdr-fleet:herdr-orchestrate
/herdr-architect              /herdr-fleet:herdr-architect
```

Use the namespaced form when you want to be certain you are addressing *this*
plugin — see [Gotchas](#gotchas). Invoke either from the repository the work is
actually about; you do not have to stand in the fleet home.

**`/herdr-architect`** — for work whose shape is not settled. It designs:
decomposition, interfaces, data shapes, trade-offs, and how the result will be
verified. It names one recommendation rather than presenting a menu, marks
every unverified mechanism as an assumption in the design itself, and has **no
authority to spawn anyone**. Hand its output to the orchestrator as the plan.

**`/herdr-orchestrate`** — for work that should be handled end to end. What it
does, in order:

1. **Plan.** Subtasks, files touched, and a verification method for each.
   Clarifying questions are asked once, up front, never guessed at mid-flight.
2. **Delegate.** One Herdr pane per worker, persona and model matched to the
   task. Anything that writes files gets **its own git worktree** — parallel
   writers never share a tree. Concurrency is capped at five workers unless you
   raise it. Each worker gets a brief as a file and must end by writing
   `.herdr-fleet/<id>/report.md`; that report, not the pane's state, is the
   completion signal, because a worker that stopped to ask a question settles
   exactly like one that finished.
3. **Validate.** The context that wrote a change never certifies it. A reviewer
   runs real verification in a fresh session; if it finds anything, a *second*
   fresh reviewer judges those findings to strip false positives. Only
   judge-confirmed findings count.
4. **Triage.** `triage-rules.md` decides whether the change finishes silently
   or comes to you. Hard rule regardless: **no push, no PR, no outward-facing
   action without your explicit approval.**
5. **Report.** Plain language — outcome, evidence, and what needs you (often
   "nothing").

The six personas are `orchestrator`, `architect`, `researcher`, `builder`,
`reviewer`, `runner`. The reviewer is spawned twice per validation — validate
mode, then judge mode — as two separate sessions.

---

## Configure

Everything below lives in the **fleet home**, not in this plugin. That is where
you edit; the plugin never needs touching.

### The roster — `agents/*.md`, `teams/default.md`

Each persona is YAML frontmatter plus a system-prompt body: its `kind`, its
model, its constraints, and whether it has escalation authority. `teams/*.md`
names which personas make a team. A themed team is just a second file in that
directory pointing at the same personas with different display names.

### The autonomy dial — `triage-rules.md`

This is the file to edit as trust builds. It is the line between "you never see
it" and "you decide". Auto-pass requires *all* of: validation green through
both reviewer passes, no sensitive paths touched, bounded blast radius, no
product or design judgment made by a worker, and fully reversible (local
commits only). Any escalation trigger — sensitive path, surviving finding,
cross-cutting change, a judgment call the plan did not cover, anything
irreversible, or validation that could not actually run — stops the run and
produces a four-line brief for you.

Tighten it or loosen it freely. Loosening is your call, never the
orchestrator's.

### Worker permissions — `install/worker-permissions.json`

The permission set a worker is started with. It is passed to `claude` on the
command line at spawn time, **not** written into the worker's tree: a project
`settings.json` is discarded wholesale in a workspace that has not been through
the trust dialog, and a fresh worktree never has, so a file there would be
inert in exactly the case it exists for.

Only a worker in a **linked git worktree** receives it. A worker sharing your
main checkout — including from a subdirectory of it — is given nothing, and the
spawn says so on stderr.

The set is small, and it is **an inference**, stated as one: it is derived from
the operations the reviewer persona prescribes (prove the tree clean, mutate
one thing, restore it, prove it clean again), not from a survey of what workers
actually reach for. So: `git status`, both spellings of restoring a single file
(`git checkout --`, `git restore`), and both common in-place rewriters
(`perl -0pi`, `sed -i`). **`git stash` is excluded on purpose** — stashing is
not "restore this one file", and the reviewer's procedure asks for one mutation
and one restore, not a stack. A worker that reaches for something unlisted
stalls on a prompt, visibly, in its own pane, with the command named. That is
the failure mode you can see and fix.

### Your own settings — `install/install-permissions.sh`

The fleet needs a handful of grants in *your* Claude Code settings so the
orchestrator can run the wrapper and read the fleet home. The installer merges
them in without disturbing anything else:

```sh
sh install/install-permissions.sh --dry-run              # show what would change
sh install/install-permissions.sh                        # <fleet-home>/.claude/settings.json
sh install/install-permissions.sh --user                 # ~/.claude/settings.json
sh install/install-permissions.sh --fleet-home ~/.fleet --user
```

It writes exactly two paths — `permissions.allow` and
`permissions.additionalDirectories` — appending and de-duplicating rather than
replacing, backs up what was there, and refuses rather than guessing when the
file is not what it expects. If your `settings.json` is a symlink into a
dotfiles repo, it writes *through* the link and leaves the symlink in place.

`--fleet-home` matters more than it looks: a grant is matched against the path
a session *uses*, not the path that resolves to, so when your fleet home is a
symlink both spellings are granted.

### The one thing no configuration can override

**If your own settings `ask` or `deny` a command a worker needs, the worker
stalls — and nothing on the worker's side outranks that.** This was measured,
not assumed: with an operator-level `ask` on `Bash(git checkout -- *)`, a
worker's restore was blocked with no flags, blocked with the fleet's own
`--settings` grant, and blocked under `bypassPermissions`, while an unlisted
command in the same session sailed through as a control. In a real unattended
run the worker sat on a confirmation prompt with nobody watching, and the
wrapper's `await` correctly returned exit 3 (*blocked*) rather than a false
"done".

The installer prints any such collision on every run and changes nothing:
widening a guard you set is your decision, not an installer's. The corollary is
worth stating plainly — **a machine with no such guard is not protected by one
either.** On a stock machine the fleet's grants work exactly as designed and a
reviewer restores files unattended.

---

## Gotchas

**A same-named skill outside the plugin wins, silently.** If you have
`~/.claude/skills/herdr-architect/` or `herdr-orchestrate/`, that copy answers
the bare name and the plugin's copy does not — no error, no warning, just a
working and plausible answer from somewhere else. Measured directly: with both
present, a deliberately altered plugin copy had no effect on the bare
invocation and full effect on the namespaced one. If you keep a development
copy, either invoke `/herdr-fleet:herdr-architect` explicitly, or **move** the
directory out of `~/.claude/skills/` entirely — a backup left inside is still
discovered.

**The plugin answers from its cache, not from a checkout.** Once installed, the
skills are served from `~/.claude/plugins/cache/cezaar/herdr-fleet/<version>/`,
which is a genuine copy pinned to a commit. Editing this repository's working
tree changes nothing about what a session runs — also measured, in both
directions. To publish a change to the skills:

```sh
claude plugin marketplace update cezaar      # refresh the marketplace clone
claude plugin update herdr-fleet@cezaar      # re-cache the plugin (restart to apply)
```

Two things about that second command, both measured. **The plugin id has to be
qualified** — bare `claude plugin update herdr-fleet` fails with `Plugin
"herdr-fleet" not found`. And **the update is decided by the version, not by
the commit**: against a freshly refreshed marketplace it answered *"herdr-fleet
is already at the latest version (0.1.0)"* and re-cached nothing. So a change
to a skill file that does not also bump `version` — in both
`.claude-plugin/plugin.json` and this marketplace's entry for it — is liable to
sit unpublished on every installed copy while the marketplace clone looks
current. `claude plugin tag` validates that those two version strings agree.

Note that all of this applies only to the two skill files. The roster in the
fleet home is read live at every invocation, so persona and policy edits take
effect immediately with no update step.

**`--timeout` is milliseconds on `spawn` and `prompt`, and seconds on `await`.**
The first two pass through to Herdr; the last is the wrapper's own.

**A brief that does not end by telling the worker to write its report produces
a worker that finishes and an `await` that never returns.** The orchestrator
persona enforces this, but it is the first thing to check if a run hangs.

---

## Further reading

The fleet home's own `README.md` is the reference for everything this page
summarises: the wrapper's full interface and exit-code contract, the permission
merge's exact guarantees, the check suite, and the reasoning behind the design
decisions. It is the authority where the two disagree — this page is the front
door, that one is the manual.
