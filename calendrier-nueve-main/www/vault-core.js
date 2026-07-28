(function(){
  const VAULT_KEY='active_vault_v1', SETTINGS_PREFIX='vault_settings_', KEY_PREFIX='vault_crypto_key_';
  const te=new TextEncoder(), td=new TextDecoder();
  window.VaultCore={
    current(){return sessionStorage.getItem(VAULT_KEY)||localStorage.getItem(VAULT_KEY)||'main';},
    set(v){v=(v==='secondary')?'secondary':'main';sessionStorage.setItem(VAULT_KEY,v);localStorage.setItem(VAULT_KEY,v);},
    label(){return this.current()==='secondary'?'Coffre secondaire':'Coffre principal';},
    dbName(kind){return 'vault_'+this.current()+'_'+kind+'_db_v1';},
    settings(){try{return JSON.parse(localStorage.getItem(SETTINGS_PREFIX+this.current())||'{}')}catch(e){return {}}},
    saveSettings(s){localStorage.setItem(SETTINGS_PREFIX+this.current(),JSON.stringify(s||{}));},
    allDbNames(){const kinds=['gallery','files','notes','pdf','archives'];const vaults=['main','secondary'];return vaults.flatMap(v=>kinds.map(k=>'vault_'+v+'_'+k+'_db_v1'));},
    deleteDb(name){return new Promise(res=>{try{const r=indexedDB.deleteDatabase(name);r.onsuccess=r.onerror=r.onblocked=()=>res();}catch(e){res();}});},
    async wipeAllVaultData(){
      const previous=this.current();
      try{
        for(const v of ['main','secondary']){try{await window.Capacitor?.Plugins?.Vault?.wipeVault?.({vault:v});}catch(e){}}
        await Promise.all(this.allDbNames().map(n=>this.deleteDb(n)));
        const remove=[];
        for(let i=0;i<localStorage.length;i++){const k=localStorage.key(i);if(!k)continue;if(k.startsWith(KEY_PREFIX)||k.startsWith(SETTINGS_PREFIX)||k.startsWith('reading_')||k.startsWith('reading_last_'))remove.push(k);}
        remove.forEach(k=>localStorage.removeItem(k));
        sessionStorage.removeItem(VAULT_KEY);
        localStorage.setItem(VAULT_KEY,previous);
        AppLogger?.event('WIPE_ALL_VAULT_DATA_DONE',{dbs:this.allDbNames().length,keys:remove.length});
        return true;
      }catch(e){AppLogger?.error('WIPE_ALL_VAULT_DATA_FAIL',e);return false;}
    },
    async key(){const v=this.current();let jwk=null;try{jwk=JSON.parse(localStorage.getItem(KEY_PREFIX+v)||'null')}catch(e){};if(!jwk){const k=await crypto.subtle.generateKey({name:'AES-GCM',length:256},true,['encrypt','decrypt']);jwk=await crypto.subtle.exportKey('jwk',k);localStorage.setItem(KEY_PREFIX+v,JSON.stringify(jwk));return k;}return crypto.subtle.importKey('jwk',jwk,{name:'AES-GCM'},false,['encrypt','decrypt']);},
    b64(buf){let s='',u=new Uint8Array(buf);for(let i=0;i<u.length;i++)s+=String.fromCharCode(u[i]);return btoa(s);},
    fromB64(b){let s=atob(b),u=new Uint8Array(s.length);for(let i=0;i<s.length;i++)u[i]=s.charCodeAt(i);return u.buffer;},
    async encrypt(buf){const iv=crypto.getRandomValues(new Uint8Array(12));const k=await this.key();const data=await crypto.subtle.encrypt({name:'AES-GCM',iv},k,buf);return {iv:this.b64(iv),data};},
    async decrypt(rec){const k=await this.key();return crypto.subtle.decrypt({name:'AES-GCM',iv:new Uint8Array(this.fromB64(rec.iv))},k,rec.data);},
    async encryptText(t){return this.encrypt(te.encode(t).buffer)},
    async decryptText(rec){return td.decode(await this.decrypt(rec));},
    async auth(){try{AppLogger?.event('AUTH_START',{vault:this.current(),hasPlugin:!!window.Capacitor?.Plugins?.VaultSecurity?.authenticate});if(window.Capacitor?.Plugins?.VaultSecurity?.authenticate){await window.Capacitor.Plugins.VaultSecurity.authenticate({reason:'Déverrouiller le coffre'});AppLogger?.event('AUTH_OK',{vault:this.current()});return true;}}catch(e){AppLogger?.error('AUTH_FAIL',e);return false;}AppLogger?.event('AUTH_BYPASS_NO_PLUGIN',{vault:this.current()});return true;},
    async applySecure(){const s=this.settings();try{AppLogger?.event('FLAG_SECURE_APPLY',{enabled:!!(s.antiScreenshot||s.antiRecording),settings:s});await window.Capacitor?.Plugins?.VaultSecurity?.setFlagSecure?.({enabled:!!(s.antiScreenshot||s.antiRecording)});}catch(e){AppLogger?.error('FLAG_SECURE_ERROR',e);}},
    async openVault(v){AppLogger?.event('OPEN_VAULT_REQUEST',{requested:v,currentBefore:this.current()});this.set(v); const ok=await this.auth(); AppLogger?.event('OPEN_VAULT_AUTH_RESULT',{vault:this.current(),ok:ok}); if(ok){AppLogger?.nav('home.html','VaultCore.openVault ok vault='+this.current()); location.href='home.html';}else{AppLogger?.warn('OPEN_VAULT_BLOCKED_AUTH_FAILED',this.current());}}
  };
  document.addEventListener('DOMContentLoaded',()=>VaultCore.applySecure());
})();
