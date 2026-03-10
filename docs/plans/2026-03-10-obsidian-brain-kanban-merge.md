# Obsidian Brain: Kanban + Daily/Wins Merge

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add kanban workflow (frontmatter status as columns + Dataview board), daily standup skill, and wins/accomplishment tracking to the obsidian-brain plugin.

**Architecture:** Extend the existing inbox system with expanded status values that map to kanban columns. A Dataview-powered board.md renders items by status across all inbox type folders. New daily and wins skills provide structured work tracking alongside the existing freeform journal. All skills prefixed `obsidian-brain:` in frontmatter.

**Tech Stack:** Obsidian, Dataview plugin, Claude Code skills (markdown)

---

**Branch:** `feat/obsidian-brain-kanban-merge`
**Working directory:** `/Users/CAvitia/repos/cezaar-obsidian-brain`
**Plugin root:** `plugins/obsidian-brain/`
**No build/test commands** — this is all markdown skill files.

**Verification:** After each task, confirm the modified file is valid markdown, frontmatter is valid YAML, and internal references (file paths, skill names) are consistent.

---

### Task 1: Prefix all skill names with `obsidian-brain:`

Update the `name:` field in YAML frontmatter of every existing SKILL.md.

**Files:**
- Modify: `plugins/obsidian-brain/skills/capture/SKILL.md:2` — `name: capture` → `name: obsidian-brain:capture`
- Modify: `plugins/obsidian-brain/skills/triage/SKILL.md:2` — `name: triage` → `name: obsidian-brain:triage`
- Modify: `plugins/obsidian-brain/skills/journal/SKILL.md:2` — `name: journal` → `name: obsidian-brain:journal`
- Modify: `plugins/obsidian-brain/skills/reflect/SKILL.md:2` — `name: reflect` → `name: obsidian-brain:reflect`
- Modify: `plugins/obsidian-brain/skills/review/SKILL.md:2` — `name: review` → `name: obsidian-brain:review`
- Modify: `plugins/obsidian-brain/skills/init-vault/SKILL.md:2` — `name: init-vault` → `name: obsidian-brain:init-vault`
- Modify: `plugins/obsidian-brain/skills/detach/SKILL.md:2` — `name: detach` → `name: obsidian-brain:detach`

**Step 1:** Edit each file's line 2 to add the `obsidian-brain:` prefix.

**Step 2:** Update cross-references. In `init-vault/SKILL.md:121`, change `obsidian-brain:detach` reference (already correct after rename). Scan all SKILL.md files for any bare skill name references and prefix them.

**Step 3:** Commit.

```bash
git add plugins/obsidian-brain/skills/*/SKILL.md
git commit -m "feat: prefix all skill names with obsidian-brain:"
```

**Done when:** Every SKILL.md has `name: obsidian-brain:<skill-name>` and all cross-references use the prefixed form.

---

### Task 2: Update vault-structure.md

Add new folders, status value, and Dataview queries to the vault structure reference.

**Files:**
- Modify: `plugins/obsidian-brain/skills/init-vault/references/vault-structure.md`

**Step 1:** Add `accomplishments/` to the directory tree (after `knowledge/`):

```
├── accomplishments/              # Promoted wins from daily EOD — evidence for reviews
```

**Step 2:** Add `accomplishments/` to the Folder Purposes table:

```markdown
| `accomplishments/` | Wins promoted from daily logs — shipped work, impact, evidence for reviews. |
```

**Step 3:** Add `blocked` to the Valid `status` Values table (between `in-progress` and `done`):

```markdown
| `blocked` | Stuck — needs attention or is waiting on something |
```

**Step 4:** Add `accomplishment` to the Valid `type` Values table:

```markdown
| `accomplishment` | Shipped work, wins, impact evidence |
```

**Step 5:** Add `daily-log` to the Valid `type` Values table:

```markdown
| `daily-log` | Structured daily standup log (morning kickoff + EOD wrap) |
```

**Step 6:** Update the Kanban Board View Dataview query to include all inbox folders and sort by status priority including `blocked`:

```dataview
TABLE WITHOUT ID
  file.link AS "Task",
  type AS "Type",
  status AS "Status",
  parent AS "Project"
FROM "inbox"
WHERE status != "archived"
SORT choice(status, "in-progress", 1, "blocked", 2, "backlog", 3, "captured", 4, "done", 5) ASC
```

