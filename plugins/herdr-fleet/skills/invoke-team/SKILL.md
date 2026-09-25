---
name: invoke-team
description: Use when you want your session to lead one of the fleet's teams (a stage of the work, run by Claude workers in Herdr panes) over many turns - e.g. the execution team building an architecture into reviewed changes. Invoked as /herdr-fleet:invoke-team <team> [input]; with no team named, it lists the teams and asks.
---

# Lead a Herdr Fleet team

This skill is a **loader**. It holds no roster, no procedure and no policy of
its own. A team is a file in the fleet home, `teams/<team>.md`, and the
procedure lives in its lead persona. Read those files; do not work from a
summary, including this one.

Your session becomes the team's **lead**. The lead persona's `model:` is
advisory here: this session already has a model, and that one wins.

The plugin ships a `fleet/` directory. It is a **seed**, never read in place:
copied to `~/.fleet` once, on a machine with no fleet home, and inert from
then on. You are reading `<plugin>/skills/invoke-team/SKILL.md`, so the seed
is `<plugin>/fleet`. You know that absolute path; use it rather than guessing
at cache locations.

## 1. Find the fleet home: cwd first, then `~/.fleet`, else install the seed

A fleet home has the directories `agents/`, `teams/`, `artifacts/` and
`system/`, and the wrapper `scripts/herdr-fleet.sh`:

```sh
for d in . ~/.fleet; do
  if [ -d "$d/agents" ] && [ -d "$d/teams" ] && [ -d "$d/artifacts" ] \
     && [ -d "$d/system" ] && [ -f "$d/scripts/herdr-fleet.sh" ]; then
    echo "fleet home: $(cd "$d" && pwd)"; break
  fi
done
```

**Say which one you are using**, as an absolute path. The operator cannot tell
by looking, and "which fleet am I running" is the first thing that goes wrong
silently. Shell state does not survive between your commands, so write that
absolute path into every later command rather than relying on `$d`. Below,
`<home>` means that path.

The current directory wins when it qualifies, so a checkout you are working in
overrides the installed one: that is how a change to a team is tried before it
is installed. `~/.fleet` is normally a symlink to a herdr-fleet checkout.

The check is on contents rather than a directory's name, because a name can be
right while the contents are not.

### An older fleet home is upgraded, not replaced

If a candidate has `agents/` and `scripts/herdr-fleet.sh` but lacks
`artifacts/` or `system/`, it is a fleet home from before stage teams, not a
foreign directory. Do not carry on with it and do not install over it. Say
which directories are missing, then give the fix that matches how it was made:

