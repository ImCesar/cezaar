# cmux Fleet Delegation Protocol

*How the orchestrator spawns, drives, and reclaims visible worker agents in cmux surfaces. Verified against cmux 0.64.19. The four verbs: `new-workspace` (spawn), `send`/`send-key` (talk), `read-screen`/`wait-for` (listen), `close-workspace` (reclaim).*

## Architecture

```
Orchestrator (Claude Code session, inside a cmux pane)
  │  drives cmux via CLI (~/.local/bin/cmux → app socket)
  ├─► Worker A = real cmux workspace running `claude` (visible, steerable)
  ├─► Worker B = real cmux workspace running `claude` (visible, steerable)
  └─► .fleet/ dir in repo = manifest + per-worker report files (the data plane)
```

**Split responsibilities:** cmux surfaces carry *liveness and steering* (screens humans and orchestrator can watch/type into); **files carry payloads** (worker reports, task briefs). Never parse long results out of `read-screen` — screens truncate and wrap; files don't.

## 0. Preflight — always, before any fleet work
```bash
cmux ping   # socket reachable?
```
- **Fails** (app not running / orchestrator not inside cmux / socket restricted): fall back to internal subagents (Agent tool) and tell the user in one line: "fleet mode unavailable — running workers invisibly this time; launch me inside cmux for visible workers."
- Socket control is restricted to processes inside cmux terminals by default. The orchestrator session should itself run in a cmux pane. (Override exists — `automation.socketControlMode: allowAll` in `~/.config/cmux/cmux.json` — but prefer running inside cmux.)

## 1. Creation — layout first, then spawn

**Layout rule (default: one sidebar GROUP per orchestration, 2×2 pages inside):**
fleet.sh puts the whole orchestration in a single **workspace group anchored by the orchestrator** — the group header in the sidebar IS the orchestrator's entry, with the fleet nested (and collapsible) under it. Workers tile into **2×2 page workspaces** inside the group: workers 1–4 form a quad (`1 2 / 3 4`) on page one; worker 5 starts a new page (`5 6 / 7 8`), and so on. **Display density is auto-detected:** external monitor attached → 2×2 quads (`4`); laptop screen only → one full-page worker per workspace (`1`), since quarter-panes on a 14" are unreadable. Detected once per orchestration and cached in `.fleet/.page` so density never flips mid-fleet. Override precedence: explicit `FLEET_PAGE` env var > `.fleetrc` (`$FLEET_HOME/.fleetrc` per-project, `~/.fleetrc` global) > auto-detect. If the user states a preference, put it in `~/.fleetrc` for them. Validators/judges spawned later flow through the same tiling. Tabs are renamed `wk-<id>-<label>`; live tiles tracked in `.fleet/.tiles`, group ref in `.fleet/.group`; `cleanup --all` dissolves the group, leaving the orchestrator standing.
- **Nothing ever teleports to a new window uninvited** — the group visibly forming under the orchestrator in the sidebar is itself the announcement that a fleet is spinning up. The orchestrator should also narrate structural changes ("opening a fleet group, 4 workers") as they happen.
- **Multiple orchestrations coexist in one window** — each is its own collapsible group, so fleets never interleave. A dedicated window (`fleet.sh window` + `--layout workspace --window <ref>`) remains available for recordings or a second monitor, but is opt-in, never automatic.

Worktree isolation for any worker that **mutates** files — parallel writers must never share a tree. **Read-only workers (auditors, analyzers, report-writers) may share the main checkout**; their only writes are their own `.fleet/<id>/` files. Acquiring a worktree:
```bash
WT=$(treehouse get --lease | tail -1)        # pre-warmed worktree, prints path
fleet.sh spawn 3 retry sonnet "$WT" brief.md                       # split mode (default)
fleet.sh spawn 3 retry sonnet "$WT" brief.md --layout workspace --window "$WIN"  # fleet window mode
```
(`fleet.sh` handles the mode differences — split inherits the orchestrator's cwd so it `cd`s into the worktree before booting `claude`; workspace mode sets `--cwd` directly. Raw equivalent: `cmux new-split down` / `cmux new-workspace --name wk-3-retry --cwd "$WT" --command claude --focus false` (`--no-focus` is not a valid flag — cmux rejects it outright).)
- `--name` convention: `wk-<id>-<short-label>` — makes `cmux tree` a fleet dashboard.
- `--command claude` starts the worker's interactive session immediately. Add `--model sonnet|haiku|opus` per the task-shape judgment, and `--permission-mode acceptEdits` for hands-off fleets (the worker can't press "allow" for itself).
- `--env KEY=VALUE` / `--env-file` for worker-specific env.
- Capture the workspace/surface ref that `new-workspace` prints — it's the worker's address for every later verb.
- No treehouse / repo too small? `git worktree add` or same-tree single worker is fine; the pool is an optimization.