**Step 7:** Commit.

```bash
git add plugins/obsidian-brain/skills/init-vault/references/vault-structure.md
git commit -m "feat: add accomplishments folder, blocked status, and daily-log type to vault structure"
```

**Done when:** vault-structure.md includes accomplishments/, blocked status, accomplishment type, daily-log type, and updated kanban query.

---

### Task 3: Create new templates

Add board, daily-log, and accomplishment templates.

**Files:**
- Create: `plugins/obsidian-brain/skills/init-vault/references/templates/board.md`
- Create: `plugins/obsidian-brain/skills/init-vault/references/templates/daily-log.md`
- Create: `plugins/obsidian-brain/skills/init-vault/references/templates/accomplishment.md`

**Step 1:** Create `board.md`:

```markdown
---
type: board
---

# Board

## In Progress

```dataview
TABLE WITHOUT ID file.link AS "Item", type AS "Type", tags AS "Tags", created AS "Created"
FROM "inbox"
WHERE status = "in-progress"
SORT created ASC
```

## Blocked

```dataview
TABLE WITHOUT ID file.link AS "Item", type AS "Type", tags AS "Tags", created AS "Created"
FROM "inbox"
WHERE status = "blocked"
SORT created ASC
```

## Backlog

```dataview
TABLE WITHOUT ID file.link AS "Item", type AS "Type", tags AS "Tags", created AS "Created"
FROM "inbox"
WHERE status = "backlog"
SORT created ASC
```

## Captured

```dataview
TABLE WITHOUT ID file.link AS "Item", type AS "Type", tags AS "Tags", created AS "Created"
FROM "inbox"
WHERE status = "captured"
SORT created DESC
```

## Done (Last 7 Days)

```dataview
TABLE WITHOUT ID file.link AS "Item", type AS "Type", created AS "Created"
FROM "inbox"
WHERE status = "done" AND created >= date(today) - dur(7 days)
SORT created DESC
```
```

**Step 2:** Create `daily-log.md`:

```markdown
---
type: daily-log
status: captured
created: "{{date}}"
tags:
  - daily
parent: ""
---

# {{date}}

## Morning Kickoff

### Top Priorities
- [ ]

### Carried Over
- [ ]

---

## Throughout the Day
<!-- Quick notes, links, context switches -->

---

## End of Day Wrap

### What Got Done
-

### Blockers
-

### Learned Today
-

### Wins
<!-- Anything here can be promoted to accomplishments/ -->
-

---

## Journal
<!-- Freeform entries appended by the journal skill -->
```

**Step 3:** Create `accomplishment.md`:

```markdown
---
type: accomplishment
status: captured
created: "{{date}}"
tags: []
parent: ""
---

## What happened


## Impact


## Evidence

```

**Step 4:** Commit.

```bash
git add plugins/obsidian-brain/skills/init-vault/references/templates/board.md
git add plugins/obsidian-brain/skills/init-vault/references/templates/daily-log.md
git add plugins/obsidian-brain/skills/init-vault/references/templates/accomplishment.md
git commit -m "feat: add board, daily-log, and accomplishment templates"
```

**Done when:** All three templates exist with valid frontmatter and correct Dataview queries.

---

### Task 4: Update init-vault skill

Add new folders and templates to the scaffolding process.

**Files:**
- Modify: `plugins/obsidian-brain/skills/init-vault/SKILL.md:69-81` (mkdir section)
- Modify: `plugins/obsidian-brain/skills/init-vault/SKILL.md:126-137` (confirmation section)

**Step 1:** Add `"$VAULT/accomplishments"` to the mkdir command at line 69-81 (after `"$VAULT/knowledge"`).

**Step 2:** Add a step after template copying to place `board.md` at the vault root:

```markdown
### Place the board view

Copy `board.md` to the vault root so it's easily accessible:

```bash
cp references/templates/board.md "$VAULT/board.md"
```
```

**Step 3:** Update the confirmation message (line 126-137) to mention accomplishments folder, board view, and new templates:

