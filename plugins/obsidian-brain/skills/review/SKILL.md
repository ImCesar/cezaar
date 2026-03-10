---
name: obsidian-brain:review
description: Generate a performance review from your Obsidian vault data — either a casual narrative summary or a formal structured self-evaluation. Use when the user asks about their performance, wants to prepare for a 1:1 or self-eval, asks "how did I do", or wants to generate a review document for any time period. Triggers on phrases like "review my performance", "how did I do this quarter", "prepare my self-eval", "performance review", or "what did I accomplish".
---

# Review

Generates performance reviews from vault data. Two modes: a casual narrative summary for personal reflection, and a formal structured self-evaluation for sharing with managers or HR. Both pull evidence directly from vault notes with wikilinks.

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

## Step 2: Mode Detection

Determine whether the user wants a **casual** summary or a **formal** self-evaluation based on their input.

### Casual mode

Triggered by informal, reflective language:

| Signal | Examples |
|--------|----------|
| Informal phrasing | "how'd I do", "what did I accomplish", "how's it going" |
| Personal reflection | "review my month", "look back at Q1", "what have I been up to" |
| General curiosity | "summarize my work", "give me a recap", "how was my quarter" |
| Unspecified mode | If they just say "review" without specifying formal/self-eval |

Casual mode produces a narrative review following `references/summary-format.md`.

### Formal mode

Triggered by professional or structured language:

| Signal | Examples |
|--------|----------|
| Explicit formal request | "prepare my performance review", "write my self-eval", "formal review" |
| Manager context | "write my review for my manager", "prep for my 1:1", "prepare for my performance conversation" |
| Self-evaluation | "self-eval", "self-evaluation", "self-assessment" |
| Structured output | "I need a structured review", "generate a review document" |

Formal mode produces a structured self-evaluation following `references/formal-format.md`.

### When ambiguous

If you can't tell which mode, ask:

> I can generate two kinds of reviews:
> - **Casual** — a narrative summary for your own reflection (conversational, paragraph-based)
> - **Formal** — a structured self-evaluation you can share with your manager (tables, impact statements, evidence blocks)
>
> Which would you prefer?

**Tell the user which mode you selected** before proceeding:

> Generating a **casual summary** review for Q1 2026.

or

> Generating a **formal self-evaluation** for Q1 2026.

## Step 3: Time Range

Parse the review period from the user's input.

### Supported ranges

| User says | Interpret as |
|-----------|-------------|
| "today" | Today only |
| "this week" | Monday through today |
| "last week" | Full previous Monday-Sunday week |
| "this month" / "March" | Current (or named) calendar month |
| "last month" | Full previous calendar month |
| "this quarter" / "Q1" | Start of quarter through today (Q1=Jan, Q2=Apr, Q3=Jul, Q4=Oct) |
| "last quarter" | Full previous quarter |
| "this year" / "2026" | January 1 through today (or full named year) |
| "last 2 weeks" | 14 days back from today |
| "last 3 months" | 3 calendar months back |
| Specific range ("Jan 1 - Mar 15") | Exact range as given |

Convert to start and end dates in `YYYY-MM-DD` format.

### If not specified

Ask the user:

> What time period should this review cover? For example: "this quarter", "last month", "January through March", or a specific date range.

**Confirm the range** before proceeding:

> Reviewing **Q1 2026** (2026-01-01 through 2026-03-09).

## Step 4: Data Gathering

Read all vault data within the time range. Use `created` frontmatter dates and filename date prefixes (`YYYY-MM-DD-*`) to filter.

### 4a. Journal entries

Scan daily and weekly journals:

```bash
find "$VAULT/journal/daily" -name "*.md" -type f | sort
find "$VAULT/journal/weekly" -name "*.md" -type f | sort
```

Read each journal file whose date falls within the range. Daily journals use `YYYY-MM-DD.md` filenames. Weekly journals use `YYYY-MM-DD-week-NN.md`. These are your richest source of context — read the full content of every matching entry.

Also check for reflection notes directly in `journal/`:

```bash
find "$VAULT/journal" -maxdepth 1 -name "*.md" -type f | sort
```

### 4b. Completed projects

Scan project notes:

```bash
find "$VAULT/projects" -name "*.md" -type f | sort
```

Read frontmatter and body of project files. Include projects that were:
- Created during the review period
- Completed or archived during the period (check `status` field)
- Actively worked on (check for child items with dates in range)

Projects are key evidence for accomplishments — read thoroughly.

### 4c. Archived items

Scan the archive for completed work:

```bash
find "$VAULT/archive" -name "*.md" -type f | sort
```

Include items whose `created` date falls within the range. These represent finished work, resolved decisions, and completed tasks.

### 4d. Knowledge notes

Scan graduated knowledge:

```bash
find "$VAULT/knowledge" -name "*.md" -type f | sort
```

Include knowledge notes created in the range. These show what was learned — research completed, questions answered, skills developed.

### 4e. Inbox and captures (supplementary)

Optionally scan the inbox for additional context:

```bash
find "$VAULT/inbox" -name "*.md" -type f | sort
```

Inbox items aren't accomplishments, but they reveal what was on the user's mind. High capture volume with low triage rates can indicate overwhelm — useful for growth areas.

