'use strict';
// Validate examiner JSON against the four-filter contract. Pure stdlib.
// Runtime usage: node validate_examiner_output.js < output.json  -> exit 0/1
const SEVERITIES = new Set(['minor', 'major', 'critical']);

function validate(data) {
  const e = [];
  if (!data || typeof data !== 'object' || Array.isArray(data)) return { ok: false, errors: ['root must be an object'] };
  for (const k of ['problem_type', 'verdict_summary', 'dimensions']) if (!(k in data)) e.push(`missing top-level key: ${k}`);
  const dims = data.dimensions;
  if (!Array.isArray(dims)) return { ok: false, errors: [...e, 'dimensions must be an array'] };
  dims.forEach((d, di) => {
    const loc = `dimensions[${di}]`;
    for (const k of ['dimension', 'score', 'meets_staff_bar', 'findings']) if (!(k in d)) e.push(`${loc} missing ${k}`);
    if (!Number.isInteger(d.score) || d.score < 1 || d.score > 5) e.push(`${loc}.score must be int 1-5`);
    const findings = d.findings;
    if (!Array.isArray(findings)) { e.push(`${loc}.findings must be an array`); return; }
    if (findings.length > 3) e.push(`${loc}.findings exceeds cap of 3 (filter 3)`);
    findings.forEach((f, fi) => {
      const fl = `${loc}.findings[${fi}]`;
      if (!SEVERITIES.has(f.severity)) e.push(`${fl}.severity invalid`);
      if (!f.consequence) e.push(`${fl}.consequence empty (filter 1)`);
      if (!f.stronger_design) e.push(`${fl}.stronger_design empty`);
      if (!f.likelihood_magnitude) e.push(`${fl}.likelihood_magnitude empty`);
      if (f.ledger_checked !== true) e.push(`${fl}.ledger_checked must be true (filter 2)`);
      if (f.survived_self_prosecution !== true) e.push(`${fl}.survived_self_prosecution must be true (filter 4)`);
    });
  });
  return { ok: e.length === 0, errors: e };
}

module.exports = { validate };

if (require.main === module) {
  let raw = '';
  process.stdin.on('data', (c) => (raw += c));
  process.stdin.on('end', () => {
    const { ok, errors } = validate(JSON.parse(raw));
    if (ok) { console.log('VALID'); process.exit(0); }
    console.log('INVALID:\n' + errors.join('\n')); process.exit(1);
  });
}
