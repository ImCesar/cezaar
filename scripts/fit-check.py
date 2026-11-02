#!/usr/bin/env python3
"""fit-check: the "print it and squint" step for a one-page design.

Static checks on a single HTML file:
  - the surface: --w and --h set in inches on :root, read by
    <main class="poster"> and by @page; never a size on the poster itself
  - navigation or hidden content (links, details, hidden, display:none,
    visibility:hidden, :hover rules, iframes)
  - text below the legibility floor (font-size in pt or px)
  - the drawing layer's viewBox: a full-surface <svg> must be 100 units per
    inch of the surface (1700 x 1100 on 17 x 11 in)
  - SVG text below the floor: a unitless font-size inside <svg> is in
    viewBox units, read at the drawing layer's actual units per inch
    (0.72 pt per unit at the kit's 100 units per inch)
  - external resources (link/script/img with http(s) src)
  - a surface wider or taller than a plotter roll (44 in)
  - the number of .callout elements, reported always; more than 8 is a finding
Optional: --preview out.png renders with headless Chrome if present.
Exit 0: no findings. 1: findings. 2: usage error.
"""
import argparse
import os
import re
import shutil
import subprocess
import sys
from html.parser import HTMLParser

PX_PER_PT = 96 / 72
MAX_CALLOUTS = 8
PLOTTER_IN = 44.0

_FONT = re.compile(r"font-size\s*:\s*(\d*\.?\d+)\s*(pt|px|em|rem|%)", re.I)
_FONT_SHORTHAND = re.compile(
    r"\bfont\s*:\s*[^;{}]*?(\d*\.?\d+)\s*(pt|px)(?:\s*/\s*[\d.]+[a-z%]*)?\s+", re.I)
_SVG_BARE = re.compile(r"^\s*(\d*\.?\d+)\s*$")
_SVG_STYLE_BARE = re.compile(r"font-size\s*:\s*(\d*\.?\d+)\s*(?=;|$)", re.I)
_SVG_ATTR_UNIT = re.compile(r"^\s*(\d*\.?\d+)\s*(pt|px)\s*$", re.I)
_VAR = re.compile(r"--(w|h)\s*:\s*(\d+(?:\.\d+)?)\s*(in|cm|mm)")
_VIEWBOX = re.compile(r"^\s*[-\d.]+[\s,]+[-\d.]+[\s,]+(\d*\.?\d+)[\s,]+(\d*\.?\d+)\s*$")
_ABS_WIDTH = re.compile(r"(?:^|;)\s*width\s*:\s*\d*\.?\d+\s*(?:in|cm|mm|px|pt)", re.I)
_VOID = {"area", "base", "br", "col", "embed", "hr", "img", "input", "link",
         "meta", "source", "track", "wbr"}
UNITS_PER_IN = 100.0


def _inches(value, unit):
    return {"in": value, "cm": value / 2.54, "mm": value / 25.4}[unit]