```markdown
> - **Folders:** inbox (ideas, todos, questions, research), projects, knowledge, accomplishments, journal (daily, weekly), reviews (summaries, formal), templates, archive
> - **Templates:** 11 templates copied to `templates/` — for todos, ideas, questions, research, daily/weekly journals, daily logs, accomplishments, reviews, and board view
> - **Board:** `board.md` at vault root — Dataview-powered kanban view of your inbox
```

**Step 4:** Update template count from "8 templates" to "11 templates" in the confirmation.

**Step 5:** Commit.

```bash
git add plugins/obsidian-brain/skills/init-vault/SKILL.md
git commit -m "feat: add accomplishments folder and new templates to init-vault scaffolding"
```

**Done when:** init-vault creates accomplishments/, copies board.md to vault root, and confirmation lists all new assets.

---

### Task 5: Update triage skill for status transitions

Add "move" as a first-class action using progressive disclosure.

**Files:**
- Modify: `plugins/obsidian-brain/skills/triage/SKILL.md`
- Modify: `plugins/obsidian-brain/skills/triage/references/graduation-rules.md`

**Step 1:** Update Step 2 (Inbox Scan, line 28-59) to group items by status AND type:

```markdown
Present a summary to the user:

> **Board overview:**
> - 2 in-progress (1 todo, 1 research)
> - 1 blocked (todo)
> - 3 backlog (2 todos, 1 idea)
> - 4 captured (1 todo, 2 ideas, 1 question)
>
> 10 items total. What would you like to do?

Ask the user if they want to:
- **Triage new captures** — walk through `captured` items (existing flow)
- **Update the board** — change statuses on existing items
- **Both** — triage first, then update
```

**Step 2:** Update Step 3 (Walk-Through, line 61-87) to show status in preview and add "move" as an action:

```markdown
3. **Ask for action:**

   > Move, graduate, archive, or skip?

   - **Move** — change status: start, block, finish, or set to backlog (Step 3a)
   - **Graduate** — move to its permanent home (Step 4)
   - **Archive** — move to `archive/` (Step 5)
   - **Skip** — leave as-is, move to next item

Accept shorthand: `m`, `g`, `a`, `s` or the full word. For move, also accept direct status shortcuts: `start` (→ in-progress), `block` (→ blocked), `finish` (→ done), `backlog` (→ backlog).
```

**Step 3:** Add a new Step 3a after Step 3 for status transitions:

```markdown
## Step 3a: Status Transition (Move)

When the user chooses to move an item, update only the `status` field in frontmatter. The file stays in its current folder.

### Valid transitions

Any status can transition to any other status. Common flows:

- `captured` → `backlog` (triaged, accepted)
- `backlog` → `in-progress` (started working)
- `in-progress` → `blocked` (stuck)
- `blocked` → `in-progress` (unblocked)
- `in-progress` → `done` (completed)
- `done` → `archived` (cleaned up)

### Execution

```bash
sed -i '' 's/^status: .*/status: <new-status>/' "$FILE"
```

Confirm the change:

> Moved **Fix the login bug** → `in-progress`
```

**Step 4:** Update `graduation-rules.md` to add `blocked` to the Frontmatter Mutation Summary table:

```markdown
| Block any | status | * | blocked |
| Unblock any | status | blocked | in-progress |
| Start any | status | captured/backlog | in-progress |
| Finish any | status | * | done |
```

**Step 5:** Commit.

```bash
git add plugins/obsidian-brain/skills/triage/SKILL.md
git add plugins/obsidian-brain/skills/triage/references/graduation-rules.md
git commit -m "feat: add status transitions (move) to triage skill"
```

**Done when:** Triage presents board overview, supports move/start/block/finish shortcuts, and graduation-rules.md documents all status transitions.

---

### Task 6: Update journal skill for daily coexistence

Modify journal to append to `## Journal` section when a daily-log file exists.

**Files:**
- Modify: `plugins/obsidian-brain/skills/journal/SKILL.md`

**Step 1:** Update Step 3 (Daily Flow, line 39-124) — add a check for existing daily-log type files:

After "If the file already exists" section, add:

```markdown
### If a daily-log file exists

If the file exists and has `type: daily-log` in frontmatter (created by the daily skill), append the journal entry under the `## Journal` section at the bottom instead of `## Entries`. If the `## Journal` section doesn't exist, create it at the end of the file.