## 2. Spawning the agent's task (the brief)
Write the brief to a file first (avoids shell-quoting hell, keeps an audit trail):
```bash
mkdir -p .fleet/wk-3
cat > .fleet/wk-3/brief.md   # task, context, constraints, verification steps
```
The brief MUST end with the contract:
> When complete: (1) write your full report to `.fleet/wk-3/report.md` — what you did, what you ran, results, open questions; (2) run `cmux wait-for -S wk-3-done`; (3) stop.

**Paths in briefs are always relative to the worker's own cwd — never absolute paths into other trees.** A worker told to write `/path/to/main-repo/.fleet/...` from inside a worktree crosses its permission boundary and triggers a human prompt, stalling the whole automation (acceptEdits covers only the session's working dirs). fleet.sh grants the orchestration root via `--add-dir` as a belt, and `fleet.sh await` reads the report from the worker's worktree — relative paths satisfy both. `FLEET_PERMISSION_MODE=bypassPermissions` exists for fully unattended runs.

Then inject:
```bash
cmux send --surface "$REF" "Read .fleet/wk-3/brief.md and execute it exactly, including its completion contract."
cmux send-key --surface "$REF" enter
```
(`send` does NOT press enter — always follow with `send-key enter`.)

## 3. Communication
- **Orchestrator → worker** (steer, answer a question, course-correct):
  `cmux send --surface "$REF" "text"` + `send-key enter`. Never Ctrl-C a worker (modifier chords unsupported) — redirect it with words, or close the surface. **Sends are atomic: text is always followed by enter immediately** — never stage text in a worker's input box for later; unsent text is indistinguishable from something the human typed. (Dim ghost text in an idle pane's input is Claude Code's own prompt suggestion — not a queued command from anyone.)
- **Worker → orchestrator:** report file (payload), done-signal (control), screen (liveness only).
- **Worker → human:** the pane itself. Plus `cmux notify --title "wk-3 needs a decision" --surface "$REF"` when the orchestrator escalates — rings the cmux notification bell.
- **Fleet dashboard for the human:** `cmux set-status fleet "3 running / 1 done" ; cmux set-progress 0.5 --label "fleet"` on the orchestrator's own workspace; `cmux trigger-flash --surface "$REF"` to point eyes at a worker.

## 4. Completion detection (layered — never trust one signal)
**Treat the report file as the only durable truth; the signal is just a wake-up.** `fleet.sh await` does file-check first, then 15s `wait-for` slices with a file re-check between each — fast workers like validators routinely finish before the await starts.

Two ways this used to return *prematurely*, both now guarded at spawn:
- **Stale report** — a `report.md` left by an earlier attempt with the same id satisfies the file check instantly. Spawn archives it to `report.stale-<ts>.md` and drops a `.spawn-stamp`; await only accepts a report newer than that stamp.
- **Latched signal** — `cmux wait-for` tokens are *not* purely ephemeral. A signalled token stays pending until some waiter consumes it (one-shot: the next waiter times out). When an await returns via the report file it never consumes the signal, so a later run with the same id fires on that stale latch. Spawn drains it with `wait-for <token> --timeout 0` (a non-blocking poll).
1. **Primary:** `fleet.sh await <id> [timeout]` (poll loop above).
2. **On timeout:** check `.fleet/wk-3/report.md` exists (worker may have written the report but flubbed the signal) — if present, treat as done.
3. **Still nothing:** liveness probe — `cmux read-screen --surface "$REF" --lines 40` twice, 60s apart. Screen changing → still working, extend once. Screen static at a prompt → stalled: nudge via `send` ("status? follow your brief's completion contract"); one nudge only, then escalate to the user.
4. Read the report file — **that** is the worker's deliverable. Screen text never is.

