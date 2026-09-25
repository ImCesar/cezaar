---
name: findings
description: One entry per defect a reviewer found, with location and evidence. Read by a judge, or by whoever fixes them.
# When #23 adds per-run state, this moves under the run directory.
written_to: .herdr-fleet/artifacts/{type}/{id}.md
---

## Findings
One entry per finding, coverage first — filtering happens downstream, not
here.

### <n>. <one-sentence defect claim>
- **Location:** file:line
- **Failure scenario:** concrete input/state → wrong outcome
- **Severity:** high | med | low
- **Confidence:** 1-5
- **Evidence:** what in the code or output demonstrates this