```markdown
## Journal

### HH:MM

<user's entry>
```

This preserves the structured daily log sections while allowing freeform journaling in the same file.
```

**Step 2:** Commit.

```bash
git add plugins/obsidian-brain/skills/journal/SKILL.md
git commit -m "feat: journal skill appends to Journal section when daily-log exists"
```

**Done when:** Journal skill detects daily-log type and appends under `## Journal` section instead of `## Entries`.

---

### Task 7: Create daily skill

New skill for morning kickoff and EOD wrap.

**Files:**
- Create: `plugins/obsidian-brain/skills/daily/SKILL.md`

**Step 1:** Create the SKILL.md with this content:

```markdown
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
   - If not, load the `daily-log.md` template (attached: from plugin templates; detached: from vault templates/) and create the file, replacing `{{date}}` with today's date.
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
- Add a note about untriaged captures if count > 0:

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
```

**Step 2:** Commit.

```bash
git add plugins/obsidian-brain/skills/daily/SKILL.md
git commit -m "feat: add daily skill for morning kickoff and EOD wrap"
```

**Done when:** `daily/SKILL.md` exists with valid frontmatter, handles morning and evening modes, promotes wins to accomplishments.

---

### Task 8: Create wins skill

New skill for surfacing accomplishments over time.

**Files:**
- Create: `plugins/obsidian-brain/skills/wins/SKILL.md`

**Step 1:** Create the SKILL.md:

```markdown
---
name: obsidian-brain:wins
description: Surface and summarize accomplishments from your Obsidian vault over a time range. Use when the user wants to see their wins, prepare for a review, write a self-assessment, or look back at what they shipped. Triggers on phrases like "show my wins", "what did I accomplish", "review prep", "self-assessment", "promo doc", or any request to summarize accomplishments.
---

# Wins

Reads accomplishments and daily log wins sections, then presents them as a list or generates a narrative summary for reviews, 1:1 prep, or promo docs.

## Step 1: Config Check

Read the obsidian-brain config to find the vault:

```bash
cat ~/.config/obsidian-brain/config.json
```

You need:
- `vault_path` — absolute path to the Obsidian vault

**If the config file doesn't exist or is invalid,** stop and tell the user:

> It looks like obsidian-brain isn't set up yet. Run the `obsidian-brain:init-vault` skill first to configure your vault.

Do not proceed without a valid config.

## Step 2: Time Range

Parse the time range from the user's input. Default to **last 7 days** if not specified.

Supported ranges: "today", "this week", "last week", "this month", "last month", "this quarter", "last 30 days", or a specific date range.

Convert to start and end dates in `YYYY-MM-DD` format.

Confirm the range:

> Showing wins for **this month** (2026-03-01 through 2026-03-10).

## Step 3: Gather Wins

Pull from two sources:

### 3a. Accomplishments folder

```bash
find "$VAULT/accomplishments" -name "*.md" -type f | sort
```

Read each file. Include notes whose `created` date falls within the range. These are curated wins — the strongest signal.

### 3b. Daily log Wins sections

```bash
find "$VAULT/journal/daily" -name "*.md" -type f | sort
```

Read daily logs in the range. Extract content under `### Wins` sections. These are raw wins that may not have been promoted to accomplishments yet.

### Handling sparse data

If no wins are found in either source:

> No wins found for this period. Use the `obsidian-brain:daily` EOD wrap to record wins, or capture accomplishments directly.

## Step 4: Present Wins

List all wins grouped by date, with source indicated:

```
Wins for March 2026:

2026-03-09:
  - Shipped automated code review pipeline via Claude Cloud (accomplishment)
  - Completed essentials:workflow refactor for RPIV (daily)

2026-03-05:
  - Deployed git-li5 plugin (accomplishment)
```

## Step 5: Narrative Summary (Optional)

If the user asks for a narrative (e.g., "for my 1:1", "for my review", "summarize"), generate a natural-language summary:

- Weight accomplishments (curated) higher than daily wins (raw).
- Use second person ("You shipped...", "Your work on...").
- Group by theme if there are enough wins to cluster.
- Include `[[wikilinks]]` to source notes.
- Target 200-400 words for a summary, longer for promo docs.

