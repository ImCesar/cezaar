---
name: obsidian-brain:journal
description: Write a journal entry in your Obsidian vault — daily stream of consciousness or weekly reflection. Use when the user wants to journal, log their day, reflect on the week, write about what happened, or record thoughts that aren't actionable captures. Triggers on phrases like "journal", "log this", "today I...", "this week was...", "I want to write about...", or when the user shares personal reflections.
---

# Journal

Write daily or weekly journal entries to the Obsidian vault. The user's words are the entry — don't over-structure, don't sanitize, don't turn their reflection into a task list. Just write it down.

## Step 1: Config Check

Read the obsidian-brain config to find the vault:

```bash
cat ~/.config/obsidian-brain/config.json
```

You need two values from the config:
- `vault_path` — absolute path to the Obsidian vault
- `mode` — either `"attached"` or `"detached"`

**If the config file doesn't exist or is invalid,** stop and tell the user:

> It looks like obsidian-brain isn't set up yet. Run the `obsidian-brain:init-vault` skill first to configure your vault.

Do not proceed without a valid config.

## Step 2: Detect Daily vs Weekly

Determine whether this is a daily or weekly journal entry.

**Use weekly if any of these are true:**
- The user explicitly mentions "week", "weekly", "this week", "last week"
- The user is doing a reflective summary that covers multiple days
- The user says "reflect", "reflection", "review the week", "week in review"

**Default to daily for everything else.** When in doubt, it's daily — most journal entries are stream-of-consciousness about the current day.

## Step 3: Daily Flow

### File path

```
<vault_path>/journal/daily/YYYY-MM-DD.md
```

Use today's date.

### If the file already exists

The user is adding another entry to the same day. Append a new timestamped entry under the `## Entries` section.

Read the existing file first, then append:

```markdown
### HH:MM

<user's entry>
```

Where `HH:MM` is the current time in 24-hour format. Write below any existing entries — don't overwrite what's already there.

### If a daily-log file exists

If the file exists and has `type: daily-log` in frontmatter (created by the daily skill), append the journal entry under the `## Journal` section at the bottom instead of `## Entries`. If the `## Journal` section doesn't exist, create it at the end of the file.

```markdown
## Journal

### HH:MM

<user's entry>
```

This preserves the structured daily log sections while allowing freeform journaling in the same file.

### If the file doesn't exist

Create it from the `daily-journal.md` template.

**If mode is `"attached"`:**

Read the template from the plugin's init-vault references:

```
plugins/obsidian-brain/skills/init-vault/references/templates/daily-journal.md
```

**If mode is `"detached"`:**

Read the template from the vault:

```
<vault_path>/templates/daily-journal.md
```

**If the template is missing,** fall back to this minimal structure:

```markdown
---
type: journal
status: captured
created: "YYYY-MM-DD"
tags:
  - daily
parent: ""
---

# YYYY-MM-DD

## Entries

```

Replace `{{date}}` placeholders in the template with today's date (`YYYY-MM-DD`).

Then write the first entry under `## Entries`:

```markdown
## Entries

### HH:MM

<user's entry>
```

### Write the file

For new files:

```bash
mkdir -p "$VAULT/journal/daily"
cat > "$VAULT/journal/daily/YYYY-MM-DD.md" << 'TEMPLATE'
<populated template content>
TEMPLATE
```

For appending to existing files, read the current content, add the new entry at the end, and write the full file back. Don't clobber existing entries.

## Step 4: Weekly Flow

### File path

```
<vault_path>/journal/weekly/YYYY-WNN.md
```

Where `NN` is the ISO week number, zero-padded. For example: `2026-W10.md` for the 10th week of 2026.

To get the current ISO week:

```bash
date +%G-W%V
```

### If the file already exists

Read the existing file. Append the user's content in the appropriate section if they've addressed a specific area (what happened, what I learned, what's next). If their input is general, append it at the end of the file as a timestamped entry:

```markdown
### HH:MM

<user's entry>
```

### If the file doesn't exist

Create it from the `weekly-journal.md` template.

**If mode is `"attached"`:**

```
plugins/obsidian-brain/skills/init-vault/references/templates/weekly-journal.md
```

**If mode is `"detached"`:**

```
<vault_path>/templates/weekly-journal.md
```

**If the template is missing,** fall back to:

```markdown
---
type: journal
status: captured
created: "YYYY-MM-DD"
tags:
  - weekly
parent: ""
---

# Week of YYYY-MM-DD

## What happened this week


## What I learned


## What's next

```

Replace `{{date}}` placeholders with today's date.

### Prompting for weekly sections

If the user's input doesn't cover the template sections (what happened, what I learned, what's next), **gently prompt them** after writing what they gave you:

> I've started your weekly entry. If you'd like to fill in more, the template has sections for:
> - **What happened this week**
> - **What I learned**
> - **What's next**
>
> Just tell me and I'll add to the entry.

Don't force structure. If the user just wants to dump a paragraph about their week, write the paragraph and offer the sections as optional follow-up. Don't nag — one prompt is enough.

### Write the file

```bash
mkdir -p "$VAULT/journal/weekly"
cat > "$VAULT/journal/weekly/YYYY-WNN.md" << 'TEMPLATE'
<populated template content>
TEMPLATE
```

For appending, same approach as daily — read, append, write back.

## Step 5: Writing the Entry

The user's input IS the entry. Follow these principles:

- **Don't rewrite their words.** If they said "today was rough, deployment broke twice and I spent 3 hours debugging IAM roles", write exactly that. Don't turn it into "Encountered deployment challenges and investigated IAM configuration issues."
- **Clean up formatting, not content.** Fix obvious typos if glaring, add line breaks for readability, but preserve their voice and tone.
- **Don't add sections they didn't ask for.** No "## Mood" or "## Gratitude" headers unless the user specifically structured their entry that way.
- **Timestamp every entry.** Use `### HH:MM` (24-hour format) before each entry block. Get the current time:

```bash
date +%H:%M
```

- **Multiple paragraphs are fine.** If the user writes a lot, keep it as-is. Don't summarize.
- **Short entries are fine too.** "Good day. Shipped the feature." is a complete journal entry. Don't pad it.

## Step 6: Confirmation

Tell the user the entry was written. Be brief:

> Journal entry written to `journal/daily/2026-03-09.md`

Or for a new day's first entry:

> Started today's journal at `journal/daily/2026-03-09.md`

For weekly:

> Weekly entry written to `journal/weekly/2026-W10.md`

If you appended to an existing file, mention it:

> Added to today's journal at `journal/daily/2026-03-09.md` (3rd entry today)

That's it. Don't recap what they wrote — they just wrote it, they know what it says.

## Error Handling

- **Vault directory doesn't exist** — the vault_path from config points somewhere that's gone. Tell the user the path is invalid and suggest re-running `obsidian-brain:init-vault`.
- **Journal subfolder missing** — create it silently with `mkdir -p` and continue. Don't bother the user about missing folders.
- **Write permission error** — report the exact error and path. The user needs to fix permissions.
- **Template missing** — use the fallback minimal template defined above. Don't fail over a missing template.
