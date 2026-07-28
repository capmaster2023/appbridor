(function(){
  const te=new TextEncoder();
  function b64(buf){let s='',u=new Uint8Array(buf);for(let i=0;i<u.length;i++)s+=String.fromCharCode(u[i]);return btoa(s).replace(/=+$/,'')}
  async function sha256(s){const d=await crypto.subtle.digest('SHA-256',te.encode(s));return b64(d)}
  function uuid(){return (crypto.randomUUID?crypto.randomUUID():Date.now()+'-'+Math.random().toString(36).slice(2)).toUpperCase()}
  function randHex(n){const a=new Uint8Array(n);crypto.getRandomValues(a);return [...a].map(x=>x.toString(16).padStart(2,'0').toUpperCase()).join('')}
  function randLicense(format){const hex=randHex(8); if(format==='XXXXXXXX-XXXXXXXX'){return hex.slice(0,8)+'-'+hex.slice(8,16)} return hex.match(/.{1,4}/g).join('-')}
  function get(k,def){try{return JSON.parse(localStorage.getItem(k)||JSON.stringify(def))}catch(e){return def}}
  function set(k,v){localStorage.setItem(k,JSON.stringify(v));}
  /* @admin-only:start */
  const DEFAULT_MODEL='claude-opus-4-8';
  const TEST_WORKFLOW='claude-test.yml';
  /* @admin-only:end */
  const API={
    sha256, randLicense,
    cfgKey:'secret_gallery_calc_v2',
    licenseStore(){return get('zak_license_db_v1',[])}, saveLicenses(v){set('zak_license_db_v1',v)},
    logs(){return get('zak_commercial_logs_v1',[])}, log(type,data){const l=this.logs();l.unshift({id:uuid(),type,date:new Date().toISOString(),data:data||{}});set('zak_commercial_logs_v1',l.slice(0,1000));try{AppLogger?.event(type,data||{})}catch(e){}},
    async localIntegrity(){
      const signs=[];
      signs.push(navigator.webdriver?'webdriver':'');
      signs.push(location.protocol==='file:'?'file-protocol':'');
      return {ok:true, signals:signs.filter(Boolean), message:'Contrôle WebView local OK. Les contrôles natifs sont installés via scripts Android quand le projet est compilé.'};
    },
    /* @admin-only:start */
    ghKey:'zak_github_build_cfg_v2', claudeKey:'zak_claude_cfg_v2', testWorkflow:TEST_WORKFLOW,
    async verifyAdmin(code){const cfg=get(this.cfgKey,{}); if(!cfg.adminHash)return false; return await sha256((code||'').trim())===cfg.adminHash},
    githubCfg(){return get(this.ghKey,{owner:'capmaster2023',repo:'calendrier-nueve',branch:'main',url:'https://github.com/capmaster2023/calendrier-nueve',workflow:'client-apk-batch.yml',token:''})},
    saveGithubCfg(v){set(this.ghKey,v)},
    claudeCfg(){const c=get(this.claudeKey,{model:DEFAULT_MODEL}); if(c.apiKey)delete c.apiKey; return {model:c.model||DEFAULT_MODEL}},
    saveClaudeCfg(v){set(this.claudeKey,{model:(v&&v.model)||DEFAULT_MODEL})},
    claudeRequests(){return get('zak_claude_requests_v1',[])},
    saveClaudeRequests(v){set('zak_claude_requests_v1',v)},
    claudeMods(){return get('zak_claude_mods_v1',[])},
    saveClaudeMods(v){set('zak_claude_mods_v1',v)},
    claudeLog(){return get('zak_claude_log_v1',[])},
    saveClaudeLog(v){set('zak_claude_log_v1',v)},
    addClaudeLog(e){const l=this.claudeLog();const now=new Date();l.unshift({id:uuid(),date:now.toLocaleDateString('fr-CA'),time:now.toLocaleTimeString('fr-CA'),iso:now.toISOString(),model:(e&&e.model)||DEFAULT_MODEL,result:(e&&e.result)||'',error:(e&&e.error)||'',type:(e&&e.type)||'test'});this.saveClaudeLog(l.slice(0,500));return l[0]},
    clearClaudeLog(){this.saveClaudeLog([])},
    addClaudeRequest(prompt,model){const l=this.claudeRequests();l.unshift({id:uuid(),date:new Date().toISOString(),model:model||this.claudeCfg().model||DEFAULT_MODEL,prompt:String(prompt||'')});this.saveClaudeRequests(l.slice(0,200));this.log('CLAUDE_REQUEST_SAVED',{model});return l[0]},
    addClaudeMod(data){const l=this.claudeMods();l.unshift({id:uuid(),date:new Date().toISOString(),...(data||{})});this.saveClaudeMods(l.slice(0,200));this.log('CLAUDE_MOD_SAVED',data||{});return l[0]},
    createLicense(customer,format){const l=this.licenseStore(); let id; do{id=randLicense(format)}while(l.some(x=>x.id===id)); const rec={id,customer:customer||'',createdAt:new Date().toISOString(),activatedAt:null,lastCheck:null,deviceId:null,appVersion:'1.0.0',status:'inactive',checks:0,configId:uuid()}; l.unshift(rec); this.saveLicenses(l); this.log('LICENSE_CREATED',{id:rec.id}); return rec},
    batch(n,format){const out=[]; n=Math.max(1,Math.min(50,Number(n)||1)); for(let i=0;i<n;i++)out.push(this.createLicense('Client '+String(i+1).padStart(2,'0'),format)); return out},
    update(id,patch){const l=this.licenseStore(); const i=l.findIndex(x=>x.id===id); if(i>=0){l[i]={...l[i],...patch};this.saveLicenses(l);this.log('LICENSE_UPDATED',{id,patch});return l[i]}},
    _ghHeaders(token,accept){return {'Accept':accept||'application/vnd.github+json','Authorization':'Bearer '+token,'X-GitHub-Api-Version':'2022-11-28'}},
    _api(cfg,p){return `https://api.github.com/repos/${encodeURIComponent(cfg.owner)}/${encodeURIComponent(cfg.repo)}${p}`},
    async checkAnthropicSecret(){
      const cfg=this.githubCfg();
      if(!cfg.token)throw new Error('API GitHub manquante');
      if(!cfg.owner||!cfg.repo)throw new Error('Dépôt GitHub manquant');
      const res=await fetch(this._api(cfg,'/actions/secrets/ANTHROPIC_API_KEY'),{headers:this._ghHeaders(cfg.token)});
      if(res.status===200)return {present:true,checkable:true};
      if(res.status===404)return {present:false,checkable:true};
      return {present:false,checkable:false,status:res.status};
    },
    async dispatchClaudeTest(model){
      const cfg=this.githubCfg();
      if(!cfg.token)throw new Error('API GitHub manquante');
      if(!cfg.owner||!cfg.repo)throw new Error('Dépôt GitHub manquant');
      const runToken=('t'+Date.now().toString(36)+randHex(3)).toLowerCase();
      const url=this._api(cfg,`/actions/workflows/${encodeURIComponent(this.testWorkflow)}/dispatches`);
      const body={ref:cfg.branch||'main',inputs:{claude_model:model||this.claudeCfg().model||DEFAULT_MODEL,run_token:runToken}};
      const res=await fetch(url,{method:'POST',headers:{...this._ghHeaders(cfg.token),'Content-Type':'application/json'},body:JSON.stringify(body)});
      if(!res.ok){let t='';try{t=await res.text()}catch(e){};throw new Error('GitHub '+res.status+' '+t)}
      this.log('CLAUDE_TEST_DISPATCHED',{model,runToken});
      return {runToken,actionsUrl:`https://github.com/${cfg.owner}/${cfg.repo}/actions/workflows/${this.testWorkflow}`};
    },
    async fetchClaudeTestResult(runToken){
      const cfg=this.githubCfg();
      const url=this._api(cfg,`/contents/status/claude-test/${encodeURIComponent(runToken)}.json?ref=${encodeURIComponent(cfg.branch||'main')}`);
      const res=await fetch(url,{headers:this._ghHeaders(cfg.token,'application/vnd.github.raw')});
      if(res.status===404)return null;
      if(!res.ok){let t='';try{t=await res.text()}catch(e){};throw new Error('GitHub '+res.status+' '+t)}
      const txt=await res.text();
      try{return JSON.parse(txt)}catch(e){return null}
    },
    async dispatchGithubBuild(licenses,options){
      const cfg=this.githubCfg();
      if(!cfg.token)throw new Error('API GitHub manquante');
      if(!cfg.owner||!cfg.repo)throw new Error('Dépôt GitHub manquant');
      const url=this._api(cfg,`/actions/workflows/${encodeURIComponent(cfg.workflow||'client-apk-batch.yml')}/dispatches`);
      const claude=this.claudeCfg(); const prompt=String((options&&options.prompt)||''); if(prompt.trim())this.addClaudeRequest(prompt,claude.model);
      const payload={ref:cfg.branch||'main',inputs:{licenses_json:JSON.stringify((licenses||[]).map((x,i)=>({id:x.id,index:i+1,createdAt:x.createdAt,appVersion:x.appVersion||'1.0.0',configId:x.configId||uuid()}))),client_mod_prompt:prompt,claude_model:claude.model||DEFAULT_MODEL}};
      const since=Date.now();
      const res=await fetch(url,{method:'POST',headers:{...this._ghHeaders(cfg.token),'Content-Type':'application/json'},body:JSON.stringify(payload)});
      if(!res.ok){let txt='';try{txt=await res.text()}catch(e){};throw new Error('GitHub '+res.status+' '+txt)}
      this.log('GITHUB_BUILD_DISPATCHED',{count:licenses.length,repo:cfg.owner+'/'+cfg.repo,claude:!!prompt.trim()}); if(prompt.trim())this.addClaudeMod({status:'envoyé à GitHub Actions',model:claude.model,prompt,count:licenses.length});
      return {ok:true,since,count:licenses.length,actionsUrl:`https://github.com/${cfg.owner}/${cfg.repo}/actions/workflows/${cfg.workflow||'client-apk-batch.yml'}`};
    },
    async findRecentRun(workflowFile,sinceMs){
      const cfg=this.githubCfg();
      const url=this._api(cfg,`/actions/workflows/${encodeURIComponent(workflowFile)}/runs?branch=${encodeURIComponent(cfg.branch||'main')}&event=workflow_dispatch&per_page=10`);
      const res=await fetch(url,{headers:this._ghHeaders(cfg.token)});
      if(!res.ok)return null;
      const data=await res.json(); const runs=(data.workflow_runs||[]);
      const cutoff=(sinceMs||0)-15000;
      const match=runs.find(r=>new Date(r.created_at).getTime()>=cutoff)||runs[0];
      return match||null;
    },
    async getRun(id){const cfg=this.githubCfg();const res=await fetch(this._api(cfg,`/actions/runs/${id}`),{headers:this._ghHeaders(cfg.token)});if(!res.ok)throw new Error('GitHub '+res.status);return res.json()},
    async getRunJobs(id){const cfg=this.githubCfg();const res=await fetch(this._api(cfg,`/actions/runs/${id}/jobs?per_page=100`),{headers:this._ghHeaders(cfg.token)});if(!res.ok)throw new Error('GitHub '+res.status);return (await res.json()).jobs||[]},
    async cancelRun(id){const cfg=this.githubCfg();const res=await fetch(this._api(cfg,`/actions/runs/${id}/cancel`),{method:'POST',headers:this._ghHeaders(cfg.token)});this.log('GITHUB_BUILD_CANCELLED',{id});return res.ok}
    /* @admin-only:end */
  };
  window.CommercialCore=API;
})();