Ask what context the summary is for to adjust tone:
- **1:1 prep** — conversational, highlight 2-3 key items
- **Self-assessment** — first person, comprehensive, impact-focused
- **Promo doc** — formal, quantified impact, leadership signals

## Error Handling

- **Vault directory doesn't exist** — tell user and suggest re-running `obsidian-brain:init-vault`.
- **Folders missing** — skip silently, check both sources independently.
- **Malformed frontmatter** — skip file, continue.
```

**Step 2:** Commit.

```bash
git add plugins/obsidian-brain/skills/wins/SKILL.md
git commit -m "feat: add wins skill for surfacing accomplishments"
```

**Done when:** `wins/SKILL.md` exists, gathers from accomplishments/ and daily wins, supports narrative generation.

---

### Task 9: Update review skill to use accomplishments

Add accomplishments and daily wins as data sources.

**Files:**
- Modify: `plugins/obsidian-brain/skills/review/SKILL.md:107-180` (Step 4: Data Gathering)

**Step 1:** Add a new section `4a-prime` right after `4a. Journal entries` (at line ~121). Insert before `4b. Completed projects`:

```markdown
### 4a+. Accomplishments

Scan the accomplishments folder:

```bash
find "$VAULT/accomplishments" -name "*.md" -type f | sort
```

Read each accomplishment note whose `created` date falls within the range. These are curated wins — weight them higher than journal entries when building the review. Every accomplishment should appear in the review output.

Also extract `### Wins` sections from daily logs in `journal/daily/` that fall within the range. These are supporting evidence for the accomplishment notes.
```

**Step 2:** Update the synthesis guidance in Step 5 (line ~195-210). After "Analyze all gathered data," add:

```markdown
**Data source priority for claims:**
1. Accomplishments (highest — user curated these as wins)
2. Completed projects and archived items
3. Daily log wins sections
4. Journal entries and knowledge notes (context and narrative color)
```

**Step 3:** Commit.

```bash
git add plugins/obsidian-brain/skills/review/SKILL.md
git commit -m "feat: add accomplishments as primary data source for review skill"
```

**Done when:** Review skill gathers from accomplishments/ and daily wins, weights them highest.

---

### Task 10: Update reflect skill to include accomplishments

Add accomplishments as a data source for reflection synthesis.

**Files:**
- Modify: `plugins/obsidian-brain/skills/reflect/SKILL.md:52-114` (Step 3: Data Gathering)

**Step 1:** Add a new section `3b+` after `3b. Archived items` (at line ~78). Insert before `3c. Active projects`:

```markdown
### 3b+. Accomplishments

Scan the accomplishments folder:

```bash
find "$VAULT/accomplishments" -name "*.md" -type f | sort
```

Include accomplishment notes whose `created` date falls within the range. These represent recognized wins and should be featured prominently in the Accomplishments section of the reflection.
```

**Step 2:** Commit.

```bash
git add plugins/obsidian-brain/skills/reflect/SKILL.md
git commit -m "feat: add accomplishments as data source for reflect skill"
```

**Done when:** Reflect skill scans accomplishments/ alongside other vault data.

---

### Task 11: Create help skill

New skill providing skill reference and getting started guide.

**Files:**
- Create: `plugins/obsidian-brain/skills/help/SKILL.md`

**Step 1:** Create the SKILL.md:

```markdown
---
name: obsidian-brain:help
description: Show available obsidian-brain skills and how to get started. Use when the user asks for help with obsidian-brain, wants to see available commands, asks what they can do, or is new to the plugin. Triggers on phrases like "help", "what can you do", "how do I use this", "getting started", "available skills", or "obsidian-brain help".
---

# Help

Show available skills and getting started guide. Don't load any reference files — everything is inline.

## Getting Started

If the user is new (no config file exists at `~/.config/obsidian-brain/config.json`), show this:

