# Crucible — Design Spec

**Date:** 2026-05-23
**Status:** Approved design, pending implementation plan
**Plugin name:** `crucible`

---

## 1. Concept

**crucible** convenes a panel of rigorous, well-researched *thinking systems* — chosen
to fit the problem at hand — and subjects an idea to their combined scrutiny. Each
system gives feedback, they debate where they disagree, and the panel stays alive so
the user can talk to it. What emerges, forged through that pressure, is a structured
artifact.

The metaphor is load-bearing: you drop a raw idea into the crucible, apply intense heat
from multiple disciplined perspectives, and what comes out is tested and refined.

A first-class purpose of the plugin is **finding the blind spots** — the questions the
user isn't asking and the parts of the problem space they aren't considering. This is
why the flow forges the *problem* before it forges the *solution*.

## 2. Goals & non-goals

**Goals**
- Help a user flesh out *any* idea or problem (not only software solutions) using
  multiple legitimate, well-researched thinking frameworks.
- Surface blind spots and unasked questions early.
- Let the user converse with a live panel to iron out details.
- Produce a structured artifact from a fixed menu of templates.
- Actively resist false consensus — the panel's value depends on it (see §5.1).

**Non-goals**
- Not a code-review tool (that's `review-hats`).
- Not a 1:1 Socratic design dialogue (that's `superpowers:brainstorming`).
- Not a general chat agent — it is invoked for deliberate, multi-perspective thinking.

## 3. Positioning (how it differs from neighbors)

| Tool | Subject | Perspectives | Lifecycle | Output |
|------|---------|--------------|-----------|--------|
| `review-hats` | Existing code/diff | Fixed hats | Fire-and-forget | Review report |
| `superpowers:brainstorming` | A design to build | The single facilitator | One conversation | Design doc → plan |
| **`crucible`** | Any idea/problem | Dynamically-selected thinking systems | **Persistent panel** | Artifact from a template menu |

## 4. Architecture

**Chosen: persistent agent team (Architecture A).**

- The **facilitator** is the orchestrator skill running in the user's main session. It is
  the single conversation partner (facilitator-mediated panel model).
- Selected thinking systems are spawned as **background teammates** via `TeamCreate` +
  the Agent tool (one teammate per system), alongside the always-on Dissent Auditor (§5.2).
- During discussion the facilitator queries teammates with `SendMessage` and synthesizes
  their replies back to the user.
- Teams are disbanded with `TeamDelete` at the end of each round.

**Concurrency cap:** 3–7 *selected* thinking systems per round (independent per round),
plus the always-on Dissent Auditor. The facilitator picks the number that fits the
problem rather than a fixed count.

**Documented fallback (Architecture B):** if the agent-team feature proves flaky in
practice, fall back to *re-dispatch with carried context* — thinking systems are
dispatched fresh via the Task tool (like `review-hats`), and the facilitator passes the
accumulated transcript so each perspective "remembers." The user experience is nearly
identical. This fallback is documented but not the primary build target.

**Models / tools for panelists:**
- Model: **sonnet** (keeps a live multi-agent panel affordable).
- Tools: `Read, Grep, Glob, WebSearch` and read-only `Bash` (to ground reasoning and
  inspect referenced material). **No `Write`/`Edit`** — only the facilitator writes the
  artifact.

## 5. Thinking systems as agents — dedicated files, kept thin

**Decision: one dedicated agent definition file per thinking system (~18), not a single
generic agent parameterized by an injected prompt.** This was researched (three parallel
investigations: Claude Code mechanics, multi-agent best practice, ecosystem precedent).
The reasoning, specific to our persistent-team architecture:

- **Persistent teammates are spawned from a named `subagent_type` (a definition file),
  and the definition body is appended to the teammate's system prompt.** The persona is
  therefore *durable* for the teammate's entire life and survives many `SendMessage`
  rounds. A generic agent with an injected persona would carry its lens only as an early
  chat message that **decays as the discussion grows** — the wrong property for a
  multi-round persistent panel. You also cannot inline a full system prompt at team-spawn
  time.
- **Precedent agrees:** `review-hats` (one file per hat) and the external "council of 18
  personas" both use one-file-per-persona with selection driven by a catalog, not by
  agent metadata.
- **The maintainability advantage of a generic-agent + prompt-library is recovered by
  keeping each agent file thin.** Each file holds only the *distinct lens* — core
  question, characteristic moves, what it foregrounds and ignores, failure modes, a brief
  worked exemplar. The shared output contract lives once in `panel/feedback-format.md`;
  agents point to it rather than duplicating it. Cross-cutting changes stay one edit.
- **Distinctness comes from prompt richness, not architecture.** Thin ≠ vague: the lens
  description must be rich and orthogonal, or perspectives homogenize (see §5.1).

**Optional future escape hatch:** a single `generic-thinker` agent the facilitator can
seed from a catalog entry, for user-defined ad-hoc lenses. Not part of v1.

### 5.1 Anti-conformity (evidence-backed, load-bearing)

Multi-agent LLM debate has a strong, well-documented pull toward **conformity**, and our
setup (one base model playing every persona, ambiguous problems, persistent personas,
shared transcript) is *high-exposure*. The evidence (sources in §15):

- A wrong consensus survives **65–96%** of the time in controlled studies, vs. ~37% human
  conformity in Asch's experiments — LLMs replicate Asch-style conformity, often more
  strongly than people.
- Debate frequently **collapses to the initial majority within 1–2 rounds** ("diversity
  collapse") and often fails to beat far simpler ensembling; more rounds converge rather
  than improve.
- LLMs conform **more when uncertain** — which open, ambiguous strategy problems guarantee.
- A root cause is **RLHF sycophancy**: each peer reads as a "user" the model was trained to
  agree with.

Because the failure mode is *polite, plausible convergence that was never earned*, the
defenses are structural, not cosmetic:

1. **Mandatory isolated round-0.** Each selected system produces its full analysis in an
   isolated context with **no visibility of peers**, before any reveal. Single
   highest-leverage, lowest-cost defense — attacks anchoring and uncertainty-driven
   conformity at the source.
2. **Orthogonality-audited library + runtime distinctness check.** System specs are
   authored to foreground genuinely different things; at runtime the facilitator checks
   round-0 outputs for collapse (too-similar pairs) and re-prompts for the missing lens.
   This is our engineered substitute for heterogeneous models.
3. **Always-on Dissent Auditor (§5.2).** A standing dissent role on *every* panel,
   regardless of selection. Replaces the earlier conditional "contrarian only if selected"
   approach, which the evidence shows is the weak link (a same-base-model contrarian that
   is only *sometimes* present is not a defense).
4. **Tension-preserving synthesis.** The facilitator's synthesis preserves dissent and
   unresolved tensions rather than resolving them into false agreement.
5. **Dissent in the artifact.** Every template carries a "Minority views & unresolved
   tensions" section by construction (§9).
6. **Capped debate rounds.** Extra rounds converge rather than diversify; do not add rounds
   for "rigor."

**Heterogeneous models** (different base models per persona) would help but are bounded and
costly; **deferred to a Phase-2 upgrade**, gated on the distinctness check still showing
collapse after the prompt-level fixes above.

### 5.2 The Dissent Auditor (always-on)

A 19th agent (`agents/dissent-auditor.md`), seated on every panel in addition to the 3–7
selected systems. It is **structural, not a selectable thinking system**, and it differs
from the selectable **Red Team** framework: Red Team attacks the *idea* through its own
lens during round-0; the Dissent Auditor attacks the *panel's convergence* after reveal.
Its job: read all round-0 outputs, name the genuine disagreements, steelman the
minority/under-represented positions, and challenge any emerging consensus before the
facilitator synthesizes. (Caveat from the research: being the same base model, it reduces
but does not eliminate conformity — which is why it is one layer among the six in §5.1, not
a standalone fix.)

## 6. The two-round flow

The core insight: *a problem well-framed is half-solved.* crucible runs two distinct
panels — one to forge the problem, one to forge the output — because the thinking systems
good at interrogating a problem differ from those good at generating and evaluating
solutions. Both rounds follow the same anti-conformity discipline (§5.1).

### Round 1 — Frame the problem
0. **Intake.** Facilitator captures the raw idea and what's prompting it. Output type is
   *not* chosen yet.
1. **Select framing panel.** Facilitator picks 3–7 systems best at interrogating the
   problem itself, and seats the always-on Dissent Auditor. Announces the picks and the
   reasoning; the user may add/drop.
2. **Convene & gather in isolation.** `TeamCreate`; spawn the framing systems (+ Dissent
   Auditor) as background teammates. Each framing system *independently, with no peer
   visibility* answers: *What is the real problem? What part of the space are we ignoring?
   What questions aren't being asked?*
3. **Reveal & audit.** Round-0 outputs are revealed; the facilitator runs the runtime
   distinctness check (re-prompting any collapsed pair), then the **Dissent Auditor** names
   the genuine disagreements and steelmans minority framings.
4. **Synthesize.** Facilitator produces a **sharpened problem definition** plus an explicit
   **Blind Spots & Unasked Questions register** (a first-class output), preserving the
   audited tensions rather than smoothing them.
5. **Discuss & lock framing.** User converses with the facilitator to settle the problem
   definition.
6. **Adjourn the framing panel** (`TeamDelete`).

### Transition
7. **Choose the output.** With the problem now defined, the user + facilitator pick the
   artifact template. The facilitator explicitly offers the **Round-1 exit**: if the user
   only wanted to explore/frame (not solve), the run ends with the Problem-Framing
   One-Pager + Blind Spots register as the artifact.

### Round 2 — Forge the output
8. **Select output panel.** Facilitator picks a *new* 3–7 systems suited to the defined
   problem and the chosen artifact (favoring solution-generation and evaluation systems),
   and again seats the Dissent Auditor.
9. **Convene & gather in isolation** (isolated round-0, as in step 2).
10. **Reveal & audit** (distinctness check + Dissent Auditor pass, as in step 3).
11. **Synthesize**, preserving dissent.
12. **Live discussion** with the user.
13. **Forge the artifact.** Facilitator drafts the chosen template — including its
    **Minority views & unresolved tensions** section — from the full deliberation and the
    user's decisions; saves to disk.
14. **Adjourn** (`TeamDelete`); brief wrap-up.

**Save location:** default `docs/crucible/YYYY-MM-DD-<topic>.md`, overridable by the user.

## 7. The thinking-systems library

A broad, dynamically-selected catalog. Each system is a real, well-researched framework
with attribution, implemented as its own thin agent. Each is tagged by where it is most
useful — **framing** the problem, **solving/evaluating**, or **both** — which drives the
two different panel selections.

| Thinking system | Core lens | Best for | Source / lineage |
|---|---|---|---|
| First-Principles | Decompose to fundamental truths, rebuild | Both (framing-lean) | Aristotle / Musk |
| Systems Thinking | Feedback loops, stocks/flows, leverage points, side effects | Both | Forrester, Meadows |
| Cynefin | Classify domain (clear/complicated/complex/chaotic) → match approach | Framing | Snowden |
| Jobs-to-be-Done | What job is this "hired" to do? | Framing | Christensen |
| Lateral Thinking | Provocation; challenge assumptions for non-obvious paths | Framing | de Bono |
| Root Cause (5 Whys) | Drill past symptoms to the real cause | Framing | Toyota |
| MECE / Pyramid Principle | Structured, exhaustive decomposition; expose gaps | Framing | Minto / McKinsey |
| Dialectical Inquiry | Thesis → antithesis → synthesis | Both | Hegel |
| Mental Models (Latticework) | Multidisciplinary models; psychology of misjudgment | Both | Munger |
| Inversion | Avoid failure — what guarantees the worst outcome? | Both (eval-lean) | Jacobi, Munger |
| Second-Order Thinking | "And then what?" — consequences of consequences | Both (eval-lean) | Howard Marks |
| Bayesian / Probabilistic | Priors, update on evidence, calibrate | Both (eval-lean) | Bayes, Tetlock |
| Red Team / Steelman | Strongest adversarial + strongest opposing case | Both (eval-lean) | Intel/debate practice |
| Design Thinking | Human-centered: empathize, define, ideate, prototype | Solving | IDEO / d.school |
| TRIZ | Resolve contradictions via inventive principles | Solving | Altshuller |
| Theory of Constraints | Find & exploit the bottleneck | Both (solving-lean) | Goldratt |
| Scenario Planning | Multiple plausible futures; robustness across them | Solving | Wack / Shell |
| Pre-Mortem | Assume it failed; trace backward to causes | Solving | Klein (HBR) |

**Always-on Dissent Auditor:** seated on every panel *in addition to* the 3–7 selected
systems; it is structural, not part of the selectable library (§5.2).

**Extensibility:** adding a system = adding one thin agent file + one catalog row. Benched
candidates for later: OODA loop (Boyd), Game Theory, Fermi estimation, Expected-Value /
decision theory.

## 8. Selection heuristics

Selection is **skill-owned** — the facilitator reads `library/selection-heuristics.md`
and reasons about which systems fit, then explains its picks. It does **not** rely on
agent-`description` auto-routing (documented as unreliable, and we need deliberate,
explainable, round-specific subsets). Example signals:

**Round 1 (framing)**
- Vague / novel / "not sure how to think about this" → Cynefin, First-Principles, Lateral
- Sprawling / many moving parts → MECE, Systems Thinking
- "We keep hitting this" / recurring pain → Root Cause (5 Whys)
- Building something for someone → Jobs-to-be-Done
- Strong existing opinion to test → Dialectical, Red Team

**Round 2 (solving/evaluating)**
- Choosing between options → Scenario Planning, Second-Order, Bayesian, Red Team
- Stuck / needs invention → TRIZ, Lateral, First-Principles
- Product / UX / user-facing → Design Thinking, Jobs-to-be-Done
- Risk-heavy / high-stakes commitment → Pre-Mortem, Red Team, Inversion
- Throughput / resource / process → Theory of Constraints, Systems Thinking

The facilitator always announces selections with brief reasoning and lets the user adjust.

## 9. Artifact templates (fixed menu)

Shipped as files under `templates/`; extensible by adding a file. **Every template
includes a "Minority views & unresolved tensions" section** (anti-conformity, §5.1) so
surviving disagreement is preserved for the user rather than hidden.

1. **Solution Design Doc** — problem, goals/non-goals, constraints, options considered,
   recommended design, risks, open questions, minority views & tensions.
2. **Problem-Framing One-Pager** — problem statement, why it matters, framing/reframing,
   key questions, hypotheses, blind spots, next steps. *(Also the Round-1-exit artifact.)*
3. **Decision Memo (ADR-style)** — context, decision, alternatives, rationale,
   consequences, dissenting views.
4. **Strategy Brief** — situation, objectives, options, recommendation, plan, key risks &
   dissent.
5. **Exploration / Research Outline** — landscape, key questions, unknowns, research
   directions, what to learn next.

## 10. File structure

Folder names are organized by *meaning* (not the default `references/` catch-all) and
referenced from `SKILL.md` with clear paths. The one hard constraint: dispatchable agents
must live in `agents/` at the plugin root so Claude Code registers them.

```
plugins/crucible/
  .claude-plugin/plugin.json
  README.md
  agents/                          # thinking systems — thin, one per system (required location)
    first-principles.md
    systems-thinking.md
    cynefin.md
    jobs-to-be-done.md
    lateral-thinking.md
    root-cause.md
    mece-pyramid.md
    dialectical-inquiry.md
    mental-models.md
    inversion.md
    second-order.md
    bayesian.md
    red-team.md
    design-thinking.md
    triz.md
    theory-of-constraints.md
    scenario-planning.md
    pre-mortem.md
    dissent-auditor.md             # always-on, structural (not a selectable system)
  skills/crucible/
    SKILL.md                       # facilitator workflow + pointers (lean, <500 lines)
    library/
      catalog.md                   # systems, framing/solving tags, attribution
      selection-heuristics.md      # Round-1 & Round-2 triage signals
    panel/
      feedback-format.md           # panelist initial-feedback contract (agents point here)
      discussion-protocol.md       # isolated round-0, reveal, dissent-audit, distinctness check, tension-preserving synthesis
    templates/
      solution-design.md
      problem-framing.md
      decision-memo.md
      strategy-brief.md
      exploration-outline.md
```

Plus: register the plugin in root `.claude-plugin/marketplace.json` and add a row to the
root `README.md` plugin table.

## 11. Skill-design principles (from skill-creator)

These shape *how* the components are written.

**Progressive disclosure.** `SKILL.md` stays lean (<500 lines): facilitator workflow plus
pointers. The catalog, heuristics, feedback format, discussion protocol, and templates
load only when the relevant phase needs them. Panelist agent bodies load only when
spawned.

**Description / triggering — the key risk.** The skill description is the primary trigger
mechanism. crucible's hard problem is the *boundary* with `superpowers:brainstorming`
(1:1 design convergence) and `review-hats` (code review). The description must:
- trigger on: "pressure-test this idea," "convene a panel," "think through this problem
  from multiple angles / with different frameworks," "what am I not considering," "help
  me figure out what questions I'm not asking," "stress-test," "run this through the
  crucible," early-stage idea exploration that wants multiple disciplined perspectives.
- *not* steal: requests to build/implement a specific feature (brainstorming → plan), or
  review existing code (review-hats).

Draft description (to be optimized, not final):
> "Convene a panel of rigorous, well-researched thinking systems (First-Principles,
> Systems Thinking, Inversion, Cynefin, Pre-Mortem, Red Team, and more) to pressure-test
> and flesh out an idea or problem from multiple perspectives. Use when the user wants to
> think through a problem from many angles, find blind spots, surface the questions they
> aren't asking, stress-test a direction, or produce a design/decision/strategy artifact
> — especially early-stage thinking where the problem itself isn't fully defined. Not for
> reviewing existing code (use review-hats) or for a straightforward 1:1 build-this-
> feature design dialogue (use brainstorming)."

**Writing style.** Imperative voice; explain the *why* behind each instruction; avoid
heavy-handed ALL-CAPS MUSTs. Panelist agents should read as genuine reasoning frameworks
a smart model applies with judgment, not as rigid checklists — this is what keeps the
perspectives substantive and distinct rather than performative.

## 12. Open questions / future enhancements

- **Heterogeneous models** — different base models per persona; deferred to Phase-2, gated
  on the distinctness check (§5.1) still showing collapse after the prompt-level fixes.
- **Separated synthesizer** — a non-participant agent that writes the synthesis instead of
  the facilitator, to further reduce anchoring bias. Considered and deferred; revisit if the
  facilitator's synthesis shows bias in practice.
- **Library growth** — OODA, Game Theory, Fermi estimation, Expected-Value/decision theory
  are benched candidates.
- **Cost monitoring** — watch token cost of persistent panels; define concrete criteria
  for switching to fallback B.
- **`generic-thinker` escape hatch** — for user-defined ad-hoc lenses; not v1.

## 13. Build & validation plan

1. Build thin agents (incl. `dissent-auditor.md`), reference files (`library/`, `panel/`),
   templates, `SKILL.md`, `plugin.json`; register in `marketplace.json` and root
   `README.md`.
2. **Verify persistent-team mechanics** end to end: spawn via `subagent_type`, message via
   `SendMessage`, persona persistence across rounds, `TeamDelete` between rounds. If the
   team feature is flaky, switch to fallback B (§4).
3. **End-to-end facilitator test** via the skill-creator eval harness. Representative
   prompts:
   - A vague early-stage idea ("I have a half-formed idea about X, help me think it
     through") — exercises Round 1 and the Round-1 exit.
   - A decision between options — exercises Round 2 evaluation systems.
   - A recurring problem ("we keep running into Y") — exercises Root Cause framing.
4. **Distinctness / anti-conformity check** — confirm selected panelists produce genuinely
   different round-0 analyses on the same problem (embed outputs, measure pairwise
   divergence); confirm the Dissent Auditor surfaces real disagreement and the artifact's
   minority section is populated when tensions exist. This metric also gates the
   heterogeneous-models decision (§12).
5. **Description-optimization loop** (skill-creator `run_loop.py`) with should-trigger /
   should-not-trigger evals. Negatives must include near-miss brainstorming prompts
   (build-this-feature) and review-hats prompts (review this diff) — the real collisions.

## 14. Research basis (conformity in multi-agent LLM systems)

Key sources behind §5.1–§5.2:
- Du et al., *Improving Factuality and Reasoning through Multiagent Debate* (arXiv 2305.14325)
- *Should we be going MAD? A Look at Multi-Agent Debate Strategies* (arXiv 2311.17371)
- *Demystifying Multi-Agent Debate: Confidence and Diversity* (arXiv 2601.19921)
- *Can LLM Agents Really Debate? A Controlled Study* (arXiv 2511.07784)
- Cemri et al., *Why Do Multi-Agent LLM Systems Fail?* (MAST, arXiv 2503.13657)
- *Conformity in Large Language Models* (arXiv 2410.12428) — Asch-style conformity,
  uncertainty→conformity, Devil's Advocate mitigation
- Sharma et al. (Anthropic), *Towards Understanding Sycophancy in Language Models* (arXiv 2310.13548)
- Naik et al., *Diversity of Thought Improves Reasoning Abilities of LLMs* (arXiv 2310.07088)
- *From Single to Societal: Persona-Induced Bias in Multi-Agent Interactions* (arXiv 2511.11789)
- *The Social Laboratory: A Psychometric Framework for Multi-Agent LLM Evaluation* (arXiv 2510.01295)
