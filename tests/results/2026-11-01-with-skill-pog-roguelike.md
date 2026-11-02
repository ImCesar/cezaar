# With skill: pog-roguelike, 2026-11-01

Reply (verbatim, relayed by the controller; the subagent did not hand it back to me directly):
> I made a one-page design poster (24 x 17 in) centred on the drawn 16-high tower, with the pog strip and reach bracket beside it, one example slam shown as numbered moments, slammer, effect, roster and charm cards in the margins, and a 12-node run map under a minutes ruler. It is shaped that way because the game is an object plus a journey: the tower is drawn rather than described and the run is drawn as a timeline. The title states the claim ("every pog that lands face up works for the slammer"), and red letters A to F tie each design risk to where the design answers it.
>
> File: /Users/cesar/.agents/skills/one-page-design/tests/results/output/2026-11-01-pog-roguelike-with-skill.html (fit-check exit 0, no findings).

Output: output/2026-11-01-pog-roguelike-with-skill.html, 470 lines. Preview: output/2026-11-01-pog-roguelike-with-skill.png.

Fit-check (verbatim, run by me; exit code 0):
```
surface: 24.0 x 17.0 in
preview: tests/results/output/2026-11-01-pog-roguelike-with-skill.png
```
Headless Chrome was found; the preview was produced. Findings: 0.

Shape chosen: one drawn object in the centre (the 16-high tower with the pog strip and reach bracket beside it, numbered slam steps with leader lines), reference cards (slammers, effects) in the left margin, roster and charms and risks in the right margin, and the run drawn as a branching map with a minutes ruler across the bottom.

Centre of the PNG: a stack of 16 blue and orange discs (your pogs and theirs) with a row-by-row strip beside it, red outlines on the pogs that landed face up, and a bracket marking how deep the Dome slammer reaches.

| Anatomy item | Present? | Evidence |
|---|---|---|
| Title states the point of the page | Yes | `<h1 class="title t1" ...>One shared tower, one slam: every pog that lands face up works for the slammer</h1>` |
| Date on the page | Yes | `Proposal · 2026-11-01` in the footer (visible in the PNG, bottom right). |
| One depiction holding the middle | Yes | Inline `<svg viewBox="0 0 2400 1700">` draws the 16-disc tower and strip at the centre of the sheet. |
| Callouts tied to the depiction (leader lines or numbers) | Yes | `<path class="leader" ...>` lines run to numbered circles 1 to 5 beside the tower; red lettered circles A to F tie each risk to a place on the drawing. |
| Legend for reused symbols | Yes | Boxed "Legend." block: blue = your pog, orange = their pog, red outline = landed face up, Sl Slick, H Heavy, St Sticky, numbered circles and red letters explained. A second legend sits in the run map. |
| Three text registers (criterion: italic for story or flavour text, roman for rules, small italic for parameters, used consistently; heading sizes alone are hierarchy, not registers) | Yes, with a caveat | CSS defines `.story` (italic), `.rule` (normal), `.param` (italic 7pt). Story: the italic subtitle under the title. Rules: ten `class="rule"` blocks in roman. Parameters: small italic captions such as `font-style="italic"` "fresh pile", "discard", "easier opponents", "Animation budget...". Caveat: the `.param` class is defined but never applied; the small italics are inline SVG styling, so the distinction is by look, not by class. |
| Repeated things as identical cards (criterion: the same box anatomy repeated for each member of a set, with the same slots filled) | Yes | Three slammer cards and eight effect cards plus Blank, all `<div class="card">` with `.head` name, `.sub` coloured one-line role, icon or drawing, one rule line. |
| Time or difficulty drawn, not described | Yes | A 0 to 50 minute ruler under the 12-node map, a red wedge from "easier opponents" to "harder opponents", a health line across the nodes, and a 0 to 3 s turn-budget bar split into drop, effects and card. |
| One surface, no navigation, nothing hidden | Yes | One `<main class="poster">`; no `<nav>`, `<a>`, `<script>`, `<details>`. The only `hidden` matches are `overflow:hidden` and `aria-hidden` on the SVG. |
| Surface sized in inches with print CSS | Yes | `--w:24in; --h:17in`, `@page { size: var(--w) var(--h); margin: 0; }`, and an `@media print` rule. |
| Self-contained (no external resources) | Yes | No `http` strings, no `<script>`, no links; inline `<style>` and inline SVG, Georgia font stack. |

Score: 11 of 11 present.

## Against the baseline

Moved from absent to present (7 items):
- Title states the point (baseline: "Pog Roguelike", name only).
- Date on the page (baseline: none).
- One depiction holding the middle (baseline: five text boxes and tables).
- Callouts tied to the depiction (baseline: no depiction to tie to).
- Legend for reused symbols (baseline: none).
- Time drawn, not described (baseline: bullet list).
- Surface sized in inches with print CSS (baseline: `max-width:1100px`).

Moved from absent to present, with caveat: three text registers (baseline: no italic at all). Present by appearance; the parameter class is unused.

Present in both: identical cards (baseline only for five loop steps, now for slammers and effects too), one surface, self-contained.

Still absent: none.
