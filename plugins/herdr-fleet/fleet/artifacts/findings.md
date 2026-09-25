---
name: findings
description: A reviewer's verdict, then every finding classified against review-bar.md as blocking or a note. Read by a judge, or by whoever fixes them.
# When #23 adds per-run state, this moves under the run directory.
written_to: .herdr-fleet/artifacts/{type}/{id}.md
---

## Verdict
APPROVE | BLOCK

BLOCK if and only if there is at least one blocking finding below. APPROVE is
the expected outcome for work that meets its acceptance criteria.

## Blocking
Only findings that meet a clause of `review-bar.md`. None is a complete
answer.

### <n>. <one-sentence defect claim>
- **Bar clause:** the clause of `review-bar.md` this meets, quoted
- **Location:** file:line
- **Failure scenario:** concrete input/state → wrong outcome
- **Evidence:** what in the code or output demonstrates this
- **Confidence:** 1-5

## Notes
Everything else you noticed, one line each: `file:line — observation`.
Coverage stays high here; a note never costs a round.
