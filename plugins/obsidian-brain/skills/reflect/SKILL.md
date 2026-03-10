---
name: reflect
description: Synthesize recent journal entries, completed work, and captures into themes and insights. Use when the user wants to reflect on a time period, identify patterns in their work, or generate insights from their vault activity. Triggers on phrases like "reflect on this week", "what patterns do you see", "summarize my month", "what have I been focused on", or any request to look back and synthesize.
---

# Reflect

Looks back over a time period and synthesizes what happened into themes, patterns, and insights. Reads journal entries, archived items, active projects, and graduated knowledge — then produces a reflection note.

## Step 1: Config Check

Read the obsidian-brain config to find the vault:

```bash
cat ~/.config/obsidian-brain/config.json
```

You need:
- `vault_path` — absolute path to the Obsidian vault

**If the config file doesn't exist or is invalid,** stop and tell the user:

> It looks like obsidian-brain isn't set up yet. Run the `init-vault` skill first to configure your vault.

Do not proceed without a valid config.

## Step 2: Parse Time Range

Determine the reflection period from the user's input. If they didn't specify, default to **"this week"**.

### Supported ranges

| User says | Interpret as |
|-----------|-------------|
| "today" | Today only |
| "this week" | Monday through today (or Sunday through today, depending on locale) |
| "last week" | The full previous Monday–Sunday week |
| "last 2 weeks" / "past 2 weeks" | 14 days back from today |
| "this month" | 1st of current month through today |
| "last month" | Full previous calendar month |
| "this quarter" | Start of current quarter through today (Q1=Jan, Q2=Apr, Q3=Jul, Q4=Oct) |
| "March" / "February" etc. | Full named month (current year unless stated otherwise) |
| Specific date range ("March 1–7") | Exact range as given |

Convert the range into a start date and end date in `YYYY-MM-DD` format. You'll use these to filter files by their `created` frontmatter field and by filename date prefixes.

**Tell the user the range you're using** before proceeding:

> Reflecting on **this week** (2026-03-02 through 2026-03-09).

## Step 3: Data Gathering

Read all relevant vault data within the time range. Use the `created` frontmatter date and filename date prefixes (`YYYY-MM-DD-*`) to filter.

### 3a. Journal entries

Scan daily and weekly journals:

```bash
find "$VAULT/journal/daily" -name "*.md" -type f | sort
find "$VAULT/journal/weekly" -name "*.md" -type f | sort
```

Read each journal file whose date falls within the range. Daily journals use filenames like `YYYY-MM-DD.md`. Weekly journals use filenames like `YYYY-MM-DD-week-NN.md`. Parse the frontmatter `created` field to confirm the date.

Read the full content of matching journal files — these are the primary source material for reflection.

### 3b. Archived items

Scan completed and archived items:

```bash
find "$VAULT/archive" -name "*.md" -type f | sort
```

Read frontmatter of each file. Include items whose `created` date falls within the range. These represent work that was finished or decisions that were made.

### 3c. Active projects

Scan projects for recent activity:

```bash
find "$VAULT/projects" -name "*.md" -type f | sort
```

Read frontmatter and body of project files. Look for items with `created` dates in the range, or items whose status changed during the period (e.g., moved to `in-progress` or `done`). Also check for child todos within epic folders that were created or completed in the range.

### 3d. Knowledge notes

Scan graduated knowledge:

```bash
find "$VAULT/knowledge" -name "*.md" -type f | sort
```

Include knowledge notes with `created` dates in the range. These represent questions answered and research completed — they show what was learned.

### 3e. Inbox items (optional context)

Optionally scan the inbox for items created in the range that haven't been triaged yet:

```bash
find "$VAULT/inbox" -name "*.md" -type f | sort
```

These don't go into the reflection as accomplishments, but they provide context about what was on the user's mind.

### Handling sparse data

If any folder is empty or missing, skip it silently. If the entire vault has no data in the time range, tell the user:

> No vault activity found for this period. There's nothing to reflect on yet — try a broader time range or make sure you've been using `capture` and `journal` to record your work.

If data is sparse (only 1-2 items), still produce a reflection but note that the period had light activity.

## Step 4: Synthesis

Analyze all gathered data and identify:

### Themes

What topics or areas dominated this period? Look for:
- Repeated tags across captures and journal entries
- Projects that received the most attention
- Subjects that came up in multiple contexts (journal, captures, knowledge)

