const { test, beforeEach } = require('node:test');
const assert = require('node:assert');
const os = require('node:os'), path = require('node:path'), fs = require('node:fs');

let d;
beforeEach(() => { d = fs.mkdtempSync(path.join(os.tmpdir(), 'sc-')); process.env.STAFF_COACH_HOME = d; });

test('creates dirs and empty progress.json', () => {
  const { initStore } = require('../init_store.js');
  initStore();
  assert.ok(fs.existsSync(path.join(d, 'sessions')));
  assert.ok(fs.existsSync(path.join(d, 'canvas')));
  const data = JSON.parse(fs.readFileSync(path.join(d, 'progress.json'), 'utf8'));
  assert.deepStrictEqual(data, { version: 1, dimensions: {} });
});

test('idempotent: does not clobber existing progress', () => {
  const { initStore } = require('../init_store.js');
  initStore();
  fs.writeFileSync(path.join(d, 'progress.json'), JSON.stringify({ version: 1, dimensions: { x: {} } }));
  initStore();
  const data = JSON.parse(fs.readFileSync(path.join(d, 'progress.json'), 'utf8'));
  assert.ok('x' in data.dimensions);
});
