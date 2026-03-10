# obsidian-brain

Scaffold and interact with an opinionated Obsidian vault from Claude Code.

## Overview

obsidian-brain lets you capture ideas, track todos on a kanban board, journal, reflect, and generate performance reviews — all without leaving the terminal.

## Attached vs. Detached

When you run `init-vault`, you choose a mode:

- **Attached** — Skills run from the cezaar plugin. Your vault only has the folder structure and templates. You get skill updates automatically when you update the plugin.
- **Detached** — Skills are copied into your vault's `.claude/` folder as a local plugin. Your vault becomes fully self-contained and portable — no dependency on cezaar. You own the skills and can customize them however you want.

You start attached by default. Run the `detach` skill anytime to eject. This is a one-way switch by design — once you detach, the vault is yours.

## Available Skills

| Skill | Description |
|-------|-------------|
| `obsidian-brain:init-vault` | Bootstrap a new vault or connect to an existing one |
| `obsidian-brain:capture` | Auto-classify and save ideas, todos, questions, and research spikes |
| `obsidian-brain:triage` | Move items across the board, graduate to projects, or archive |
| `obsidian-brain:daily` | Morning kickoff and end-of-day wrap with accomplishment tracking |
| `obsidian-brain:journal` | Daily stream-of-consciousness and weekly reflections |
| `obsidian-brain:reflect` | Synthesize recent activity into themes and insights |
| `obsidian-brain:review` | Generate casual or formal performance reviews from vault data |
| `obsidian-brain:wins` | Surface accomplishments over a time range |
| `obsidian-brain:detach` | Eject skills into the vault for full customization |
| `obsidian-brain:help` | Show available skills and getting started guide |

## Kanban Workflow

Every capture lands in your inbox with `status: captured`. Use `triage` to move items through the board:

```
captured → backlog → in-progress → done → archived
                   ↕ blocked
```

Open `board.md` at your vault root to see all items grouped by status, powered by [Dataview](https://github.com/blacksmithgu/obsidian-dataview).
