const fs = require('fs');
const path = require('path');

const apiKey = process.env.ANTHROPIC_API_KEY || '';
const model = process.env.CLAUDE_MODEL || 'claude-opus-4-8';
const prompt = process.env.CLIENT_MOD_PROMPT || '';
const root = process.cwd();
const www = path.join(root, 'www');

const blocked = [
  'www/admin.html',
  'www/commercial-core.js',
  'scripts/prepare_client_variant.js',
  'scripts/apply_claude_client_mods.js',
  '.github/',
  'server/'
];

function normalizeRel(p) {
  return String(p || '').replace(/\\/g, '/').replace(/^\/+/, '');
}
function isBlocked(rel) {
  rel = normalizeRel(rel);
  return blocked.some(b => rel === b || rel.startsWith(b));
}
function assertSafeFile(rel) {
  rel = normalizeRel(rel);
  if (!rel.startsWith('www/')) throw new Error('Claude peut modifier seulement le dossier www/ client: ' + rel);
  if (isBlocked(rel)) throw new Error('Fichier interdit pour Claude: ' + rel);
  const abs = path.resolve(root, rel);
  if (!abs.startsWith(path.resolve(root, 'www') + path.sep)) throw new Error('Chemin invalide: ' + rel);
  return { rel, abs };
}
function snapshot() {
  const out = {};
  function walk(dir) {
    for (const n of fs.readdirSync(dir)) {
      const p = path.join(dir, n);
      const st = fs.statSync(p);
      if (st.isDirectory()) walk(p);
      else {
        const rel = normalizeRel(path.relative(root, p));
        if (!isBlocked(rel) && rel.startsWith('www/')) out[rel] = fs.readFileSync(p, 'utf8');
      }
    }
  }
  walk(www);
  return out;
}
function extractJson(text) {
  const t = String(text || '').trim();
  try { return JSON.parse(t); } catch(e) {}
  const m = t.match(/```json\s*([\s\S]*?)```/i) || t.match(/```\s*([\s\S]*?)```/i);
  if (m) return JSON.parse(m[1]);
  const a = t.indexOf('{'), b = t.lastIndexOf('}');
  if (a >= 0 && b > a) return JSON.parse(t.slice(a, b + 1));
  throw new Error('Réponse Claude non JSON');
}
async function callClaude(context) {
  const body = {
    model,
    max_tokens: 12000,
    system: 'Tu modifies uniquement une copie temporaire CLIENT d’une application web Android/Capacitor. Interdiction absolue de modifier, recréer ou référencer admin.html, commercial-core.js, GitHub, Claude, licences générateur, server, scripts, workflows ou panneau admin. Réponds seulement en JSON valide: {"summary":"...","files":[{"path":"www/fichier.html","content":"contenu complet"}]} . Pas de Markdown.',
    messages: [{ role: 'user', content: `Demande administrateur:\n${prompt}\n\nFichiers clients modifiables actuels JSON:\n${JSON.stringify(context).slice(0, 120000)}` }]
  };
  const res = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01'
    },
    body: JSON.stringify(body)
  });
  const txt = await res.text();
  if (!res.ok) throw new Error('Anthropic ' + res.status + ': ' + txt);
  const data = JSON.parse(txt);
  return (data.content || []).map(x => x.text || '').join('\n');
}
async function main() {
  fs.mkdirSync(path.join(root, 'build'), { recursive: true });
  if (!prompt.trim()) {
    fs.writeFileSync(path.join(root, 'build', 'claude-client-modifications.json'), JSON.stringify({ skipped: true, reason: 'Aucune demande Claude' }, null, 2));
    return;
  }
  if (!apiKey.trim()) throw new Error('ANTHROPIC_API_KEY manquante');
  const beforeAdminExists = fs.existsSync(path.join(www, 'admin.html'));
  const context = snapshot();
  const answer = await callClaude(context);
  const patch = extractJson(answer);
  if (!patch || !Array.isArray(patch.files)) throw new Error('JSON Claude invalide: champ files manquant');
  const changed = [];
  for (const file of patch.files) {
    const { rel, abs } = assertSafeFile(file.path);
    const content = String(file.content || '');
    if (/admin\.html|CommercialCore|dispatchGithubBuild|verifyAdmin|anthropic|github/i.test(content)) {
      throw new Error('Contenu refusé: référence admin/GitHub/Claude détectée dans ' + rel);
    }
    fs.mkdirSync(path.dirname(abs), { recursive: true });
    fs.writeFileSync(abs, content, 'utf8');
    changed.push(rel);
  }
  if (beforeAdminExists && !fs.existsSync(path.join(www, 'admin.html'))) {
    throw new Error('Protection: admin.html a été supprimé pendant une étape Claude');
  }
  fs.writeFileSync(path.join(root, 'build', 'claude-client-modifications.json'), JSON.stringify({ skipped: false, model, prompt, summary: patch.summary || '', changed }, null, 2));
  console.log('Claude client modifications applied:', changed.join(', ') || 'none');
}
main().catch(err => { console.error(err); process.exit(1); });
