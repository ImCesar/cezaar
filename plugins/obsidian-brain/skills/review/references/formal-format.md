# Formal Review Format

Reference for generating structured self-evaluation documents. Used when the user needs to prepare for a performance review, fill out a self-eval form, or bring evidence to a 1:1 with their manager.

## Structure

Sections with clear headers, tables for structured data, and explicit evidence blocks. This format is designed to be copy-pasted directly into a self-eval form or shared document.

## Sections

### Goals & Outcomes

A table summarizing each goal or objective and its outcome.

| Column | Description |
|--------|-------------|
| **Goal** | The objective as stated (or inferred from project notes) |
| **Status** | Completed, In Progress, Partially Met, Not Started, Exceeded |
| **Evidence** | Specific vault references with dates that demonstrate the outcome |

Pull goals from:
- Project notes with explicit objectives
- Quarterly goals mentioned in journal entries
- Recurring themes that functioned as implicit goals

### Key Accomplishments

Each accomplishment gets its own block with an **impact statement** — not just what was done, but why it mattered. Format:

```
**Accomplishment title**
What: <concise description of what was delivered or achieved>
Impact: <measurable or observable effect on the team, product, or organization>
Evidence: [[wikilink-1]], [[wikilink-2]], [[wikilink-3]]
Timeline: <start date> - <end date>
```

Aim for 3-7 accomplishments depending on the review period.

### Areas for Development

Structured observations about growth opportunities. Each area gets:

```
**Area title**
Observation: <what the pattern is, grounded in vault data>
Evidence: [[wikilink-1]] (date), [[wikilink-2]] (date)
Suggested action: <concrete next step>
```

Frame these as forward-looking development opportunities, not failures. Ground every observation in data from the vault — journal entries, inbox backlogs, project timelines, etc.

### Evidence & References

A consolidated reference section that lists all vault notes cited in the review, organized by type:

- **Projects** — project notes referenced
- **Journal entries** — daily/weekly entries cited
- **Knowledge notes** — research and learning referenced
- **Archived items** — completed work cited

Each entry includes the note name as a `[[wikilink]]` and a brief description of its relevance.

## Tone

- **Professional** — suitable for sharing with a manager or HR
- **Specific** — every statement backed by concrete evidence
- **Measurable** — quantify impact where possible (number of incidents caught, days to ship, items processed)
- **Balanced** — honest about both strengths and areas for growth
- **First person** — written as the user's own self-eval ("I led...", "I shipped...")

## Evidence Standards

This format demands more rigorous evidence than the casual summary:
- Every accomplishment needs at least 2 supporting vault references
- Dates should be explicit (not "early February" but "February 3-7")
- Impact statements should be measurable when possible
- Development areas need evidence too — not just feelings, but patterns in the data

Use `[[wikilinks]]` with dates in parentheses:
```
[[auth-migration-project]] (Jan 15 - Feb 24), [[2026-02-24]] (launch day)
```

## Example Structure