## 5. Cleanup (always runs — success, failure, or abandon)
**And cleanup is INCREMENTAL:** the moment a worker's await returns and you've read its report, clean *that* worker (`fleet.sh cleanup <id>`) — don't leave finished panes lingering while the rest of the fleet runs. A pane sitting at "waiting for your input" with its report on disk is done, not busy; its durable evidence is the `.fleet/<id>/` files, not the pane. (Held-for-escalation workers are the exception — see below.) Batch `cleanup --all` is for sweeps at session end, not the primary path.
```bash
fleet.sh cleanup <id>                      # verified close — prefer this over raw cmux
treehouse return "$WT"                     # worktree back to the pool (kills lingering procs)
```
**Cleanup VERIFIES against `cmux tree` and reports honestly.** A close command's own exit status is not evidence — `close-surface` on a workspace's last surface fails with `invalid_state: Cannot close the last surface`, and the old code swallowed that with `2>/dev/null || true` while printing "cleaned" regardless. `fleet.sh cleanup` now re-reads the tree after every close and prints `closed <id> (<ref>)` only when the ref is genuinely gone, `FAILED to close <id> (<ref>)` (with cmux's real error) otherwise, exiting **nonzero** if anything failed. Treat a nonzero cleanup as leftover panes and check `cmux tree` yourself.

**The close verb is chosen from what the workspace actually holds, not from the requested layout.** Grid-mode page-first tiles and every fallback-path worker are real *workspaces* even though the layout said `grid`; later workers are *surfaces* split into that same workspace. The manifest records this as `placement` (`surface`|`workspace`) alongside `layout`. Cleanup closes a surface when its workspace still holds others, and closes the workspace when it holds the last one — so cleaning the worker that happened to create a page never takes its siblings down with it.

- Update `.fleet/manifest.jsonl` (one line per worker: id, ref, worktree, model, status, `layout`, `wsref`, `placement`, timestamps) — the orchestrator appends at spawn and at completion; it's the source of truth for `cleanup --all` sweeps and post-mortems.
- `cleanup --all` also reclaims the empty **group header workspace** cmux mints for every workspace group (recorded in `.fleet/.anchor`). Without that, each orchestration strands one `fleet: <root>` workspace forever.
- Keep `.fleet/<id>/` report/brief files — they're the audit trail (gitignore `.fleet/`).
- **Reusing a worker id respawns it destructively:** the manifest is keyed by id and only the newest entry is resolvable, so spawn retires the previous attempt's pane first (it would otherwise survive every future cleanup), archives any `report.md` from that attempt, and drains its `wk-<id>-done` signal. See §4 on why both are required.
- **Exception:** a worker held for user escalation keeps its pane open (frozen evidence, resumable) until the user decides; note it in the manifest as `held`.
- Session end: sweep manifest for any `running`/`held` leftovers → close + return each. `treehouse prune` occasionally.

## 6. Failure handling
- **Spawn fails** (no ref printed): retry once; then fall back to internal subagent for that task and tell the user.
- **Worker errors out** (claude crashes, pane dead — `cmux surface-health`): capture `read-screen --scrollback` to `.fleet/<id>/crash.log`, clean up, respawn once with the same brief; twice → escalate.
- **Human takes over a pane** (types into it): that worker is theirs now — stop steering it, note `taken-over` in manifest, don't close it.
- **Fleet cap:** max 5 concurrent workers unless the user raises it — runaway spawning burns Max-plan limits fast.

## When to use fleet vs internal subagents
| Fleet (cmux surface) | Internal (Agent tool) |
|---|---|
| Implementation workers writing code | Quick lookups, scans, mechanical retrieval |
| **Validator / review-judge runs** | Trivial checks (one-line diff confirmation) |
| Long tasks the user may want to watch or steer | Single fast subtask inside one flow |
| Parallel multi-task runs | Fallback when the cmux socket is unreachable |

**Validators are visible on purpose** — validation is the step the user's trust rests on, so it gets a pane like everything else (delegation = visibility, no exceptions for "short-lived" agents). Spawn pattern: `fleet.sh spawn v1 validate opus <tree> brief.md` where the brief opens with *"Adopt <absolute path to the plugin's agents/validator.md> as your role instructions, then:"* — resolve that path when writing the brief (the agent definitions live in `agents/` two levels above this skill's directory); same for review-judge. No worktree lease needed (validators read the existing tree, they don't mutate it). Panes auto-close at cleanup once verdicts land, so validation appears as a visible phase: checking panes open, verdicts land, panes clear.
