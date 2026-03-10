# obsidian-brain

Scaffold and interact with an opinionated Obsidian vault from Claude Code.

## Overview

obsidian-brain lets you capture ideas, track todos, journal, reflect, and generate performance reviews — all without leaving the terminal.

## Attached vs. Detached

When you run `init-vault`, you choose a mode:

- **Attached** — Skills run from the cezaar plugin. Your vault only has the folder structure and templates. You get skill updates automatically when you update the plugin.
- **Detached** — Skills are copied into your vault's `.claude/` folder as a local plugin. Your vault becomes fully self-contained and portable — no dependency on cezaar. You own the skills and can customize them however you want.

You start attached by default. Run the `detach` skill anytime to eject. This is a one-way switch by design — once you detach, the vault is yours.

## Available Skills

| Skill | Description |
|-------|-------------|
| `init-vault` | Bootstrap a new vault or connect to an existing one |
| `capture` | Auto-classify and save ideas, todos, questions, and research spikes |
| `triage` | Process inbox items — graduate to projects, knowledge, or archive |
| `journal` | Daily stream-of-consciousness and weekly reflections |
| `reflect` | Synthesize recent activity into themes and insights |
| `review` | Generate casual or formal performance reviews from vault data |
| `detach` | Eject skills into the vault for full customization |