```markdown
---
type: review
status: captured
created: "2026-03-09"
tags:
  - review
  - formal
period: "2026 Q1"
parent: ""
---

# Performance Review: 2026 Q1

*Self-evaluation covering January 1 - March 9, 2026*

## Goals & Outcomes

| Goal | Status | Evidence |
|------|--------|----------|
| Migrate authentication to OAuth2 | Completed | [[auth-migration-project]], [[2026-02-24]] (shipped Feb 24) |
| Build production monitoring dashboard | Completed | [[monitoring-dashboard-project]], [[2026-02-20]] (launched Feb 20) |
| Reduce p95 API latency by 20% | Partially Met | [[api-performance-research]] (achieved 12% reduction per [[2026-03-01]]) |
| Learn Rust fundamentals | In Progress | [[rust-ownership-notes]], [[rust-error-handling]], [[rust-cli-experiment-project]] |

## Key Accomplishments

**Authentication Migration to OAuth2**
What: Led end-to-end migration of the authentication system from custom session-based auth to OAuth2 via Auth0. Included provider evaluation, migration planning, implementation, and rollout.
Impact: Eliminated 3 classes of auth-related bugs identified in [[2026-01-10]], reduced login-related support tickets by approximately 40% (per [[2026-03-05]] journal entry), and brought the system in line with SOC2 requirements.
Evidence: [[auth-migration-project]], [[2026-01-15-research-oauth2-options]], [[2026-01-28]] (decision), [[2026-02-24]] (launch)
Timeline: January 15 - February 24 (6 weeks)

**Production Monitoring Dashboard**
What: Designed and built a monitoring dashboard covering API health, error rates, latency percentiles, and deployment markers. Included alerting rules for critical thresholds.
Impact: Caught 2 production incidents within the first week of deployment ([[2026-02-22]], [[2026-02-25]]) that would have gone undetected. Reduced mean time to detection from ~45 minutes to <5 minutes.
Evidence: [[monitoring-dashboard-project]], [[2026-02-20]] (launch), [[2026-02-22]] (first incident caught), [[2026-02-25]] (second incident caught)
Timeline: February 5 - February 20 (2.5 weeks)

**Maintained Consistent Knowledge Management**
What: Kept the Obsidian vault active throughout the quarter — 52 daily journal entries, 12 weekly reflections, 23 knowledge notes, and 89 captures triaged.
Impact: Created a searchable record of decisions, research, and work context that directly supported this self-eval and multiple project decisions.
Evidence: vault activity logs, [[2026-01-05]] through [[2026-03-09]] journal entries
Timeline: Ongoing

## Areas for Development

**Workload Management During Crunch Periods**
Observation: During the authentication migration's final push (Feb 10-24), journal entries show signs of overload on 6 separate days. The capture inbox grew from 5 to 28 untriaged items during this period, and two scheduled research tasks were deferred.
Evidence: [[2026-02-10]] ("feeling stretched"), [[2026-02-14]] ("too many context switches"), [[2026-02-18]] ("inbox is piling up"), [[2026-02-22]] ("need to catch up on triage")
Suggested action: Establish a "crunch mode" protocol — reduced scope for non-critical activities (like triage) rather than full abandonment, and explicit communication to stakeholders about temporary capacity reduction.

**Moving from Learning to Application (Rust)**
Observation: Rust learning has been consistent but remains in the exploration phase after 3 months. Knowledge notes cover fundamentals well, but the only applied project ([[rust-cli-experiment-project]]) was a small experiment.
Evidence: [[rust-ownership-notes]] (Jan), [[rust-error-handling]] (Feb), [[rust-cli-experiment-project]] (Mar, unfinished)
Suggested action: Set a concrete goal for Q2 — e.g., "build one internal tool in Rust" — to convert accumulated learning into practical experience.

## Evidence & References

### Projects
- [[auth-migration-project]] — OAuth2 authentication migration (completed)
- [[monitoring-dashboard-project]] — Production monitoring dashboard (completed)
- [[rust-cli-experiment-project]] — Rust CLI learning experiment (in progress)

### Journal Entries
- [[2026-01-10]] — Initial auth bug analysis
- [[2026-01-15-research-oauth2-options]] — OAuth2 provider evaluation
- [[2026-01-28]] — Auth provider decision (Auth0)
- [[2026-02-10]], [[2026-02-14]], [[2026-02-18]], [[2026-02-22]] — Crunch period entries
- [[2026-02-20]] — Monitoring dashboard launch
- [[2026-02-22]], [[2026-02-25]] — Production incidents caught by monitoring
- [[2026-02-24]] — Auth migration launch
- [[2026-03-01]] — API latency progress check
- [[2026-03-05]] — Support ticket reduction noted
- [[2026-03-05-research-distributed-tracing]] — Tracing research

### Knowledge Notes
- [[rust-ownership-notes]] — Rust ownership model
- [[rust-error-handling]] — Rust error handling patterns
- [[api-performance-research]] — API latency investigation
```

## Key Principles

1. **Copy-paste ready** — the output should work in a Google Doc, Notion page, or self-eval form without reformatting
2. **Evidence-first** — every claim has explicit references with dates
3. **Impact over activity** — focus on outcomes and effects, not just tasks completed
4. **Quantify where possible** — numbers, percentages, timelines, counts
5. **Development areas are forward-looking** — observations + suggested actions, not criticisms
6. **First person voice** — this is the user's self-eval, written as them
