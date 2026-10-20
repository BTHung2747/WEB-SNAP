const {chromium}=require('C:/Users/LENOVO/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright');
const fs=require('node:fs/promises'),path=require('node:path'),assert=require('node:assert/strict'),crypto=require('node:crypto');
const out=process.argv[2],before=process.argv[3]==='before',build=process.argv[4],imageFile=process.argv[5],base='http://127.0.0.1:5196';
const cases=[],requests=[],errors=[],contexts=[];let browser,server;
const sleep=n=>new Promise(r=>setTimeout(r,n));
async function record(name,fn){await fs.writeFile(path.join(out,'current-case.json'),JSON.stringify({name}));await fn();cases.push({name,status:'PASS'});await fs.writeFile(path.join(out,'progress.json'),JSON.stringify(cases,null,2));}
function data(n=5,kind='photo',id='job-A'){return {id,state:'selectable',title:kind==='photo'?'Bài ảnh kiểm thử':'Video kiểm thử',duration:kind==='photo'?null:27,previewUrl:null,errorCode:null,items:[{id:'item-'+id,kind,formats:Array.from({length:kind==='photo'?n:1},(_,i)=>({id:kind==='photo'?'ttp1_'+String(i+1).padStart(2,'0')+'_'+'a'.repeat(64):'18',label:kind==='photo'?`Ảnh ${i+1}/${n}`:'MP4 H.264 có tiếng',size:null,...(kind==='photo'?{kind:'photo',imageCount:n,index:i+1,width:64,height:64}:{})}))}]};}
async function fixture(opts={}){
 const {n=5,kind='photo',width=1280,motion='no-preference',color='light'}=opts,cap=Object.hasOwn(opts,'cap')?opts.cap:true;
 const context=await browser.newContext({viewport:{width,height:960},reducedMotion:motion,colorScheme:color,acceptDownloads:true});contexts.push(context);
 const page=await context.newPage();page.setDefaultTimeout(6000);page.on('pageerror',e=>errors.push(e.name));
 let job=data(n,kind),prepares=[],tickets=0,next=0,holdPrepare=false,releasePrepare,holdTicket=false,releaseTicket,ticketFail=false;
 const f={page,context,prepares,get job(){return job},set job(v){job=v},get tickets(){return tickets},holdPrepare(){holdPrepare=true},releasePrepare(){releasePrepare?.()},holdTicket(){holdTicket=true},releaseTicket(){releaseTicket?.()},failTicket(){ticketFail=true}};
 await context.route('**/*',async route=>{
  const req=route.request(),u=new URL(req.url());
  if(u.origin!==base){requests.push({kind:'blocked-external',type:req.resourceType()});await route.abort();return;}
  if(!u.pathname.startsWith('/api/'))return route.continue();
  const p=u.pathname.replace('/api/v1/',''),m=req.method();let body;try{body=req.postDataJSON()}catch{}
  requests.push({fixture:true,path:p,method:m,...(p.endsWith('/prepare')?{body}:{}),csrfPresent:req.headers()['x-csrf-token']==='fixture-csrf'});
  const json=(v,status=200)=>route.fulfill({status,contentType:'application/json',body:JSON.stringify(v)});
  if(p==='session')return json({csrf:'fixture-csrf',productName:'WED SNAP',supported:['youtube','tiktok'],contact:null,heartbeatSeconds:15,...(cap===undefined?{}:{capabilities:{tiktokPhoto:cap}})});
  if(p.startsWith('ads'))return json(null);
  if(p==='jobs/analyze'){next++;if(next>1)job=data(n,kind,'job-'+next);return json({jobId:job.id},202);}
  if(p.endsWith('/prepare')){prepares.push(body);if(holdPrepare)await new Promise(r=>releasePrepare=r);job.state='queued';return json({state:'queued'},202);}
  if(p.endsWith('/download-ticket')){tickets++;if(holdTicket)await new Promise(r=>releaseTicket=r);if(ticketFail){ticketFail=false;return json({code:'SOURCE_TIMEOUT'},504);}return json({url:'/native-image.jpg'},201);}
  if(p.endsWith('/cancel'))return json({state:'cancelled'});
  if(p.endsWith('/heartbeat')||p.endsWith('/release'))return json({ok:true});
  if(p.startsWith('jobs/'))return json(job);
  return json({code:'NOT_FOUND'},404);
 });
 await page.goto(base);await page.getByLabel(/Đường dẫn/).waitFor();
 f.analyze=async()=>{await page.getByLabel(/Đường dẫn/).fill(kind==='photo'?'https://www.tiktok.com/@fixture/photo/7000000000000000001':'https://www.youtube.com/watch?v=abcdefghijk');await page.getByRole('button',{name:'Phân tích link'}).click();await sleep(100);if(!before&&kind==='photo'&&cap!==true)await page.getByText('Tải ảnh TikTok chưa được bật.',{exact:false}).waitFor();else await page.getByRole('heading',{name:job.title}).waitFor();};
 f.refresh=async()=>{await sleep(2150)};
 f.close=()=>context.close();
 return f;
}
async function shot(page,name){await page.screenshot({path:path.join(out,name+'.png'),fullPage:true});}
async function main(){
 const end=Date.now()+15000;while(true){try{await fs.access(path.join(out,'release'));break;}catch{if(Date.now()>end)throw Error('JOB_ASSIGNMENT_GATE');await sleep(30);}}
 server=require('node:http').createServer(async(req,res)=>{
  try{
   const u=new URL(req.url,base),download=u.pathname==='/native-image.jpg';
   const target=download?imageFile:path.resolve(build,'.'+(u.pathname==='/'?'/index.html':u.pathname));
   if(!download&&!target.startsWith(path.resolve(build)+path.sep)){res.writeHead(403).end();return;}
   const body=await fs.readFile(target);res.writeHead(200,{'content-type':download?'image/jpeg':target.endsWith('.js')?'application/javascript':target.endsWith('.css')?'text/css':'text/html','content-length':body.length,'cache-control':'no-store',...(download?{'content-disposition':'attachment; filename="wed-snap-image.jpg"'}:{})});res.end(body);
  }catch{res.writeHead(404).end();}
 });
 await new Promise((resolve,reject)=>{server.once('error',reject);server.listen(5196,'127.0.0.1',resolve)});
 browser=await chromium.launch({channel:'msedge',headless:true,chromiumSandbox:true,timeout:20000});
 if(before){const f=await fixture({cap:false,kind:'video'});await f.analyze();await shot(f.page,'before-desktop');await f.page.setViewportSize({width:375,height:960});await shot(f.page,'before-mobile');await f.close();}
 else{
 await record('photo2-pending-lock-idempotency-queued-preparing-ready-native-jpg',async()=>{
  const f=await fixture();await f.analyze();const p=f.page,s=p.getByLabel('Chọn một ảnh');assert.equal(await s.locator('option').count(),5);assert.equal(await p.locator('.selection img').count(),0);
  await s.selectOption({index:1});await s.focus();assert.equal(await s.evaluate(e=>e===document.activeElement),true);await shot(p,'photo5-desktop-focus');
  const contrasts=await p.evaluate(()=>{
   const rgb=s=>s.match(/[\d.]+/g).slice(0,3).map(Number),l=c=>c.map(v=>{v/=255;return v<=.04045?v/12.92:((v+.055)/1.055)**2.4}).reduce((a,v,i)=>a+v*[.2126,.7152,.0722][i],0),ratio=(a,b)=>(Math.max(l(a),l(b))+.05)/(Math.min(l(a),l(b))+.05);
   return ['.selection label','.selection .micro','.photo-selection-note','.selection .primary'].map(sel=>{const s=getComputedStyle(document.querySelector(sel));return {sel,ratio:ratio(rgb(s.color),s.backgroundColor==='rgba(0, 0, 0, 0)'?[255,255,255]:rgb(s.backgroundColor))}});
  });assert.ok(contrasts.every(c=>c.ratio>=4.5));await fs.writeFile(path.join(out,'contrast.json'),JSON.stringify(contrasts,null,2));
  f.holdPrepare();await p.getByRole('button',{name:'Chuẩn bị ảnh đã chọn'}).click();await s.waitFor();assert.equal(await s.isDisabled(),true);assert.equal(f.prepares.length,1);assert.equal(f.prepares[0].itemId,'item-job-A');assert.equal(f.prepares[0].formatId,f.job.items[0].formats[1].id);
  f.releasePrepare();await p.getByText('Đang chờ đến lượt xử lý…').waitFor();assert.equal(await s.isDisabled(),true);f.job.state='preparing';await f.refresh();await p.getByText('Đang chuẩn bị tệp của bạn…').waitFor();assert.equal(await s.isDisabled(),true);
  f.job.state='ready';await f.refresh();const a=p.getByRole('link',{name:'Tải xuống'});await a.waitFor();assert.equal(await a.getAttribute('download'),'wed-snap-image.jpg');assert.equal(f.tickets,1);await shot(p,'photo-ready');
  const downloadEvent=p.waitForEvent('download');await a.click();const d=await downloadEvent;assert.equal(d.suggestedFilename(),'wed-snap-image.jpg');await d.saveAs(path.join(out,'browser-native-image.jpg'));assert.equal(await d.failure(),null);await p.getByText('Đã bắt đầu yêu cầu tải.',{exact:false}).waitFor();assert.equal((await p.locator('body').innerText()).includes('Codex'),false);
  const previousKey=f.prepares[0].idempotencyKey;await f.analyze();await p.getByLabel('Chọn một ảnh').selectOption({index:2});await p.getByRole('button',{name:'Chuẩn bị ảnh đã chọn'}).click();assert.notEqual(f.prepares[1].idempotencyKey,previousKey);assert.equal(f.prepares[1].itemId,'item-job-2');await f.close();
 });
 for(const cap of [false,undefined,'true'])await record('capability-failclosed-'+String(cap),async()=>{const f=await fixture({cap});await f.analyze();await f.page.getByText('Tải ảnh TikTok chưa được bật.',{exact:false}).waitFor();assert.equal(await f.page.locator('#format').count(),0);assert.equal(f.tickets,0);assert.equal(await f.page.locator('.photo-support').count(),0);assert.equal(f.prepares.length,0);await f.close();});
 for(const n of [1,5,50])await record('count'+n+'-mobile320-375-theme-lock-reduced-motion',async()=>{
  const f=await fixture({n,width:320,motion:'reduce',color:'dark'});await f.analyze();assert.equal(await f.page.locator('#format option').count(),n);for(const width of [320,375]){await f.page.setViewportSize({width,height:960});assert.equal(await f.page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),true);}await f.page.locator('#format').focus();await f.page.keyboard.press('ArrowDown');await f.page.keyboard.press('Tab');assert.equal(await f.page.getByRole('button',{name:'Chuẩn bị ảnh đã chọn'}).evaluate(e=>e===document.activeElement),true);
  assert.equal(await f.page.locator('body').evaluate(()=>getComputedStyle(document.documentElement).backgroundColor),'rgb(246, 248, 251)');if(n===50)await shot(f.page,'photo50-mobile375-dark-preference-light-theme');f.job.state='preparing';await f.refresh();assert.equal(await f.page.locator('.spinner').evaluate(e=>getComputedStyle(e).animationName),'none');await f.close();
 });
 await record('video-native-mp4-unchanged',async()=>{const f=await fixture({kind:'video',cap:false});await f.analyze();await f.page.getByLabel('Chất lượng từ nguồn').waitFor();f.job.state='ready';await f.refresh();assert.equal(await f.page.getByRole('link',{name:'Tải xuống'}).getAttribute('download'),'wed-snap-video.mp4');await f.close();});
 for(const state of ['failed','cancelled','expired'])await record('terminal-'+state,async()=>{const f=await fixture();await f.analyze();f.job.state=state;await f.refresh();assert.equal(await f.page.locator('#format').count(),0);assert.equal(await f.page.getByRole('link',{name:'Tải xuống'}).count(),0);await f.page.getByText('Bạn có thể phân tích lại link',{exact:false}).waitFor();await f.close();});
 await record('ticket-retry-native-no-blob',async()=>{const f=await fixture();await f.analyze();f.failTicket();f.job.state='ready';await f.refresh();await f.page.getByRole('button',{name:'Tạo lại liên kết tải'}).click();await f.page.getByRole('link',{name:'Tải xuống'}).waitFor();assert.equal(f.tickets,2);await f.close();});
 await record('old-ticket-after-new-job-cannot-return-stale-link',async()=>{const f=await fixture();await f.analyze();f.holdTicket();f.job.state='ready';await f.refresh();await f.page.getByText('Đang tạo liên kết tải…').waitFor();await f.analyze();f.releaseTicket();await sleep(100);assert.equal(await f.page.getByRole('link',{name:'Tải xuống'}).count(),0);assert.equal(f.job.id,'job-2');await f.close();});
 await record('empty-formats-no-prepare',async()=>{const f=await fixture();f.job.items[0].formats=[];await f.analyze();await f.page.getByText('Chưa có lựa chọn phù hợp.',{exact:false}).waitFor();assert.equal(await f.page.getByRole('button',{name:'Chuẩn bị ảnh đã chọn'}).isDisabled(),true);await f.close();});
 assert.equal(requests.filter(r=>r.kind==='blocked-external').length,0);assert.equal(errors.length,0);
 }
 await fs.writeFile(path.join(out,'browser-result.json'),JSON.stringify({status:'PASS_BROWSER_OFFLINE_FIXTURE',before,browser:browser.version(),playwright:require('C:/Users/LENOVO/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/playwright/package.json').version,sandboxRequested:true,apiMocked:true,staticResponseMockedFromActualBuild:false,staticAndNativeHTTPActual:true,physicalServerPortOpened:'127.0.0.1:5196',backendCombined:false,sourceCalls:0,cases,requests,errors},null,2));
}
main().catch(async e=>{await fs.writeFile(path.join(out,'failure.json'),JSON.stringify({class:e.name,message:e.message.slice(0,500)}));process.exitCode=1;}).finally(async()=>{for(const c of contexts)await c.close().catch(()=>{});if(browser)await browser.close();if(server){server.closeAllConnections();await new Promise(r=>server.close(r));}});
