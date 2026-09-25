---
name: acceptance-results
description: One pass/fail row per acceptance criterion, with evidence from running the system. Read by whoever writes the validation report.
# When #23 adds per-run state, this moves under the run directory.
written_to: .herdr-fleet/artifacts/{type}/{id}.md
---

## Results
One row per acceptance criterion from the solution-design: pass or fail,
and the evidence — a command and its output — that decided it.
