const fs=require('fs');
const path=require('path');
const license=process.env.CLIENT_LICENSE||'';
const index=process.env.CLIENT_INDEX||'1';
const configId=process.env.CLIENT_CONFIG_ID||('client-'+index);
const www=path.join(process.cwd(),'www');

// Les APK clients doivent toujours rester une app séparée nommée Calculatrice.
try {
  const capPath = path.join(process.cwd(), 'capacitor.config.json');
  const cap = JSON.parse(fs.readFileSync(capPath, 'utf8'));
  cap.appId = 'com.capmaster2023.calculatrice';
  cap.appName = 'Calculatrice';
  fs.writeFileSync(capPath, JSON.stringify(cap, null, 2));
} catch (e) { console.warn('capacitor client config patch', e.message); }
function rw(file,fn){const p=path.join(www,file); let s=fs.readFileSync(p,'utf8'); s=fn(s); fs.writeFileSync(p,s)}
try{fs.rmSync(path.join(www,'admin.html'),{force:true});}catch(e){}
try{rw('home.html',s=>s
  .replace(/\s*<button class="app" data-app="admin"[\s\S]*?<\/button>/,'')
  .replace(/\s*else if\(a==='admin'\)\{goInternal\('admin\.html','home app admin click'\);\}/,'')
  .replace(/const cfg=JSON\.parse\(localStorage\.getItem\('secret_gallery_calc_v2'\)\|\|'\{\}'\); if\(cfg\.adminEnabled&&document\.getElementById\('adminApp'\)\) document\.getElementById\('adminApp'\)\.style\.display='flex';/,'')
);}catch(e){console.warn('home patch',e.message)}
try{rw('index.html',s=>{
  // Retirer l'interface et la logique Admin UNIQUEMENT dans la copie client.
  s=s.replace(/\n\s*<input id="setupAdmin"[^>]*>/g,'');

  // Retirer le bloc de retour automatique Admin 5 minutes ajouté dans la version administrateur.
  s=s.replace(/\n\s*\(function\(\)\{\n\s*const ADMIN_TIMEOUT_MS[\s\S]*?\n\s*\}\)\(\);/,'');
  s=s.replace(/\n\s*const ADMIN_TIMEOUT_MS[\s\S]*?sessionStorage\.removeItem\('admin_unlocked'\);\n\s*\}\n\s*\}catch\(e\)\{\}/,'');

  // Retirer les accès directs au panneau Admin depuis la calculatrice.
  s=s.replace(/\n\s*if\(CFG\s*&&\s*CFG\.adminHash\s*&&\s*await\s+CommercialCore\.verifyAdmin\(n\)\)\{[^\n]*?admin\.html';return\}/g,'');

  // Retirer la remise à zéro du champ admin dans la fenêtre de configuration.
  s=s.replace(/\n\s*\$\('setupAdmin'\)\.value\s*=\s*'';?/g,'');

  // Remplacer l'enregistrement à 3 codes par une configuration client à 2 codes.
  s=s.replace(/\n\s*const admin=norm\(\$\('setupAdmin'\)\.value\);[\s\S]*?\n\s*CommercialCore\.sha256\(admin\)\.then\(adminHash=>\{\n\s*setCfg\(\{calc:c,secondaryCalc:c2,adminHash,adminEnabled:true,created:Date\.now\(\)\}\);/,
`\n  if(c===c2){toast('Les deux codes doivent être différents');return}
  try{calcEval(c);calcEval(c2)}catch(e){toast('Code invalide');return}
  AppLogger?.event('CONFIG_SAVE_ATTEMPT',{main:c,secondary:c2,client:true});
  setCfg({calc:c,secondaryCalc:c2,clientLicense:CLIENT_LICENSE_ID,adminEnabled:false,created:Date.now()});`);

  // Retirer la fermeture du Promise .then retiré ci-dessus.
  s=s.replace(/\n\s*AppLogger\?\.event\('CONFIG_SAVE_OK',\{main:c,secondary:c2,admin:true\}\);toast\('Code enregistré'\);\n\s*\}\);/,
"\n  AppLogger?.event('CONFIG_SAVE_OK',{main:c,secondary:c2,client:true});toast('Code enregistré');");

  // Nettoyage de sécurité si un ancien marqueur admin reste dans la copie client.
  s=s.replace(/adminHash/g,'clientHashRemoved');
  s=s.replace(/adminEnabled:true/g,'adminEnabled:false');
  s=s.replace(/admin_unlocked/g,'client_unlocked_removed');
  s=s.replace(/admin_session_active_v1/g,'client_session_removed');
  s=s.replace(/admin_last_activity_v1/g,'client_last_removed');
  s=s.replace(/admin\.html/g,'home.html');

  s=s.replace('<script src="app-logger.js"></script>','<script>const CLIENT_LICENSE_ID='+JSON.stringify(license)+';</script>\n<script src="app-logger.js"></script>');
  return s;
});}catch(e){console.warn('index patch',e.message)}
// Retire tout le code admin/GitHub/Claude de la copie CLIENT via les marqueurs @admin-only.
try{rw('commercial-core.js',s=>s.replace(/\/\*\s*@admin-only:start\s*\*\/[\s\S]*?\/\*\s*@admin-only:end\s*\*\//g,''));}catch(e){console.warn('core patch',e.message)}
fs.writeFileSync(path.join(www,'client-license.json'),JSON.stringify({license,index,configId,admin:false,createdAt:new Date().toISOString()},null,2));
console.log('Client variant prepared without admin code:', license);
