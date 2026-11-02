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

## Round 3 (measurable margin budget)

Changes under test:
- **Margin budget.** "The margin budget" is rewritten with numbers. The depiction's box covers at least half the surface and is the widest thing on the page. The title and the depiction's labels are the only tier-one text, and margin text is 11 pt or less. There are at most eight callouts, each with a leader ending on the depiction, and at most three card sets along one or two edges.
- **Contract.** The contract carries the same numbers as a required item.
- **Step 4.** Tier one in step 4 now reads "the title and the big labels on the depiction"; the legend was dropped from it to match.
- **Fit-check.** Fit-check reports `callouts: N` and flags more than 8. On the round 2 page it now gives `- callouts: 11 exceeds 8` and exits 1.

Run: one fresh `general-purpose` subagent on model `sonnet`, with the same prompt as round 2 and the round 3 output path. Its reply did not come back to me, so this record is scored from the HTML and the PNG only.

Output: output/2026-11-01-pog-roguelike-with-skill-round3.html, 626 lines. Preview: output/2026-11-01-pog-roguelike-with-skill-round3.png.

Fit-check, verbatim, exit code 0:
```
callouts: 8
surface: 26.0 x 15.0 in
preview: tests/results/output/2026-11-01-pog-roguelike-with-skill-round3.png
```
Findings: 0.

Shape chosen: one framed scene of a single slam fills the middle of the sheet. It holds both rosters above the tower, the 16-disc tower with the Dome slammer and its aim mark, and the strip of rows 1 to 16. It also holds the top-down results with a summary card, the take-or-remove panel, the three slammer cards and the pile and discard. Under it, in a framed band of the same width, is the 12-stop run map on a minutes ruler. Eight numbered callouts sit in the left and right margins, three on the left and five on the right. Eight effect cards stack along the left edge and the legend sits on the right. This shape differs from rounds 1 and 2. There, the tower stood in a column between two margins of cards and text. Here the drawing is one wide scene, and the margins are narrow strips.

Centre of the PNG: a blue and orange tower of 16 discs with the grey Dome slammer above it and a red aim mark on the top disc. Red curved arrows show the flipped discs, and a "DOME REACHES ABOUT 5" bracket spans the top rows. The strip highlights rows 1, 2, 4 and 5 with "THEM −2", "THEM −4", "YOU −3" and "YOU +3", and a summary card reads "THEM −6 / YOU ±0".

| Anatomy item | Present? | Evidence |
|---|---|---|
| Title states the point of the page | Yes | `<h1 class="title t1">One shared tower, one slam: every pog that lands face up fires for the slammer, whoever put it there.</h1>`, `.title { top: 0.3in; left: 0.5in; ...}`. |
| Date on the page | Yes | `<footer class="date">Design proposal · 2026-11-01</footer>`, `.date { bottom: 0.3in; right: 0.5in; ...}`. |
| One depiction holding the middle | Yes | `<svg viewBox="0 0 2600 1500" ...>` with the scene frame `<rect x="420" y="130" width="1800" height="1100" ...>` holding the tower, strip and slammer. The run map is in `<rect x="420" y="1262" width="1800" height="215" ...>`. |
| Callouts tied to the depiction (leader lines or numbers) | Yes | 8 `<div class="callout">` numbered "1. Aim and drop" to "8. The run", and 8 `<path class="leader">` ending on numbered circles in the drawing. For example, `M2240,240 L1150,240` runs from callout 1 to the slammer and `M2240,1125 L2160,1125` from callout 6 to the discard pile. |
| Legend for reused symbols | Yes | `<div class="legend" ...><b ...>LEGEND</b>`: you put the pog in, they did, flipped face up, Blank, H heavy, S slick, T sticky, "All numbers are placeholders for tuning." The run map has its own key: fight, elite, shop, rest. |
| Three text registers (every callout and card carries an italic story line, roman rule text and a small italic parameter line where the design has them) | Yes | `class="story"`, `class="rule"` and `class="param"` each occur 16 times, one per callout (8) and per effect card (8). Example: `<p class="story">The honest hit.</p><p class="rule">Deals 4 to the slammer's opponent.</p><p class="param">value 4 · placeholder</p>`. The three SVG slammer cards carry an italic line ("flips the top few") and a drawn reach bar in place of a parameter line. |
| Repeated things as identical cards (same box anatomy, same slots filled) | Yes | 8 `<div class="card ec">`, each with an icon and name in `.head`, a `.sub` target line, then story, rule and param. Three slammer cards in the SVG share one anatomy: a drawing, a name, an italic line and a 16-cell reach bar from top to bottom. |
| Time or difficulty drawn, not described | Yes | The run map sits on a 0 to 50 minute ruler with zones "easier", "rising" and "hard, then the boss", and a red bar over 40 to 50. A "3 SECOND TURN BUDGET" bar is split into drop, "4 pops" and card. |
| One surface, no navigation, nothing hidden | Yes | One `<main class="poster">`. There is no `<a>`, `<details>` or `<script>`, and fit-check is clean. |
| Surface sized in inches with print CSS | Yes | `--w: 26in; --h: 15in;`, `@page { size: var(--w) var(--h); margin: 0; }`, and an `@media print` rule. |
| Self-contained (no external resources) | Yes | No `http` strings, no `<link>` and no `<script>`. |

