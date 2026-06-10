'use strict';
// Idempotently scaffold the staff-coach store. Safe to run on every skill invocation.
const fs = require('node:fs');
const sp = require('./store_paths.js');

const EMPTY_PROGRESS = { version: 1, dimensions: {} };

function initStore() {
  fs.mkdirSync(sp.sessionsDir(), { recursive: true });
  fs.mkdirSync(sp.canvasDir(), { recursive: true });
  const pf = sp.progressFile();
  if (!fs.existsSync(pf)) fs.writeFileSync(pf, JSON.stringify(EMPTY_PROGRESS, null, 2));
}

module.exports = { initStore };
if (require.main === module) { initStore(); console.log(`store ready at ${sp.storeRoot()}`); }
