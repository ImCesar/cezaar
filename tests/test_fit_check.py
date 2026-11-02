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
