---
name: dev-workflow
description: Reset and enforce the 4-phase development workflow. Use when Claude has drifted from the protocol or when starting a complex task. Auto-triggers on feature requests, bug reports, refactors, or any task involving multi-file changes.
---

# 4-Phase Development Workflow

**CRITICAL: For ANY non-trivial task (multi-file changes, new features, bug fixes, refactors), follow all 4 phases in order. Do NOT skip phases. Do NOT write code before Phase 3.**

**Trivial tasks** (typo fixes, single-line changes, research questions) are exempt.

| Phase | What | Skill | Gate |
|-------|------|-------|------|
| 1. Gather Context | Understand the problem | `superpowers:systematic-debugging` (bugs) or `superpowers:brainstorming` (features) | Interactive — user answers questions |
| 2. Plan | Write implementation plan | `superpowers:writing-plans` | Blocks until user approves (unless "auto") |
| 3. Implement | Execute the plan | `superpowers:subagent-driven-development` | None |
| 4. Review | Validate the work | `review-hats:review` | None — present findings to user |

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

## Red Flags — If You Think This, STOP

| Thought | What to do instead |
|---------|--------------------|
| "This is simple, I'll just write the code" | If it touches >1 file, it's not simple. Start Phase 1. |
| "I already understand the problem" | You haven't asked the user. Start Phase 1. |
| "Let me just explore the codebase first" | That IS Phase 1. Invoke the skill. |
| "I'll plan in my head and implement" | Plans go in documents. Start Phase 2. |
| "The plan is obvious, I'll skip to code" | Write it down anyway. Phase 2. |
| "I'll review my own work as I go" | Self-review is not review. Phase 4 uses review-hats. |
| "The user seems to want this fast" | Fast ≠ skip phases. Phases prevent rework. |

## Phase Verification

Before writing ANY implementation code, confirm:
1. Context gathered via skill (Phase 1 complete)
2. Plan document exists and is approved (Phase 2 complete)
3. Executing via `superpowers:subagent-driven-development` (Phase 3)

After implementation, confirm:
4. `review-hats:review` ran on the completed work (Phase 4 complete)
