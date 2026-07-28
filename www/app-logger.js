// app-logger.js — journal détaillé local copiable
(function(){
  const KEY='app_debug_logs_v2';
  const OLD_KEY='app_debug_logs_v1';
  const MAX=1500;
  if(window.__APP_LOGGER_INSTALLED__) return;
  window.__APP_LOGGER_INSTALLED__ = true;

  function safeString(v){
    try{
      if(v instanceof Error) return (v.stack || v.message || String(v));
      if(v && typeof v === 'object'){
        const seen=new WeakSet();
        return JSON.stringify(v,function(k,val){
          if(typeof val==='object' && val!==null){ if(seen.has(val)) return '[Circular]'; seen.add(val); }
          if(typeof val==='function') return '[Function]';
          return val;
        });
      }
      return String(v);
    }catch(e){ try{return String(v);}catch(_){return '[unprintable]';} }
  }
  function readKey(k){try{return JSON.parse(localStorage.getItem(k)||'[]')}catch(e){return []}}
  function read(){ const a=readKey(KEY); return a.length?a:readKey(OLD_KEY); }
  function write(arr){try{localStorage.setItem(KEY, JSON.stringify(arr.slice(-MAX)));}catch(e){}}
  function context(){
    let vault='?'; try{vault=sessionStorage.getItem('active_vault_v1')||localStorage.getItem('active_vault_v1')||'main'}catch(e){}
    let cfg='?'; try{cfg=localStorage.getItem('secret_gallery_calc_v2')?'yes':'no'}catch(e){}
    return `page=${location.pathname||location.href} vault=${vault} hidden=${document.hidden} vis=${document.visibilityState} cfg=${cfg}`;
  }
  function add(level,args){
    const item={t:new Date().toLocaleString('fr-CA'),level,msg:Array.from(args||[]).map(safeString).join(' '),ctx:context()};
    const arr=read(); arr.push(item); write(arr);
    try{window.dispatchEvent(new CustomEvent('app-log-added',{detail:item}));}catch(e){}
  }
  window.AppLogger={
    log:(...a)=>add('LOG',a), info:(...a)=>add('INFO',a), warn:(...a)=>add('WARN',a), error:(...a)=>add('ERROR',a),
    event:(name,data)=>add('EVENT',[name,data||'']),
    nav:(to,reason)=>{add('NAV',[`${location.pathname||location.href} -> ${to}`, 'reason='+reason]);},
    clear:()=>{try{localStorage.removeItem(OLD_KEY)}catch(e){} write([])},
    all:()=>read(),
    text:()=>read().map(x=>`[${x.t}] ${x.level}: ${x.msg}${x.ctx?' | '+x.ctx:''}`).join('\n')
  };

  const oldLog=console.log.bind(console), oldWarn=console.warn.bind(console), oldError=console.error.bind(console);
  console.log=function(){ add('LOG',arguments); oldLog.apply(console,arguments); };
  console.warn=function(){ add('WARN',arguments); oldWarn.apply(console,arguments); };
  console.error=function(){ add('ERROR',arguments); oldError.apply(console,arguments); };

  window.addEventListener('error',function(e){add('JS ERROR',[e.message,'file='+e.filename,'line='+e.lineno,'col='+e.colno,e.error&&(e.error.stack||e.error.message)]);});
  window.addEventListener('unhandledrejection',function(e){const r=e.reason;add('PROMISE ERROR',[r&&(r.stack||r.message)||r||'unknown']);});
  document.addEventListener('DOMContentLoaded',function(){add('PAGE',[location.pathname||location.href,'ref='+document.referrer]);});
  window.addEventListener('pageshow',function(e){add('LIFECYCLE',['pageshow persisted='+!!e.persisted]);});
  window.addEventListener('pagehide',function(e){add('LIFECYCLE',['pagehide persisted='+!!e.persisted]);});
  document.addEventListener('visibilitychange',function(){add('LIFECYCLE',['visibilitychange hidden='+document.hidden,'state='+document.visibilityState]);});
})();
