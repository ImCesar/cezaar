'use strict';
// Tiny stdlib whiteboard server: serves index.html, accepts board exports.
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const sp = require('../store_paths.js');

function nextIndex() {
  if (!fs.existsSync(sp.canvasDir())) return 1;
  return fs.readdirSync(sp.canvasDir()).filter(f => f.startsWith('board-') && f.endsWith('.png')).length + 1;
}

function saveBoard(payload) {
  fs.mkdirSync(sp.canvasDir(), { recursive: true });
  const n = nextIndex();
  const png = path.join(sp.canvasDir(), `board-${n}.png`);
  const json = path.join(sp.canvasDir(), `board-${n}.excalidraw.json`);
  fs.writeFileSync(png, Buffer.from(payload.png_base64, 'base64'));
  fs.writeFileSync(json, JSON.stringify(payload.scene_json, null, 2));
  return { png, json };
}

function main(port = 4137) {
  const server = http.createServer((req, res) => {
    if (req.method === 'GET' && (req.url === '/' || req.url === '/index.html')) {
      const body = fs.readFileSync(path.join(__dirname, 'index.html'));
      res.writeHead(200, { 'Content-Type': 'text/html' }); res.end(body);
    } else if (req.method === 'POST' && req.url === '/save') {
      let raw = ''; req.on('data', c => (raw += c));
      req.on('end', () => {
        const out = saveBoard(JSON.parse(raw));
        res.writeHead(200, { 'Content-Type': 'application/json' }); res.end(JSON.stringify(out));
      });
    } else { res.writeHead(404); res.end(); }
  });
  server.listen(port, 'localhost', () => console.log(`Whiteboard at http://localhost:${port}  (canvas: ${sp.canvasDir()})`));
}

module.exports = { saveBoard, main };
if (require.main === module) main();
