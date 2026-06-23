/**
 * auto-improve-prompt.mjs
 *
 * Analyzes scan test failures with deterministic rules written by the
 * development team. When a known failure pattern is detected, a targeted
 * fix is applied to buildPrompt() in route.ts.
 *
 * This approach is safer than asking an AI to rewrite the prompt because:
 *   - Rules are predictable and auditable
 *   - Each fix is tested against round-2 before committing
 *   - No additional Gemini quota consumed for analysis
 *
 * ENV:
 *   FAILURES_FILE  path to the round-1 test output log  (default /tmp/scan-round1.txt)
 *   ROUTE_FILE     path to route.ts                     (default web/app/api/gemini-product/route.ts)
 *   GITHUB_OUTPUT  set automatically by GitHub Actions
 */

import fs from 'fs';

const FAIL_FILE  = process.env.FAILURES_FILE ?? '/tmp/scan-round1.txt';
const ROUTE_FILE = process.env.ROUTE_FILE    ?? 'web/app/api/gemini-product/route.ts';
const GH_OUTPUT  = process.env.GITHUB_OUTPUT ?? '';

function setOutput(k, v) {
  if (GH_OUTPUT) fs.appendFileSync(GH_OUTPUT, `${k}=${v}\n`);
  else console.log(`[output] ${k}=${v}`);
}

// ─── PARSE FAILURES ───────────────────────────────────────────────────────────
// Returns [{ label, reasons, img }] from the scan test stdout
function parseFailures(log) {
  const failures = [];
  const blocks = log.split(/\n\s*•\s+/).slice(1);
  for (const block of blocks) {
    const lines = block.split('\n').map(l => l.trim()).filter(Boolean);
    if (!lines.length) continue;
    const label   = lines[0].toLowerCase();
    const reasons = lines.filter(l => l.startsWith('- ')).map(l => l.slice(2).toLowerCase());
    const imgLine = lines.find(l => l.startsWith('img:'));
    const img     = imgLine ? imgLine.replace(/^img:\s*/, '') : null;
    failures.push({ label, reasons, img });
  }
  return failures;
}

// ─── PROMPT PATCH RULES ───────────────────────────────────────────────────────
// Each rule: { match(label, reasons) → bool, patch: string to append to prompt }
// Rules are ordered — most specific first.
const PATCH_RULES = [
  {
    id: 'fish-meat-market',
    desc: 'Fish/seafood/meat at market returns is_product:false',
    match: (label) => /fish|prawn|shrimp|crab|lobster|seafood|chicken|mutton|beef|pork|meat/.test(label),
    patch: `\n• Fresh fish, prawns, crabs, chicken, mutton, or any meat/seafood displayed at a market stall or shop = is_product: true (these are sold by weight and are core Kerala shop products)`,
    section: 'WHAT IS NOT A PRODUCT',
  },
  {
    id: 'egg-tray',
    desc: 'Eggs in a tray or carton returns is_product:false',
    match: (label) => /egg/.test(label),
    patch: `\n• Eggs on a tray, in a carton, or loose on a shelf = is_product: true; name = "Eggs" or "Egg Tray 30" etc.`,
    section: 'WHAT IS NOT A PRODUCT',
  },
  {
    id: 'loose-veg-produce',
    desc: 'Loose vegetable / fruit returns is_product:false',
    match: (label) => /banana|bitter gourd|okra|ladyfinger|tomato|onion|potato|carrot|bean|mango|papaya|pineapple|jackfruit|coconut|ginger|garlic|chilli|pepper/.test(label),
    patch: `\n• A single or grouped fresh vegetable or fruit (banana, bitter gourd, tomato, onion, coconut, ginger, chilli …) photographed on a table or in a crate = is_product: true; name it by type (e.g. "Banana", "Bitter Gourd", "Tomato")`,
    section: 'WHAT IS NOT A PRODUCT',
  },
  {
    id: 'spice-loose',
    desc: 'Loose spice / dal / grain returns is_product:false',
    match: (label) => /turmeric|cardamom|pepper|chilli|cinnamon|clove|coriander|cumin|fenugreek|mustard|rice|dal|lentil|pulse|moong|urad|chana|wheat/.test(label),
    patch: `\n• Loose or bagged spices, grains, and pulses (turmeric powder, cardamom, black pepper, rice, dal, lentils …) = is_product: true; name them accurately by type`,
    section: 'WHEN THERE IS NO LABEL OR BRAND',
  },
  {
    id: 'medicine-blister',
    desc: 'Medicine / blister pack / syrup returns is_product:false',
    match: (label) => /paracetamol|medicine|tablet|syrup|blister|capsule|antibiotic|cream|ointment|drops|vitamin|supplement/.test(label),
    patch: `\n• A blister pack, medicine strip, syrup bottle, or cream tube = is_product: true even if brand is unclear; name it by the medicine name visible on pack`,
    section: 'WHAT IS NOT A PRODUCT',
  },
  {
    id: 'hardware-tool',
    desc: 'Hardware / tool returns is_product:false',
    match: (label) => /hammer|screwdriver|wrench|pliers|drill|saw|nail|bolt|screw|wire|pipe|tap|lock|hinge|switch|socket|bulb|torch|battery/.test(label),
    patch: `\n• Hardware items, tools, electrical fittings (hammer, screwdriver, bulb, switch, lock, battery) = is_product: true; name them accurately`,
    section: 'WHAT IS NOT A PRODUCT',
  },
  {
    id: 'clothing-footwear',
    desc: 'Folded clothing or footwear returns is_product:false',
    match: (label) => /t.shirt|shirt|trouser|saree|kurti|pant|dress|kurta|sandal|chappal|shoe|slipper|sneaker|footwear/.test(label),
    patch: `\n• Folded or stacked clothing (shirt, t-shirt, saree, kurta) or footwear (sandal, chappal, shoe) on a shelf or floor display = is_product: true`,
    section: 'WHAT IS NOT A PRODUCT',
  },
  {
    id: 'empty-name',
    desc: 'is_product:true but name is empty',
    match: (_label, reasons) => reasons.some(r => /name empty|must identify/i.test(r)),
    patch: `\n• When is_product is true, the "name" field must NEVER be empty — give a best-guess name based on what you can see and add "name" to uncertain_fields`,
    section: 'JSON OUTPUT',
  },
];

