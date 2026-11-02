# One-Page Design Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A personal skill at `~/.agents/skills/one-page-design/` that turns any design into a Librande-style one-page document as a single printable HTML surface, tested the way the writing-skills skill requires (baseline failure first, then the skill, then loophole closing).

**Architecture:** The skill is a method (SKILL.md) plus a visual-grammar reference, a drawing kit, an illustrator brief template, an HTML scaffold for the surface, and a fit-check script. No layout template: the page's shape comes from the design. Skill text is tested with subagent scenarios; the script is tested with pytest.

**Tech Stack:** Markdown, HTML with inline SVG and CSS, Python 3 standard library for the script (headless Chrome optional for a PNG preview), pytest for the script's tests, the Agent tool for skill scenarios, git.

**Spec:** `/Users/cesar/.agents/skills/one-page-design/docs/2026-11-01-one-page-design-skill-design.md`

## Global Constraints

- One surface, zero navigation: no second page, tabs, links, collapsed, hidden or hover-only content. Everything visible when printed.
- Legibility floor at print: tier-three text is never below 6 pt (spec open question, taken as 6 pt unless the operator changes it).
- The surface is sized to the content, in inches, set per design on the poster element. Print CSS sets the page size to exactly those dimensions.
- The HTML is self-contained: no external scripts, stylesheets or fonts.
- Labels, numbers, leader lines, cards and legends are HTML or SVG laid over the picture, never baked into a generated image.
- The illustrator brief is model-agnostic: it names no model, runtime or fleet.
- The skill's `description` states triggering conditions only, never the workflow.
- Every page is unique; the skill never ships a fill-in layout.
- Paths: the skill lives at `/Users/cesar/.agents/skills/one-page-design/` and is symlinked as `/Users/cesar/.claude/skills/one-page-design`.

## Review Focus

1. A design with nothing spatial in it (a pricing rule, a scoring formula): a reader expects a depiction anyway, as cards or a matrix or a worked example, not a retreat to headed prose. Pinned in Task 7, scenario 2.
2. A design too big for one surface: the fit-check should say the surface exceeds a plotter's 44 in roll rather than letting the page grow silently. Pinned in Task 2 (`test_warns_above_plotter_width`).
3. A page that links a Google Font or a CDN script: it would print differently offline. The fit-check flags any external resource. Pinned in Task 2 (`test_flags_external_resources`).
4. A commissioned illustration that came back with text baked in: the brief forbids it and the skill's step says to re-commission, not to accept. Pinned in Task 4 (brief template has the rule as a REQUIRED line) and Task 5 (SKILL.md route A step).
5. A page viewed on a phone or narrow window: the surface must keep its true proportions and allow pan, not reflow into a column. Pinned in Task 2 (`test_scaffold_has_fixed_surface_and_print_size`).

---

### Task 1: Baseline scenarios (RED for the skill text)

**Files:**
- Create: `tests/scenarios/pog-roguelike.md`
- Create: `tests/scenarios/single-mechanic.md`
- Create: `tests/baselines/README.md`
- Create: `tests/baselines/2026-11-01-no-skill-pog-roguelike.md` (filled by the run)
- Create: `tests/baselines/2026-11-01-no-skill-single-mechanic.md` (filled by the run)

**Interfaces:**
- Produces: two scenario prompts reused verbatim in Task 7, and two recorded baselines that Task 5's "Common mistakes" section is written against.

- [ ] **Step 1: Write scenario 1, the Pog Roguelike feature set**

`tests/scenarios/pog-roguelike.md`:

```markdown
# Scenario: Pog Roguelike, whole-game feature set

You are a game designer's assistant. Produce a one-page design document for
the game below, as a single HTML file written to the path given at the end.
The reader is a programmer who has never seen the design. They should get
the whole game from the page.

## The design

Single-player roguelike on desktop, mouse and controller, against AI
opponents. Core loop: one stack of pogs built from both combatants' rosters
combined. You aim a slammer and it drops with real physics. Pogs that land
face up activate their effect for the slammer, whoever contributed them;
effects can help or hurt the slammer. Everything that did not flip is
shuffled into a fresh pile. When the pile is low, the discard is shuffled
back in. Turns alternate until one combatant is dead.

Readability: a 3D tower in the middle, and a strip beside it listing every
pog top to bottom with its icon, value and contributor colour, plus a
bracket showing how deep the chosen slammer usually reaches from the aim
point. Effects resolve one at a time top-down, each with a number popping
up, then a summary card.

Slammers: three, by striking-face shape. Dome (flips the top few), Ring
(hollow, tips one side), Flat (broad, reaches deep). You own up to three and
choose one before each fight after seeing the opponent's roster.

Effects (placeholders): Strike 4, Heal 3, Poison 3 (hurts the slammer),
Guard 3, Drain 2, Recoil (them -6, you -2), Deep Strike (doubled from the
bottom half), Capstone (+2 if on top). Pogs may be Heavy, Slick or Sticky.

Roster: eight slots. After each fight take one of three offered pogs into
an empty slot, or remove one, never both. Three copies of a pog merge into
a stronger one (numbers x1.5) and free two slots. An empty slot holds a
Blank pog with no effect so the tower is always 16 high. Opponents field
eight slots too.

Run: a branching map of about 12 nodes ending in a boss, 40 to 50 minutes.
Node types: fight, elite, shop (charms and slammers), rest (heals 30%).
Health carries over between fights. Items are charms: number-only, three
slots, they fire only on the holder's own slam.

Risks the design must answer: an obvious best shot; unreadable outcomes;
shared healing prolonging fights (Heals lose 1 point each reshuffle);
poison stalls (a slam that flips nothing is a dud and costs 1 health);
conversion items erasing trade-offs; long animations (3 s turn budget).

## Output

Write the HTML to: {OUTPUT_PATH}
Then reply with three sentences on what you made and why it is shaped
that way.
```

- [ ] **Step 2: Write scenario 2, a single mechanic with nothing spatial**

`tests/scenarios/single-mechanic.md`:

