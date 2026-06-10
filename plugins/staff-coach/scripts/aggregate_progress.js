'use strict';
// Derive weak spots, trends, disputes, and a recommendation from progress.json.
const progressIo = require('./progress_io.js');

function trend(scores) {
  const pts = scores.map(s => s.score).slice(-3);
  if (pts.length < 2) return 'insufficient-data';
  if (pts.at(-1) > pts[0]) return 'improving';
  if (pts.at(-1) < pts[0]) return 'declining';
  return 'flat';
}

function aggregate() {
  const dims = progressIo.load().dimensions;
  const all = [], weak = [], disputed = [];
  for (const [name, d] of Object.entries(dims)) {
    const row = { dimension: name, current_estimate: d.current_estimate ?? 0, attempts: d.attempts ?? 0, trend: trend(d.scores || []), last_seen: d.last_seen };
    all.push(row);
    const ledMore = ((d.nudged_count ?? 0) + (d.never_count ?? 0)) > (d.unprompted_count ?? 0);
    if ((d.current_estimate ?? 0) < 3.0 || ledMore) weak.push({ ...row, reason: (d.current_estimate ?? 0) < 3.0 ? 'low score' : 'needs nudging' });
    if ((d.disputed_count ?? 0) > 0) disputed.push({ dimension: name, disputed_count: d.disputed_count });
  }
  weak.sort((a, b) => a.current_estimate - b.current_estimate || a.attempts - b.attempts);
  const recommended_next = weak.length ? weak[0].dimension : (all.length ? all.reduce((m, r) => r.attempts < m.attempts ? r : m).dimension : null);
  return { weak_spots: weak, disputed_unresolved: disputed, all, recommended_next };
}

module.exports = { aggregate };
if (require.main === module) console.log(JSON.stringify(aggregate(), null, 2));
