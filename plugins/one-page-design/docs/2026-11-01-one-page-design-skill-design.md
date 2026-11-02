# One-page design skill: design spec

Date: 2026-11-01. Status: draft for operator review.

## Purpose

A personal skill that turns any design (a feature set, a system, a mechanic,
a level, a run structure, a flow) into a one-page design document in Stone
Librande's sense: one continuous surface, as large as the design needs,
with nothing hidden behind navigation, built around a picture of the thing
itself with the words hung off it.

It is for the operator directly and for any agent the operator points at
it. It does not replace other document templates; it wraps their content.

Source material: Librande's GDC talk "One-Page Designs" (transcript read in
full) and fourteen slides from it, kept in `examples/librande/`.

## Where it lives

`~/.agents/skills/one-page-design/`, symlinked into `~/.claude/skills/`.
Versioned with its own git repository.

## What the skill is not

- Not a layout template. Every page is unique; its shape comes from the
  design's shape. The only fixed things are the anatomy (below) and the
  print scaffold.
- Not a chart tool. Boxes and arrows are demoted to one use: screen and
  menu flow.
- Not tied to any model, agent runtime or fleet. The illustration step
  produces a brief any illustrator can take.

## The method (what SKILL.md teaches)

1. **Name the one thing the page must communicate.** That is the title.
   If it cannot be named, stop; there is no page to make.
2. **Find the design's native shape and depict it.** Ask what a photo of
   this design would look like, and draw that. A space becomes a plan or an
   isometric view. An object becomes a drawing of the object. A procedure
   in the world becomes the world with numbered moments on it. A set of
   like things becomes cards, each with a small picture. Two things crossed
   becomes a matrix. Things that affect each other become a relationship
   shape (triangle with axes on its edges, ring, line). A journey over time
   becomes a map with a time ruler. Screen flow, and only screen flow,
   becomes a flowchart with thumbnails in the boxes. Most pages combine
   two shapes. Picking the shape is the design act. A design that fits no
   shape on one surface is probably too complex, and the skill says so.
3. **Build the centre first**, before any prose, by one of two routes
   (below).
4. **Hang the words off the picture, in three tiers.** Tier one is
   readable from across the room: title, the big labels, the legend. Tier
   two at arm's length: callouts tied to the picture by leader lines or
   shared numbers, cards. Tier three is fine print: parameters, formulas,
   notes. Anything that would need a fourth tier comes off the page.
5. **Date it, size it, hand it over.** The surface is sized to the content,
   not the content to a sheet. Start from the size that shows the centre at
   legible scale, grow until the tiers fit, stop. If it is growing past
   what a plotter prints, the design is too complex; do not shrink the
   font. Date in the bottom-right. Deliver a file people can print and
   scribble on.

## Page anatomy (fixed across every page)

- Title, top-left, large, stating the point of the page.
- Date, bottom-right, with an optional label such as "Proposal".
- One main depiction holding the middle.
- Callouts in the margins, tied to the depiction by thin leader lines or
  shared numbers (1A, 1B, 2–3).
- A legend wherever a symbol is reused.
- Insets where useful: a world thumbnail, a plan beside an isometric, a
  mini-map in a corner.
- Three text registers: italic for story and flavour, roman for rules,
  small italic lists for parameters. Formulas in a monospace box.
  Procedures as circled numbers, one sentence each, a drawing under each.
- Repeated things as cards with identical anatomy: rounded box, header line
  (number plus name), coloured sub-line (level, time), rows of icon, name,
  note. Design the card once, fill the page by repeating it.
- Each page defines a tiny visual vocabulary and keeps to it (O is the
  player, X the monster, a burst is a hit, blue is an area). Cheaper than
  prose, readable from across the room.
- Time and difficulty are drawn: rulers along an edge, vertical dividers,
  bands and zones on the map, levels descending the page.
- Colour: soft fills, dark outlines, one accent per category, grey for the
  rest. A placemat, not a dashboard.
- Working-document feel: the page expects pen marks.

## The hard rule

One surface, zero navigation. No second page, no tabs, no links to
elsewhere, no collapsed or hover-only content. Everything in the design is
visible when the page is printed. Legibility is measured at print: tier
three has a floor in points, and below it content comes off or the surface
grows.