class _Walker(HTMLParser):
    def __init__(self):
        super().__init__()
        self.findings = []
        self.poster_size = None
        self.poster_seen = False
        self._in_style = False
        self._svg_depth = 0
        self._stack = []        # open elements: (tag, is_poster)
        self._svg_ctx = []      # per open <svg>: index into surface_svgs, or None
        self.surface_svgs = []  # (viewBox width, viewBox height) of drawing layers
        self.svg_sizes = []     # (value in user units, source, tag, surface index or None)
        self.callouts = 0
        self.styles = []

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        cls = (a.get("class") or "").split()
        style = a.get("style") or ""
        if "callout" in cls:
            self.callouts += 1
        if tag == "main" and "poster" in cls:
            self.poster_seen = True
            w = h = None
            for m in _VAR.finditer(style):
                v = _inches(float(m.group(2)), m.group(3))
                if m.group(1) == "w":
                    w = v
                else:
                    h = v
            if w is not None and h is not None:
                self.poster_size = (w, h)
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
        for m in _FONT_SHORTHAND.finditer(style):
            self._font(m, f"inline on <{tag}>")
        parent_is_poster = bool(self._stack) and self._stack[-1][1]
        if tag == "svg":
            self._svg_ctx.append(self._surface_index(a, style, parent_is_poster))
            self._svg_depth += 1
        if self._svg_depth:
            self._svg_font(tag, a.get("font-size"), style)
        if tag not in _VOID:
            self._stack.append((tag, tag == "main" and "poster" in cls))
        if tag == "style":
            self._in_style = True

    def handle_endtag(self, tag):
        if tag == "style":
            self._in_style = False
        if tag == "svg" and self._svg_depth:
            self._svg_depth -= 1
            self._svg_ctx.pop()
        for i in range(len(self._stack) - 1, -1, -1):
            if self._stack[i][0] == tag:
                del self._stack[i:]
                break

    def _surface_index(self, a, style, parent_is_poster):
        """The drawing layer whose viewBox this <svg>'s text is measured in.

        An outer <svg> with a viewBox that spans the surface (no absolute
        width of its own) is a drawing layer when it is a direct child of the
        poster, or when it is the first such <svg> on the page. Nested <svg>
        inherit their parent's layer."""
        if self._svg_depth:
            return self._svg_ctx[-1]
        m = _VIEWBOX.match(a.get("viewbox") or "")
        if not m:
            return None
        full = (a.get("width") or "100%").strip() == "100%" and not _ABS_WIDTH.search(style)
        if full and (parent_is_poster or not self.surface_svgs):
            self.surface_svgs.append((float(m.group(1)), float(m.group(2))))
            return len(self.surface_svgs) - 1
        return None

    def _svg_font(self, tag, attr, style):
        layer = self._svg_ctx[-1]
        if attr is not None:
            m = _SVG_BARE.match(attr)
            if m:
                self.svg_sizes.append((float(m.group(1)), f'font-size="{attr.strip()}"', tag, layer))
            else:
                m = _SVG_ATTR_UNIT.match(attr)
                if m:
                    self._font(m, f"attribute on <{tag}>")
        for m in _SVG_STYLE_BARE.finditer(style):
            self.svg_sizes.append((float(m.group(1)), f'style="font-size:{m.group(1)}"', tag, layer))

    def check_svg(self, size):
        """Check drawing layers against the surface, then SVG text against the
        floor at each layer's actual scale. Runs once :root is known."""
        units_per_in = []
        for vw, vh in self.surface_svgs:
            upi = UNITS_PER_IN
            if size:
                ux, uy = vw / size[0], vh / size[1]
                if abs(ux - UNITS_PER_IN) > UNITS_PER_IN / 100 or abs(uy - UNITS_PER_IN) > UNITS_PER_IN / 100:
                    self.findings.append(
                        f"svg viewBox {vw:g} x {vh:g} does not match the surface at 100 units per inch "
                        f"(expected {size[0] * UNITS_PER_IN:g} x {size[1] * UNITS_PER_IN:g})")
                upi = max(ux, uy)  # the viewBox is fitted whole: the tighter axis sets the scale
            units_per_in.append(upi)
        for value, source, tag, layer in self.svg_sizes:
            upi = UNITS_PER_IN if layer is None else units_per_in[layer]
            pt = value * 72 / upi
            if pt < self.floor:
                self.findings.append(
                    f"svg text below floor: {source} ({pt:.1f}pt at {upi:.0f} units/in) "
                    f"on <{tag}>; floor is {self.floor:g}pt")

    def handle_data(self, data):
        if self._in_style:
            self.styles.append(data)

    def _font(self, m, where):
        v, unit = float(m.group(1)), m.group(2).lower()
        if unit in ("em", "rem", "%"):
            self.findings.append(
                f"font-size in {unit} ({where}): not checkable at print; use pt or px")
            return
        pt = v if unit == "pt" else v / PX_PER_PT
        if pt < self.floor:
            self.findings.append(
                f"text below floor: {m.group(1)}{unit} ({pt:.1f}pt) {where}; floor is {self.floor}pt")


def _root_size(css):
    size = None
    for block in re.findall(r":root\s*\{([^}]*)\}", css):
        vals = {m.group(1): _inches(float(m.group(2)), m.group(3)) for m in _VAR.finditer(block)}
        if "w" in vals and "h" in vals:
            size = (vals["w"], vals["h"])
    return size


def check(html, floor_pt=6.0, max_in=PLOTTER_IN, stats=None):
    w = _Walker()
    w.floor = floor_pt
    w.feed(html)
    css = "\n".join(w.styles)
    for m in _FONT.finditer(css):
        w._font(m, "in a <style> block")
    for m in _FONT_SHORTHAND.finditer(css):
        w._font(m, "in a <style> block")
    if not w.poster_seen:
        w.findings.append("poster: no <main class=\"poster\"> element found")
    root = _root_size(css)
    poster = w.poster_size
    if root is None and poster is None:
        w.findings.append("poster: --w and --h must be set in inches on :root")
    elif root is None:
        w.findings.append("size on poster only: declare --w and --h on :root so @page can read them")
    elif poster is not None and poster != root:
        w.findings.append(
            f"size declared twice and differs: :root {root[0]:g} x {root[1]:g} in, "
            f"poster {poster[0]:g} x {poster[1]:g} in")
    if ":hover" in css:
        w.findings.append(":hover rule in <style>: hover-only content is hidden content")
    if re.search(r"display\s*:\s*none", css):
        w.findings.append("display:none in <style>")
    if w.callouts > MAX_CALLOUTS:
        w.findings.append(f"callouts: {w.callouts} exceeds {MAX_CALLOUTS}")
    if stats is not None:
        stats["callouts"] = w.callouts
    size = root
    w.check_svg(size)
    if size:
        sw, sh = size
        if sw > max_in or sh > max_in:
            w.findings.append(
                f"surface {sw:g} x {sh:g} in exceeds a {max_in:g} in plotter roll; the design may be too complex for one page")
    return w.findings, size


def _preview(path, size, out):
    chrome = shutil.which("google-chrome") or shutil.which("chromium") or shutil.which("chrome")
    mac = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
    if not chrome and os.path.exists(mac):
        chrome = mac
    if not chrome:
        print("preview: no headless Chrome found; skipped")
        return
    w, h = size or (17.0, 11.0)
    subprocess.run([chrome, "--headless=new", "--hide-scrollbars",
                    f"--window-size={int(w*96)+96},{int(h*96)+96}",
                    f"--screenshot={out}", f"file://{os.path.abspath(path)}"],
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
    stats = {}
    findings, size = check(html, args.floor_pt, args.max_in, stats)
    for f in findings:
        print(f"- {f}")
    print(f"callouts: {stats['callouts']}")
    if size:
        print(f"surface: {size[0]:.1f} x {size[1]:.1f} in")
    if args.preview:
        _preview(args.page, size, args.preview)
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
