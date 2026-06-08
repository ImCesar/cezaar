# crucible

Convene a panel of rigorous, well-researched **thinking systems** to pressure-test and flesh
out an idea, then produce a structured artifact.

## What it does
You bring a half-formed idea or a thorny problem. crucible selects a panel of thinking
systems that fit it, runs them through two disciplined rounds — first to **frame the problem**
(and find the questions you aren't asking), then to **forge an output** — and writes the
result to a design, decision, strategy, framing, or exploration document.

## When to use it
- Early-stage thinking where the problem itself isn't fully defined.
- "What am I not considering?" / "pressure-test this direction."
- Producing a design / decision / strategy artifact with multiple perspectives.

Not for: reviewing existing code (use **review-hats**) or a straightforward 1:1
build-this-feature design chat (use **brainstorming**).

## The flow
1. **Frame the problem** — a framing panel surfaces blind spots and a sharpened problem
   statement. You can stop here with a Problem-Framing one-pager.
2. **Forge the output** — a fresh panel suited to the defined problem produces the artifact.

## The library
18 selectable thinking systems (First-Principles, Systems Thinking, Cynefin,
Jobs-to-be-Done, Lateral Thinking, Root Cause, MECE/Pyramid, Dialectical Inquiry, Mental
Models, Inversion, Second-Order, Bayesian, Red Team, Design Thinking, TRIZ, Theory of
Constraints, Scenario Planning, Pre-Mortem) plus an always-on **Dissent Auditor**.

## Why it resists groupthink
Multi-agent panels tend to converge on agreeable, unearned consensus. crucible defends
against this: each system analyzes **independently before** seeing the others, a distinctness
check keeps lenses from collapsing together, an always-on Dissent Auditor attacks the panel's
consensus, and the artifact always preserves minority views and unresolved tensions.

## Install
```bash
claude plugins marketplace add ImCesar/cezaar
claude plugins install crucible
```

## Attribution
Each thinking system is grounded in an established framework; see the agent definitions in
`agents/` for lineage (Aristotle, Meadows/Forrester, Snowden, Christensen, de Bono, Toyota,
Minto, Hegel, Munger, Jacobi, Marks, Bayes/Tetlock, IDEO/d.school, Altshuller, Goldratt,
Wack, Klein).
