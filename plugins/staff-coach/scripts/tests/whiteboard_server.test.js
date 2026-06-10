const { test, beforeEach } = require('node:test');
const assert = require('node:assert');
const os = require('node:os'), path = require('node:path'), fs = require('node:fs');

let d;
beforeEach(() => { d = fs.mkdtempSync(path.join(os.tmpdir(), 'sc-')); process.env.STAFF_COACH_HOME = d; require('../init_store.js').initStore(); });

test('saveBoard writes png and json', () => {
  const srv = require('../whiteboard/server.js');
  const pngB64 = Buffer.from('\x89PNG fake').toString('base64');
  const out = srv.saveBoard({ png_base64: pngB64, scene_json: { elements: [{ id: 'a' }] } });
  assert.ok(fs.existsSync(out.png) && fs.existsSync(out.json));
  assert.strictEqual(fs.readFileSync(out.png).toString(), '\x89PNG fake');
  assert.strictEqual(JSON.parse(fs.readFileSync(out.json, 'utf8')).elements[0].id, 'a');
});