```markdown
# Scenario: Merge-and-sell economy for a roster game

Produce a one-page design document for the mechanic below, as a single HTML
file written to the path given at the end. The reader is a producer who
needs to know whether this economy punishes impatient picks.

## The mechanic

A player has eight roster slots. After each win they may take one of three
offered pieces into an empty slot, or remove one piece, never both. Three
copies of the same piece merge automatically into one piece with all its
numbers multiplied by 1.5, rounded up, and the two freed slots become
Blanks. A Blank does nothing. A removed piece becomes a Blank. There is no
currency. A run offers about nine such choices. Opponents' rosters are
visible before each fight, including their merged pieces.

The claim to show: an impatient pick (taking a piece that does not belong
to the build because it "sounds good") costs roughly one ninth of the run's
choices to undo, and the slot it occupied sits Blank until the next reward.

## Output

Write the HTML to: {OUTPUT_PATH}
Then reply with three sentences on what you made and why it is shaped
that way.
```

- [ ] **Step 3: Write the baselines README**

`tests/baselines/README.md`:

```markdown
# Baselines

Each file here is a verbatim record of what a fresh subagent produced for a
scenario in `../scenarios/` WITHOUT the skill loaded. Record: the three
sentence reply, the file's line count, a copy of the HTML under
`output/<date>-<scenario>-no-skill.html`, and a checklist of the page
anatomy items it missed. Do not edit a baseline after the fact.
```

- [ ] **Step 4: Run scenario 1 with no skill**

Dispatch a `general-purpose` subagent with the scenario text, `{OUTPUT_PATH}` replaced by
`/Users/cesar/.agents/skills/one-page-design/tests/baselines/output/2026-11-01-pog-roguelike-no-skill.html`.
The prompt must not mention one-page design principles, Librande, posters,
or this skill. Record the reply verbatim.

- [ ] **Step 5: Score the output against the anatomy**

Write `tests/baselines/2026-11-01-no-skill-pog-roguelike.md`:

```markdown
# Baseline: pog-roguelike, no skill, 2026-11-01

Reply (verbatim):
> ...

Output: output/2026-11-01-pog-roguelike-no-skill.html, N lines.

| Anatomy item | Present? | Evidence |
|---|---|---|
| Title states the point of the page | | |
| Date on the page | | |
| One depiction holding the middle | | |
| Callouts tied to the depiction (leader lines or numbers) | | |
| Legend for reused symbols | | |
| Three text registers | | |
| Repeated things as identical cards | | |
| Time or difficulty drawn, not described | | |
| One surface, no navigation, nothing hidden | | |
| Surface sized in inches with print CSS | | |
| Self-contained (no external resources) | | |

Rationalizations or shortcuts seen in the reply (verbatim):
- ...
```

Fill every row from the actual file.

- [ ] **Step 6: Run scenario 2 with no skill and score it the same way**

Same dispatch, output path
`.../tests/baselines/output/2026-11-01-single-mechanic-no-skill.html`,
record to `tests/baselines/2026-11-01-no-skill-single-mechanic.md` with the
same table.

- [ ] **Step 7: Commit**

```bash
cd /Users/cesar/.agents/skills/one-page-design
git add tests
git commit -m "test: baseline scenarios and no-skill results for one-page-design"
```

---

### Task 2: Scaffold and fit-check script

**Files:**
- Create: `scaffold.html`
- Create: `scripts/fit-check.py`
- Create: `tests/test_fit_check.py`

**Interfaces:**
- Produces: `scaffold.html` with a `<main class="poster" style="--w:17in;--h:11in">` element, tier classes `.t1`, `.t2`, `.t3`, header `.title` and footer `.date`.
- Produces: `python3 scripts/fit-check.py PAGE.html [--floor-pt 6] [--max-in 44] [--preview out.png]`. Prints one line per finding, then `surface: W x H in`. Exit 0 with no findings, 1 with findings, 2 on a usage error.
- Produces: `check(html: str, floor_pt: float = 6.0, max_in: float = 44.0) -> tuple[list[str], tuple[float, float] | None]` importable from the script.

- [ ] **Step 1: Write the failing tests**

`tests/test_fit_check.py`:

```python
import importlib.util
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts" / "fit-check.py"
SCAFFOLD = ROOT / "scaffold.html"

spec = importlib.util.spec_from_file_location("fit_check", SCRIPT)
fit_check = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fit_check)

GOOD = """<!doctype html><html><head><style>
@page { size: 17in 11in; margin: 0 }
.poster { width: var(--w); height: var(--h) }
.t3 { font-size: 7pt }
</style></head><body>
<main class="poster" style="--w:17in;--h:11in">
<h1 class="t1">Why the stack is shared</h1>
<p class="t3">fine print</p>
<footer class="date">2026-11-01</footer>
</main></body></html>"""


def run(html, *args):
    p = pathlib.Path("/tmp/fit-check-under-test.html")
    p.write_text(html)
    return subprocess.run([sys.executable, str(SCRIPT), str(p), *args],
                          capture_output=True, text=True)


def test_clean_page_passes():
    findings, size = fit_check.check(GOOD)
    assert findings == []
    assert size == (17.0, 11.0)


def test_reports_surface_size_on_cli():
    r = run(GOOD)
    assert r.returncode == 0
    assert "surface: 17.0 x 11.0 in" in r.stdout


def test_flags_navigation_and_hidden_content():
    html = GOOD.replace("<p class=\"t3\">fine print</p>",
        '<a href="other.html">more</a>'
        '<details><summary>x</summary>hidden</details>'
        '<div style="display:none">gone</div>'
        '<div hidden>gone</div>')
    findings, _ = fit_check.check(html)
    joined = "\n".join(findings)
    assert "link" in joined
    assert "details" in joined
    assert "display:none" in joined
    assert "hidden attribute" in joined


def test_flags_hover_only_text():
    html = GOOD.replace("</style>", ".note:hover .more { display:block }</style>")
    findings, _ = fit_check.check(html)
    assert any(":hover" in f for f in findings)


def test_flags_text_below_floor():
    html = GOOD.replace(".t3 { font-size: 7pt }", ".t3 { font-size: 5pt }")
    findings, _ = fit_check.check(html)
    assert any("5pt" in f and "below" in f for f in findings)
    html2 = GOOD.replace('class="t3"', 'class="t3" style="font-size:4px"')
    findings2, _ = fit_check.check(html2)
    assert any("4px" in f for f in findings2)


def test_flags_external_resources():
    html = GOOD.replace("<head>",
        '<head><link rel="stylesheet" href="https://fonts.googleapis.com/x">'
        '<script src="https://cdn.example/x.js"></script>')
    findings, _ = fit_check.check(html)
    assert sum("external" in f for f in findings) == 2


def test_warns_above_plotter_width():
    html = GOOD.replace("--w:17in;--h:11in", "--w:60in;--h:11in")
    findings, size = fit_check.check(html)
    assert size == (60.0, 11.0)
    assert any("44" in f and "plotter" in f for f in findings)


def test_missing_poster_is_a_finding():
    findings, size = fit_check.check("<html><body><p>hi</p></body></html>")
    assert size is None
    assert any("poster" in f for f in findings)


def test_exit_code_one_with_findings():
    r = run(GOOD.replace("--w:17in;--h:11in", "--w:60in;--h:11in"))
    assert r.returncode == 1


def test_scaffold_has_fixed_surface_and_print_size():
    html = SCAFFOLD.read_text()
    findings, size = fit_check.check(html)
    assert findings == []
    assert size is not None
    assert "@page" in html and "size: var(--w) var(--h)" in html
    assert "overflow: auto" in html  # the viewport pans; the surface never reflows
    assert "<script src" not in html and "<link" not in html
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd /Users/cesar/.agents/skills/one-page-design && python3 -m pytest tests/test_fit_check.py -v`
Expected: errors at import, `scripts/fit-check.py` does not exist.

