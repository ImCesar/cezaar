---
name: progress
description: >
  Report the user's staff-coach learning progress: score trends over time, persistent weak spots,
  disputed-but-unresolved areas, and recommended drills plus targeted reading. Use whenever the
  user asks how they're doing on their engineering practice, what to work on next, where their
  gaps are, or wants a recommendation for what to drill or read next from their staff-coach
  history. Reads only the `~/.staff-coach/` store; does not run a session (use practice for that).
---

# Progress — learning trajectory report

This skill formats the output of the aggregator; all computation happens in the script. No session
is run here.

---

## 1. Run the aggregator

```bash
cd plugins/staff-coach/scripts && node aggregate_progress.js
```

The script prints JSON with four top-level keys: `all`, `weak_spots`, `disputed_unresolved`, and
`recommended_next`.

---

## 2. Narrate the results

Walk through the JSON in a way that gives the user a clear picture of where they stand and where to
focus next.

**Trends over time** — for each dimension in `all`, describe the trajectory: improving, flat, or
declining, and how many attempts are behind it. A dimension with two attempts and an "improving"
tag is fragile; one with ten attempts and a "flat" tag is a genuine plateau. Give the user that
context, not just the label.

**Persistent weak spots** — `weak_spots` are sorted by priority: lowest current estimate first,
fewest attempts as a tiebreaker. For each, name the dimension and its `reason`: `"low score"` means
the estimate has landed below 3.0 across attempts; `"needs nudging"` means the user is consistently
led there by the coach rather than arriving unprompted. Both matter, but they feel different — one
is a knowledge gap, the other is a fluency gap. Make that distinction visible.

**Disputed-but-unresolved areas** — `disputed_unresolved` lists dimensions where the user pushed
back on examiner findings during reconciliation and the dispute was recorded but not resolved. These
are worth calling out: a high dispute count may mean the user genuinely has a different mental model
than the rubric, or it may mean a real gap the user reasoned themselves out of. Either way it's
signal worth surfacing.

**Recommended next drill** — `recommended_next` is the single highest-priority dimension based on
the aggregator's logic. Name it and briefly say why it surfaces: is it the lowest-scoring dimension,
a frequently nudged one, or the only dimension with any attempts at all?

---

## 3. Offer targeted reading

Offer 1–3 reading pointers tied to the top weak spot (the first entry in `weak_spots`, or
`recommended_next` if `weak_spots` is empty).

Resources come from the curated anchor map in `../practice/references/resources.md`, supplemented
by web search for gaps the map doesn't cover well. The no-uncited-link rule always applies: never
cite a URL that was not actually retrieved. If web search doesn't produce a usable result, name the
resource without a URL rather than fabricate one.

Each pointer gets a one-liner that explains why it maps to this specific gap — not a generic
description, but a direct connection to the dimension and what the score or nudge pattern reveals
about the user's current understanding.