### Handling sparse data

If a folder is empty or missing, skip it silently.

If the entire vault has no data in the time range:

> No vault activity found for this period. There's nothing to build a review from — try a broader time range, or make sure you've been using `obsidian-brain:capture` and `obsidian-brain:journal` to record your work.

If data is sparse (only a few items), still produce a review but note that coverage is limited. Don't fabricate content to fill gaps.

## Step 5: Generation

### Read the format reference

Based on the detected mode, read the appropriate format spec:

- **Casual**: Read `references/summary-format.md` from this skill's directory
- **Formal**: Read `references/formal-format.md` from this skill's directory

Follow the format spec closely — it defines structure, tone, sections, evidence standards, and length targets.

### Build the review

Analyze all gathered data and construct the review:

**For casual mode (summary):**
- Write narrative paragraphs, not bullet points
- Second person voice ("you shipped...", "your work on...")
- Sections: Overview, Key Themes, Highlights, Growth Areas
- Target 500-800 words
- Weave in `[[wikilinks]]` to source notes naturally within paragraphs

**For formal mode (self-eval):**
- Use structured sections with headers and tables
- First person voice ("I led...", "I shipped...")
- Sections: Goals & Outcomes (table), Key Accomplishments (with impact statements), Areas for Development, Evidence & References
- Every claim backed by explicit references with dates
- Quantify impact wherever possible
- Designed to be copy-pasted into a self-eval form

### Evidence standards

Both modes require grounding in vault data:

- Reference specific journal entries, project notes, knowledge notes, and archived items
- Use `[[wikilinks]]` for all references
- In formal mode, include dates with every reference: `[[note-name]] (Feb 24)`
- Don't fabricate evidence — only reference notes you actually read
- If the data doesn't support a claim, don't make the claim

### Identifying themes and accomplishments

Look across all gathered data for:

1. **Recurring topics** — what subjects appear in multiple journals, projects, and captures?
2. **Completed work** — what moved from in-progress to done? What got archived?
3. **Learning** — what knowledge notes were created? What research was done?
4. **Patterns** — what does the journal cadence reveal? Energy levels? Focus shifts?
5. **Growth signals** — where did the user stretch? What was hard? What improved?
6. **Gaps** — what was planned but didn't happen? What backed up?

## Step 6: Output

### Filename

**Casual reviews** go to `reviews/summaries/`:

| Period | Filename |
|--------|----------|
| Quarter | `YYYY-QN-review.md` (e.g., `2026-Q1-review.md`) |
| Month | `YYYY-MM-review.md` (e.g., `2026-03-review.md`) |
| Week | `YYYY-WNN-review.md` (e.g., `2026-W10-review.md`) |
| Custom range | `YYYY-MM-DD-to-YYYY-MM-DD-review.md` |

**Formal reviews** go to `reviews/formal/`:

| Period | Filename |
|--------|----------|
| Quarter | `YYYY-QN-self-eval.md` (e.g., `2026-Q1-self-eval.md`) |
| Month | `YYYY-MM-self-eval.md` (e.g., `2026-03-self-eval.md`) |
| Week | `YYYY-WNN-self-eval.md` (e.g., `2026-W10-self-eval.md`) |
| Custom range | `YYYY-MM-DD-to-YYYY-MM-DD-self-eval.md` |

### Frontmatter

```yaml
---
type: review
status: captured
created: "YYYY-MM-DD"
tags:
  - review
  - summary   # or "formal" for self-evals
period: "<period description>"
parent: ""
---
```

### Write the file

Ensure the output directory exists, then write:

```bash
mkdir -p "$VAULT/reviews/summaries"  # or reviews/formal
cat > "$VAULT/reviews/summaries/<filename>" << 'REVIEW'
<populated review content>
REVIEW
```

If a file with the same name already exists, append a numeric suffix: `2026-Q1-review-2.md`.

### Present in conversation

After writing the file, **show the full review content in the conversation**. The user should be able to read the entire review without opening Obsidian.

Then confirm where it was saved:

> Review written to `reviews/summaries/2026-Q1-review.md`.

or

> Self-evaluation written to `reviews/formal/2026-Q1-self-eval.md`.

### Suggest next steps

If the review surfaced actionable insights, briefly suggest next steps:

> A few things that might be worth acting on:
> - The auth research could be turned into a formal project proposal for Q2.
> - Your growth area around workload management might be worth discussing in your next 1:1.

Keep suggestions brief and grounded in the review content. Don't over-prescribe.

## Error Handling

- **Vault directory doesn't exist** — the vault_path from config points somewhere invalid. Tell the user and suggest re-running `obsidian-brain:init-vault`.
- **Empty vault** — no data found for the requested period. Suggest a broader range or note that the vault needs more content first.
- **Unreadable files** — if a specific file can't be read, skip it and continue. Mention skipped files at the end.
- **Malformed frontmatter** — if a file has broken YAML, skip it for synthesis purposes. Don't halt the review.
- **Write permission error** — report the exact error and path. The user needs to fix permissions.
- **File already exists** — append numeric suffix. Don't overwrite existing reviews.
- **Insufficient data for formal mode** — if there's not enough evidence to fill a proper self-eval, suggest switching to casual mode or broadening the time range.