- [ ] **Step 3: Write the scaffold**

`scaffold.html`:

```html
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>One-page design</title>
<!--
  one-page-design scaffold. The surface is sized to the content, in inches,
  on the <main class="poster"> element's --w and --h. Print CSS makes the
  page exactly that size. Nothing inside the poster is fixed: compose it
  per design (see SKILL.md). Keep everything inline: no external fonts,
  scripts or stylesheets.
-->
<style>
  :root {
    --ink: #1f2328;
    --paper: #fbfaf7;
    --rule: #8a8f98;
    --accent: #c0392b;    /* one accent per page: the thing the page is about */
    --soft-1: #dfe9e3;    /* placemat fills: soft, with dark outlines */
    --soft-2: #e8e3d4;
    --soft-3: #dde3ee;
    --w: 17in;
    --h: 11in;
  }
  @page { size: var(--w) var(--h); margin: 0; }
  html, body { margin: 0; background: #d9d9d9; }
  /* The viewport pans and zooms; the surface never reflows. */
  body { overflow: auto; }
  .poster {
    position: relative;
    width: var(--w);
    height: var(--h);
    margin: 0.5in auto;
    background: var(--paper);
    color: var(--ink);
    font-family: Georgia, "Times New Roman", serif;
    box-shadow: 0 2px 12px rgba(0,0,0,.25);
    overflow: hidden;
  }
  @media print {
    html, body { background: none; }
    .poster { margin: 0; box-shadow: none; }
  }
  /* Three tiers. t1 reads across the room, t2 at arm's length, t3 is fine print. */
  .t1 { font-size: 28pt; font-weight: 700; letter-spacing: .01em; }
  .t2 { font-size: 11pt; }
  .t3 { font-size: 7pt; }
  .story { font-style: italic; }              /* flavour and narrative */
  .rule  { font-style: normal; }              /* rules */
  .param { font-style: italic; font-size: 7pt; color: #444; }  /* parameters */
  .formula { font-family: "Courier New", monospace; font-size: 8pt;
             border: 1px solid var(--rule); padding: 4px 6px; background: #fff; }
  .title { position: absolute; top: 0.4in; left: 0.5in; margin: 0; }
  .date  { position: absolute; bottom: 0.3in; right: 0.5in; font-size: 9pt; color: #555; }
  .callout { position: absolute; width: 2.2in; }
  .callout h3 { margin: 0 0 2px; font-size: 10pt; }
  .callout p, .callout li { margin: 0; font-size: 8pt; }
  .card { position: absolute; width: 1.9in; border: 1px solid var(--ink);
          border-radius: 8px; padding: 4px 6px; background: #fff; }
  .card .head { font-size: 9pt; font-weight: 700; }
  .card .sub  { font-size: 7pt; color: #2b5fa8; }
  .card .row  { display: flex; gap: 4px; align-items: center; font-size: 7.5pt; }
  .legend { position: absolute; border: 1px solid var(--rule); padding: 4px 6px;
            background: #fff; font-size: 7.5pt; }
  svg .leader { stroke: var(--rule); stroke-width: 0.6; fill: none; }
  svg .outline { stroke: var(--ink); stroke-width: 1; }
</style>
</head>
<body>
<main class="poster" style="--w:17in;--h:11in">
  <h1 class="title t1">Title that states the point of the page</h1>
  <!-- centre: the depiction goes here, built before any prose -->
  <!-- margins: callouts, cards, legend, tied to the depiction -->
  <footer class="date">Proposal · 2026-11-01</footer>
</main>
</body>
</html>
```

- [ ] **Step 4: Write the fit-check script**

`scripts/fit-check.py`:

