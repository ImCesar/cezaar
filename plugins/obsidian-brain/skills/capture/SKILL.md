---
name: obsidian-brain:capture
description: Capture ideas, todos, questions, research spikes, or anything else into your Obsidian vault. This is the DEFAULT skill when the user's intent is ambiguous — if someone says something that sounds like it should be saved, remembered, tracked, or looked into later, use this skill. Triggers on phrases like "I need to...", "remind me to...", "what if we...", "look into...", "I was thinking about...", or any freeform thought that should be preserved.
---

# Capture

The default obsidian-brain skill. Takes whatever the user said, classifies it, and writes it to the vault inbox. Speed matters — get the thought down first, refine later.

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

## Step 2: Classify the Input

Analyze the user's input and assign one of these types:

| Type | Destination folder |
|------|-------------------|
| `todo` | `inbox/todos/` |
| `idea` | `inbox/ideas/` |
| `question` | `inbox/questions/` |
| `research` | `inbox/research/` |

**Quick classification:** Most inputs are obvious from signal words and sentence structure. Use these shortcuts:

- Imperative verb ("fix", "build", "deploy") → **todo**
- "What if" / "maybe" / "I was thinking" → **idea**
- Starts with how/why/what/is/can → **question**
- "Research" / "look into" / "explore options" → **research**

**Ambiguous input:** If the type isn't immediately clear, read `references/classification.md` for detailed rules, signal patterns, and edge cases. That file has the full decision tree.

**Always tell the user what type you chose.** If the classification was a judgment call, say so — the user can ask you to reclassify.

## Step 3: Load the Template

Fetch the right template based on mode and type.

**If mode is `"attached"`:**

Read the template from the plugin's init-vault references:

```
plugins/obsidian-brain/skills/init-vault/references/templates/capture-<type>.md
```

Use the path relative to this skill's location in the plugin repo. The templates live alongside the init-vault skill, not the capture skill.

**If mode is `"detached"`:**

Read the template from the vault itself:

```
<vault_path>/templates/capture-<type>.md
```

In detached mode, templates were copied into the vault during init, so they live there.

**If the template file doesn't exist,** fall back to a minimal frontmatter block:

```yaml
---
type: <type>
status: captured
created: "<YYYY-MM-DD>"
tags: []
parent: ""
---
```

Don't fail just because a template is missing — always capture.

## Step 4: Generate the File

### Filename

Format: `YYYY-MM-DD-slugified-title.md`

Create the slug from the user's input:
- Extract the core subject (drop filler words like "I need to", "remind me to", "what if we")
- Lowercase, replace spaces with hyphens, strip special characters
- Keep it under 60 characters — truncate if needed
- Use today's date

Examples:
- "Fix the login bug" → `2026-03-09-fix-the-login-bug.md`
- "What if we used WebSockets instead of polling?" → `2026-03-09-websockets-instead-of-polling.md`
- "How does OAuth2 work?" → `2026-03-09-how-does-oauth2-work.md`
- "Research state management options" → `2026-03-09-state-management-options.md`

### Fill in the template

Don't just write an empty template — populate it with content from the user's input:

1. **Frontmatter:**
   - Set `created` to today's date (`YYYY-MM-DD`)
   - Set `type` and `status: captured`
   - Infer `tags` from the content. Pull 1-3 relevant tags from the subject matter. Use lowercase, hyphenated tags (e.g., `auth`, `frontend`, `performance`, `ci-cd`). If nothing stands out, leave the array empty.
   - Leave `parent` empty (`""`) — triage handles project assignment later.

2. **Body sections:** Fill in each template section with meaningful content derived from what the user said. Expand terse input into useful notes, but don't hallucinate details the user didn't mention.

   For a **todo** ("Fix the login bug"):
   ```markdown
   ## Description
   Fix the login bug — users are unable to log in.

   ## Acceptance Criteria
   - [ ] Identify root cause of the login failure
   - [ ] Implement fix
   - [ ] Verify login works end to end
   ```

   For an **idea** ("What if we used WebSockets instead of polling?"):
   ```markdown
   ## Description
   Replace the current polling mechanism with WebSockets for real-time updates.

   ## Why This Matters
   Polling adds unnecessary latency and server load. WebSockets would give instant updates.

   ## Possible Approaches
   - Evaluate WebSocket libraries compatible with the current stack
   - Prototype a single endpoint with WebSocket support
   - Compare resource usage between polling and WebSocket approaches
   ```

   For a **question** ("How does OAuth2 work?"):
   ```markdown
   ## The Question
   How does OAuth2 work?

   ## Context
   Understanding OAuth2 for evaluating authentication approaches.

   ## Answer

   ```

   For **research** ("Research state management options"):
   ```markdown
   ## Topic
   State management options for the application.

   ## Why
   Need to choose a state management solution — evaluate what's available and what fits.

   ## Key Questions
   - What are the leading options?
   - How do they compare in complexity, performance, and ecosystem support?
   - What does the team already have experience with?

   ## Findings

   ```

### Write the file

Write the populated file to the correct inbox subfolder:

```bash
cat > "$VAULT/inbox/<type_plural>/<filename>" << 'TEMPLATE'
<populated template content>
TEMPLATE
```

Where `<type_plural>` maps as:
- `todo` → `todos`
- `idea` → `ideas`
- `question` → `questions`
- `research` → `research`

## Step 5: Confirmation

Tell the user what you captured. Be concise but specific:

> Captured as **todo** → `inbox/todos/2026-03-09-fix-the-login-bug.md`
>
> Tags: `bug`, `auth`

That's it. Don't over-explain. The user can open the file in Obsidian to see the full content.

If the classification was a judgment call, add a one-liner:

> Captured as **research** → `inbox/research/2026-03-09-login-bug-investigation.md`
>
> I went with research since you said "look into" — let me know if this should be a todo instead.

## Error Handling

- **Vault directory doesn't exist** — the vault_path from config points somewhere that's gone. Tell the user the path is invalid and suggest re-running `obsidian-brain:init-vault`.
- **Inbox subfolder missing** — create it silently with `mkdir -p` and continue. Don't bother the user about missing folders.
- **File already exists** — append a short numeric suffix: `2026-03-09-fix-the-login-bug-2.md`. Don't overwrite.
- **Write permission error** — report the exact error and path. The user needs to fix permissions.

## Multiple Captures

If the user gives you several things at once ("Capture these: fix the login bug, research OAuth options, and what if we added SSO?"), create one file per item. Classify each independently. Report all of them in the confirmation:

> Captured 3 items:
> - **todo** → `inbox/todos/2026-03-09-fix-the-login-bug.md`
> - **research** → `inbox/research/2026-03-09-oauth-options.md`
> - **idea** → `inbox/ideas/2026-03-09-add-sso.md`
