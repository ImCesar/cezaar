# cezaar Marketplace Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Create a personal Claude Code plugin marketplace at `ImCesar/cezaar` that hosts the `cesarpowers` plugin and re-exports `superpowers` and `review-hats`.

**Architecture:** Standard Claude Code marketplace repo on GitHub. Contains one local plugin (`cesarpowers` with the `dev-workflow` skill) and two URL-sourced external plugins (`superpowers`, `review-hats`). Replaces the local `~/.claude/skills/cesarpowers/` directory.

**Tech Stack:** Claude Code plugin system, Git, GitHub CLI (`gh`)

---

### Task 1: Initialize Git Repo

**Files:**
- Create: `cezaar/.gitignore`

**Step 1: Initialize git in the cezaar directory**

Run: `cd /Users/cesar/repos/cezaar && git init`

**Step 2: Create .gitignore**

```
.DS_Store
```

**Step 3: Commit**

```bash
git add .gitignore
git commit -m "Initial commit"
```

---

### Task 2: Create Marketplace Metadata

**Files:**
- Create: `.claude-plugin/marketplace.json`

**Step 1: Create marketplace.json**

```json
{
  "name": "cezaar",
  "owner": {
    "name": "Cesar Avitia"
  },
  "metadata": {
    "description": "Cesar's personal Claude Code plugin marketplace"
  },
  "plugins": [
    {
      "name": "cesarpowers",
      "source": "./plugins/cesarpowers",
      "description": "Cesar's development workflow and personal Claude Code skills.",
      "version": "1.0.0",
      "category": "development",
      "author": {
        "name": "Cesar Avitia"
      },
      "repository": "https://github.com/ImCesar/cezaar",
      "keywords": ["workflow", "development", "skills"]
    },
    {
      "name": "superpowers",
      "description": "Core skills library for Claude Code: TDD, debugging, collaboration patterns, and proven techniques.",
      "category": "development",
      "source": {
        "source": "url",
        "url": "https://github.com/obra/superpowers.git"
      },
      "homepage": "https://github.com/obra/superpowers.git"
    },
    {
      "name": "review-hats",
      "description": "Multi-perspective code review with specialized AI agents inspired by Thinking Hats.",
      "category": "development",
      "source": {
        "source": "url",
        "url": "https://github.com/ImCesar/review-hats.git"
      },
      "homepage": "https://github.com/ImCesar/review-hats.git"
    }
  ]
}
```

**Step 2: Commit**

```bash
git add .claude-plugin/marketplace.json
git commit -m "Add marketplace metadata with cesarpowers, superpowers, and review-hats"
```

---

### Task 3: Create cesarpowers Plugin

**Files:**
- Create: `plugins/cesarpowers/.claude-plugin/plugin.json`
- Create: `plugins/cesarpowers/README.md`
- Create: `plugins/cesarpowers/skills/dev-workflow/SKILL.md`

**Step 1: Create plugin.json**

```json
{
  "name": "cesarpowers",
  "description": "Cesar's development workflow and personal Claude Code skills.",
  "version": "1.0.0",
  "author": {
    "name": "Cesar Avitia"
  },
  "repository": "https://github.com/ImCesar/cezaar",
  "keywords": ["workflow", "development", "skills"]
}
```

**Step 2: Create plugin README.md**

```markdown
# cesarpowers

Personal Claude Code plugin by Cesar Avitia.

## Skills

### dev-workflow

Enforces the 4-phase development workflow:

1. **Gather Context** — `systematic-debugging` (bugs) or `brainstorming` (features)
2. **Plan** — `writing-plans`
3. **Implement** — `subagent-driven-development`
4. **Review** — `review-hats:review`

### Dependencies

This plugin relies on skills from:

- [superpowers](https://github.com/obra/superpowers) — brainstorming, debugging, TDD, planning, subagent-driven-development
- [review-hats](https://github.com/ImCesar/review-hats) — multi-perspective code review

Both are available from this marketplace.
```