```python
#!/usr/bin/env python3
"""fit-check: the "print it and squint" step for a one-page design.

Static checks on a single HTML file:
  - the surface: <main class="poster" style="--w:..in;--h:..in">
  - navigation or hidden content (links, details, hidden, display:none,
    visibility:hidden, :hover rules, iframes, overflow scroll inside)
  - text below the legibility floor (font-size in pt or px)
  - external resources (link/script/img with http(s) src)
  - a surface wider or taller than a plotter roll (44 in)
Optional: --preview out.png renders with headless Chrome if present.
Exit 0: no findings. 1: findings. 2: usage error.
"""
import argparse
import re
import shutil
import subprocess
import sys
from html.parser import HTMLParser

PX_PER_PT = 96 / 72
PLOTTER_IN = 44.0

_LEN = re.compile(r"(\d+(?:\.\d+)?)\s*(in|cm|mm|pt|px)")
_FONT = re.compile(r"font-size\s*:\s*(\d+(?:\.\d+)?)\s*(pt|px)", re.I)
_VAR = re.compile(r"--(w|h)\s*:\s*(\d+(?:\.\d+)?)\s*(in|cm|mm)")


def _inches(value, unit):
    return {"in": value, "cm": value / 2.54, "mm": value / 25.4}[unit]


class _Walker(HTMLParser):
    def __init__(self):
        super().__init__()
        self.findings = []
        self.size = None
        self._in_style = False
        self.styles = []

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        cls = (a.get("class") or "").split()
        style = a.get("style") or ""
        if tag == "main" and "poster" in cls:
            w = h = None
            for m in _VAR.finditer(style):
                v = _inches(float(m.group(2)), m.group(3))
                if m.group(1) == "w":
                    w = v
                else:
                    h = v
            if w is None or h is None:
                self.findings.append("poster: --w and --h must be set in inches on <main class=\"poster\">")
            else:
                self.size = (w, h)
        if tag == "a" and a.get("href"):
            self.findings.append(f"link: <a href=\"{a['href']}\"> is navigation; put the content on the page")
        if tag == "details":
            self.findings.append("details: collapsed content is hidden content")
        if tag == "iframe":
            self.findings.append("iframe: embeds another page")
        if "hidden" in a:
            self.findings.append(f"hidden attribute on <{tag}>")
        s = style.replace(" ", "").lower()
        if "display:none" in s:
            self.findings.append(f"display:none on <{tag}>")
        if "visibility:hidden" in s:
            self.findings.append(f"visibility:hidden on <{tag}>")
        if tag in ("link", "script", "img", "iframe"):
            src = a.get("href") or a.get("src") or ""
            if src.startswith(("http://", "https://", "//")):
                self.findings.append(f"external resource: <{tag}> {src}")
        for m in _FONT.finditer(style):
            self._font(m, f"inline on <{tag}>")
        if tag == "style":
            self._in_style = True

    def handle_endtag(self, tag):
        if tag == "style":
            self._in_style = False

    def handle_data(self, data):
        if self._in_style:
            self.styles.append(data)

    def _font(self, m, where):
        v, unit = float(m.group(1)), m.group(2).lower()
        pt = v if unit == "pt" else v / PX_PER_PT
        if pt < self.floor:
            self.findings.append(
                f"text below floor: {m.group(1)}{unit} ({pt:.1f}pt) {where}; floor is {self.floor}pt")


def check(html, floor_pt=6.0, max_in=PLOTTER_IN):
    w = _Walker()
    w.floor = floor_pt
    w.feed(html)
    css = "\n".join(w.styles)
    for m in _FONT.finditer(css):
        w._font(m, "in a <style> block")
    if ":hover" in css:
        w.findings.append(":hover rule in <style>: hover-only content is hidden content")
    if re.search(r"display\s*:\s*none", css):
        w.findings.append("display:none in <style>")
    if w.size:
        sw, sh = w.size
        if sw > max_in or sh > max_in:
            w.findings.append(
                f"surface {sw:g} x {sh:g} in exceeds a {max_in:g} in plotter roll; the design may be too complex for one page")
    return w.findings, w.size


def _preview(path, size, out):
    chrome = shutil.which("google-chrome") or shutil.which("chromium") or shutil.which("chrome")
    mac = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    if not chrome and shutil.os.path.exists(mac):
        chrome = mac
    if not chrome:
        print("preview: no headless Chrome found; skipped")
        return
    w, h = size or (17.0, 11.0)
    subprocess.run([chrome, "--headless=new", "--hide-scrollbars",
                    f"--window-size={int(w*96)+96},{int(h*96)+96}",
                    f"--screenshot={out}", f"file://{shutil.os.path.abspath(path)}"],
                   capture_output=True)
    print(f"preview: {out}")


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("page")
    ap.add_argument("--floor-pt", type=float, default=6.0)
    ap.add_argument("--max-in", type=float, default=PLOTTER_IN)
    ap.add_argument("--preview", metavar="OUT.png")
    args = ap.parse_args(argv)
    try:
        html = open(args.page, encoding="utf-8").read()
    except OSError as e:
        print(f"fit-check: {e}", file=sys.stderr)
        return 2
    findings, size = check(html, args.floor_pt, args.max_in)
    for f in findings:
        print(f"- {f}")
    if size:
        print(f"surface: {size[0]:.1f} x {size[1]:.1f} in")
    if args.preview:
        _preview(args.page, size, args.preview)
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `cd /Users/cesar/.agents/skills/one-page-design && python3 -m pytest tests/test_fit_check.py -v`
Expected: 10 passed.

- [ ] **Step 6: Commit**

```bash
git add scaffold.html scripts/fit-check.py tests/test_fit_check.py
git commit -m "feat: surface scaffold and fit-check script with tests"
```

---

### Task 3: Visual grammar reference and example notes

**Files:**
- Create: `grammar.md`
- Create: `examples/librande/README.md`

**Interfaces:**
- Produces: section names in `grammar.md` that SKILL.md links by name: Anatomy, Shapes, Cards, Vocabulary, Time and difficulty, Relationships, Text registers, Colour, Working documents.

- [ ] **Step 1: Write the example notes**

`examples/librande/README.md`:

```markdown
# Librande slides: what each one teaches

From Stone Librande's GDC talk "One-Page Designs". Look at the slide before
designing a page of the same kind.

- slide-1.png: DHack world, normal difficulty. Levels descend the page, so
  depth is drawn. Left margin: section lore with bracket lines grouping
  levels. Right margin: per-level spec in one line. Title top-left.
- slide-2.png: DHack act one, early. Isometric tiles in a chain, area names
  with monster lists beneath, pen annotations circled. A working document.
