---
name: obsidian-brain:detach
description: Eject obsidian-brain skills into your Obsidian vault's .claude/ folder for full customization. Use when the user wants to customize their skills, detach from the plugin, eject, or take ownership of their vault's Claude Code configuration. This is a one-way operation — once detached, the vault is fully self-contained and independent.
---

# Detach

Copies the obsidian-brain plugin into the vault's `.claude/` folder so the user owns everything. After detaching, the vault is fully self-contained — no dependency on the cezaar marketplace plugin. Updates from cezaar will no longer apply, which is intentional and fine.

This is a one-way door. There is no "reattach."

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

**If mode is already `"detached"`,** stop and tell the user:

> Your vault is already detached. Skills live in `<vault_path>/.claude/plugins/obsidian-brain/skills/` — you can edit them directly.

Do not proceed if already detached.

Confirm the vault directory exists on disk. If it doesn't, stop and tell the user the configured vault path doesn't exist.

## Step 2: Explain

Tell the user what detaching means. Use language like this (adapt naturally, don't read it verbatim):

> Detaching will copy all obsidian-brain skills into your vault at `<vault>/.claude/plugins/obsidian-brain/`. After this:
>
> - Your vault becomes fully self-contained — it carries its own Claude Code skills.
> - You can edit, delete, or add skills freely in that folder.
> - You will no longer receive updates from the cezaar obsidian-brain plugin.
> - This is intentional. The skills are yours to customize.
>
> This is a one-way operation. There is no undo.

## Step 3: Confirm

Ask the user to confirm before proceeding. Something like:

> Do you want to proceed with detaching? (yes/no)

**Wait for explicit confirmation.** Do not proceed on ambiguous answers. If the user says no or anything other than a clear yes, stop and tell them nothing was changed.

## Step 4: Copy Skills into Vault

The plugin source lives alongside this skill file. To find it, start from this skill's own location and navigate up to the plugin root. The plugin root is the directory containing `.claude-plugin/plugin.json` and the `skills/` folder.

The plugin root is at: `plugins/obsidian-brain/` in the cezaar repo (two levels up from this skill file's directory).

Create the following structure inside the vault:

```
<vault>/.claude/plugins/obsidian-brain/
├── .claude-plugin/
│   └── plugin.json
└── skills/
    └── (all skills except init-vault and detach)
```

### 4a: Determine the plugin source path

Use this skill's file path to find the plugin root. This skill lives at:

```
<plugin-root>/skills/detach/SKILL.md
```

So the plugin root is two directories up from this file. Resolve that to an absolute path.

### 4b: Create the destination directory

```bash
mkdir -p "<vault>/.claude/plugins/obsidian-brain/.claude-plugin"
mkdir -p "<vault>/.claude/plugins/obsidian-brain/skills"
```

### 4c: Write plugin.json

Create `<vault>/.claude/plugins/obsidian-brain/.claude-plugin/plugin.json` with this content:

```json
{
  "name": "obsidian-brain",
  "description": "Detached copy of obsidian-brain — local to this vault. Edit skills freely.",
  "version": "1.0.0",
  "author": {
    "name": "Cesar Avitia"
  },
  "repository": "https://github.com/ImCesar/cezaar",
  "keywords": ["obsidian", "productivity", "capture", "journal", "review", "second-brain"]
}
```

### 4d: Copy skills (excluding init-vault and detach)

List the skill directories in the plugin source:

```bash
ls "<plugin-root>/skills/"
```

For each skill directory that is NOT `init-vault` and NOT `detach`, copy the entire directory recursively into the vault:

```bash
cp -R "<plugin-root>/skills/<skill-name>" "<vault>/.claude/plugins/obsidian-brain/skills/"
```

This copies all SKILL.md files and all reference files. The expected result (assuming all skills exist):

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

The exact contents depend on what skills exist at the time of detaching. Copy whatever is there, minus init-vault and detach.

### 4e: Verify the copy

List the copied skills to confirm:

```bash
find "<vault>/.claude/plugins/obsidian-brain/skills" -type f | sort
```

Make sure at least the core skills (capture, triage, daily, journal, reflect, wins) are present. If the copy looks incomplete, warn the user but continue.

## Step 5: Update Config

Update `~/.config/obsidian-brain/config.json` to set the mode to detached. Read the current config, change `mode` to `"detached"`, and write it back:

```bash
cat ~/.config/obsidian-brain/config.json
```

Update the JSON so that `mode` is `"detached"` and write it back. Preserve all other fields (especially `vault_path`).

```bash
# Example using jq if available, otherwise use python or write directly
cat ~/.config/obsidian-brain/config.json | jq '.mode = "detached"' > /tmp/obsidian-brain-config.json && mv /tmp/obsidian-brain-config.json ~/.config/obsidian-brain/config.json
```

If jq is not available, use python3:

```bash
python3 -c "
import json
with open('$HOME/.config/obsidian-brain/config.json', 'r') as f:
    config = json.load(f)
config['mode'] = 'detached'
with open('$HOME/.config/obsidian-brain/config.json', 'w') as f:
    json.dump(config, f, indent=2)
    f.write('\n')
"
```

## Step 6: Confirmation

Tell the user detaching is complete. Include:

1. Where the skills now live: `<vault>/.claude/plugins/obsidian-brain/skills/`
2. They can open any SKILL.md and edit it to change behavior.
3. They can add new skills by creating new folders with a SKILL.md.
4. They can safely uninstall the obsidian-brain plugin from cezaar if they want — the vault is fully independent.
5. The config has been updated to `mode: "detached"` so other skills know not to look at the marketplace plugin.

Keep the message concise and practical. The user should feel confident they own their setup now.
