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
import os
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
        self.poster_seen = False
        self._in_style = False
        self.styles = []

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        cls = (a.get("class") or "").split()
        style = a.get("style") or ""
        if tag == "main" and "poster" in cls:
            self.poster_seen = True
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
    if not w.poster_seen:
        w.findings.append("poster: no <main class=\"poster\"> element found")
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