- slide-3.png: DHack act one, two years on. Poster. Isometric map in the
  middle; cards around the edge with identical anatomy (number and name,
  level and time in blue, rows of icon, name, note); leader lines to the
  map.
- slide-5.png: Guild castle. Isometric building centre, plan view inset
  top-left with labelled rooms, upgrade trees as icon rows on the right,
  a numbered rules list bottom. Plan, isometric and tree on one page.
- slide-6.png: Delivery types. A grid of boxed cards, each: name, one
  sentence, an O-and-X diagram, and an italic Parameters list. A visual
  vocabulary defined once and reused.
- slide-7.png: Demonic Mage, Fire Chain. Letter-size, mostly text, one
  three-frame storyboard (click, 1 s, 2 s) in the same O/X vocabulary. A
  one-pager can be small.
- slide-8.png: Living Springfield. Plotter poster. Town map centre,
  interiors around the edge with leader lines to their buildings, legend
  bottom centre, title block and date bottom-right.
- slide-9.png: Time + Space. Island map with migration paths numbered 0
  to 4, difficulty zones as circles, vertical dividers per brain level, a
  minute ruler along the bottom. Space on the map, time on the axis.
- slide-10.png: Relationships Between Modules. Circular arena map centre,
  screen flow on the left with thumbnails in the boxes, click actions on
  the right ending in boxed outcomes, game types as cards along the bottom.
- slide-11.png: Relationships Between Units. A triangle with the axes on
  its edges (slow/fast, heavy/fragile, damage), a faction in each region
  with a trait card and a figure. A shape that argues against
  rock-paper-scissors.
- slide-12.png: Faction x Class matrix. Plain grid, x for empty cells.
  Filled top-down.
- slide-13.png: The dreamcatcher. Beautiful, symmetric, and wrong: the
  circle implied adjacencies that did not exist. The warning slide.
- slide-14.png: Calculating Space Game Archetypes. Letter-size proposal,
  circled steps 1 to 4, a sentence and a drawing each, formulas in
  monospace boxes, a red "FUN FACT!" marker note, dated footer.
- slide-15.png: Trader 3 mission. World thumbnail top-left, title and
  italic story, oval map centre with numbered locations (1A, 1B, 2-3, 4,
  5) listing contents, acts 1 to 5 down the right with goal bullets,
  legend bottom-left, date bottom-right.
```

- [ ] **Step 2: Write the grammar**

`grammar.md`:

```markdown
# Visual grammar of a one-page design

Drawn from Librande's pages (see `examples/librande/README.md`). Each entry
says when it fits and which slide shows it. None of this is a layout; it
is the vocabulary pages are composed from.

## Anatomy (every page)

Title top-left, large, stating the point. Date bottom-right, optionally
labelled ("Proposal"). One depiction in the middle. Callouts in the
margins tied to the depiction by thin leader lines or shared numbers (1A,
1B, 2-3). A legend wherever a symbol repeats. Insets where useful: world
thumbnail, plan beside isometric, mini-map. Slides 1, 8, 15.

## Shapes (pick by what the design is)

| The design is | Draw | Slide |
|---|---|---|
| a space or level | plan view, or isometric tiles and blocks | 1, 2, 5, 15 |
| an object or building | the object, with a plan inset | 5 |
| a journey over time | a map with numbered waypoints and a time ruler | 9 |
| a procedure in the world | the world with circled moments 1, 2, 3 | 14 |
| a set of like things | cards with identical anatomy, each with a small picture | 3, 6, 10 |
| two attributes crossed | a matrix, filled top-down, x in empty cells | 12 |
| things that affect each other | a triangle with axes on its edges, a ring, a line | 11 |
| a moment-by-moment action | a storyboard strip in one vocabulary | 7 |
| screen and menu flow, only | a flowchart with thumbnails in the boxes | 10 |

Most pages combine two. If no shape fits on one surface, say so: the
design is probably too complex.

## Cards

A rounded box with a header line (number and name), a coloured sub-line
(level, time, tier), then rows of icon, name, note. Design the card once,
then fill the page by repeating it. Slides 3, 6, 10.

## Vocabulary

Define a tiny set of marks for the page and keep to it: O is the player,
X is the enemy, a burst is a hit, a blue area is an effect zone, a
triangle is a projectile, a coloured dot is a token. Cheaper than prose
and readable from across the room. Put the set in the legend. Slides 6,
7, 14.

## Time and difficulty

Draw them. A ruler along an edge in minutes or turns, vertical dividers
for phases, bands or zones on the map for difficulty, levels descending
the page for depth. Slides 1, 9.

## Relationships

A triangle whose axes are its edges makes "slow" and "heavy" into places
and turns a rock-paper-scissors into sliders (slide 11). A matrix exposes
gaps (slide 12). A ring implies adjacency; use it only when adjacency is
real (slide 13, the warning).

## Text registers

Italic for story and flavour. Roman for rules. Small italic lists for
parameters. Formulas in a monospace box. Procedures as circled numbers,
one sentence each, a drawing under each. Slides 6, 7, 14, 15.

## Colour

Soft fills with dark outlines, like a placemat. One accent for the thing
the page is about; grey for everything else. One colour per category when
categories are the point, with a legend. Slides 8, 9, 11, 14.

## Working documents

Pages expect pen marks: circles, crossings-out, "FUN FACT!" in red. Leave
white space for them. Slides 2, 14.
```

- [ ] **Step 3: Commit**

```bash
git add grammar.md examples/librande/README.md
git commit -m "docs: visual grammar reference and notes on the Librande slides"
```

---

### Task 4: Drawing kit and illustrator brief template

**Files:**
- Create: `kit.md`
- Create: `brief-template.md`

**Interfaces:**
- Produces: `kit.md` snippets that use the scaffold's classes (`.callout`, `.card`, `.legend`, `.leader`, `.outline`) from Task 2.
- Produces: `brief-template.md` with REQUIRED lines the SKILL.md route A step quotes.

- [ ] **Step 1: Write the kit**

`kit.md`:

````markdown
# Drawing kit

Inline SVG and HTML you copy and adapt. Everything uses the scaffold's
classes. Coordinates are in a 100-unit-per-inch viewBox so a 17 x 11 in
poster is `viewBox="0 0 1700 1100"`. Place a full-surface SVG first for
leader lines and drawings, then absolutely positioned HTML on top for
text.

## Full-surface drawing layer

```html
<svg viewBox="0 0 1700 1100" width="17in" height="11in"
     style="position:absolute;inset:0" aria-hidden="true">
  <!-- drawings and leader lines go here -->