Score: 11 of 11 present.

### Margin budget, by measurement

Coordinates are viewBox units at 100 per inch on a 26 x 15 in surface, which is 390 sq in.

| Predicate | Measured | Met? |
|---|---|---|
| Depiction box at least half the surface | Scene frame alone: 1800 x 1100 units, 18 x 11 in, 198 sq in, 50.8%. Scene and run map together: x 420 to 2220, y 130 to 1477, 18 x 13.5 in, 242 sq in, 62%. | Yes |
| Depiction is the widest thing on the page | The scene frame and the run band are both 18 in wide. The title is set in a 22 in box and its text runs about 20.5 in in the PNG. | Partly: the title is wider |
| Title and depiction labels are the only tier-one text; margin text 11 pt or less | Largest margin text: 10 pt. That covers `.callout h3` and `.card .head` at 10pt and the two inline `font-size:10pt` labels "EFFECTS: placeholder numbers, one card each" and "LEGEND". Callout body text is 9pt, card body 8pt and params 7pt. The largest labels inside the scene are 28 units, 20.2 pt ("DOME", "THEM −6"), and the run map heading is 19 units, 13.7 pt. | Yes |
| At most eight callouts, each leader ending on the depiction | `callouts: 8`. Seven leaders end inside the scene frame: at the slammer, the rosters, the take-or-remove panel, strip row 3, the results, the discard and the Dome card. Leader 8 ends on the boss in the run map. | Yes if the run map counts as part of the depiction; 7 of 8 if only the scene frame does |
| At most three card sets, along one or two edges | Two sets. The 8 effect cards stack along the left edge, and the 3 slammer cards sit along the bottom of the scene frame. | Yes |

Judgement: met on measurement. Two points are open for the final review:
- **Title width.** The title is wider than the depiction, which goes against "the widest thing on the page" if the title counts. The recipe does not say whether it does.
- **Run map.** Whether the run map is part of the depiction decides whether the box predicate reads 62% or 50.8%. It also decides whether callout 8 ends on the depiction. Under both readings the box is at least half the surface.

Against round 2: callouts went from 11 to 8 and the largest margin text from 15 pt to 10 pt. The central drawing went from about 21% of the surface to 50.8%. Round 3 is the last round; the controller ruled out a round 4.

## Final run (after the final-review fix wave)

Changes under test, all from the final review:
- **Common mistakes.** They no longer cite earlier runs or this scenario's tower. Each is stated generally and points at a method step or contract slot. The overview draws "the level" instead of "the tower".
- **Contract.** The size is declared on `:root` and read by the poster and the print CSS.
- **Step 3, route A.** The PNG is embedded as a `data:` URI. Route B was used, so this did not bind.
- **Step 5.** The agent opens the preview PNG and checks for cut or overlapping content. The page is printed to PDF, then on a plotter or through a PDF reader's tile option.
- **Fit-check.** A full-surface SVG whose viewBox is not 100 units per inch of the surface is a finding. SVG text is measured at the layer's real scale.

Run: one fresh `general-purpose` subagent on model `sonnet`. It was given the line "Use the one-page-design skill at /Users/cesar/.claude/skills/one-page-design/SKILL.md." followed by `tests/scenarios/pog-roguelike.md` verbatim, with the output path filled in. Its reply did not come back to me, so this record is scored from the HTML and the PNG only.

Output: output/2026-11-01-pog-roguelike-with-skill-final.html, 476 lines. Preview: output/2026-11-01-pog-roguelike-with-skill-final.png.

Fit-check, the updated script, verbatim, exit code 0:
```
callouts: 8
surface: 28.0 x 17.5 in
preview: tests/results/output/2026-11-01-pog-roguelike-with-skill-final.png
```
Findings: 0. The drawing layer is `viewBox="0 0 2800 1750"` on a 28 x 17.5 in surface, which is 100 units per inch, so the new viewBox check passes.

Preview inspected by eye at preview resolution: nothing is cut at the edges, and no two elements overlap.

Shape chosen: one framed panel holds the whole game. Its upper part is a scene of one slam. You (O) are on the left with charms and roster, and the foe (X) is on the right with its roster. The 16-disc tower sits in the middle under a Dome slammer and aim line, with flipped pogs in the air and a "dome usually reaches here" bracket. The strip lists rows 1 to 16 beside it. To the right, the top-down resolution shows four numbered results and a summary card on a 3 s turn-budget ruler. The fresh pile and discard sit below the tower. A dashed rule divides the lower part of the same frame, which holds the 12-node run map with one red route, a health line and a 0 to 50 minute ruler. The slammer cards and effect cards are on the left edge, and the risk cards are on the right.

