(function(){
  'use strict';

  const ID='cameraActiveIndicator';
  const STYLE_ID='cameraActiveIndicatorStyle';
  const KEY_SHOWN='CAMERA_INDICATOR_SHOWN_FOR_CURRENT_RECORDING';
  const SHOW_MS=10000;
  let hideTimer=null;

  function ensureStyle(){
    if(document.getElementById(STYLE_ID)) return;
    const st=document.createElement('style');
    st.id=STYLE_ID;
    st.textContent=`
      #${ID}{
        position:fixed;
        top:4px;
        right:5px;
        width:18px;
        height:18px;
        border-radius:999px;
        background:#2596be;
        box-shadow:0 0 0 2px rgba(255,255,255,.65),0 0 12px rgba(37,150,190,.75);
        z-index:2147483647;
        pointer-events:none;
        display:none;
      }
      #${ID}.on{display:block;}
    `;
    document.head.appendChild(st);
  }

  function ensureDot(){
    ensureStyle();
    let el=document.getElementById(ID);
    if(!el){
      el=document.createElement('div');
      el.id=ID;
      el.setAttribute('aria-hidden','true');
      document.documentElement.appendChild(el);
    }
    return el;
  }

  function setVisible(on){
    const el=ensureDot();
    el.classList.toggle('on',!!on);
  }

  function clearHideTimer(){
    if(hideTimer){
      clearTimeout(hideTimer);
      hideTimer=null;
    }
  }

  // Affiche le cercle seulement 10 secondes au début de l'activation caméra.
  // Tant que l'enregistrement continue, il ne revient pas en boucle.
  function showForTenSecondsOnce(){
    ensureDot();
    let alreadyShown=false;
    try{ alreadyShown=localStorage.getItem(KEY_SHOWN)==='1'; }catch(_){ }
    if(alreadyShown) return;

    try{ localStorage.setItem(KEY_SHOWN,'1'); }catch(_){ }
    setVisible(true);
    clearHideTimer();
    hideTimer=setTimeout(()=>{
      hideTimer=null;
      setVisible(false);
    },SHOW_MS);
  }

  // À appeler quand la caméra s'arrête : ça cache tout et réarme pour le prochain démarrage.
  function resetAfterCameraStop(){
    clearHideTimer();
    setVisible(false);
    try{ localStorage.removeItem(KEY_SHOWN); }catch(_){ }
  }

  async function syncFromNative(){
    try{
      const p=window.Capacitor?.Plugins?.CameraRecorder;
      if(p?.isRecording){
        const r=await p.isRecording();
        if(r?.recording) showForTenSecondsOnce();
        else resetAfterCameraStop();
      }
    }catch(_){ }
  }

  window.CameraIndicator={
    show:showForTenSecondsOnce,
    hide:resetAfterCameraStop,
    sync:syncFromNative
  };

  if(document.readyState==='loading'){
    document.addEventListener('DOMContentLoaded',syncFromNative,{once:true});
  }else{
    syncFromNative();
  }
  setInterval(syncFromNative,1500);
  window.addEventListener('focus',syncFromNative);
  document.addEventListener('visibilitychange',syncFromNative);
})();