</svg>
```

## Isometric tile (a 2:1 diamond) and block

```html
<g transform="translate(600,420)">
  <polygon points="0,-40 80,0 0,40 -80,0" fill="var(--soft-1)" class="outline"/>
</g>
<!-- block: top face plus two sides -->
<g transform="translate(700,400)">
  <polygon points="0,-40 80,0 0,40 -80,0" fill="var(--soft-2)" class="outline"/>
  <polygon points="-80,0 0,40 0,100 -80,60" fill="#cfc9b6" class="outline"/>
  <polygon points="0,40 80,0 80,60 0,100" fill="#b9b3a0" class="outline"/>
</g>
```

Stack blocks by translating up 60 units per layer. Draw back to front.

## Plan-view room

```html
<g transform="translate(200,200)">
  <rect width="220" height="160" fill="var(--soft-3)" class="outline"/>
  <rect x="100" y="150" width="30" height="10" fill="#fff" class="outline"/> <!-- door -->
  <text x="110" y="85" font-size="12" text-anchor="middle">Main hall</text>
</g>
```

## Map blob with terrain

```html
<path d="M300,500 C350,380 600,360 700,420 C820,490 900,620 780,700 C640,790 420,760 340,660 C290,600 280,560 300,500 Z"
      fill="var(--soft-1)" class="outline"/>
<circle cx="520" cy="560" r="60" fill="#fff" fill-opacity=".6" stroke="none"/> <!-- a zone -->
<text x="520" y="564" font-size="11" text-anchor="middle" fill="#555">Easy combat</text>
```

## Path with numbered waypoints

```html
<polyline points="340,640 460,560 620,520 760,470" fill="none" stroke="var(--ink)" stroke-width="2"/>
<g font-size="11" font-weight="700" text-anchor="middle">
  <circle cx="340" cy="640" r="11" fill="#fff" class="outline"/><text x="340" y="644">0</text>
  <circle cx="620" cy="520" r="11" fill="#fff" class="outline"/><text x="620" y="524">1</text>
</g>
```

## Time ruler

```html
<g transform="translate(150,1000)" font-size="9" fill="#555">
  <line x1="0" y1="0" x2="1400" y2="0" stroke="var(--rule)"/>
  <!-- one tick per 6 minutes over 60 minutes = 10 ticks, 140 units apart -->
  <g><line x1="0" y1="-6" x2="0" y2="6" stroke="var(--rule)"/><text x="0" y="20" text-anchor="middle">0</text></g>
  <g><line x1="140" y1="-6" x2="140" y2="6" stroke="var(--rule)"/><text x="140" y="20" text-anchor="middle">6</text></g>
  <text x="700" y="36" text-anchor="middle">gameplay minutes</text>
</g>
```

Vertical dividers for phases: `<line x1="430" y1="100" x2="430" y2="1000" stroke="#9ab" stroke-dasharray="4 4"/>`.

## Tokens, figures, O and X

```html
<circle cx="900" cy="300" r="10" fill="var(--accent)" class="outline"/>        <!-- token -->
<path d="M960,290 l0,30 m-8,-18 l16,0 m-8,-12 a6,6 0 1,0 0.1,0" stroke="var(--ink)" stroke-width="3" fill="none"/> <!-- figure -->
<text x="1000" y="310" font-size="22" font-weight="700">O</text>              <!-- player -->
<text x="1060" y="310" font-size="22" font-weight="700">X</text>              <!-- enemy -->
<path d="M1120,300 l6,-14 4,12 10,-8 -4,12 14,2 -12,6 10,10 -14,-4 2,14 -8,-10 -8,10 2,-14 -14,4 10,-10 -12,-6 14,-2 -4,-12 10,8 z"
      fill="#f6b84a" class="outline"/>                                          <!-- burst -->
<path d="M1200,300 m0,0 a40,40 0 0,1 40,-40 l0,80 z" fill="#9fc5ea" fill-opacity=".7" stroke="none"/> <!-- cone zone -->
```

## Leader line from a callout to a point

```html
<path class="leader" d="M1420,260 L1300,260 L1180,330"/>
<circle cx="1180" cy="330" r="2.5" fill="var(--rule)"/>
```

Leader lines are straight or one bend, never curved, never crossing each
other.

## Callout (HTML, on top of the drawing)

```html
<div class="callout" style="left:14.2in; top:2.4in">
  <h3>2. Mines (levels 1 to 5)</h3>
  <p class="story">A prosperous operation, now in ruins.</p>
  <p class="rule">Up and down stairway plus 3 random tiles.</p>
  <p class="param">Monsters: miner, spider, rat mage</p>
</div>
```

## Card

```html
<div class="card" style="left:0.5in; top:3in">
  <div class="head">10) Widow's Tier</div>
  <div class="sub">Level 12 · 20 minutes</div>
  <div class="row"><svg width="14" height="14"><circle cx="7" cy="7" r="6" fill="var(--accent)"/></svg>
    <b>Tattooed Corpse</b> <span class="param">melee</span></div>
  <div class="row"><svg width="14" height="14"><rect width="14" height="14" fill="#555"/></svg>
    <b>Death Cap Shaman</b> <span class="param">poison, ranged</span></div>
</div>
```

Repeat the card; never vary its anatomy on one page.

## Matrix

```html
<table class="t3" style="position:absolute;left:9in;top:7in;border-collapse:collapse">
  <tr><th></th><th>Fighter</th><th>Archer</th><th>Mage</th></tr>
  <tr><th>Fire</th><td>Rage</td><td>x</td><td>Fireball</td></tr>
  <tr><th>Metal</th><td>Cleave</td><td>Piercing</td><td>x</td></tr>
