const fs = require('fs');
const path = require('path');
const root = process.cwd();
const www = path.join(root, 'www');
const bannedFiles = ['admin.html'];
const bannedTerms = [/admin_unlocked/i, /verifyAdmin/i, /dispatchGithubBuild/i, /githubCfg/i, /saveGithubCfg/i, /ANTHROPIC/i, /Claude/i, /GitHub Personal Access Token/i, /Modifier une version client/i];
let errors = [];
for (const f of bannedFiles) if (fs.existsSync(path.join(www, f))) errors.push('Fichier interdit présent: www/' + f);
function walk(dir) {
  for (const n of fs.readdirSync(dir)) {
    const p = path.join(dir, n);
    const st = fs.statSync(p);
    if (st.isDirectory()) walk(p);
    else if (/\.(html|js|css|json|txt)$/i.test(n)) {
      const rel = path.relative(root, p).replace(/\\/g, '/');
      const s = fs.readFileSync(p, 'utf8');
      for (const re of bannedTerms) if (re.test(s)) errors.push('Terme admin interdit dans ' + rel + ': ' + re);
    }
  }
}
walk(www);
if (errors.length) { console.error(errors.join('\n')); process.exit(1); }
console.log('Client variant validation OK: aucun code admin/GitHub/Claude détecté dans www.');
