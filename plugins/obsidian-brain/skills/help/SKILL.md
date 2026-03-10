---
name: obsidian-brain:help
description: Show available obsidian-brain skills and how to get started. Use when the user asks for help with obsidian-brain, wants to see available commands, asks what they can do, or is new to the plugin. Triggers on phrases like "help", "what can you do", "how do I use this", "getting started", "available skills", or "obsidian-brain help".
---

# Help

Show available skills and getting started guide. Don't load any reference files — everything is inline.

## Step 1: Config Check

Check if the config exists:

```bash
cat ~/.config/obsidian-brain/config.json
```

Use the result to determine whether to show the getting started section.

## Step 2: Getting Started (new users only)

If the config file doesn't exist, show this before the skill reference:

> **Getting started with obsidian-brain:**
>
> 1. **Set up your vault** — run `obsidian-brain:init-vault` to create or connect an Obsidian vault
> 2. **Start capturing** — say anything and it gets captured to your inbox automatically
> 3. **Triage your inbox** — run `obsidian-brain:triage` to organize captures into projects or move them across your board
> 4. **Daily standup** — run `obsidian-brain:daily` each morning and evening to track your work
> 5. **Review your wins** — run `obsidian-brain:wins` to see what you've accomplished
>
> The inbox is your board. Every capture gets a status (captured → backlog → in-progress → done) and you can view it all in `board.md` at your vault root.

## Step 3: Skill Reference (always show)

> **Available skills:**
>
> | Skill | What it does |
> |-------|-------------|
> | `obsidian-brain:capture` | Auto-classify and save ideas, todos, questions, research to your inbox |
> | `obsidian-brain:triage` | Move items across the board, graduate to projects, or archive |
> | `obsidian-brain:daily` | Morning kickoff (surface active work) and EOD wrap (log what got done) |
> | `obsidian-brain:journal` | Freeform daily or weekly journaling — your words, preserved as-is |
> | `obsidian-brain:reflect` | Synthesize recent activity into themes, patterns, and insights |
> | `obsidian-brain:review` | Generate casual or formal performance reviews from vault data |
> | `obsidian-brain:wins` | Surface accomplishments over a time range for 1:1s or reviews |
> | `obsidian-brain:init-vault` | Bootstrap a new vault or connect to an existing one |
> | `obsidian-brain:detach` | Eject skills into your vault for full customization |
> | `obsidian-brain:help` | You are here |
>
> **Common workflows:**
>
> - "I need to fix the login bug" → `obsidian-brain:capture` (auto-triggers)
> - "What's on my board?" → `obsidian-brain:triage`
> - "Start my day" → `obsidian-brain:daily` (morning mode)
> - "How'd today go?" → `obsidian-brain:daily` (evening mode)
> - "Show my wins this month" → `obsidian-brain:wins`
> - "How did I do this quarter?" → `obsidian-brain:review`
> - "What patterns do you see?" → `obsidian-brain:reflect`

## Rules

- Don't load any external files — this skill is self-contained.
- If config exists, skip getting started and show just the skill reference.
- If config doesn't exist, show getting started first, then skill reference.
- Keep it brief — the user is looking for orientation, not documentation.