</table>
<style>table.t3 th, table.t3 td { border: 1px solid var(--rule); padding: 3px 8px; }</style>
```

## Triangle with axes on its edges

```html
<g transform="translate(850,560)">
  <polygon points="0,-200 180,110 -180,110" fill="#fff" class="outline"/>
  <polygon points="0,-200 0,0 -180,110" fill="#f6d6d2" stroke="none"/>   <!-- region A -->
  <polygon points="0,-200 0,0 180,110" fill="#f8efc8" stroke="none"/>     <!-- region B -->
  <polygon points="-180,110 0,0 180,110" fill="#e3dcf0" stroke="none"/>   <!-- region C -->
  <text x="-120" y="-60" font-size="11" transform="rotate(-60 -120 -60)">Slow</text>
  <text x="90" y="-60" font-size="11" transform="rotate(60 90 -60)">Low damage</text>
  <text x="0" y="135" font-size="11" text-anchor="middle">Fragile</text>
</g>
```

## Storyboard strip

```html
<div style="position:absolute;left:1in;top:6in;display:flex;gap:.2in">
  <figure style="margin:0;width:2.2in;border:1px solid var(--rule);padding:4px">
    <svg viewBox="0 0 220 120" width="100%"><!-- frame 1 in the page's vocabulary --></svg>
    <figcaption class="t3">Click: the rope connects O to X.</figcaption>
  </figure>
</div>
```

## Legend

```html
<div class="legend" style="left:0.5in; bottom:0.6in">
  <b>O</b> you · <b>X</b> monster · <span style="color:#f6b84a">✶</span> hit · <span style="color:#9fc5ea">▮</span> area
</div>
```

## Circled step numbers

```html
<span style="display:inline-block;width:18px;height:18px;border:1.5px solid var(--ink);border-radius:50%;text-align:center;line-height:18px;font-size:10pt;font-weight:700">1</span>
```
````

- [ ] **Step 2: Write the brief template**

`brief-template.md`:

```markdown
# Illustrator brief

Hand this to whoever draws the centrepiece: an image model, an agent with
image tools, or a person. It names no model. Fill every line.

---

**Page:** <the page title, so the drawing serves it>

**Subject:** <the one thing to depict, in a sentence. "A 16-pog tower on a
table, one slammer hovering above it, seen from a three-quarter angle.">

**View:** <isometric | plan | side-on | three-quarter scene | storyboard frame>

**Must be present:** <the parts a reader will be pointed at, listed. These
get callouts, so they must be distinct and findable.>

**Must be absent:** <anything that would mislead: extra characters, UI,
effects not in the design>

**Style:** flat placemat illustration; soft fills with dark outlines; white
or paper background; one accent colour: <colour>; no gradients, no photo
realism, no lens effects.

**REQUIRED: no text, letters, numbers, labels or logos anywhere in the
image.** Labels are added on the page afterwards. An image with text in it
is rejected and re-commissioned, not cleaned up.

**REQUIRED: largest size available**, at least 2048 px on the long edge,
PNG, transparent or plain background.

**Output path:** <absolute path, e.g. /path/to/page/art/centre.png>

---

Keep this brief in the page as an HTML comment beside the <img>, so
regenerating is one step.
```

- [ ] **Step 3: Commit**

```bash
git add kit.md brief-template.md
git commit -m "docs: drawing kit and model-agnostic illustrator brief template"
```

---

### Task 5: SKILL.md and the symlink

**Files:**
- Create: `SKILL.md`
- Create symlink: `/Users/cesar/.claude/skills/one-page-design -> ../../.agents/skills/one-page-design`

**Interfaces:**
- Consumes: `grammar.md` section names (Task 3), `kit.md` (Task 4), `brief-template.md` (Task 4), `scaffold.html` and `scripts/fit-check.py` (Task 2), the baselines (Task 1) for the Common mistakes section.

- [ ] **Step 1: Write SKILL.md**

Write the file below, then replace the two `<from baseline>` lines in
"Common mistakes" with the actual rationalizations recorded in Task 1.

````markdown
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
   across the room: title, big labels, legend. Tier two at arm's length:
   callouts tied to the picture by leader lines or shared numbers, cards
   with one anatomy. Tier three is fine print: parameters in small
   italics, formulas in a monospace box. Anything that would need a fourth
   tier comes off the page. Draw time and difficulty (a ruler, dividers,
   zones) instead of describing them.
5. **Date it, size it, hand it over.** Start from `scaffold.html`. Set the
   surface size in inches on the poster element: begin at the size that
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
- three text registers: italic story, roman rules, small italic parameters;
- time and difficulty drawn, where the design has them;
- one surface: no links, tabs, collapsed, hidden or hover-only content;
- a size in inches on the poster, and print CSS to match;
- no external fonts, scripts or stylesheets.

If the fit-check reports the surface above 44 inches, the design is too
complex for one page. Cut tiers or split the design; never shrink the
fine print below 6 pt.

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
- <from baseline: the exact shortcut the no-skill run took on scenario 1>
- <from baseline: the exact shortcut the no-skill run took on scenario 2>
````

- [ ] **Step 2: Check the frontmatter**

Run: `head -4 /Users/cesar/.agents/skills/one-page-design/SKILL.md | wc -c`
Expected: under 1024. Name is letters and hyphens only. Description starts with "Use when" and names no workflow step.

- [ ] **Step 3: Create the symlink**

```bash
ln -s ../../.agents/skills/one-page-design /Users/cesar/.claude/skills/one-page-design
ls -la /Users/cesar/.claude/skills/one-page-design
```

Expected: the symlink resolves and `SKILL.md` is readable through it.

- [ ] **Step 4: Commit**

```bash
git add SKILL.md
git commit -m "feat: one-page-design SKILL.md (method, contract, routes, mistakes)"
```

---

### Task 6: Micro-test the two negotiable rules

**Files:**
- Create: `tests/microtests/README.md`
- Create: `tests/microtests/2026-11-01-results.md`

**Interfaces:**
- Consumes: SKILL.md from Task 5 as the system context.

- [ ] **Step 1: Write the microtest procedure**

`tests/microtests/README.md`:

```markdown
# Wording micro-tests

