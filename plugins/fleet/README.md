# fleet

Hands-off agentic orchestration for Claude Code + cmux. One orchestrator you
talk to; it plans, spawns **visible worker panes** (watch or steer any of
them), validates every change with fresh-context reviewer agents, and triages
by risk — routine work finishes without you, anything risky comes back as a
four-line brief.

Born from a live gauntlet: every mechanism here (grouped sidebar layout, 2×2
pane paging, display-density auto-detect, lost-signal-proof awaits, verified
cleanup, permission boundaries) was field-tested and hardened against real
failures. `fleet.sh` ships with a 41-case integration matrix it has passed.

## What's inside

- **`/orchestrate` skill** — the orchestrator protocol: plan → task-matched
  delegation (model chosen per task shape) → validation chain → risk triage →
  plain-language report. Never writes project code itself.
- **`cmux-delegation.md`** — the fleet protocol: spawn/steer/await/cleanup of
  worker panes, grouped sidebar layout, completion contracts, failure handling.
- **`fleet.sh`** — deterministic wrapper for the cmux CLI (spawn, await,
  steer, status, verified cleanup). `FLEET_TEST_CMD` enables fake-worker
  integration testing.
- **`triage-rules.md`** — the editable auto-pass vs. escalate policy. Tune
  this as trust builds; it is the line between "never see it" and "you decide."
- **Agents:** `validator` (fresh-context, evidence-based reviewer) and
  `review-judge` (adversarial false-positive filter). Both pinned to opus.

## Prerequisites (not bundled — install on each machine)

1. **cmux** (macOS): `brew install --cask cmux`
2. **cmux CLI on PATH**:
   `ln -sf /Applications/cmux.app/Contents/Resources/bin/cmux ~/.local/bin/cmux`
3. **treehouse** (optional, worktree pool for parallel writers):
   `curl -fsSL https://kunchenguid.github.io/treehouse/install.sh | sh`
4. Run the orchestrator **inside a cmux pane** — the socket refuses outside
   callers by design. Without cmux the skill degrades gracefully to internal
   (invisible) subagents.

## Usage

Open cmux → pane in your repo → `claude` (shift+tab for acceptEdits) → either
`/orchestrate <task>` or natural phrasing: "handle X end-to-end, only involve
me if something genuinely needs my judgment."

Optional `~/.fleetrc`:

```sh
FLEET_PAGE=1        # panes per page: 1 (laptop) / 4 (2x2, big monitor); default auto-detects
# FLEET_PERMISSION_MODE=bypassPermissions   # fully unattended fleets
```

## Note for machines with a prior manual install

If `~/.claude/skills/orchestrate/` or `~/.claude/agents/validator.md` /
`review-judge.md` exist from a pre-plugin install, remove them — otherwise the
skill and agents appear twice.
