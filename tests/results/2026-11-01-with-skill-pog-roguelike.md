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

Legibility:
- (a) The nested SVG at line 431 sets `font-size="8"` on the labels "bottom" and "half". At the page's top-level scale of 100 units per inch that is 5.8 pt, below the 6 pt floor, and it is visibly the smallest text in the PNG. The nested SVG's own scale was not measured, so this is probable, not confirmed. Fit-check does not check SVG text.
- (b) The page carries a lot of 7 to 8 pt text and is dense for a 24 x 17 in wall poster.

Shape chosen: one drawn object in the centre (the 16-high tower with the pog strip and reach bracket beside it, numbered slam steps with leader lines), reference cards (slammers, effects) in the left margin, roster and charms and risks in the right margin, and the run drawn as a branching map with a minutes ruler across the bottom.

Centre of the PNG: a stack of 16 blue and orange discs (your pogs and theirs) with a row-by-row strip beside it, red outlines on the pogs that landed face up, and a bracket marking how deep the Dome slammer reaches.

| Anatomy item | Present? | Evidence |
|---|---|---|
| Title states the point of the page | Yes | `<h1 class="title t1" ...>One shared tower, one slam: every pog that lands face up works for the slammer</h1>` |
| Date on the page | Yes | `Proposal · 2026-11-01` in the footer (visible in the PNG, bottom right). |
| One depiction holding the middle | Yes | Inline `<svg viewBox="0 0 2400 1700">` draws the 16-disc tower and strip at the centre of the sheet. |
| Callouts tied to the depiction (leader lines or numbers) | Yes | `<path class="leader" ...>` lines run to numbered circles 1 to 5 beside the tower; red lettered circles A to F tie each risk to a place on the drawing. |
| Legend for reused symbols | Yes | Boxed "Legend." block: blue = your pog, orange = their pog, red outline = landed face up, Sl Slick, H Heavy, St Sticky, numbered circles and red letters explained. A second legend sits in the run map. |
| Three text registers (criterion: italic for story or flavour text, roman for rules, small italic for parameters, used consistently; heading sizes alone are hierarchy, not registers) | No | `.param` is defined (html:18) and never applied. The only italic prose is the subtitle at line 426, which describes the game rather than carrying story text. The SVG italics at lines 259-262, 352 and 413 are captions ("fresh pile", "discard", "minutes", "easier opponents"), not parameters. The real parameters ("Reach: top ~4", the effect-card numbers) are roman. The page does not use the three registers. |
| Repeated things as identical cards (criterion: the same box anatomy repeated for each member of a set, with the same slots filled) | Yes | Three slammer cards and eight effect cards plus Blank, all `<div class="card">` with `.head` name, `.sub` coloured one-line role, icon or drawing, one rule line. |
| Time or difficulty drawn, not described | Yes | A 0 to 50 minute ruler under the 12-node map, a red wedge from "easier opponents" to "harder opponents", a health line across the nodes, and a 0 to 3 s turn-budget bar split into drop, effects and card. |
| One surface, no navigation, nothing hidden | Yes | One `<main class="poster">`; no `<nav>`, `<a>`, `<script>`, `<details>`. The only `hidden` matches are `overflow:hidden` and `aria-hidden` on the SVG. |
| Surface sized in inches with print CSS | Yes | `--w:24in; --h:17in`, `@page { size: var(--w) var(--h); margin: 0; }`, and an `@media print` rule. |
| Self-contained (no external resources) | Yes | No `http` strings, no `<script>`, no links; inline `<style>` and inline SVG, Georgia font stack. |

Score: 10 of 11 present.

## Against the baseline

Moved from absent to present (7 items):
- Title states the point (baseline: "Pog Roguelike", name only).
- Date on the page (baseline: none).
- One depiction holding the middle (baseline: five text boxes and tables).
- Callouts tied to the depiction (baseline: no depiction to tie to).
- Legend for reused symbols (baseline: none).
- Time drawn, not described (baseline: bullet list).
- Surface sized in inches with print CSS (baseline: `max-width:1100px`).

Present in both: identical cards (baseline only for five loop steps, now for slammers and effects too), one surface, self-contained.

Still absent: three text registers (the baseline lacked them too; the skill did not change this on scenario 1).

Skill gaps surfaced by this run, for Task 8: the three-registers rule did not bind on scenario 1; fit-check does not check SVG font-size attributes.

## Round 2 (after Task 8 fixes)

Changes under test: the three registers are now a required slot in each callout and card; a margin-budget recipe follows the contract; fit-check now checks unitless SVG font sizes at 100 units per inch.

Run: one fresh `general-purpose` subagent on model `sonnet`, given the line "Use the one-page-design skill at /Users/cesar/.claude/skills/one-page-design/SKILL.md." followed by `tests/scenarios/pog-roguelike.md` verbatim with the output path filled in. Its reply did not come back to me, so this record is scored from the HTML and the PNG only.

Output: output/2026-11-01-pog-roguelike-with-skill-round2.html, 416 lines. Preview: output/2026-11-01-pog-roguelike-with-skill-round2.png.

Fit-check after the Task 8 fixes, verbatim, exit code 0:
```
surface: 26.0 x 17.0 in
preview: tests/results/output/2026-11-01-pog-roguelike-with-skill-round2.png
```
Findings: 0. SVG text sizes run from 11 to 20 units, which is 7.9 to 14.4 pt at 100 units per inch. The page's comment says "the SVG viewBox is 100 units per inch", and its top-level `viewBox="0 0 2600 1700"` matches the 26 x 17 in surface. For comparison, the round 1 page now fails the updated check:
```
- svg text below floor: font-size="8" (5.8pt at 100 units/in) on <text>; floor is 6pt
- svg text below floor: font-size="8" (5.8pt at 100 units/in) on <text>; floor is 6pt
surface: 24.0 x 17.0 in
```

