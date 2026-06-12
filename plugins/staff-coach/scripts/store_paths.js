'use strict';
// Resolve staff-coach store paths. Honors STAFF_COACH_HOME for testability.
const os = require('node:os');
const path = require('node:path');

function storeRoot() {
  return process.env.STAFF_COACH_HOME || path.join(os.homedir(), '.staff-coach');
}
function progressFile() { return path.join(storeRoot(), 'progress.json'); }
function sessionsDir() { return path.join(storeRoot(), 'sessions'); }
function canvasDir() { return path.join(storeRoot(), 'canvas'); }

module.exports = { storeRoot, progressFile, sessionsDir, canvasDir };
