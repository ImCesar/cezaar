const { test, beforeEach } = require('node:test');
const assert = require('node:assert');
const os = require('node:os'), path = require('node:path'), fs = require('node:fs');

const SESSION = {
  date: '2026-06-10', slug: 'rate-limiter', problem_type: 'greenfield-design',
  problem: 'Design a distributed rate limiter', solution: 'Token bucket in Redis',
  ledger: [{ decision: 'eventual consistency', reason: 'reads tolerate staleness', dimension: 'data-consistency' }],
  breadcrumbs: { 'operability-resilience': 'nudged', 'data-consistency': 'unprompted' },
  verdict: { problem_type: 'greenfield-design', verdict_summary: 'ok', dimensions: [
    { dimension: 'operability-resilience', score: 3, meets_staff_bar: false, findings: [
      { id: 'f1', severity: 'major', consequence: 'c', stronger_design: 's', likelihood_magnitude: 'high', ledger_checked: true, survived_self_prosecution: true, missed_answer_reveal: null } ] },
    { dimension: 'data-consistency', score: 5, meets_staff_bar: true, findings: [] } ] },
  dispositions: [{ finding_id: 'f1', disposition: 'accepted' }]
};

let d;
beforeEach(() => { d = fs.mkdtempSync(path.join(os.tmpdir(), 'sc-')); process.env.STAFF_COACH_HOME = d; require('../init_store.js').initStore(); });

test('writes record and updates progress', () => {
  const ws = require('../write_session.js');
  const p = ws.writeSession(SESSION);
  assert.ok(fs.existsSync(p));
  const body = fs.readFileSync(p, 'utf8');
  assert.ok(p.includes('rate-limiter'));
  assert.ok(body.includes('Token bucket'));
  const prog = require('../progress_io.js').load();
  const opr = prog.dimensions['operability-resilience'];
  assert.strictEqual(opr.attempts, 1);
  assert.strictEqual(opr.nudged_count, 1);
  assert.strictEqual(opr.scores.at(-1).score, 3);
  assert.strictEqual(opr.last_seen, '2026-06-10');
  assert.strictEqual(prog.dimensions['data-consistency'].unprompted_count, 1);
});

test('disputed disposition increments counter', () => {
  const ws = require('../write_session.js');
  const s = JSON.parse(JSON.stringify(SESSION));
  s.dispositions = [{ finding_id: 'f1', disposition: 'disputed', reason: 'intentional' }];
  ws.writeSession(s);
  const prog = require('../progress_io.js').load();
  assert.strictEqual(prog.dimensions['operability-resilience'].disputed_count, 1);
});
