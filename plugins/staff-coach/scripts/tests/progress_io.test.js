const { test, beforeEach } = require('node:test');
const assert = require('node:assert');
const os = require('node:os'), path = require('node:path'), fs = require('node:fs');

let d;
beforeEach(() => {
  d = fs.mkdtempSync(path.join(os.tmpdir(), 'sc-')); process.env.STAFF_COACH_HOME = d;
  require('../init_store.js').initStore();
});

test('load returns empty when fresh', () => {
  const io = require('../progress_io.js');
  assert.deepStrictEqual(io.load(), { version: 1, dimensions: {} });
});

test('atomic write roundtrip', () => {
  const io = require('../progress_io.js');
  const data = { version: 1, dimensions: { 'data-consistency': { attempts: 2 } } };
  io.save(data);
  assert.deepStrictEqual(io.load(), data);
});

test('save rejects bad shape', () => {
  const io = require('../progress_io.js');
  assert.throws(() => io.save({ dimensions: {} }), /version/);
});
