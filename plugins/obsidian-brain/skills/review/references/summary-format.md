# Summary Review Format

Reference for generating casual narrative performance reviews. Used when the user wants an informal look-back at what they accomplished.

## Structure

Narrative paragraphs — not bullet points, not tables. Write like you're talking to the person about their own work. The reader should feel like they're getting a thoughtful recap from someone who actually read everything they did.

## Sections

### Overview

A 2-3 sentence opener that sets the stage. What was the overall shape of this period? Was it heads-down building, scattered across many things, a transition period, a sprint to a deadline?

### Key Themes

The 2-4 major threads that defined the period. Each theme gets its own paragraph. Weave in specific evidence from vault notes — don't just name the theme, show it.

Use `[[wikilinks]]` to reference source notes inline. For example:

> The authentication overhaul dominated the first half of the quarter. You kicked it off with research into OAuth2 providers ([[2026-01-15-research-oauth2-options]]) and by mid-February had shipped the new login flow ([[auth-migration-project]]). The daily journals from that stretch show real momentum — almost every entry mentions auth work.

### Highlights

What went well? What should the person feel good about? Pick 3-5 concrete accomplishments and explain why they matter. This isn't a list of tasks completed — it's a narrative about impact.

Link to the evidence:

> The monitoring dashboard you built ([[monitoring-dashboard-project]]) didn't just check a box — your journal entries after launch ([[2026-02-20]]) show it caught two incidents in the first week that would have gone unnoticed.

### Growth Areas

Honest, constructive observations about patterns that could improve. Frame these as patterns you noticed, not judgments. Ground them in vault data.

> Your journals mention feeling stretched thin at least six times in February ([[2026-02-03]], [[2026-02-10]], [[2026-02-14]], [[2026-02-18]], [[2026-02-22]], [[2026-02-27]]). The capture inbox also grew significantly during that stretch — 23 items came in but only 8 got triaged. When things get busy, the system breaks down a bit. Finding a way to keep triage flowing during crunch periods would help.

## Tone

- **Conversational** — write like a thoughtful colleague, not a corporate form
- **Encouraging** — lead with what went well, be genuine about it
- **Honest** — don't dodge areas that need work, but frame them constructively
- **Specific** — vague praise is worthless; always tie back to actual vault data
- **Second person** — speak directly to the reader ("you did X", "your work on Y")

## Evidence

Every claim should trace back to vault data. Use `[[wikilinks]]` to link to:
- Journal entries (daily/weekly) that mention the topic
- Completed project notes
- Archived items that demonstrate progress
- Knowledge notes that show learning

Don't dump every reference — choose the most illustrative ones. A few well-chosen links are better than an exhaustive list.

## Length

Target 500-800 words for the full review. Enough to be substantive, short enough to read in one sitting.

- Overview: 50-75 words
- Key Themes: 150-300 words (scales with number of themes)
- Highlights: 150-200 words
- Growth Areas: 100-150 words

## Example Structure

```markdown
---
type: review
status: captured
created: "2026-03-09"
tags:
  - review
  - summary
period: "2026 Q1"
parent: ""
---

# Review: 2026 Q1

*January through March 2026*

## Overview

This quarter was defined by two big pushes — the authentication overhaul and the new monitoring stack — with a quieter stretch of maintenance work and learning in between. You shipped two significant projects, kept the capture pipeline flowing, and found time to dig into some Rust exploration on the side.

## Key Themes

### The Auth Overhaul

The authentication migration was the headline project for Q1. It started with a research spike in January ([[2026-01-15-research-oauth2-options]]) where you evaluated three OAuth2 providers. By the end of January you'd made the call to go with Auth0 ([[2026-01-28]]) and started the migration plan ([[auth-migration-project]]). February was heads-down implementation — your daily journals show auth work mentioned in 18 out of 20 working days. The new flow shipped on February 24th ([[2026-02-24]]) and the post-launch journal entries were cautiously optimistic.

### Monitoring & Observability

The second half of the quarter shifted to observability. The monitoring dashboard ([[monitoring-dashboard-project]]) went from idea to production in about three weeks. Your journal from launch day ([[2026-02-20]]) captures the relief of finally having visibility into the system. By March, you were iterating on alerts and starting to think about tracing ([[2026-03-05-research-distributed-tracing]]).

### Side Learning

Scattered throughout the quarter, you kept a thread of Rust exploration going. The knowledge notes show a steady accumulation — ownership model ([[rust-ownership-notes]]), error handling patterns ([[rust-error-handling]]), and a small CLI experiment ([[rust-cli-experiment-project]]). Not a main focus, but a consistent investment.

## Highlights

The auth migration stands out as the biggest win. It touched every part of the system and you drove it from research through launch without major incidents. The fact that you documented the decision process ([[2026-01-28]]) and kept the project note updated makes it easy to trace the whole arc.

The monitoring dashboard's value proved itself immediately — catching those two incidents in week one ([[2026-02-22]], [[2026-02-25]]) justified the investment before you even finished the alerting layer.

You also maintained a steady capture habit throughout the quarter. Your inbox stayed manageable and triage happened regularly, which kept the vault useful rather than just a dumping ground.

## Growth Areas

The February crunch around auth shipping showed some strain. Your journals mention feeling overwhelmed on six separate days, and the inbox backed up noticeably during that stretch ([[2026-02-10]], [[2026-02-18]]). When the pressure was on, triage was the first thing to slip. Building a lighter triage habit — even 5 minutes a day — during intense periods would keep the system from accumulating debt.

The Rust learning, while consistent, stayed exploratory. If you want to actually use it for something real, setting a concrete goal for next quarter (like "build one production tool in Rust") would give the learning more direction.
```

## Key Principles

1. **Show, don't tell** — don't say "you were productive", show the evidence
2. **Narrative over enumeration** — paragraphs over bullet points
3. **Link to sources** — every significant claim gets a `[[wikilink]]`
4. **Balance praise and growth** — both grounded in data
5. **Make it readable** — someone should want to read this, not skim past it
