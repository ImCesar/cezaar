# cezaar

Cesar's personal Claude Code plugin marketplace.

## Plugins

| Plugin | Description |
|--------|-------------|
| **[herdr-fleet](plugins/herdr-fleet)** | Hands-off orchestration on Herdr: Claude workers in Herdr panes, a file-based brief/report contract, fresh-context validation, risk-triaged escalation |
| **[superpowers](https://github.com/obra/superpowers)** | TDD, debugging, brainstorming, planning |
| **[review-hats](https://github.com/ImCesar/review-hats)** | Multi-perspective code review |
| **[gh-dashboard](plugins/gh-dashboard)** | GitHub project status dashboard |
| **[crucible](plugins/crucible)** | Convene a panel of thinking systems to pressure-test ideas |
| **[one-page-design](plugins/one-page-design)** | Turn any design into a Librande-style one-page document |
| **[rooms](plugins/rooms)** | A chat room per task for Claude agents, with mention wake-ups and a Herdr app panel |
| **[app-fleet](plugins/app-fleet)** | The fleet on the Herdr app: channels and threads, the lead dictates, threads run themselves |

## Installation

```bash
claude plugins marketplace add ImCesar/cezaar
claude plugins install herdr-fleet
claude plugins install superpowers
claude plugins install review-hats
claude plugins install gh-dashboard
claude plugins install crucible
claude plugins install one-page-design
claude plugins install rooms
claude plugins install app-fleet
```

herdr-fleet needs `herdr`, `claude` and `python3` on `PATH`; see its [README](plugins/herdr-fleet/README.md) before installing.
