# staff-coach

A staff-level engineering sparring partner and learning system. Claude proposes (or
ingests) a staff/architect-level problem; you work it as an ongoing collaborative dialogue
with a **coach**; when you are satisfied, an independent **examiner** grades the work cold
against a rubric. Scores persist and steer future problems and learning recommendations.

The defining behavior: **discovery, not answers.** The coach prompts you to find what
you are missing ("What maintainability are we trading off here — are those the right
trade-offs?") rather than supplying solutions, and engages **one topic at a time** to avoid
overwhelm. Answers are finally allowed after the session ends — the examiner reveals what a
stronger response would have surfaced on any dimensions you missed.

## Skills

- **`practice`** — run a coached, graded session: pick a mode (generated problem or
  bring-your-own architecture), work through the coach loop, then receive an independent
  examiner verdict and save the result to your learning store.
- **`progress`** — report trends, weak spots, disputed-but-unresolved areas, and recommended
  drills and reading drawn from your `~/.staff-coach/` history; does not run a session.

## How a session works

1. **Open — pick the mode.** Choose a generated staff-level problem (biased toward your
   persistent weak spots) or supply a real architecture, RFC, or diagram as the problem.
2. **Coach loop.** You stake a position; the coach probes one rubric dimension at a time;
   you revise; back and forth until you are satisfied. The coach never delivers answers —
   only escalating probes — and tracks privately whether each dimension was resolved
   unprompted, required a nudge, or was never reached.
3. **You declare satisfaction.** The session ends when you say so, not after a fixed number
   of questions. The coach may note uncovered dimensions and ask "keep going or grade here?"
   but never pushes toward the door.
4. **Examiner handoff.** The `practice` skill dispatches the `examiner` subagent with the
   problem, the relevant rubric, your final solution, the full dialogue transcript, and the
   trade-off ledger of decisions you consciously accepted.
5. **Validate + reconcile.** `validate_examiner_output.py` gates the JSON before anything
   touches the store. You and the coach then review each finding: accepted, factually
   corrected (examiner misread the transcript), or disputed on the merits (with a one-line
   reason logged as a paper trail).
6. **Record + close.** `write_session.py` renders an immutable session record — problem,
   verdict, dispositions, reconciled scores — and applies deltas to `progress.json`.

## The coach/examiner split

An LLM that coaches you through a design and then grades it is a co-author grading its own
work — co-author sycophancy is a documented failure mode. staff-coach removes this by making
the examiner a separate subagent that never participated in the dialogue.

The examiner is engineered for **high precision**: every finding must carry a concrete failure
scenario, a comparison against a stronger design, and a rough likelihood/magnitude. Findings
are checked against the trade-off ledger (so consciously accepted trade-offs are never
re-raised as gaps), capped at three per dimension to force prioritization, and subjected to an
adversarial self-prosecution pass before surfacing. The examiner may and is rewarded to return
"meets the staff bar, nothing material" — legal abstention is a first-class outcome. The raw
examiner verdict is stored immutably; the reconciliation review layers dispositions on top,
never overwrites the assessed record.

## Requirements

- Node.js (any current LTS) for the helper scripts in `scripts/`.
- Nothing leaves the machine — no external services, no telemetry.

## Data

Sessions and progress are stored in `~/.staff-coach/`:

```
~/.staff-coach/
├── sessions/   # immutable per-session records
├── canvas/     # whiteboard exports
└── progress.json
```

Override the location with the `STAFF_COACH_HOME` environment variable.

## Install

```bash
claude plugins marketplace add ImCesar/cezaar
claude plugins install staff-coach
```

## Research provenance

The examiner's anti-nitpick, high-precision design is grounded in the following published
work. These are rationale for the design choices; they are not loaded into the agent's
runtime context.

- CriticGPT, *LLM Critics Help Catch LLM Bugs* — https://arxiv.org/abs/2407.00215
- *Are LLMs Reliable Code Reviewers? Systematic Overcorrection* — https://arxiv.org/abs/2603.00539 ; *Uncovering Systematic Failures of LLMs in Verifying Code Against NL Specs* — https://arxiv.org/html/2508.12358v1
- *On the Self-Verification Limitations of LLMs* — https://arxiv.org/pdf/2402.08115
- *Towards Understanding Sycophancy in Language Models* — https://arxiv.org/abs/2310.13548 ; *ELEPHANT: Social Sycophancy* — https://arxiv.org/abs/2505.13995
- *AbstentionBench* — https://arxiv.org/pdf/2506.09038 ; *Calibrating LLM Judges* — https://arxiv.org/pdf/2512.22245
- *From Generation to Judgment* (survey) — https://arxiv.org/pdf/2411.16594