Shape chosen: one drawn object in the centre, the 16-disc tower with its strip, the Dome reach bracket and the slammer above it. Health bars, and a pile and discard with arrows, sit above the strip. The left margin holds the turn as five numbered moments and the six risks A to F. Three slammer cards run across the top centre. The right margin holds nine effect cards and small drawings of the roster, the merge, the take-or-remove choice, the slammers owned and the charms. A 12-node run map lies across the bottom on a minutes ruler. This is the same family as round 1 with the margins swapped: round 1 had slammers and effects on the left and roster and risks on the right.

Centre of the PNG: a column of 16 blue and orange discs with a red dome slammer above it. The strip beside it lists rows 1 to 16 with icons and values. A red bracket labelled "DOME usually reaches here" spans rows 1 to 4, with "foe -2", "you +3", "face down" and "you -3" against those rows.

| Anatomy item | Present? | Evidence |
|---|---|---|
| Title states the point of the page | Yes | `<h1 class="title t1">One shared tower of pogs: each slam fires whatever lands face up</h1>`, at `top:.4in; left:.5in`. |
| Date on the page | Yes | `<footer class="date">Proposal &middot; 2026-11-01</footer>`, `.date { position:absolute; bottom:.25in; right:.5in; ...}`. |
| One depiction holding the middle | Yes | `<svg viewBox="0 0 2600 1700" ...>` draws the 16 discs at x 950 to 1250 with the strip at x 1400 to 1730, in the centre of the sheet. |
| Callouts tied to the depiction (leader lines or numbers) | Yes | Shared numbers: the left-margin steps "1 Aim" to "5 Swap" match circles 1 to 5 on the drawing. Circle 1 is at the slammer, 2 at the tower top, 3 at the strip, 4 at the pile and 5 at the health bars. Risk letters A to D are boxed on the drawing at the bracket, the strip, the pile and the tower. E is at the charms drawing in the right margin and F at the 3 s bar in the left margin. No leader lines are drawn; `svg .leader` is defined and never used. |
| Legend for reused symbols | Yes | `<div class="legend" ...><b>Legend</b>` with yours, theirs and Blank swatches, and a node key: "Nodes: ✕ fight ● elite (red, harder) $ shop (charms and slammers) ▲ rest (heals 30%) boss ...". |
| Three text registers (criterion: every callout and card carries an italic story line, roman rule text and a small italic parameter line where the design has them) | Yes | `class="story"`, `class="rule"` and `class="param"` each occur 23 times. That is one per callout (11: five steps, six risks) and one per card (12: three slammers, nine effects). Example: `<p class="story">The plain hit.</p><p class="rule">Other side takes 4.</p><p class="param">value 4</p>`. `.story` is italic, `.rule` is roman, and `.param` is italic at 8pt. |
| Repeated things as identical cards (same box anatomy, same slots filled) | Yes | Nine `<div class="card eff">` share one anatomy: icon and name in `.head`, a `.sub` role line, then story, rule and param. Three `<div class="card slam">` share a drawing, head, sub, story, rule and param. |
| Time or difficulty drawn, not described | Yes | The run map sits on a 0 to 50 minute ruler, "minutes into the run (40 to 50 total)", with zones EASIER, HARDER and BOSS COUNTRY and a health line. A 0 to 3 s bar is split into drop, "effects, one by one" and card, with a red stop at 3 s. |
| One surface, no navigation, nothing hidden | Yes | One `<main class="poster">`. There is no `<a>`, `<details>`, `<script>`, `<iframe>` or `display:none`, and fit-check is clean. The only matches for hidden are `overflow:hidden` and `aria-hidden`. |
| Surface sized in inches with print CSS | Yes | `:root { ... --w:26in; --h:17in; }`, `@page { size: var(--w) var(--h); margin:0; }`, and an `@media print` rule. |
| Self-contained (no external resources) | Yes | No `http` strings, no `<link>` and no `<script>`. The style and SVG are inline, in a Georgia font stack. |

Score: 11 of 11 present (round 1: 10 of 11). The registers row moved from absent to present.

### Margin budget, judged from the PNG

Not met.

- **Share of the surface.** The central depiction covers about a fifth of the sheet: the tower, strip, slammer, pile and health bars fill about 742 x 675 px of a 1926 x 1260 px surface. The run map adds about a sixth. Together the depictions cover roughly 37%. The left text column, the slammer cards and the right card column cover about 40%. In round 1 the tower and strip covered about 18% and the run map about 27%, so the share did not grow; the central tower is drawn smaller than in round 1. The extra lines per callout from the register slot add to the margin text.
- **Callouts point at one spot.** Partly met. Steps 1 to 5 and risks A to D point at spots on the drawing. Risk E points at the charms drawing in the right margin and risk F at the 3 s bar in the left margin, not at the depiction. The roster, merge, take-or-remove and slammers-owned drawings in the right margin are small pictures. Nothing on the depiction points to them.
- **One entry point.** Partly met. The title reads first and the coloured tower is the strongest mass after it. The left margin's section labels and step headings are 15pt bold, larger than the depiction's largest labels: "SLAMMER" and "16 pogs: 8 yours + 8 theirs, shuffled" are both `font-size="20"`, which is 14.4pt. They compete with the tower for second place.
- **Round 1 gaps.** The empty top-left of round 1 is gone, because the five moments fill it. The reviewer's "reference sheet with a picture in the middle" still describes the page.

Round 3 was not run. The controller's rule triggers round 3 on a failed anatomy row or a fit-check finding, and there are none. The margin-budget recipe did not bind on this run; see the Task 8 report.
