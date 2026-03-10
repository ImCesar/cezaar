---
name: obsidian-brain:init-vault
description: Bootstrap or initialize an Obsidian vault with the obsidian-brain structure. Use when the user wants to set up a new second brain, create an Obsidian vault, initialize obsidian-brain, or says anything about getting started with capturing ideas, todos, or journaling in Obsidian. Also triggers when the user runs any obsidian-brain skill and no vault is configured yet.
---

# Init Vault

Set up an Obsidian vault with the obsidian-brain folder structure, templates, and config. This skill walks the user through vault detection, mode selection, scaffolding, and configuration.

## Overview

The workflow has five steps:

1. Detect or create a vault
2. Choose attached vs detached mode
3. Scaffold the directory structure and copy templates
4. Write the config file
5. Confirm and orient the user

Each step is interactive — present options, wait for the user's choice, then proceed.

## Step 1: Vault Detection

Search for existing Obsidian vaults by looking for `.obsidian/` directories in common locations:

```bash
find ~/Documents ~/Library/Mobile\ Documents ~/ -maxdepth 3 -name ".obsidian" -type d 2>/dev/null
```

Present what you find as a numbered list. Always include two extra options at the end:

- **Create new** — ask for a name, create at `~/Documents/<name>/`
- **Specify path** — let the user type or paste an absolute path

Example output to the user:

> I found these Obsidian vaults:
> 1. ~/Documents/MyVault
> 2. ~/Documents/Work
> 3. Create a new vault
> 4. Specify a path
>
> Which one should I set up with obsidian-brain?

If no vaults are found, skip straight to asking whether to create a new one or specify a path.

If the user picks "create new," create the directory and run `mkdir -p <path>/.obsidian` so Obsidian recognizes it as a vault on first open.

## Step 2: Mode Selection

Ask the user to choose between **attached** and **detached** mode:

> How would you like to use obsidian-brain with this vault?
>
> 1. **Attached** — Skills live in the cezaar plugin repo. Claude reads/writes your vault, but the skill files stay external. Best if you want automatic updates when the plugin improves.
> 2. **Detached** — Skills are copied into your vault's `.obsidian-brain/` folder. The vault becomes self-contained and works without the plugin repo. Best if you want to version-control everything together or share the vault.

Default to attached if the user doesn't express a preference.

## Step 3: Scaffold the Vault

This is where the vault gets its structure. Read `references/vault-structure.md` now — it contains the complete directory tree, folder purposes, and frontmatter schema that define what you're creating.

### Create directories

Create every folder from the directory tree in vault-structure.md:

```bash
mkdir -p \
  "$VAULT/inbox/ideas" \
  "$VAULT/inbox/todos" \
  "$VAULT/inbox/questions" \
  "$VAULT/inbox/research" \
  "$VAULT/projects" \
  "$VAULT/knowledge" \
  "$VAULT/journal/daily" \
  "$VAULT/journal/weekly" \
  "$VAULT/reviews/summaries" \
  "$VAULT/reviews/formal" \
  "$VAULT/templates" \
  "$VAULT/archive"
```

### Copy templates

Copy all files from `references/templates/` into the vault's `templates/` folder:

```bash
cp references/templates/*.md "$VAULT/templates/"
```

Use the actual resolved path to the skill's `references/templates/` directory — it lives alongside this SKILL.md file within the plugin.

After copying, replace the `{{date}}` placeholder in each template with Obsidian's native template date syntax if the user's Obsidian is configured for it, or leave `{{date}}` as-is (it works with both the Templater plugin and Obsidian's core Templates plugin).

## Step 4: Write Config

Create the obsidian-brain config file so other skills know where the vault is:

```bash
mkdir -p ~/.config/obsidian-brain
```

Write `~/.config/obsidian-brain/config.json`:

```json
{
  "vault_path": "/absolute/path/to/vault",
  "mode": "attached"
}
```

Use the actual vault path and the mode the user chose. Always use an absolute path (expand `~`).

### If detached mode was chosen

After writing the config, invoke the `obsidian-brain:detach` skill to copy skill files into the vault. Tell the user you're doing this and why:

> Since you chose detached mode, I'll copy the obsidian-brain skills into your vault so it's self-contained.

Then invoke `obsidian-brain:detach`.

## Step 5: Confirmation

Tell the user what was set up. Be specific — list what was created so they can verify:

> Your vault is ready at `<path>`. Here's what I set up:
>
> - **Folders:** inbox (ideas, todos, questions, research), projects, knowledge, journal (daily, weekly), reviews (summaries, formal), templates, archive
> - **Templates:** 8 templates copied to `templates/` — for todos, ideas, questions, research, daily/weekly journals, and reviews
> - **Config:** `~/.config/obsidian-brain/config.json` pointing to your vault
> - **Mode:** attached/detached
>
> You can start capturing right away:
> - "Capture a todo" — drops a new item in `inbox/todos/`
> - "Write today's journal" — creates a daily entry in `journal/daily/`
> - "I have an idea" — captures it in `inbox/ideas/`

## Error Handling

- **Vault path doesn't exist** — offer to create it. Don't silently fail.
- **Config already exists** — show the current config and ask if the user wants to overwrite or update it. An existing config usually means init already ran, so confirm before re-scaffolding.
- **Templates directory already has files** — ask before overwriting. The user may have customized templates.
- **Permission errors** — report the exact error and suggest the user check directory permissions.

## Reading Other Skills' Config

Other obsidian-brain skills should check for `~/.config/obsidian-brain/config.json` before doing anything. If the config is missing, they should tell the user to run init-vault first. This skill is the entry point for the entire plugin.
