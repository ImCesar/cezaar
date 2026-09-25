---
name: confirmed-findings
description: The judge's ruling on each blocking finding — upheld, downgraded to a note, or refuted — citing the bar clause and the code it read. Read by whoever owns the fix.
# When #23 adds per-run state, this moves under the run directory.
written_to: .herdr-fleet/artifacts/{type}/{id}.md
---

## Rulings
One entry per **blocking** finding from the findings artifact; notes are not
judged.

### <n>. <the finding, one sentence>
- **Ruling:** upheld | downgraded | refuted
  - `upheld` — real, and meets the bar;
  - `downgraded` — real, but below the bar, so it becomes a note;
  - `refuted` — not real.
- **Bar clause:** the clause of `review-bar.md` the ruling turns on
- **Code read:** file:line, and what it shows
- **Reproduced:** no, or what was run and why — only when the evidence was
  missing or the code contradicted the finding

## Noticed, not judged
Anything new the judge saw, one line each, for the lead. Not findings: the
judge adds none.