## The centre: two routes

**Route A, commissioned illustration.** The skill writes an illustrator
brief: subject, view (isometric, plan, side-on, scene), style (flat
placemat illustration, soft fills, dark outlines, white background), what
must be present, what must be absent, and the rule that the image carries
no text or labels. Output: a PNG at the largest size the illustrator can
give, saved to a path the skill names. Who takes the brief is not the
skill's concern: an image model, an agent with image tools, a human. The
brief is kept in the page as an HTML comment beside the image so
regeneration is one step.

**Route B, drawn by hand.** Inline SVG from a primitives kit: isometric
tiles and blocks, a plan-view room, a map blob with terrain, a path with
numbered waypoints, tokens and dots, a figure silhouette, O and X, a burst,
a zone. Used when no illustrator is available, or when the picture must
stay editable or exact (a map with positions, a matrix, a card grid).

In both routes every label, number, leader line, card and legend is HTML
or SVG laid over the picture, never baked into it. Supplied art (concept
images, screenshots, sprites) is embedded directly where it exists.

An honest limit, written into the skill: hand-built SVG is plainer than
Illustrator work. The response is to keep depicting concrete things and
keep them simple, not to retreat to boxes.

## The scaffold

`scaffold.html`: one poster element whose width and height are set per
design, in inches. Print CSS sets the page size to exactly those
dimensions, so the page prints to PDF at the declared size. Print the
PDF on a plotter, or use a PDF reader's poster or tile option for a desk
printer. (Corrected 2026-11-01: this sentence first said a desk printer
tiles the page; it does not, since browsers print an oversized page as one
PDF page that a desk printer scales down or crops.) Screen CSS shows it at true proportions with zoom and pan. A header
band holds title and date. Nothing else is fixed: no sections, no columns,
no placeholder text. Self-contained: no external scripts or fonts.

## The fit-check

`scripts/fit-check.py`: renders the HTML headless (if a headless browser
is available; otherwise parses statically and says so) and reports:
surface size in inches; any anchor to another page, hidden element,
collapsed element or hover-only text; any text below the legibility floor
at print. It is the "print it and squint" step. It never edits the page.

## Skill file layout

```
one-page-design/
  SKILL.md             method, anatomy, hard rule, routes, triggers
  grammar.md           the visual grammar with one example each, and
                       which slide shows it
  kit.md               SVG primitives and the card pattern, copy-and-adapt
  brief-template.md    the illustrator brief
  scaffold.html        the surface
  scripts/fit-check.py
  examples/librande/   fourteen slides, each with a one-line note on
                       what to learn from it (README.md)
  docs/                this spec
```

## Description (triggering only, no workflow)

Use when someone asks for a one-page design, a one-pager, a design poster
or placemat, a design on one sheet, something to hang on a wall or hand
out in a meeting, or says a design document is too long or that nobody
reads it; also when a document's deliverable is specified as a one-page
design. Not for reports, slide decks or dashboards.

## Testing (per the skill-writing rules)

1. **Baseline, no skill.** A fresh subagent gets the Pog Roguelike design
   state and "make a one-page design document for this". Record what it
   produces verbatim. Expected failure: a scrolling page of headed sections
   and bullets, maybe a Mermaid chart, no date, no centre, nothing drawn.
2. **With the skill, same prompt.** Check against the anatomy and the hard
   rule, item by item.
3. **A second scenario of a different shape** (one mechanic, or a run over
   time) to prove the skill does not force every design into one layout.
4. **Fit-check** on every output.
5. **Micro-test the wording** of the two guidance forms most likely to be
   negotiated (the hard rule, and "depict, don't diagram") against a
   no-guidance control, five reps each, before the full scenarios.

## Out of scope for now

- Fleet integration (a `kind:` other than claude in the wrapper, an
  illustrator persona). The operator will set that up later.
- Any particular image model or agent.
- A PDF export step. Browsers print the HTML.

## Open questions

- Legibility floor in points for tier three at print: proposed 6 pt,
  operator to confirm or change.
- Whether `fit-check` should also emit a PNG preview for a quick look.
