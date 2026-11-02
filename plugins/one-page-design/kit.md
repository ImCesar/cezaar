# Drawing kit

Inline SVG and HTML you copy and adapt. Everything uses the scaffold's
classes. Coordinates are in a 100-unit-per-inch viewBox that must match the surface declared on `:root`: a 17 x 11 in poster is `viewBox="0 0 1700 1100"`; if you change `--w`/`--h`, change the viewBox to match. Place a full-surface SVG first for
leader lines and drawings, then absolutely positioned HTML on top for
text.

## Full-surface drawing layer

```html
<svg viewBox="0 0 1700 1100" width="100%" height="100%"
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
