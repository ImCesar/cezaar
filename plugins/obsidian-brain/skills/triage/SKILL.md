---
name: triage
description: Process and graduate items from your Obsidian vault inbox. Use when the user wants to review their captures, process their inbox, organize todos into projects, graduate ideas into epics, or move items out of the inbox. Triggers on phrases like "triage my inbox", "what's in my inbox", "process captures", "organize my todos", or "review my ideas".
---

# Triage

Walk through the inbox, one item at a time. For each item: graduate it to its proper home, archive it, or skip it. This is how raw captures become organized projects and knowledge.

## Step 1: Config Check

Read the obsidian-brain config to find the vault:

```bash
cat ~/.config/obsidian-brain/config.json
```

You need:
- `vault_path` — absolute path to the Obsidian vault
- `mode` — either `"attached"` or `"detached"`

**If the config file doesn't exist or is invalid,** stop and tell the user:

> It looks like obsidian-brain isn't set up yet. Run the `init-vault` skill first to configure your vault.

Do not proceed without a valid config.

## Step 2: Inbox Scan

List everything in the inbox subdirectories:

```bash
find "$VAULT/inbox" -name "*.md" -type f | sort
```

Group the results by type based on their parent folder:

| Folder | Type |
|--------|------|
| `inbox/ideas/` | idea |
| `inbox/todos/` | todo |
| `inbox/questions/` | question |
| `inbox/research/` | research |

Present a summary to the user:

> **Inbox summary:**
> - 3 todos
> - 2 ideas
> - 1 question
> - 0 research
>
> 6 items total. Ready to triage?

If the inbox is empty, tell the user and stop:

> Your inbox is empty — nothing to triage. Use the `capture` skill to add items first.

Ask the user if they want to triage all types or focus on a specific type (e.g., "just todos"). Filter accordingly.

## Step 3: Walk-Through

Present items one at a time. For each item:

1. **Read the file** — parse frontmatter and body.
2. **Show a preview:**

   > **[2/6] Fix the login bug**
   > Type: todo | Created: 2026-03-05
   >
   > Users are unable to log in after the latest deploy. Need to investigate the auth flow and identify the root cause...

   Show the item number out of total, the title (from filename, cleaned up), type, created date from frontmatter, and the first 2-3 lines of the body as a snippet.

3. **Ask for action:**

   > Graduate, archive, or skip?

   - **Graduate** — move to its permanent home (Step 4)
   - **Archive** — move to `archive/` (Step 5)
   - **Skip** — leave in inbox, move to next item

Accept shorthand: `g`, `a`, `s` or the full word.

### Batch shortcuts

If the user says "skip the rest" or "archive all remaining," respect that without prompting for each remaining item. Apply the action to all unprocessed items.

## Step 4: Graduation

When the user chooses to graduate an item, read `references/graduation-rules.md` for the detailed routing logic. That file has the complete rules per type — follow them exactly.

**Quick reference for the conversation flow:**

### Todos

Auto-suggest: `projects/`

Ask: standalone file at `projects/` root, or inside an epic folder?

If epic, list existing epic folders under `projects/`:

```bash
find "$VAULT/projects" -mindepth 1 -maxdepth 1 -type d | sort
```

Let the user pick an existing epic or create a new one.

### Ideas

Auto-suggest: `projects/` as a project.

This is a type change — the idea becomes a project. Ask: standalone project or epic?

If epic, trigger the epic creation flow (folder + summary note + optional child todos). The full flow is in graduation-rules.md.

### Questions

Auto-suggest: `knowledge/`

Check if the `## Answer` section has content. If empty, ask the user to provide an answer before graduating. If they can't answer yet, suggest skipping instead.

### Research

Ask the user: is this research done with documented findings, or did it turn into something actionable?

- Findings → `knowledge/`
- Actionable → `projects/` (follows the idea-to-project flow)

## Step 5: File Operations

Every graduation or archive involves two operations: moving the file and updating its frontmatter.

### Moving files

Use `mv` to relocate the file:

```bash
mv "$VAULT/inbox/<type>/<filename>" "$VAULT/<destination>/<filename>"
```

For epics, create the folder first:

```bash
mkdir -p "$VAULT/projects/<epic-name>"
mv "$VAULT/inbox/<type>/<filename>" "$VAULT/projects/<epic-name>/<epic-name>.md"
```

### Updating frontmatter

After moving, update the frontmatter fields in place. Read the file, modify the YAML block, and write it back. The specific field changes depend on the graduation path — see the Frontmatter Mutation Summary table in `references/graduation-rules.md`.

Common patterns:

- **Status update:** `status: captured` → `status: backlog` (or `answered`, `documented`, `archived`)
- **Type change:** `type: idea` → `type: project` (only for idea/research graduation to projects)
- **Parent assignment:** `parent: ""` → `parent: <epic-name>` (when assigned to an epic folder)

Use `sed` for simple field replacements:

```bash
sed -i '' 's/^status: captured/status: backlog/' "$FILE"
sed -i '' 's/^type: idea/type: project/' "$FILE"
sed -i '' 's/^parent: ""/parent: "<epic-name>"/' "$FILE"
```

### Creating child todos

When spawning child todos for an epic, create each one as a new file in the epic folder. Use today's date and a slugified title. See graduation-rules.md for the template.

### Archive

```bash
mv "$VAULT/inbox/<type>/<filename>" "$VAULT/archive/<filename>"
sed -i '' 's/^status: .*/status: archived/' "$VAULT/archive/<filename>"
```

If a file with the same name exists in archive, append a suffix:

```bash
# Check and add suffix if needed
DEST="$VAULT/archive/$FILENAME"
if [ -f "$DEST" ]; then
  BASE="${FILENAME%.md}"
  DEST="$VAULT/archive/${BASE}-2.md"
fi
mv "$SOURCE" "$DEST"
```

## Step 6: Summary

After processing all items (or when the user says they're done), show a summary:

> **Triage complete:**
> - Graduated: 3 items
>   - `fix-the-login-bug.md` → `projects/auth-overhaul/`
>   - `websockets-idea.md` → `projects/websockets-migration.md`
>   - `oauth2-question.md` → `knowledge/`
> - Archived: 1 item
>   - `old-deploy-script.md` → `archive/`
> - Skipped: 2 items (still in inbox)

Show file names and destinations so the user knows where everything went.

## Error Handling

- **Vault directory doesn't exist** — the vault_path from config points somewhere invalid. Tell the user and suggest re-running `init-vault`.
- **Inbox folders missing** — if an inbox subfolder doesn't exist, skip it silently. Don't create it here (that's init-vault's job).
- **File read error** — report the filename and error, skip to the next item. Don't halt the whole triage.
- **Move/write permission error** — report the exact error and path. The user needs to fix permissions.
- **Destination conflict** — if a file with the same name exists at the destination, append a numeric suffix. Don't overwrite.
- **Malformed frontmatter** — if a file doesn't have valid YAML frontmatter, show a warning and let the user decide: fix it, skip it, or archive it as-is.
