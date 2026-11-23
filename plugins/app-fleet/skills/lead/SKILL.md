---
name: lead
description: Use when the operator wants to start or resume an app-fleet run, the fleet on the Herdr app where agents work in rooms (a channel per stage, a thread per task). Invoked as /app-fleet:lead <run> --repo <path> --architecture <file.md> [--verify "<cmd>"] [--teardown "<cmd>"], or /app-fleet:lead <run> to resume.
---

# Start or resume an app-fleet run

This skill only starts things. The lead is a separate Claude session that `fleet lead` opens in the Herdr app, in its own `lead` tab. The operator works with the lead there, not in this session.

1. **Check the prerequisites.**
   - The Herdr app must be open: `herdr-app status` exits 0.
   - The `rooms` plugin must be installed: `room --help` works.
   - `fleet` must be on PATH. If it isn't, run `<this plugin>/scripts/fleet install`, which links it into `~/.local/bin`.
2. **For a new run,** you need:
   - a run name (a-z, 0-9, `-`, `_`);
   - the repo path;
   - the architecture file: any markdown document that describes the work;
   - optionally the full-suite command (`--verify`) and the cleanup command (`--teardown`).

   Ask for whatever the operator hasn't given, then run:
   ```sh
   fleet lead <run> --repo <path> --architecture <file.md> --verify "<cmd>" --teardown "<cmd>"
   ```
3. **For an existing run** (after a crash, a `/clear`, or a compacted lead), run `fleet lead <run>`. It reopens the lead tab, and the lead first reads `fleet status` and the channel. Nothing is reset.
4. **Tell the operator** where things are:
   - The `<run>` space has a `lead` tab, where they talk to the lead.
   - Each thread gets its own tab when it opens.
   - Rooms appear in the Rooms panel, grouped by run. Open the panel with `herdr-app do tab.new --name Rooms --mod rooms` if it isn't showing.
   - The run's result is the branch `fleet/<run>/integration`, left for them to merge or open a PR from.

Do not lead the run from this session, and do not relay messages between rooms.
