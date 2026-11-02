---
name: one-page-design
description: Use when someone asks for a one-page design, a one-pager, a design poster or placemat, a design on one sheet, something to hang on a wall or hand out in a meeting, or says a design document is too long or nobody reads it; also when a deliverable is specified as a one-page design. Not for reports, slide decks or dashboards.
---

# One-page design

## Overview

A one-page design is one continuous surface, as large as the design needs,
with nothing hidden behind navigation, built around a picture of the thing
itself with the words hung off it. The method is Stone Librande's. The
page's shape comes from the design's shape; no two pages share a layout.

**Core principle: depict, then annotate.** A diagram describes a system
from outside. A depiction shows the thing. Draw the tower, the island, the
castle, the O and the X on the floor; then hang the words off the drawing.

## When to use

- Someone wants a design others will actually read, on a wall or a table.
- A design document has grown past what anyone reads.
- A fleet or team deliverable is specified as a one-page design.

Not for: status reports, slide decks, dashboards, API references.

## The method

1. **Name the one thing this page must communicate.** That is the title.
   If it cannot be named in a sentence, stop: there is no page to make yet.
2. **Find the design's native shape.** Ask what a photo of this design
   would look like, and plan to draw that. Use the Shapes table in
   `grammar.md`: a space becomes a plan or isometric view; an object, the
   object; a journey over time, a map with a time ruler; a procedure,
   circled moments on the world; a set of like things, cards; two things
   crossed, a matrix; things that affect each other, a triangle with its
   axes on its edges. Screen flow, and only screen flow, is a flowchart.
   Most pages combine two shapes. If no shape fits on one surface, say so
   to the person: the design is probably too complex.
3. **Build the centre first**, before any prose, by one of two routes:
   - **Route A, commission it.** Fill `brief-template.md` and hand it to
     whoever draws (a model, an agent, a person). Place the PNG with
     `<img>` and keep the brief beside it as an HTML comment. The image
     must carry no text; if it comes back with text, re-commission, do not
     accept it. Use route A for scenes and objects.
   - **Route B, draw it.** Inline SVG from `kit.md`. Use route B when no
     illustrator is available, or when the picture must stay exact and
     editable: a map with positions, a matrix, a card grid.
   Either way every label, number, leader line, card and legend is HTML or
   SVG over the picture, never inside it.
4. **Hang the words off the picture, in three tiers.** Tier one reads
   across the room: the title and the big labels on the depiction. Tier
   two at arm's length: callouts tied to the picture by leader lines or
   shared numbers, cards with one anatomy. Tier three is fine print: parameters in small
   italics, formulas in a monospace box. SVG font sizes are in viewBox
   units: at 100 per inch the floor is 8.4. Anything that would need a
   fourth tier comes off the page. Draw time and difficulty (a ruler, dividers,
   zones) instead of describing them.
5. **Date it, size it, hand it over.** Start from `scaffold.html`. Set the
   surface size in inches on `:root` (`--w`, `--h`); the poster reads it, and so does the print CSS: begin at the size that
   shows the centre legibly, grow until the tiers fit, stop. Date in the
   bottom-right. Run the fit-check:

   ```bash
   python3 scripts/fit-check.py page.html --preview page.png
   ```

   Fix every finding. Deliver the HTML file; it prints as one piece on a
   plotter and tiles on a desk printer.

## The page, stated as a contract

A finished page has, and a reader can point to each:

- a title, top-left, that states the point of the page;
- a date, bottom-right;
- one depiction holding the middle, drawn or commissioned, of the thing
  itself;
- callouts in the margins, each tied to the depiction by a leader line or
  a shared number;
- a legend if any symbol repeats;
- repeated things as cards with identical anatomy;
- **required:** each callout and card carries an italic story line, roman
  rule text and a small italic parameter line, where the design has them.
  Callouts and cards set in one register fail this item;
- **required:** a depiction covering at least half the surface; margin
  text at 11 pt or less; at most eight callouts, each pointing at the
  depiction; at most three card sets;
- time and difficulty drawn, where the design has them;
- one surface: no links, tabs, collapsed, hidden or hover-only content;
- a size in inches on the poster, and print CSS to match;
- no external fonts, scripts or stylesheets.

If the fit-check reports the surface above 44 inches, the design is too
complex for one page. Cut tiers or split the design; never shrink the
fine print below 6 pt.

### The margin budget

The depiction's bounding box covers at least half the surface, and it is
the widest thing on the page. The title and the depiction's own labels
are the only tier-one text; all margin text, card and callout headings
included, is tier two or smaller, 11 pt or less. The page has at most
eight callouts, and every callout's leader ends on the depiction itself.
Everything else that must be on the page belongs to one of at most three
card sets, placed along one or two edges.

## Quick reference

| Need | Use |
|---|---|
| the vocabulary of these pages | `grammar.md` |
| SVG and HTML parts to copy | `kit.md` |
| a brief for an illustrator | `brief-template.md` |
| the surface and print CSS | `scaffold.html` |
| the squint test | `python3 scripts/fit-check.py` |
| what a good page looks like | `examples/librande/README.md` and the slides |

## Common mistakes

- **Headed sections and bullet lists.** That is a document on a poster,
  not a one-page design. The fix is step 2: find the shape and draw it.
- **Boxes and arrows for everything.** Flowcharts are for screen flow
  only. A loop in the world is drawn in the world.
- **Text baked into a generated image.** Misspelt, unsearchable,
  uneditable. Labels go over the picture.
- **Shrinking the font to fit.** Below 6 pt, cut content or grow the
  surface.
- **A fixed sheet size.** The surface fits the design, not the printer.
- **Leaving the date off.** Printed copies cannot be told apart.
- **Tables and prose for a game with a world.** The no-skill run chose a
  scrolling page of tables so a reader could "follow the order of play",
  and drew nothing: no tower, no strip, no centre. Draw the thing first.
- **Drawing the timeline but telling the claim.** The no-skill run drew
  one SVG strip, then put the verdict in a text box above it, left the
  date off, rewrote the claim in prose and sized the page in px with no
  print CSS. The title states the claim; the drawing shows it.
- **Margins fuller than the picture.** One run hung twenty cards round the
  tower. Spend the margin budget.
- **Registers defined, never used.** One run set every parameter in roman.
  Fill the required register slot.
