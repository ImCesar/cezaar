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
