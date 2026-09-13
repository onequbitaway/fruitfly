const byId=id=>document.getElementById(id);
async function command(name,extra={}){
  try{
    const response=await fetch('/command',{method:'POST',headers:{'Content-Type':'application/json','X-FlyPilot':'1'},body:JSON.stringify({command:name,...extra})});
    if(!response.ok)throw new Error(await response.text());
  }catch(error){byId('error').hidden=false;byId('error').textContent=error.message;}
}
for(const name of ['start','pause','reset'])byId(name).addEventListener('click',()=>command(name));
byId('mode').addEventListener('change',event=>command('mode',{mode:event.target.value}));
byId('details').addEventListener('click',()=>{const panel=byId('detail-panel');panel.hidden=!panel.hidden;byId('details').setAttribute('aria-expanded',String(!panel.hidden));});
let lastTime=-1,lastMode='';
async function poll(){
  try{
    const response=await fetch('/state');if(!response.ok)throw new Error('The local server stopped. Open the launcher to start it.');
    const state=await response.json();byId('status').textContent=state.status;
    byId('dot').classList.toggle('running',state.running);byId('start').disabled=state.running||state.status.startsWith('Loading');byId('pause').disabled=!state.running;
    byId('mode').value=state.mode;byId('cell-count').textContent=state.mode==='full'?'The Full map calculates 166,700 cells.':'Simple calculates 3,745 cells. It uses a smell proxy.';byId('error').hidden=!state.error;byId('error').textContent=state.error||'';
    if(state.frame){
      const f=state.frame;byId('clock').textContent=`Model ${f.time.toFixed(1)} s / Wall ${f.wallSeconds.toFixed(1)} s`;
      byId('speed').textContent=`${(f.time/Math.max(.001,f.wallSeconds)).toFixed(2)}× real time`;
      byId('hash').textContent=`Rate hash: ${f.rateHash}`;
      if(f.time!==lastTime||state.mode!==lastMode){
        const image=await fetch(`/frame.jpg?t=${f.time}`);
        if(image.status===200){const old=byId('view').src;byId('view').src=URL.createObjectURL(await image.blob());if(old.startsWith('blob:'))URL.revokeObjectURL(old);byId('view').hidden=false;byId('empty').hidden=true;}
        lastTime=f.time;lastMode=state.mode;
      }
    }else{byId('view').hidden=true;byId('empty').hidden=false;byId('clock').textContent='No flight yet';byId('speed').textContent='Local calculation';byId('hash').textContent='No rate hash yet.';lastTime=-1;}
  }catch(error){byId('status').textContent='Connection lost.';byId('error').hidden=false;byId('error').textContent=error.message;}
  setTimeout(poll,150);
}
poll();