**Step 3: Create SKILL.md**

Copy the content from `/Users/cesar/.claude/skills/cesarpowers/SKILL.md` with the `name` field updated to `dev-workflow`.

```markdown
---
name: dev-workflow
description: Reset and enforce the 4-phase development workflow. Use when Claude has drifted from the protocol or when starting a complex task. Auto-triggers on feature requests, bug reports, refactors, or any task involving multi-file changes.
---

# 4-Phase Development Workflow

You MUST follow all 4 phases in order for any non-trivial task. Do NOT skip phases. Do NOT write code before Phase 3.

## Phase 1: Gather Context

**Goal:** Fully understand the problem before proposing solutions.

**Routing:**
- Bug / issue / failure / unexpected behavior → `superpowers:systematic-debugging`
- Feature / change / improvement / new capability → `superpowers:brainstorming`

**Stay in Phase 1 until you can articulate:**
- What the user wants
- What exists today
- What constraints apply

**Artifact:** Design doc or debug analysis from the invoked skill.

## Phase 2: Plan

- Invoke `superpowers:writing-plans`
- Write plan to `docs/plans/YYYY-MM-DD-<topic>-plan.md`
- Present to user for approval
- If user said "auto": skip the gate, proceed immediately
- Plan MUST exist as a file before Phase 3 begins
- Verify which plan with the user before starting execution

## Phase 3: Implement

- Invoke `superpowers:subagent-driven-development`
- Execute from the plan document
- Fresh subagent per task with spec and code quality reviews
- Do NOT deviate from the plan without returning to Phase 2

## Phase 4: Review

- Invoke `review-hats:review` on all changes from Phase 3
- Present findings to user
- If critical issues found → fix and re-review (do not skip back to user without clean review)

## Auto Mode

When the user says "auto", "just go", "run through it", or similar:
- Complete Phase 1 interactively (user input is still needed)
- Run Phases 2-4 without stopping for approval
- Present the final review results when done
```

**Step 4: Commit**

```bash
git add plugins/cesarpowers/
git commit -m "Add cesarpowers plugin with dev-workflow skill"
```

---

### Task 4: Create Marketplace README

**Files:**
- Create: `README.md`

**Step 1: Create README.md**

```markdown
# cezaar

Cesar's personal Claude Code plugin marketplace.

## Plugins

| Plugin | Description |
|--------|-------------|
| **cesarpowers** | Development workflow and personal skills |
| **[superpowers](https://github.com/obra/superpowers)** | TDD, debugging, brainstorming, planning |
| **[review-hats](https://github.com/ImCesar/review-hats)** | Multi-perspective code review |

## Installation

```bash
claude plugins marketplace add ImCesar/cezaar
claude plugins install cesarpowers
claude plugins install superpowers
claude plugins install review-hats
```
```

**Step 2: Commit**

```bash
git add README.md
git commit -m "Add marketplace README"
```

---

### Task 5: Create GitHub Repo and Push

**Step 1: Create the GitHub repo**

Run: `gh repo create ImCesar/cezaar --public --source=/Users/cesar/repos/cezaar --push`

**Step 2: Verify the repo exists**

Run: `gh repo view ImCesar/cezaar`

---

### Task 6: Remove Local Skill

**Step 1: Remove the old local cesarpowers skill directory**

Run: `rm -rf /Users/cesar/.claude/skills/cesarpowers`

**Step 2: Verify it's gone**

Run: `ls /Users/cesar/.claude/skills/`

Should no longer contain `cesarpowers/`.

---

### Task 7: Register and Install from Marketplace

**Step 1: Add the cezaar marketplace**

Run: `claude plugins marketplace add ImCesar/cezaar`

**Step 2: Install cesarpowers from cezaar**

Run: `claude plugins install cesarpowers@cezaar`

**Step 3: Verify installation**

Check that `cesarpowers@cezaar` appears in the installed plugins list.