| Anatomy item | Present? | Evidence |
|---|---|---|
| Title states the point of the page | Yes | `<h1 class="title t1">Whatever lands face up works for the slammer, whoever put it there</h1>`, top-left. |
| Date on the page | Yes | `<footer class="date">Design proposal · 2026-11-01</footer>`, bottom-right. |
| One depiction holding the middle | Yes | `<svg viewBox="0 0 2800 1750" ...>` with the frame `<rect x="540" y="190" width="1720" height="1460" ...>` holding the tower, strip, slammer, rosters, resolution, pile, discard and run map. |
| Callouts tied to the depiction (leader lines or numbers) | Yes | There are 8 `<div class="callout">` and 8 callout leaders (`<polyline class="leader">`), each ending inside the frame: `1120,150 1120,274` at the slammer, `1480,150 1276,548` at the strip, `505,270 588,368` at the charms, `505,460 590,456` at the roster, `505,1070 650,1020` at the fresh pile, `2280,760 2228,723` at the resolution, `2280,1010 2214,1028` at the dud line, and `2280,1370 2016,1370` at the boss. Circled 1 to 5 on the drawing match the numbered callouts. Four more leaders join strip rows to result cards inside the drawing. |
| Legend for reused symbols | Yes | The legend row under the tower reads: O you, X foe, your pog, foe pog, Blank, lands face up, slammer reach, letters = effect initial. The run map has its own key: fight, elite, shop, rest, boss and the red route. |
| Three text registers (every callout and card carries an italic story line, roman rule text and a small italic parameter line where the design has them) | Yes | `story`, `rule` and `param` each occur 25 times: once per callout (8) and per card (17). Example: `<h3>Charms: three slots</h3><p class="story">Small numbers, big habits.</p><p class="rule">Number-only items that fire only on the holder's own slam, ...</p>` followed by a `.param` line. |
| Repeated things as identical cards (same box anatomy, same slots filled) | Yes | There are 17 `<div class="card">` in three sets: 3 slammer cards (head, coloured sub-line, story, rule, param, a drawing and a reach bar), 8 effect cards and 6 risk cards (head, coloured sub-line, story, rule, param). |
| Time or difficulty drawn, not described | Yes | The run map sits on a 0 to 50 minute ruler with a red "target finish: 40 to 50 min" band and a health line across the nodes. A 0 to 3 s ruler sits under the resolution. |
| One surface, no navigation, nothing hidden | Yes | One `<main class="poster">`. There is no `<a>`, `<details>`, `<script>` or `<link>`, and fit-check is clean. |
| Surface sized in inches with print CSS | Yes | `--w:28in; --h:17.5in;` on `:root`, `@page { size: var(--w) var(--h); margin:0; }`, and an `@media print` rule. The poster reads `var(--w)`/`var(--h)`. |
| Self-contained (no external resources) | Yes | No `http` strings, no `<link>` and no `<script>`. |

Score: 11 of 11 present.

### Margin budget, by measurement

Coordinates are viewBox units at 100 per inch on a 28 x 17.5 in surface, which is 490 sq in.

| Predicate | Measured | Met? |
|---|---|---|
| Depiction box at least half the surface | Frame x 540 to 2260, y 190 to 1650: 17.2 x 14.6 in, 251.1 sq in, 51.2%. The run map is inside the frame this time, so there is one reading. | Yes |
| Depiction is the widest thing on the page, apart from the title | Frame 17.2 in. Next widest: the lede under the title at 9.8 in, then the card columns and callouts at 4.7 to 4.8 in. | Yes |
| Margin text 11 pt or less | Largest margin text: 10.5 pt (`.callout h3`). The lede and card heads are 10 pt, the legend and set heads 9 pt, callout body 8.5 pt, card body 8 pt and params 7 to 7.5 pt. | Yes |
| At most eight callouts, each leader ending on the depiction | `callouts: 8`. All 8 callout leaders end inside the frame (see the anatomy table). | Yes |
| At most three card sets, along one or two edges | Three sets: slammers (3) and effects (8) on the left edge, and risks (6) on the right edge. | Yes, at the cap |

Judgement: the margin budget is met on measurement, with no open readings. Compared with round 3: the run map moved inside the frame, removing round 3's open question. The depiction share is 51.2% against round 3's 50.8% for the scene alone. The card sets went from two to three, which is at the cap.

Observation for the reviewer: the page has the same overall form as round 3. It is a framed panel of about half the surface, with narrow margins of callouts and cards. The no-single-focal-point weakness from the final review persists. The frame holds a scene, a strip, a resolution panel and a run map at similar weight.
