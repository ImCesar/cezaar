# app-fleet

The fleet on the Herdr app, with agents talking in rooms. This is a rebuild of herdr-fleet's execution stage, not a port. herdr-fleet stays as it is, as the fallback.

- **The lead sets the work.** It turns an architecture into waves of tasks and opens a **thread** per task: a room, a worktree, and members (for example a builder and a reviewer).
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

Members run under Herdr's `hc`, whose PATH isn't your shell's. `fleet lead` records your PATH in the run and gives it to every member, so tools such as nvm's `node` are found. Start a run from a shell where the verify command works.

Fleet runs the `room` that sits beside it in this repo. Members and the lead get this repo's `plugins/rooms/scripts` first on PATH, and the installed rooms plugin's `scripts` last. That plugin adds its own `scripts` to the front of PATH only when they're missing, so listing them last keeps this repo's `room` in front, even when the installed plugin is an older release.

## Where to look

- **Agents list.** Members run as Herdr sub-agents, with no tabs of their own. They nest under the lead, and each reviewer nests under its builder. Each row carries the member's id, which starts with its room's name (`auth-builder`, `auth-reviewer`). The lead's row folds them away and shows the most urgent status underneath. Click a member to peek at it live, or use "keep as tab" to give it a pane.
- **Rooms tab.** `fleet lead` opens a `rooms` tab beside `lead` in the run's space, showing only that run's rooms (resume reopens it if you closed it). Every thread with live members has a `window` button on its row: one window with the thread's live member terminals beside its timeline and composer. Close the window whenever you like; the button brings it back. Reading a room in its window marks it read in the panel.
- **The lead runs inside a shell** in its tab. If its Claude crashes, `fleet lead myrun` restarts it in the same shell, resuming its session, so the members stay nested under it. If the lead tab itself is gone, a new lead tab resumes the session, and each thread's first member gets a tab of its own, so nothing runs out of sight.

- **Asking an ended member.** Every member starts with a recorded session id, and its room entry carries `fleet thread resume <run> <task> <member>` as its resume command. Closing a thread leaves its room open. Mention an ended member in its room (`@auth-builder why did you pick X?`) and `room post` runs that command: the member comes back in its own session, with its context, and answers in the room. Nothing archives a room automatically, `fleet cleanup --all` included. Archive a room yourself (the panel's archive button, or `room archive <room>`) when you're done with it; an archived room takes no posts, so nothing in it can be resumed.

## Commands (used mostly by the lead)

| Command | What it does |
|---|---|
| `fleet lead <run> --repo P --architecture F [--base B] [--verify C] [--teardown C] [--try C]` | Starts a run (channel, Herdr space, lead tab, rooms tab). Run it again to resume: it selects a running lead, restarts a crashed one in its shell, or opens a new lead tab; it reopens a closed rooms tab and gives a tab to any member whose parent ended. |
| `fleet thread open <run> <task> --template T --brief F [--from <task>] [--wave N]` | Opens a thread: a worktree on `fleet/<run>/<task>`, a room, its members (named `<task>-<persona>`, as sub-agents under the lead) and the brief. Task names are at most 21 characters. |
| `fleet thread close <run> <task>` | Ends the members' terminals and removes the worktree if its branch is merged. The room stays open, so you can still ask its members questions. Closing a closed thread ends any resumed member again. |
| `fleet thread resume <run> <task> <member>` | Starts an ended member again in its own Claude session (`--resume`), in the folder it started in (a removed build or fix worktree is recreated from its branch). Refuses (exit 3) if the room is archived or the thread is from before sessions were recorded; does nothing if the member is still live. You rarely run it yourself: see "Asking an ended member". |
| `fleet merge <run> <task>` | Merges the thread branch into `fleet/<run>/integration`. On a conflict it aborts and lists the files (exit 3). |
| `fleet verify <run> <wave>` | Opens a runner thread on the integration worktree: verify, then teardown, then report. |
| `fleet curate <run> [--note L]...` | Opens the stage's curate thread. Fleet writes the brief from the run: every thread log and report, and the memory file of each role that took part. `--note` adds a candidate lesson. |
| `fleet try <run>` | Runs the run's `try` command in the integration worktree, so you can use the merged work live before it reaches your branch (for this repo's Rooms panel: `plugins/rooms/scripts/room herdr-install --panel-only`). The lead runs it before reporting done. |
| `fleet status <run> [--json]` | Shows threads and their members' working, idle or gone state. |
| `fleet config <run> maxThreads\|verify\|teardown\|try <value>` | Changes a run setting. |
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
