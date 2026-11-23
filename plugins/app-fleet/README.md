# app-fleet

The fleet on the Herdr app, with agents talking in rooms. This is a rebuild of herdr-fleet's execution stage, not a port. herdr-fleet stays as it is, as the fallback.

- **The lead sets the work.** It turns an architecture into waves of tasks and opens a **thread** per task: a room, a worktree, and members (for example a builder and a reviewer), each in its own pane.
- **The thread runs itself.** Members hand off by @-mention in their room. The reviewer's APPROVE closes the thread, and the builder posts `done @lead`. Members never pass messages through the lead.
- **The stage has a channel** (`execution`) that every member belongs to, for questions that cross threads.
- **The lead merges** each finished thread into `fleet/<run>/integration`, and runs the full suite once per wave in a verify thread. The branch is left for you; nothing is pushed or merged into your base branch.

Requires the **`rooms` plugin** (its mod wakes members on mentions and its `room` CLI is how they post), the **Herdr app** (0.1.16; `herdr-app`, `hc` 0.1.22), and **Claude Code 2.1.330 or later**.

## Start

```sh
claude plugins install rooms app-fleet
fleet install                     # or: <plugin>/scripts/fleet install
fleet lead myrun --repo ~/repos/myproj --architecture ~/repos/myproj/ARCHITECTURE.md \
  --verify "make verify" --teardown "make down"
```

Switch to the `lead` tab in the new `myrun` space and talk to the lead there. Inside Claude, `/app-fleet:lead` walks you through the same thing. To resume a run after a crash or a `/clear`, run `fleet lead myrun`.

## Commands (used mostly by the lead)

| Command | What it does |
|---|---|
| `fleet lead <run> --repo P --architecture F [--base B] [--verify C] [--teardown C]` | Starts a run (channel, Herdr space, lead tab). Run it again to resume. |
| `fleet thread open <run> <task> --template T --brief F [--from <task>] [--wave N]` | Opens a thread: a worktree on `fleet/<run>/<task>`, a room, its members and the brief. |
| `fleet thread close <run> <task>` | Archives the room, ends the members' terminals, closes the tab, and removes the worktree if its branch is merged. |
| `fleet merge <run> <task>` | Merges the thread branch into `fleet/<run>/integration`. On a conflict it aborts and lists the files (exit 3). |
| `fleet verify <run> <wave>` | Opens a runner thread on the integration worktree: verify, then teardown, then report. |
| `fleet status <run> [--json]` | Shows threads and their members' working, idle or gone state. |
| `fleet config <run> maxThreads\|verify\|teardown <value>` | Changes a run setting. |
| `fleet cleanup <run> [--all]` | Closes every thread. `--all` also removes the integration worktree and the space, but always keeps the integration branch. |
| `fleet roster check` | Checks that every template persona exists with a model and effort. |

Templates (`roster/templates.json`):

| Template | Members |
|---|---|
| `build`, `fix` | builder + reviewer |
| `research` | researcher |
| `verify` | runner |
| `judge` | judge, in a room `judge-<task>` beside a deadlocked thread |
| `curate` | curator |

## Layout

```
~/.app-fleet/                    fleet home (APP_FLEET_HOME overrides)
  memory/<persona>/MEMORY.md     persona memory; the curator appends to it, members read it
  runs/<run>/run.json            run state
  runs/<run>/rooms/              the run's rooms (ROOMS_ROOT): the channel plus one room per thread
  runs/<run>/briefs/, reports/   briefs written by the lead, reports written by members
  runs/<run>/members/            each member's prompt file and settings file
<repo>/.worktrees/<run>/<task>   thread worktrees (.worktrees/ is added to .git/info/exclude)
<repo>/.worktrees/<run>/_integration
```

A member is a `claude` session started with its persona's model and effort. Its system prompt gets the persona, the room norms and (for reviewers and judges) the review bar. Its settings carry `ROOM_ID`, `ROOMS_ROOT` and a `Bash(room *)` grant. Claude's trust prompt on a fresh worktree is answered automatically.

## Trust

Members run as you, like any Claude session, and the rooms mod is unsandboxed. Every member inherits your global Claude permissions. The lead also gets `Bash(fleet *)` and `Bash(git *)`.

## Tests

```sh
sh plugins/app-fleet/tests/fleet_cli_test.sh   # real git and room; stub hc, herdr-app and claude
fleet roster check
```