// ─── PROMPT MANIPULATION ─────────────────────────────────────────────────────
// Inserts patch text after the section header inside the prompt string
function applyPatch(prompt, rule) {
  // Find the section and insert the patch after the last bullet in that section
  const sectionRx = new RegExp(`(━━━ ${rule.section} ━━━[\\s\\S]*?)(\\n━━━|$)`);
  const m = prompt.match(sectionRx);
  if (!m) {
    // Section not found — just append before the JSON OUTPUT section
    return prompt.replace(/(━━━ JSON OUTPUT ━━━)/, `${rule.patch}\n\n$1`);
  }
  // Insert patch at the end of the matched section content
  const sectionContent = m[1];
  const after = m[2];
  return prompt.replace(sectionContent + after, sectionContent + rule.patch + after);
}

function extractPrompt(routeSrc) {
  const m = routeSrc.match(/return `([\s\S]*?)\$\{hint\}`;\s*\n/);
  if (m) return { text: m[1], hasHint: true };
  const m2 = routeSrc.match(/return `([\s\S]*?)`;\s*\n\s*\}/);
  return m2 ? { text: m2[1], hasHint: false } : null;
}

function writePrompt(routeSrc, newText, hasHint) {
  if (hasHint) {
    return routeSrc.replace(
      /(return `)([\s\S]*?)(\$\{hint\}`;\s*\n)/,
      (_, a, _old, c) => a + newText + c
    );
  }
  return routeSrc.replace(
    /(return `)([\s\S]*?)(`;\s*\n\s*\})/,
    (_, a, _old, c) => a + newText + c
  );
}

// ─── MAIN ────────────────────────────────────────────────────────────────────
async function main() {
  if (!fs.existsSync(FAIL_FILE)) {
    console.log(`[auto-improve] ${FAIL_FILE} not found — nothing to do`);
    setOutput('improved', 'false');
    return;
  }
  if (!fs.existsSync(ROUTE_FILE)) {
    console.log(`[auto-improve] ${ROUTE_FILE} not found`);
    setOutput('improved', 'false');
    return;
  }

  const log      = fs.readFileSync(FAIL_FILE, 'utf8');
  const failures = parseFailures(log);
  if (!failures.length) {
    console.log('[auto-improve] No failures in log — prompt is already good');
    setOutput('improved', 'false');
    return;
  }

  console.log(`[auto-improve] Analysing ${failures.length} failures with deterministic rules:`);
  failures.forEach(f => console.log(`  • ${f.label}`));

  const routeSrc = fs.readFileSync(ROUTE_FILE, 'utf8');
  const extracted = extractPrompt(routeSrc);
  if (!extracted) {
    console.log('[auto-improve] Could not extract prompt from route.ts');
    setOutput('improved', 'false');
    return;
  }

  let { text: prompt, hasHint } = extracted;
  const appliedRules = [];

  for (const failure of failures) {
    for (const rule of PATCH_RULES) {
      if (rule.match(failure.label, failure.reasons)) {
        // Only apply each rule once
        if (appliedRules.includes(rule.id)) continue;
        // Only apply if patch not already present
        if (prompt.includes(rule.patch.trim())) {
          console.log(`  [skip] ${rule.id} — already in prompt`);
          continue;
        }
        console.log(`  [fix] ${rule.id} — ${rule.desc}`);
        prompt = applyPatch(prompt, rule);
        appliedRules.push(rule.id);
      }
    }
  }

  if (!appliedRules.length) {
    console.log('[auto-improve] No matching rules — manual review needed');
    console.log('[auto-improve] Unmatched failures:');
    failures.forEach(f => console.log(`  • "${f.label}" — ${f.reasons.join('; ')}`));
    setOutput('improved', 'false');
    return;
  }

  const newRouteSrc = writePrompt(routeSrc, prompt, hasHint);
  if (newRouteSrc === routeSrc) {
    console.log('[auto-improve] writePrompt produced no change — regex mismatch');
    setOutput('improved', 'false');
    return;
  }

  fs.writeFileSync(ROUTE_FILE, newRouteSrc, 'utf8');
  console.log(`[auto-improve] Applied ${appliedRules.length} fix(es): ${appliedRules.join(', ')}`);
  setOutput('improved', 'true');
}

main().catch(e => {
  console.error('[auto-improve] Fatal:', e.message);
  setOutput('improved', 'false');
});
