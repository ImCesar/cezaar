'use strict';
// Single gateway for progress.json: schema-checked load + atomic write.
const fs = require('node:fs');
const sp = require('./store_paths.js');

function validate(data) {
  if (!data || typeof data !== 'object' || data.version !== 1 || typeof data.dimensions !== 'object' || data.dimensions === null) {
    throw new Error("progress.json must be { version: 1, dimensions: {...} }");
  }
}

function load() {
  const pf = sp.progressFile();
  if (!fs.existsSync(pf)) return { version: 1, dimensions: {} };
  const data = JSON.parse(fs.readFileSync(pf, 'utf8'));
  validate(data);
  return data;
}

function save(data) {
  validate(data);
  const pf = sp.progressFile();
  fs.mkdirSync(require('node:path').dirname(pf), { recursive: true });
  const tmp = `${pf}.${process.pid}.tmp`;
  fs.writeFileSync(tmp, JSON.stringify(data, null, 2));
  fs.renameSync(tmp, pf); // atomic on same filesystem
}

module.exports = { load, save, validate };
