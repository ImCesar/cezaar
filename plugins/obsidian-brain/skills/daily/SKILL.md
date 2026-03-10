---
name: obsidian-brain:daily
description: Morning kickoff or end-of-day wrap for your Obsidian vault. Creates structured daily logs with priorities, carried-over items, and EOD summaries. Use when the user wants to start their day, wrap up their day, check today's status, or update their daily log. Triggers on phrases like "morning", "start my day", "kickoff", "eod", "end of day", "wrap up", "how was today", or "daily".
---

# Daily

Structured daily standup logs — morning kickoff surfaces active work and untriaged captures, EOD wrap records what got done and promotes wins to accomplishments.

## Step 1: Config Check

Read the obsidian-brain config to find the vault:

```bash
cat ~/.config/obsidian-brain/config.json
```

You need:
- `vault_path` — absolute path to the Obsidian vault
- `mode` — either `"attached"` or `"detached"`

**If the config file doesn't exist or is invalid,** stop and tell the user:

> It looks like obsidian-brain isn't set up yet. Run the `obsidian-brain:init-vault` skill first to configure your vault.

Do not proceed without a valid config.

## Step 2: Mode Detection

1. Determine today's date (`YYYY-MM-DD`).
2. Check if `journal/daily/YYYY-MM-DD.md` exists.
   - If not, load the `daily-log.md` template and create the file, replacing `{{date}}` with today's date.
   - **If mode is `"attached"`:** read template from `plugins/obsidian-brain/skills/init-vault/references/templates/daily-log.md`
   - **If mode is `"detached"`:** read template from `<vault_path>/templates/daily-log.md`
   - **If template missing:** use minimal daily-log structure with frontmatter and section headers.
3. Select mode:
   - If user explicitly says "morning" or "kickoff" → morning mode.
   - If user explicitly says "eod", "end of day", or "wrap" → evening mode.
   - Otherwise, auto-detect: before 12:00 local time → morning; 12:00 or later → evening.

## Step 3: Morning Mode

Gather context from two sources, then update the daily note.

### 3a. Active and untriaged inbox items

Scan the inbox:

```bash
find "$VAULT/inbox" -name "*.md" -type f
```

Read frontmatter of each file. Collect:
- Items with `status: in-progress` — your active work
- Items with `status: blocked` — stuck items needing attention
- Count of items with `status: captured` — untriaged backlog

### 3b. Previous day carry-over

Find the most recent daily log before today:

```bash
ls "$VAULT/journal/daily/" | grep -v "$(date +%Y-%m-%d)" | sort -r | head -1
```

If found, read it and extract unchecked items (`- [ ]`) from:
- `### Top Priorities`
- `### What Got Done` (items that weren't checked off)

### 3c. Update the daily note

- Under **Top Priorities**: list active (`in-progress`) and blocked inbox items.
- Under **Carried Over**: list unchecked items from previous day's daily log.
- If unprocessed captures exist, add a note:

  > **N untriaged captures** in inbox — run `obsidian-brain:triage` when ready.

### 3d. Present summary

```
Morning kickoff for YYYY-MM-DD

Active work (N):
  - Fix the login bug [in-progress]
  - Auth research [blocked]

Carried over (N):
  - Deploy staging environment

Untriaged captures: N

Daily note updated -> journal/daily/YYYY-MM-DD.md
```

## Step 4: Evening Mode

Conversational — do NOT silently fill in sections.

### 4a. Ask the user

Start with:

> How'd today go? What got done?

Let the user talk. Ask follow-up questions if responses are brief:
- "Any blockers worth noting?"
- "Learn anything interesting?"
- "Any wins you want to call out?"

### 4b. Fill in EOD sections

From the conversation, populate these sections in the daily log:

- **What Got Done**: concrete items completed today.
- **Blockers**: anything slowing progress, or "None" if clear.
- **Learned Today**: insights, TILs, or remove placeholder if none.
- **Wins**: accomplishments, shipped work, positive outcomes.

### 4c. Accomplishment promotion

If the user listed anything in **Wins**, ask:

> Any of these wins worth capturing as a full accomplishment note?

If yes, create a note in `accomplishments/` using the accomplishment template:
- Filename: `YYYY-MM-DD-slugified-title.md`
- Populate from the conversation: what happened, impact, evidence.

**If mode is `"attached"`:** read template from `plugins/obsidian-brain/skills/init-vault/references/templates/accomplishment.md`
**If mode is `"detached"`:** read template from `<vault_path>/templates/accomplishment.md`

### 4d. Confirm

```
EOD wrap for YYYY-MM-DD

What got done:
  - Item 1
  - Item 2

Daily note updated -> journal/daily/YYYY-MM-DD.md
```

If accomplishments were promoted:

```
Accomplishment saved -> accomplishments/YYYY-MM-DD-title.md
```

## Rules

- Never overwrite content the user previously entered. Append or fill empty sections only.
- If morning sections are already filled, skip re-populating — just show current state.
- If EOD sections are already filled, ask before overwriting.
- Keep the daily note format consistent with the daily-log template.

## Error Handling

- **Vault directory doesn't exist** — tell user and suggest re-running `obsidian-brain:init-vault`.
- **Journal/daily folder missing** — create it silently with `mkdir -p`.
- **Template missing** — fall back to minimal daily-log structure.
- **Write permission error** — report exact error and path.