> **Getting started with obsidian-brain:**
>
> 1. **Set up your vault** — run `obsidian-brain:init-vault` to create or connect an Obsidian vault
> 2. **Start capturing** — say anything and it gets captured to your inbox automatically
> 3. **Triage your inbox** — run `obsidian-brain:triage` to organize captures into projects or move them across your board
> 4. **Daily standup** — run `obsidian-brain:daily` each morning and evening to track your work
> 5. **Review your wins** — run `obsidian-brain:wins` to see what you've accomplished
>
> The inbox is your board. Every capture gets a status (captured → backlog → in-progress → done) and you can view it all in `board.md` at your vault root.

If the user already has a config, skip the getting started section.

## Skill Reference

Always show this:

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
> - "I need to fix the login bug" → `capture` (auto-triggers)
> - "What's on my board?" → `triage`
> - "Start my day" → `daily` (morning mode)
> - "How'd today go?" → `daily` (evening mode)
> - "Show my wins this month" → `wins`
> - "How did I do this quarter?" → `review`
> - "What patterns do you see?" → `reflect`

## Rules

- Don't load any external files — this skill is self-contained.
- If config exists, skip getting started and show just the skill reference.
- If config doesn't exist, show getting started first, then skill reference.
- Keep it brief — the user is looking for orientation, not documentation.
```

**Step 2:** Commit.

```bash
git add plugins/obsidian-brain/skills/help/SKILL.md
git commit -m "feat: add help skill with skill reference and getting started"
```

**Done when:** `help/SKILL.md` exists with getting started guide and complete skill reference table.

---

### Task 12: Update detach skill for new skills

Update the expected output in detach to include new skill directories.

**Files:**
- Modify: `plugins/obsidian-brain/skills/detach/SKILL.md:123-146`

**Step 1:** Update the expected directory listing at line 123-146 to include daily, wins, and help:

```
<vault>/.claude/plugins/obsidian-brain/skills/
├── capture/
│   ├── SKILL.md
│   └── references/
│       └── classification.md
├── daily/
│   └── SKILL.md
├── help/
│   └── SKILL.md
├── triage/
│   ├── SKILL.md
│   └── references/
│       └── graduation-rules.md
├── journal/
│   └── SKILL.md
├── reflect/
│   └── SKILL.md
├── review/
│   ├── SKILL.md
│   └── references/
│       ├── summary-format.md
│       └── formal-format.md
└── wins/
    └── SKILL.md
```

**Step 2:** Update the verification check at line 156 to include daily and wins in the core skills list:

```markdown
Make sure at least the core skills (capture, triage, daily, journal, reflect, wins) are present.
```

**Step 3:** Commit.

```bash
git add plugins/obsidian-brain/skills/detach/SKILL.md
git commit -m "feat: update detach to include daily, wins, and help skills"
```

**Done when:** Detach expected output includes all new skills and verification checks for them.

---

### Task 13: Update README

Update the plugin README with new skills and kanban workflow description.

**Files:**
- Modify: `plugins/obsidian-brain/README.md`

**Step 1:** Update the Overview paragraph to mention the board:

```markdown
obsidian-brain lets you capture ideas, track todos on a kanban board, journal, reflect, and generate performance reviews — all without leaving the terminal.
```

**Step 2:** Replace the Available Skills table:

```markdown
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
```

**Step 3:** Add a Kanban Workflow section after Available Skills:

```markdown
## Kanban Workflow

Every capture lands in your inbox with `status: captured`. Use `triage` to move items through the board:

```
captured → backlog → in-progress → done → archived
                   ↕ blocked
```

Open `board.md` at your vault root to see all items grouped by status, powered by [Dataview](https://github.com/blacksmithgu/obsidian-dataview).
```

**Step 4:** Commit.

```bash
git add plugins/obsidian-brain/README.md
git commit -m "docs: update README with new skills and kanban workflow"
```

**Done when:** README lists all 10 skills with prefixed names and describes the kanban workflow.

---

## Final Verification

After all tasks are complete:

1. Confirm every SKILL.md has `name: obsidian-brain:<skill-name>` in frontmatter.
2. Confirm vault-structure.md references all folders that init-vault creates.
3. Confirm init-vault's mkdir list matches vault-structure.md's directory tree.
4. Confirm the detach skill's expected output lists all skill directories.
5. Confirm the help skill's reference table lists all skills.
6. Confirm the README skill table matches the actual skills/ directory contents.
7. Review the full diff with `git diff main...HEAD`.