Two rules in SKILL.md are the ones an agent will negotiate with under a
competing incentive ("be thorough", "include everything"):

A. "depict, then annotate" (step 2 and 3) against the pull toward headed
   prose and flowcharts;
B. "one surface, nothing hidden" against the pull toward tabs, details and
   links when content grows.

Procedure, per rule: five fresh single-shot subagents with SKILL.md in the
prompt, five with no guidance (control), same task: scenario 2
(`../scenarios/single-mechanic.md`) with the instruction "be thorough".
Score each output by hand: for A, does the centre of the page depict the
mechanic (cards, a worked example strip, a matrix) or is it headed prose?
For B, does `fit-check` report zero navigation or hidden content? Read
every output; do not score by grep alone. Record the counts and the
variance: if the five skill runs land on five different shapes, the wording
is not binding yet.
```

- [ ] **Step 2: Run the micro-tests and record**

Dispatch the ten subagents per rule (twenty in all, each a fresh
`general-purpose` agent). Write `tests/microtests/2026-11-01-results.md`:

```markdown
# Micro-test results, 2026-11-01

## Rule A: depict, then annotate
| run | guidance | centre is a depiction? | shape chosen |
|---|---|---|---|
| 1 | none | | |
| ... | | | |
| 1 | skill | | |
Control depictions: n/5. Skill depictions: n/5. Distinct shapes under the skill: n.

## Rule B: one surface
| run | guidance | fit-check navigation findings |
|---|---|---|
Control clean: n/5. Skill clean: n/5.

## Verdict
<which rule's wording held, which needs tightening, and the specific
rationalization seen in any failing skill run, verbatim>
```

- [ ] **Step 3: Tighten wording if a rule did not hold**

If the skill arm converged on fewer than 4 of 5 for either rule, rewrite
that rule in SKILL.md as a tighter positive recipe (state what the output
is, no exemption clauses), re-run the five skill reps, and append the
second round to the results file.

- [ ] **Step 4: Commit**

```bash
git add tests/microtests SKILL.md
git commit -m "test: micro-tests of the two negotiable rules, with results"
```

---

### Task 7: GREEN scenarios with the skill

**Files:**
- Create: `tests/results/2026-11-01-with-skill-pog-roguelike.md`
- Create: `tests/results/2026-11-01-with-skill-single-mechanic.md`
- Create: `tests/results/output/` (the two HTML pages and their previews)

**Interfaces:**
- Consumes: the two scenarios from Task 1 verbatim; the skill via the symlink from Task 5.

- [ ] **Step 1: Run scenario 1 with the skill**

Dispatch a fresh `general-purpose` subagent with the scenario text and the
line "Use the one-page-design skill at /Users/cesar/.claude/skills/one-page-design/SKILL.md.",
output path `.../tests/results/output/2026-11-01-pog-roguelike-with-skill.html`.

- [ ] **Step 2: Fit-check and score**

```bash
python3 scripts/fit-check.py tests/results/output/2026-11-01-pog-roguelike-with-skill.html --preview tests/results/output/2026-11-01-pog-roguelike-with-skill.png
```

Write the results file with the same anatomy table as the baseline, the
fit-check output verbatim, and a line "Shape chosen: ...". Look at the
PNG: does the centre depict the game? Say what it depicts.

- [ ] **Step 3: Run scenario 2 with the skill, fit-check, score**

Same as steps 1 and 2 for `single-mechanic`. The scoring line that matters
most: "Shape chosen" must differ from scenario 1's. If both pages have the
same layout, the skill is forcing a template; note it for Task 8.

- [ ] **Step 4: Compare against the baselines**

In each results file add a section "Against the baseline" listing each
anatomy item that moved from absent to present, and any that are still
absent.

- [ ] **Step 5: Commit**

```bash
git add tests/results
git commit -m "test: with-skill runs of both scenarios, fit-checked and scored"
```

---

### Task 8: REFACTOR, close loopholes and finish

**Files:**
- Modify: `SKILL.md` (Common mistakes and any rule that was bent)
- Modify: `grammar.md` or `kit.md` only if a run lacked a part it needed
- Create: `README.md` (one paragraph: what this is, how to invoke, where the spec is)

- [ ] **Step 1: List every shortcut seen in Tasks 6 and 7**

From the results files, collect each rationalization or shortcut
verbatim. For each, decide the form of the fix (per writing-skills "Match
the form to the failure"): a wrong-shaped output gets a tighter recipe in
the contract; an omitted element gets a REQUIRED slot in the contract
list; a bent rule gets a conditional on an observable predicate.

- [ ] **Step 2: Apply the fixes to SKILL.md**

Edit the specific lines. Do not add prohibition lists for shaping
failures.

- [ ] **Step 3: Re-run the scenario that exposed each loophole**

Fresh subagent, same scenario, fit-check, score. Append a "Round 2"
section to that results file. Repeat until both scenarios pass every
anatomy item and fit-check is clean.

- [ ] **Step 4: Write README.md**

```markdown
# one-page-design

A skill that turns any design into a Librande-style one-page document: one
printable HTML surface, a depiction in the middle, the words hung off it.
Invoke by asking for a one-page design, or load `SKILL.md`. Spec and plan
are in `docs/`. Reference slides and what each teaches are in
`examples/librande/`. Tests: `python3 -m pytest tests/` for the script;
`tests/baselines/` and `tests/results/` hold the skill's own
before-and-after runs.
```

- [ ] **Step 5: Final checks and commit**

```bash
python3 -m pytest tests/ -q
head -4 SKILL.md | wc -c
wc -w SKILL.md
git add -A
git commit -m "refactor: close loopholes from scenario runs; add README"
git log --oneline
```

Expected: tests pass; frontmatter under 1024 characters; SKILL.md under
about 900 words.
