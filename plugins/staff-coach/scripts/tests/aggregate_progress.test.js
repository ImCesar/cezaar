const { test, beforeEach } = require('node:test');
const assert = require('node:assert');
const os = require('node:os'), path = require('node:path'), fs = require('node:fs');

let d;
beforeEach(() => {
  d = fs.mkdtempSync(path.join(os.tmpdir(), 'sc-')); process.env.STAFF_COACH_HOME = d;
  require('../init_store.js').initStore();
  const prog = { version: 1, dimensions: {
    'operability-resilience': { attempts: 3, scores: [{date:'2026-06-01',score:2},{date:'2026-06-05',score:2},{date:'2026-06-09',score:3}], current_estimate: 2.33, unprompted_count: 0, nudged_count: 3, never_count: 0, disputed_count: 0, last_seen: '2026-06-09' },
    'data-consistency': { attempts: 2, scores: [{date:'2026-06-02',score:5},{date:'2026-06-08',score:5}], current_estimate: 5.0, unprompted_count: 2, nudged_count: 0, never_count: 0, disputed_count: 1, last_seen: '2026-06-08' } } };
  require('../progress_io.js').save(prog);
});

test('identifies weak spot and recommends it', () => {
  const { aggregate } = require('../aggregate_progress.js');
  const r = aggregate();
  assert.ok(r.weak_spots.map(w => w.dimension).includes('operability-resilience'));
  assert.ok(!r.weak_spots.map(w => w.dimension).includes('data-consistency'));
  assert.strictEqual(r.recommended_next, 'operability-resilience');
  assert.ok(r.disputed_unresolved.map(x => x.dimension).includes('data-consistency'));
});

test('trend direction reflects last-3 scores', () => {
  const { aggregate } = require('../aggregate_progress.js');
  const opr = aggregate().all.find(x => x.dimension === 'operability-resilience');
  assert.strictEqual(opr.trend, 'improving'); // 2,2,3
});
