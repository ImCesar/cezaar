const { test } = require('node:test');
const assert = require('node:assert');

const VALID = {
  problem_type: 'greenfield-design',
  verdict_summary: 'Solid core; gaps in operability.',
  dimensions: [
    { dimension: 'operability-resilience', score: 3, meets_staff_bar: false, findings: [
      { id: 'f1', severity: 'major', consequence: 'No way to detect partial outage',
        stronger_design: 'Add health checks + SLO alerts', likelihood_magnitude: 'high',
        ledger_checked: true, survived_self_prosecution: true, missed_answer_reveal: 'RED metrics' } ] },
    { dimension: 'data-consistency', score: 5, meets_staff_bar: true, findings: [] }
  ]
};
const clone = (o) => JSON.parse(JSON.stringify(o));

test('accepts valid output including abstention', () => {
  const { validate } = require('../validate_examiner_output.js');
  const { ok, errors } = validate(VALID);
  assert.ok(ok, JSON.stringify(errors));
});

test('rejects empty consequence (filter 1)', () => {
  const { validate } = require('../validate_examiner_output.js');
  const bad = clone(VALID); bad.dimensions[0].findings[0].consequence = '';
  const { ok, errors } = validate(bad);
  assert.ok(!ok); assert.ok(errors.some(e => e.includes('consequence')));
});

test('rejects unchecked ledger (filter 2)', () => {
  const { validate } = require('../validate_examiner_output.js');
  const bad = clone(VALID); bad.dimensions[0].findings[0].ledger_checked = false;
  const { ok, errors } = validate(bad);
  assert.ok(!ok); assert.ok(errors.some(e => e.includes('ledger_checked')));
});

test('rejects more than three findings (filter 3)', () => {
  const { validate } = require('../validate_examiner_output.js');
  const bad = clone(VALID);
  const f = bad.dimensions[0].findings[0];
  bad.dimensions[0].findings = [0,1,2,3].map(i => ({ ...f, id: `f${i}` }));
  const { ok, errors } = validate(bad);
  assert.ok(!ok); assert.ok(errors.some(e => e.includes('findings')));
});

test('rejects survived_self_prosecution:false (filter 4)', () => {
  const { validate } = require('../validate_examiner_output.js');
  const bad = clone(VALID); bad.dimensions[0].findings[0].survived_self_prosecution = false;
  const { ok, errors } = validate(bad);
  assert.ok(!ok); assert.ok(errors.some(e => e.includes('survived_self_prosecution')));
});

test('rejects whitespace-only consequence (filter 1)', () => {
  const { validate } = require('../validate_examiner_output.js');
  const bad = clone(VALID); bad.dimensions[0].findings[0].consequence = '   ';
  const { ok, errors } = validate(bad);
  assert.ok(!ok); assert.ok(errors.some(e => e.includes('consequence')));
});

test('rejects meets_staff_bar:true dimension with non-empty findings', () => {
  const { validate } = require('../validate_examiner_output.js');
  const bad = clone(VALID);
  bad.dimensions[1].findings = [bad.dimensions[0].findings[0]]; // add a finding to the abstained dim
  const { ok, errors } = validate(bad);
  assert.ok(!ok); assert.ok(errors.some(e => e.includes('meets_staff_bar')));
});
