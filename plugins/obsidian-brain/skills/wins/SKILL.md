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
