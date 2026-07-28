// Test réel de connexion Claude, exécuté DANS GitHub Actions.
// La clé vient du secret ANTHROPIC_API_KEY. Aucun appel direct depuis l'app.
// Le résultat exact est publié dans status/claude-test/<run_token>.json (lisible par l'app).
const apiKey   = process.env.ANTHROPIC_API_KEY || '';
const model    = process.env.CLAUDE_MODEL || 'claude-opus-4-8';
const runToken = process.env.RUN_TOKEN || ('test-' + Date.now());
const repo     = process.env.GITHUB_REPOSITORY || '';            // owner/name
const branch   = process.env.RESULT_BRANCH || 'main';
const ghToken  = process.env.GH_TOKEN || process.env.GITHUB_TOKEN || '';

async function publish(result) {
  if (!repo || !ghToken) { console.log('Pas de token/repo: publication ignorée'); return; }
  const p = `status/claude-test/${runToken}.json`;
  const url = `https://api.github.com/repos/${repo}/contents/${p}`;
  const h = { 'Authorization': 'Bearer ' + ghToken, 'Accept': 'application/vnd.github+json', 'User-Agent': 'claude-connection-test', 'X-GitHub-Api-Version': '2022-11-28' };
  let sha;
  try { const head = await fetch(url + `?ref=${encodeURIComponent(branch)}`, { headers: h }); if (head.ok) { sha = (await head.json()).sha; } } catch (e) {}
  const body = { message: `claude test ${runToken}`, content: Buffer.from(JSON.stringify(result, null, 2)).toString('base64'), branch };
  if (sha) body.sha = sha;
  const put = await fetch(url, { method: 'PUT', headers: { ...h, 'Content-Type': 'application/json' }, body: JSON.stringify(body) });
  if (!put.ok) { console.error('Publication échouée', put.status, await put.text()); }
  else { console.log('Résultat publié:', p); }
}

async function main() {
  const result = { runToken, date: new Date().toISOString(), model, ok: false, result: '', error: '', httpStatus: 0 };
  if (!apiKey.trim()) {
    result.result = 'Échec';
    result.error = 'Secret ANTHROPIC_API_KEY absent ou vide dans GitHub Secrets';
    await publish(result);
    console.error(result.error);
    process.exit(1);
  }
  try {
    const res = await fetch('https://api.anthropic.com/v1/messages', {
      method: 'POST',
      headers: { 'content-type': 'application/json', 'x-api-key': apiKey, 'anthropic-version': '2023-06-01' },
      body: JSON.stringify({ model, max_tokens: 16, messages: [{ role: 'user', content: 'Réponds uniquement: OK' }] })
    });
    result.httpStatus = res.status;
    const txt = await res.text();
    if (!res.ok) {
      result.result = 'Échec';
      result.error = `Anthropic ${res.status}: ${txt.slice(0, 600)}`;
    } else {
      let data = {}; try { data = JSON.parse(txt); } catch (e) {}
      const reply = (data.content || []).map(x => x.text || '').join(' ').trim();
      result.ok = true;
      result.result = 'Connexion réussie';
      result.reply = reply.slice(0, 160);
    }
  } catch (e) {
    result.result = 'Échec';
    result.error = 'Réseau: ' + (e && e.message ? e.message : String(e));
  }
  await publish(result);
  console.log(JSON.stringify(result));
  process.exit(result.ok ? 0 : 1);
}
main().catch(async e => { console.error(e); try { await publish({ runToken, date: new Date().toISOString(), model, ok: false, result: 'Échec', error: String(e && e.message || e) }); } catch (_) {} process.exit(1); });
