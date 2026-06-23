/**
 * save-scan-history.mjs
 * Called by GitHub Actions after each scan run.
 * Reads /tmp/scan-round1.txt and /tmp/scan-round2.txt, appends a record
 * to web/scripts/scan-history.json (keeps last 30 entries).
 */
import fs from 'fs';

function extract(file) {
  let txt = '';
  try { txt = fs.readFileSync(file, 'utf8'); } catch {}
  const n = rx => { const m = txt.match(rx); return m ? +m[1] : 0; };
  return { pass: n(/(\d+) passed/), fail: n(/(\d+) failed/), skip: n(/(\d+) skipped/) };
}

const rec = {
  ts: new Date().toISOString(),
  round1: extract('/tmp/scan-round1.txt'),
  round2: extract('/tmp/scan-round2.txt'),
};

let hist = [];
try { hist = JSON.parse(fs.readFileSync('web/scripts/scan-history.json', 'utf8')); } catch {}
hist.unshift(rec);
if (hist.length > 30) hist = hist.slice(0, 30);
fs.writeFileSync('web/scripts/scan-history.json', JSON.stringify(hist, null, 2));
console.log('Saved:', JSON.stringify(rec));
