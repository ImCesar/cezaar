const { test } = require('node:test');
const assert = require('node:assert');
const os = require('node:os');
const path = require('node:path');
const fs = require('node:fs');

function freshRequire(p) { delete require.cache[require.resolve(p)]; return require(p); }

test('respects STAFF_COACH_HOME override', () => {
  const d = fs.mkdtempSync(path.join(os.tmpdir(), 'sc-'));
  process.env.STAFF_COACH_HOME = d;
  const sp = freshRequire('../store_paths.js');
  assert.strictEqual(sp.storeRoot(), d);
  assert.strictEqual(sp.progressFile(), path.join(d, 'progress.json'));
  assert.strictEqual(sp.sessionsDir(), path.join(d, 'sessions'));
});

test('defaults to ~/.staff-coach', () => {
  delete process.env.STAFF_COACH_HOME;
  const sp = freshRequire('../store_paths.js');
  assert.strictEqual(sp.storeRoot(), path.join(os.homedir(), '.staff-coach'));
});