Group related items into 2-5 themes. Name each theme concisely (e.g., "Authentication overhaul", "Team process improvements", "Learning Rust").

### Patterns

What recurring behaviors or tendencies show up? Look for:
- **Capture type distribution** — mostly todos? Lots of questions? Heavy research? This reveals what mode the user was operating in.
- **Energy and momentum** — did daily journals show increasing or decreasing engagement? Were there bursts of activity followed by lulls?
- **Inbox vs. graduation rate** — lots of captures but few triaged? Or a clean pipeline?
- **Topic drift** — did focus shift significantly from start to end of the period?

### Accomplishments

What got done? Pull from:
- Archived items (explicitly completed)
- Todos with `status: done`
- Ideas that graduated to projects (decisions made)
- Questions that got answered (knowledge gained)
- Research that produced findings

### Connections

What links exist between items that the user might not have noticed?
- An idea that relates to an active project
- A question whose answer impacts a todo
- A pattern in daily journals that explains why a project stalled
- Research that could unblock something in the inbox

Don't force connections — only surface ones that seem genuinely useful.

### Open threads

What's still unresolved or in motion?
- Inbox items from this period still waiting for triage
- Projects that are in-progress but haven't seen updates
- Questions that remain unanswered
- Research that hasn't been synthesized yet

## Step 5: Write the Reflection Note

### Filename

Format: `YYYY-MM-DD-reflection-<period>.md`

Where `<period>` describes the range:
- "today" → `2026-03-09-reflection-today.md`
- "this week" → `2026-03-09-reflection-week-10.md` (ISO week number)
- "last 2 weeks" → `2026-03-09-reflection-2-weeks.md`
- "this month" → `2026-03-09-reflection-march.md`
- "this quarter" → `2026-03-09-reflection-q1.md`
- Specific range → `2026-03-09-reflection-mar-1-to-mar-7.md`

### Frontmatter

```yaml
---
type: journal
status: captured
created: "YYYY-MM-DD"
tags:
  - reflection
parent: ""
---
```

### Body structure

```markdown
# Reflection: <period description>

*Covering <start date> through <end date>*

## Themes

### <Theme 1 name>
<2-4 sentences explaining this theme with specific references to vault items>

### <Theme 2 name>
<2-4 sentences>

(repeat for each theme)

## Patterns

- <Pattern observation with evidence>
- <Pattern observation with evidence>
- ...

## Accomplishments

- <What was completed, with links to the relevant notes using wikilinks>
- ...

## Connections

- <Connection between items the user might not have noticed>
- ...

## Open Threads

- <Unresolved item or ongoing work>
- ...

## Looking Ahead

<1-2 paragraphs: based on the themes and patterns observed, what might be worth focusing on next? What deserves attention? This is suggestive, not prescriptive.>
```

### Write the file

Write the reflection to `journal/`:

```bash
cat > "$VAULT/journal/<filename>" << 'REFLECTION'
<populated reflection content>
REFLECTION
```

Note: reflections go directly in `journal/`, not in `journal/daily/` or `journal/weekly/` — they're their own kind of journal entry.

If a file with the same name already exists, append a numeric suffix: `2026-03-09-reflection-week-10-2.md`.

## Step 6: Present the Reflection

After writing the file, **show the full reflection content in the conversation**. The user should be able to read it without opening Obsidian.

Format it cleanly in the conversation, then confirm where it was saved:

> Reflection written to `journal/2026-03-09-reflection-week-10.md`.

If the reflection surfaced something worth acting on, suggest next steps:

> A few things that might be worth acting on:
> - The auth research in your inbox could unblock the login project — consider triaging it.
> - You've had 3 daily entries mentioning burnout — might be worth a lighter week.

Keep suggestions brief and grounded in the data. Don't over-prescribe.

## Error Handling

- **Vault directory doesn't exist** — the vault_path from config points somewhere invalid. Tell the user and suggest re-running `init-vault`.
- **Empty vault** — no data found for the requested period. Suggest a broader range or note that the vault needs more content first.
- **Unreadable files** — if a specific file can't be read, skip it and continue. Mention skipped files at the end.
- **Malformed frontmatter** — if a file has broken YAML, skip it for synthesis purposes. Don't halt the reflection.
- **Write permission error** — report the exact error and path. The user needs to fix permissions.
- **File already exists** — append numeric suffix. Don't overwrite existing reflections.
