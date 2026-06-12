'use strict';
// Write an immutable session record and apply deltas to progress.json.
const fs = require('node:fs');
const path = require('node:path');
const sp = require('./store_paths.js');
const progressIo = require('./progress_io.js');

function blankDim(date) {
  return { attempts: 0, scores: [], current_estimate: 0.0, unprompted_count: 0, nudged_count: 0, never_count: 0, disputed_count: 0, last_seen: date };
}

function renderMd(s) {
  const L = [`# ${s.slug} — ${s.date}`, '', `**Problem type:** ${s.problem_type}`, '', '## Problem', s.problem, '', '## Solution', s.solution, '', '## Trade-off ledger'];
  for (const t of s.ledger || []) L.push(`- **${t.decision}** (${t.dimension}): ${t.reason}`);
  L.push('', '## Examiner verdict (immutable)', '```json', JSON.stringify(s.verdict, null, 2), '```', '', '## Dispositions');
  for (const d of s.dispositions || []) L.push(`- ${d.finding_id}: **${d.disposition}**${d.reason ? ` — ${d.reason}` : ''}`);
  return L.join('\n') + '\n';
}

function writeSession(s) {
  fs.mkdirSync(sp.sessionsDir(), { recursive: true });
  const outPath = path.join(sp.sessionsDir(), `${s.date}-${s.slug}.md`);
  fs.writeFileSync(outPath, renderMd(s));

  const prog = progressIo.load();
  const dims = prog.dimensions;
  const verdictByDim = Object.fromEntries((s.verdict?.dimensions || []).map((d) => [d.dimension, d]));
  const findingDim = {};
  for (const d of s.verdict?.dimensions || []) for (const f of d.findings) findingDim[f.id] = d.dimension;
  const disputedByDim = {};
  for (const disp of s.dispositions || []) {
    if (disp.disposition === 'disputed') {
      const dim = findingDim[disp.finding_id];
      if (dim) disputedByDim[dim] = (disputedByDim[dim] || 0) + 1;
    }
  }
  for (const [dim, crumb] of Object.entries(s.breadcrumbs || {})) {
    const entry = (dims[dim] ||= blankDim(s.date));
    entry.attempts += 1;
    entry.last_seen = s.date;
    if (['unprompted', 'nudged', 'never'].includes(crumb)) entry[`${crumb}_count`] += 1;
    const v = verdictByDim[dim];
    if (v) {
      entry.scores.push({ date: s.date, score: v.score });
      entry.current_estimate = Math.round((entry.scores.reduce((a, x) => a + x.score, 0) / entry.scores.length) * 100) / 100;
    }
    entry.disputed_count += disputedByDim[dim] || 0;
  }
  progressIo.save(prog);
  return outPath;
}

module.exports = { writeSession };
if (require.main === module) {
  let raw = ''; process.stdin.on('data', (c) => (raw += c));
  process.stdin.on('end', () => console.log(writeSession(JSON.parse(raw))));
}