- **A git checkout of herdr-fleet** (`git -C <home> rev-parse --show-toplevel`
  succeeds; on the operator's machine `~/.fleet` is a symlink to one): the fix
  is to update the checkout. Tell the operator; it is their repository, so do
  not pull or merge in it yourself.
- **Copied from the seed** (not a git checkout): the fix is to copy in only
  the seeded files it is missing. List them first, and list the files that
  exist but differ from the seed, which stay as they are:

  ```sh
  seed="<plugin>/fleet"; home="<home>"
  (cd "$seed" && find . -type f) | while read -r f; do
    if [ ! -e "$home/$f" ]; then echo "missing: $f"
    elif ! cmp -s "$seed/$f" "$home/$f"; then echo "differs, left alone: $f"; fi
  done
  ```

  **Get the operator's approval before copying anything.** Then copy only the
  missing ones, never overwriting:

  ```sh
  seed="<plugin>/fleet"; home="<home>"
  (cd "$seed" && find . -type f) | while read -r f; do
    [ -e "$home/$f" ] && continue
    mkdir -p "$(dirname "$home/$f")" && cp -p "$seed/$f" "$home/$f"
  done
  ```

  Report what was added, and name the files that differ: those are the
  operator's edits or an older copy, and deciding between them is theirs.

### No fleet home at all: install the seed

If neither place qualifies and neither is an older fleet home, **this plugin
ships a working fleet; install it rather than refusing.** Do not improvise a
roster, do not fall back to subagents, and do not carry on as a
general-purpose assistant holding the task.

Say what you are about to do *before* you do it: what is copied, where it
goes, and that it becomes theirs to edit. Then:

```sh
cp -R "<plugin>/fleet" ~/.fleet
```

**Expect a permission prompt, and say what it is for first.** The plugin
directory and `~` both sit outside the working directory, so this copy can be
the one moment the operator has to approve something.

**Never overwrite.** If `~/.fleet` exists and is neither a fleet home nor an
older one, stop and report what is there and what was missing. It belongs to
someone.

After the copy, resolve the home again. Tell the operator it is theirs now:
edits there are live, and reinstalling or updating this plugin will not touch
it.

**The fleet home is where the teams live, not where the work happens.**
Workers are spawned with their own `--cwd` against whatever repository the
task concerns.

## 2. Pick the team

If the invocation named a team, it is `<home>/teams/<team>.md`. If that file
does not exist, say so and list the teams as below.

With no team named, list every team with its `description` and `takes`, and
ask which one:

```sh
for f in "<home>"/teams/*.md; do
  echo "$(basename "$f" .md):"
  grep -m1 '^description:' "$f"; grep -m1 '^takes:' "$f"
done
```

No team file is special. Any `teams/<name>.md` is invoked by its name.

## 3. Read before acting

Read these, and spell out each absolute path as you read it, so the transcript
shows what was loaded:

- the team file, `<home>/teams/<team>.md`;
- its lead persona, `<home>/agents/<lead>.md`, where `<lead>` is the team's
  `lead:`. This is the persona you are about to become;
- the artifact template for every type in the team's `takes` and `produces`,
  `<home>/artifacts/<type>.md`;
- every file in the team's `policy:`. Those paths resolve from `<home>`, not
  from `teams/`. `triage-rules.md` and `review-bar.md` are policy: applying
  them is not optional, and loosening them is the operator's call.

## 4. Become the lead for the rest of the session

Its constraints bind you from here on.

## 5. Check the input against the team's `takes`

Every type in `takes` is required. Compare what the invocation gave you with
the templates you just read, and ask for whatever is missing. For a team whose
job starts from a raw problem (the solution-design team), drawing the problem
out through conversation is part of the job, not a gap to report.

## 6. The team is in effect for everything you run: `FLEET_TEAM`

Every call to the wrapper carries the team file's absolute path:

```sh
FLEET_TEAM="<home>/teams/<team>.md" sh "<home>/scripts/herdr-fleet.sh" <verb> ...
```

Put it on every call, not once: shell state does not survive between your
commands. `spawn` records it in the worker's manifest row and in its launch
settings, which is how a worker's own `tell` reads this team's `peers:`. A
worker never inherits it from your shell, because a pane is a child of the
herdr server. Without it, `tell` refuses: there is no default team.

## 7. Preflight before spawning anything

```sh
FLEET_TEAM="<home>/teams/<team>.md" sh "<home>/scripts/herdr-fleet.sh" preflight
```

If the herdr socket is unreachable there is no fleet, and every later step
fails in a way that is harder to read than this one. Report what it says.

`sh "<home>/scripts/herdr-fleet.sh" --help` is the source of truth for the
wrapper's verbs, flags and exit codes. The lead persona says how to use them.

## 8. Close

**A clean close** is the lead writing the team's `produces` artifact and
reporting it. Write it to the path its template's `written_to` gives,
resolved from `<home>`, unless the operator named another location when
invoking the team. Report that path. Then run curation:

```sh
FLEET_TEAM="<home>/teams/<team>.md" sh "<home>/scripts/herdr-fleet.sh" curate
```

It spawns the curator (a system persona, never a team member) on the logs of
this run's workers. Wait for its report with `await curator` and relay it
briefly.

**After an abort, do not curate.** An abort is any run that ends without that
artifact: the operator stopped it, or it was abandoned part-way. Curating a
half-finished run would promote lessons from work nobody finished. Say that
you did not curate, and why.

**Never run `cleanup` on your own**, on either path. The panes stay up until
the operator says to clean up.
