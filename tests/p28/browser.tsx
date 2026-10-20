import React from 'react';
import {createRoot, type Root} from 'react-dom/client';
import {flushSync} from 'react-dom';
import Admin from '../../apps/web/src/pages/Admin';
import '../../apps/web/src/style.css';
import '../../apps/web/src/styles/layout.css';
import '../../apps/web/src/styles/admin.css';
import '../../apps/web/src/styles/responsive.css';
import {expected,limits,writable} from './expectations';
import {focusExpected} from './focus-expectation';

// Only API transport is controlled. React, Admin, api(), forms and computed CSS are production.
// No business server/auth/datastore: these responses are contract27 fixtures, not HTTP27 reruns.
const nativeFetch=window.fetch.bind(window), host=document.getElementById('admin-root')!;
const output=document.getElementById('result')!;
const id='28282828-2828-4282-8282-282828282828';
const session={productName:'WED SNAP',csrf:'p28-fixture-only',supported:['youtube'],contact:null,heartbeatSeconds:20};
const clone=<T,>(v:T):T=>JSON.parse(JSON.stringify(v));
const dashboard=(populated=false)=>({groups:populated?[{state:'failed',_count:2}]:[],failed:populated?[{id,platform:'youtube',errorCode:null,updatedAt:'2026-10-03T12:34:56.000Z'}]:[],queue:{waiting:0,active:0},budget:populated?[{month:new Date().toISOString().slice(0,7),charged:'9007199254740993'}]:[],events:[],verified:['youtube']});
const campaign=()=>({id,title:'Fixture tài trợ',imageUrl:null,targetUrl:'https://fixture.invalid/campaign',linkType:'sponsored',placement:'banner',enabled:false,startsAt:'2026-10-01T00:00:00.000Z',endsAt:'2026-10-08T00:00:00.000Z',weight:1,updatedAt:'2026-10-03T00:00:00.000Z',_count:{events:0}});
type Rec={order:number;phase:string;method:string;path:string;keys:string[];csrf:boolean;time:number;status?:number};
type Result={status:number;data:unknown};
type Gate={method:string;path:string;pending:boolean;finish:(r?:Result)=>void;defaultResult:Result};
let root:Root|null=null, sequence=0, records:Rec[]=[], gates:Gate[]=[], issues:string[]=[], originalError=console.error;
let state={auth:false,settings:clone(limits) as any,campaigns:[] as any[],dashboard:dashboard()};
let faults=new Map<string,Result>();
const fault=(status:number,code:string):Result=>({status,data:{error:{code}}});
const assert=(ok:unknown,msg:string)=>{if(!ok)throw Error(msg);};
async function pause(){await new Promise<void>(r=>setTimeout(r,0));}
async function settle(){for(let i=0;i<5;i++)await pause();}
async function until(fn:()=>unknown){const end=performance.now()+1800;while(!fn()){if(performance.now()>end)throw Error('DOM/request timeout1800ms');await pause();}await settle();}
const text=()=>host.textContent||'';
const button=(label:string)=>{const b=[...host.querySelectorAll<HTMLButtonElement>('button')].find(e=>e.textContent?.trim()===label);assert(b,'Missing button '+label);return b!;};
async function click(label:string){button(label).click();await settle();}
function input(label:string){const l=[...host.querySelectorAll('label')].find(e=>(e.firstChild?.textContent||'').trim()===label);const e=l?.querySelector<HTMLInputElement>('input');assert(e,'Missing labelled input '+label);return e!;}
async function fill(label:string,value:string){const e=input(label);Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,'value')!.set!.call(e,value);e.dispatchEvent(new Event('input',{bubbles:true}));await settle();}
function strict(keys:string[],allowed:string[]){assert(keys.slice().sort().join('|')===allowed.slice().sort().join('|'),'Strict body keys differ');}
function response(method:string,path:string,body:any):Result{
 const bad=faults.get(method+' '+path);if(bad)return clone(bad);
 if(path==='admin/login'){state.auth=true;return {status:201,data:{ok:true}};}
 if(path==='admin/logout'){state.auth=false;return {status:201,data:{ok:true}};}
 if(!state.auth)return fault(403,'ADMIN_REQUIRED');
 if(method==='GET')return {status:200,data:clone(path==='admin/dashboard'?state.dashboard:path==='admin/settings'?state.settings:state.campaigns)};
 if(path==='admin/settings'){state.settings=clone(body);return {status:200,data:clone(body)};}
 if(method==='DELETE'){state.campaigns=state.campaigns.filter(c=>c.id!==id);return {status:200,data:{ok:true}};}
 const c={...campaign(),...clone(body)};state.campaigns=method==='POST'?[...state.campaigns,c]:state.campaigns.map(v=>v.id===id?c:v);return {status:method==='POST'?201:200,data:c};
}
async function transport(url:RequestInfo|URL,options:RequestInit={}){
 const path=String(url);assert(path.startsWith('/api/v1/admin/'),'API fence refused '+path);
 const route=path.slice('/api/v1/'.length),method=options.method||'GET';
 assert(['admin/login','admin/logout','admin/dashboard','admin/settings','admin/campaigns','admin/campaigns/'+id].includes(route),'Route inventory');
 const headers=new Headers(options.headers),body=options.body===undefined?undefined:JSON.parse(String(options.body));
 assert(options.credentials==='same-origin','credentials');assert(headers.get('Content-Type')==='application/json','content-type');
 assert(method==='GET'?!headers.has('x-csrf-token'):headers.get('x-csrf-token')===session.csrf,'CSRF method contract');
 const keys=body?Object.keys(body):[];
 if(method==='GET'||method==='DELETE'||route==='admin/logout')assert(body===undefined,'No arbitrary request body');
 else if(route==='admin/login')strict(keys,['email','password']);
 else if(route==='admin/settings')strict(keys,Object.keys(limits));
 else {strict(keys,writable);assert(body.imageUrl===null||typeof body.imageUrl==='string','nullable image');assert(body.startsAt.endsWith('Z')&&body.endsAt.endsWith('Z'),'ISO date body');}
 assert(records.filter(r=>r.phase==='start').length<30,'Bounded30requests/case');
 const rec={order:++sequence,phase:'start',method,path:route,keys,csrf:headers.has('x-csrf-token'),time:performance.now()};records.push(rec);
 const result=response(method,route,body);const gate=gates.find(g=>g.method===method&&g.path===route&&!g.pending);
 let actual=result;
 if(gate){gate.pending=true;gate.defaultResult=result;actual=await new Promise<Result>(resolve=>{gate.finish=(r)=>{gate.pending=false;gates=gates.filter(x=>x!==gate);resolve(r||result);};});}
 records.push({...rec,order:++sequence,phase:'finish',time:performance.now(),status:actual.status});
 return new Response(JSON.stringify(actual.data),{status:actual.status,headers:{'Content-Type':'application/json'}});
}
function defer(method:string,path:string){const g:Gate={method,path,pending:false,finish:()=>{throw Error('Gate not started');},defaultResult:{status:0,data:null}};gates.push(g);return g;}
function deferRefresh(){return ['admin/dashboard','admin/settings','admin/campaigns'].map(p=>defer('GET',p));}
function dispose(){if(root){flushSync(()=>root!.unmount());root=null;}}
async function cleanup(){dispose();for(const g of [...gates])if(g.pending)g.finish();await settle();gates=[];window.fetch=nativeFetch;console.error=originalError;}
async function mount(auth=true,populated=false,initial?:()=>void){await cleanup();sequence=0;records=[];issues=[];faults=new Map();state={auth,settings:clone(limits),campaigns:[],dashboard:dashboard(populated)};initial?.();window.fetch=transport as typeof fetch;console.error=(...args)=>{issues.push(args.map(String).join(' '));originalError(...args);};root=createRoot(host);flushSync(()=>root!.render(<Admin session={session}/>));await settle();}
async function login(){await fill('Email','fixture-admin@example.invalid');await fill('Mật khẩu','fixture-only-password');await click('Đăng nhập →');}
async function newDraft(){await click('Quảng cáo');await click('+ Tạo chiến dịch');await fill('Tiêu đề','Fixture mới');await fill('URL đích HTTPS','https://fixture.invalid/new');}
const started=(method:string,path:string)=>records.filter(r=>r.phase==='start'&&r.method===method&&r.path===path).length;
function luminance(rgb:string){const c=rgb.match(/[\d.]+/g)!.slice(0,3).map(Number).map(v=>{v/=255;return v<=.04045?v/12.92:((v+.055)/1.055)**2.4;});return .2126*c[0]+.7152*c[1]+.0722*c[2];}
function bg(el:Element):string{const c=getComputedStyle(el).backgroundColor;if(c!=='rgba(0, 0, 0, 0)'&&c!=='transparent')return c;return el.parentElement?bg(el.parentElement):'rgb(255, 255, 255)';}
function contrasts(){return [...host.querySelectorAll<HTMLElement>('.admin-tabs button,.metrics span,.settings-top p,.platform-toggles small,.muted,label,.primary,.secondary')].filter(e=>e.getClientRects().length&&!e.closest('[disabled]')).map(e=>{const a=luminance(getComputedStyle(e).color),b=luminance(bg(e));return {text:e.textContent?.trim().slice(0,45),color:getComputedStyle(e).color,background:bg(e),ratio:(Math.max(a,b)+.05)/(Math.min(a,b)+.05)};});}
function view(){const admin=host.querySelector('.admin')!;return {width:innerWidth,height:innerHeight,pageWidth:document.documentElement.scrollWidth,adminWidth:admin?.getBoundingClientRect().width,reducedMotion:matchMedia('(prefers-reduced-motion: reduce)').matches,animated:[...host.querySelectorAll('*')].filter(e=>getComputedStyle(e).animationName!=='none'||getComputedStyle(e).transitionDuration.split(',').some(v=>parseFloat(v)>0)).map(e=>e.className),active:document.activeElement?.outerHTML.slice(0,250),contrast:contrasts()};}
const cases:Record<string,()=>Promise<void>>={
 unauthenticated:async()=>{await mount(false);assert(started('GET','admin/dashboard')===1&&!text().includes('Đăng xuất'),'Unauthenticated');},
 'initial500-visible':async()=>{await mount(false,false,()=>faults.set('GET admin/dashboard',fault(500,'INTERNAL_ERROR')));assert(host.querySelector('[role=alert]')&&text().includes('Đăng nhập admin'),'Initial500 silently discarded');},
 'pending-refresh-loading':async()=>{await mount();const g=deferRefresh();await click('Làm mới ↻');assert(g.every(x=>x.pending),'Refresh pending precondition');assert([...host.querySelectorAll('[role=status]')].some(e=>/Đang|Tải/.test(e.textContent||'')),'No visible pending refresh');g.forEach(x=>x.finish());await settle();},
 'login-native-required':async()=>{await mount(false);await click('Đăng nhập →');assert(started('POST','admin/login')===0,'HTML required bypass');},
 'login-invalid':async()=>{await mount(false,false,()=>faults.set('POST admin/login',fault(403,'LOGIN_FAILED')));await login();assert(host.querySelector('[role=alert]')&&input('Email').value.includes('fixture')&&!text().includes('Đăng xuất'),'Invalid login');},
 'login-success-strict':async()=>{await mount(false);await login();assert(started('POST','admin/login')===1&&text().includes('Đăng xuất')&&!host.querySelector('input[type=password]'),'Login success');},
 'dashboard-empty':async()=>{await mount();assert(/Chưa có tác vụ/.test(text())&&/Chưa có lỗi/.test(text()),'Empty dashboard blank');},
 'dashboard-populated':async()=>{await mount(true,true);assert(text().includes('2')&&text().includes('YouTube')&&text().includes('2026')&&!/NaN|Infinity|\[object Object\]|null/.test(text()),'Populated date/null/BigInt');},
 'settings17-success':async()=>{await mount();await click('Cấu hình');assert(host.querySelectorAll('input[type=number]').length===15,'15 numeric + boolean + platforms');await fill('Số tác vụ tối đa','19');await click('Lưu cấu hình');assert(state.settings.queueLimit===19&&text().includes('Đã lưu cấu hình'),'Settings17');},
 'settings400-draft':async()=>{await mount();await click('Cấu hình');faults.set('PUT admin/settings',fault(400,'INVALID_REQUEST'));await fill('Số tác vụ tối đa','18');await click('Lưu cấu hình');assert(host.querySelector('[role=alert]')&&!text().includes('Đã lưu')&&input('Số tác vụ tối đa').value==='18','400 draft');},
 'settings500-draft':async()=>{await mount();await click('Cấu hình');faults.set('PUT admin/settings',fault(500,'INTERNAL_ERROR'));await fill('Số tác vụ tối đa','18');await click('Lưu cấu hình');assert(host.querySelector('[role=alert]')&&!text().includes('Đã lưu')&&input('Số tác vụ tối đa').value==='18','500 draft');},
 'campaign-empty':async()=>{await mount();await click('Quảng cáo');assert(text().includes('Chưa có chiến dịch'),'Empty campaign blank');},
 'campaign-create-null':async()=>{await mount();await newDraft();await click('Lưu chiến dịch');assert(state.campaigns.length===1&&state.campaigns[0].imageUrl===null&&text().includes('Fixture mới')&&!host.querySelector('.campaign-form'),'Create');},
 'campaign-edit-writable':async()=>{await mount();state.campaigns=[campaign()];await click('Làm mới ↻');await click('Quảng cáo');await click('Sửa');await fill('Tiêu đề','Fixture sửa');await click('Lưu chiến dịch');assert(started('PUT','admin/campaigns/'+id)===1&&text().includes('Fixture sửa'),'Edit');},
 'campaign-reject-after-notice':async()=>{await mount();await newDraft();await click('Lưu chiến dịch');await click('+ Tạo chiến dịch');await fill('Tiêu đề','Rejected');await fill('URL đích HTTPS','https://fixture.invalid/rejected');faults.set('POST admin/campaigns',fault(400,'INVALID_REQUEST'));await click('Lưu chiến dịch');assert(host.querySelector('[role=alert]')&&!text().includes('Đã lưu chiến dịch')&&input('Tiêu đề').value==='Rejected','Stale success notice');},
 'campaign-delete':async()=>{await mount();state.campaigns=[campaign()];await click('Làm mới ↻');await click('Quảng cáo');await click('Xóa');assert(started('DELETE','admin/campaigns/'+id)===1&&state.campaigns.length===0&&!text().includes('Fixture tài trợ'),'Delete');},
 'campaign-delete500':async()=>{await mount();state.campaigns=[campaign()];await click('Làm mới ↻');await click('Quảng cáo');faults.set('DELETE admin/campaigns/'+id,fault(500,'INTERNAL_ERROR'));await click('Xóa');assert(host.querySelector('[role=alert]')&&text().includes('Fixture tài trợ'),'Delete fail');},
 'refresh500-active':async()=>{await mount();faults.set('GET admin/dashboard',fault(500,'INTERNAL_ERROR'));await click('Làm mới ↻');assert(host.querySelector('[role=alert]')&&text().includes('Đăng xuất'),'Transient refresh');},
 'expired403-relogin':async()=>{await mount();state.auth=false;await click('Làm mới ↻');assert(text().includes('Đăng nhập admin')&&!host.querySelector('.metrics'),'Expired still logged');await login();assert(text().includes('Đăng xuất'),'Relogin');},
 'refresh-late-after-logout':async()=>{await mount();const g=deferRefresh();await click('Làm mới ↻');assert(g.every(x=>x.pending),'Old refresh truly pending');const starts=sequence;await click('Đăng xuất');assert(text().includes('Đăng nhập admin')&&g.every(x=>x.pending),'Logout settled before old responses');g.forEach(x=>x.finish());await settle();assert(!text().includes('Đăng xuất')&&!host.querySelector('.metrics'),'Late refresh revived admin');assert(records.find(r=>r.path==='admin/logout'&&r.phase==='finish')!.order>starts,'Order');},
 'logout500-active':async()=>{await mount();faults.set('POST admin/logout',fault(500,'INTERNAL_ERROR'));await click('Đăng xuất');assert(host.querySelector('[role=alert]')&&text().includes('Đăng xuất')&&!button('Đăng xuất').disabled,'Logout failure');},
 'initial-old403-after-login':async()=>{let g:Gate[]=[];await mount(false,false,()=>{g=deferRefresh();});assert(g.every(x=>x.pending),'Initial pending');await login();assert(text().includes('Đăng xuất'),'New login complete');g.forEach(x=>x.finish(fault(403,'ADMIN_REQUIRED')));await settle();assert(text().includes('Đăng xuất')&&!host.querySelector('[role=alert]'),'Stale403 applied');},
 'login-deferred-unmount':async()=>{await mount(false);const g=defer('POST','admin/login');await login();assert(g.pending,'Login pending');dispose();const before=records.length;g.finish();await settle();assert(records.slice(before).filter(r=>r.phase==='start').length===0&&!host.children.length,'Login continued after unmount');},
 'save-deferred-unmount':async()=>{await mount();await click('Cấu hình');const g=defer('PUT','admin/settings');await click('Lưu cấu hình');assert(g.pending,'Save pending');dispose();const before=records.length;g.finish();await settle();assert(records.slice(before).filter(r=>r.phase==='start').length===0&&!host.children.length,'Save continued after unmount');},
 'logout-deferred-unmount':async()=>{await mount();const g=defer('POST','admin/logout');await click('Đăng xuất');assert(g.pending,'Logout pending');dispose();g.finish();await settle();assert(!host.children.length&&issues.length===0,'Unmount logout');},
 'login-pending-single':async()=>{await mount(false);const g=defer('POST','admin/login');await login();assert(g.pending,'Login pending');assert(button('Đăng nhập →').disabled&&host.querySelector('[role=status]'),'Pending submit enabled/no loading');await click('Đăng nhập →');assert(started('POST','admin/login')===1,'Duplicate login');g.finish();await settle();},
 'campaign-close-focus':async()=>{await mount();await newDraft();input('Tiêu đề').focus();await click('Đóng');assert(document.activeElement===button('+ Tạo chiến dịch'),'Close lost focus');},
 'labels-focus-regions':async()=>{await mount();await click('Cấu hình');assert([...host.querySelectorAll('input')].every(e=>e.closest('label')),'Labels');input('Số tác vụ tối đa').focus();assert(getComputedStyle(input('Số tác vụ tối đa')).outlineStyle!=='none','Input focus');await click('Tổng quan');assert([...host.querySelectorAll('.table-wrap')].every(e=>(e as HTMLElement).tabIndex>=0&&e.hasAttribute('aria-label')),'Table regions not keyboard focusable');},
 'contrast-controls':async()=>{await mount();let c=contrasts();await click('Cấu hình');c=c.concat(contrasts());assert(c.every(e=>e.ratio>=4.5),'Contrast '+JSON.stringify(c.filter(e=>e.ratio<4.5)));},
 'viewport-motion':async()=>{await mount();await click('Cấu hình');const v=view();assert(v.pageWidth<=v.width,'Page overflow '+JSON.stringify(v));assert(v.animated.length===0,'Admin animation');},
};
async function record(value:unknown){await nativeFetch('/__p28/record',{method:'POST',body:JSON.stringify(value)});}
let busy=false;
async function run(){if(busy)return;busy=true;const environment=await (await nativeFetch('/__p28/environment')).json();const results:any[]=[];
 await record({kind:'matrix-start',utc:new Date().toISOString(),vn:new Date().toLocaleString('vi-VN',{timeZone:'Asia/Ho_Chi_Minh'}),environment,expected,scope:'30 browser DOM cases, HTTP/clock transport doubles; native real clock, no auth/PG/Redis/Internet',viewport:{width:innerWidth,height:innerHeight}});
 for(const [name,expectation] of expected){const startedAt=performance.now();let result='PASS',error='';try{await cases[name]();assert(issues.length===0,'Console errors '+issues.join(';'));}catch(e){result='FAIL';error=String(e);}
 const beforeCleanup={dom:text().slice(0,1500),pendingResponse:gates.some(g=>g.pending),pending:gates.filter(g=>g.pending).map(g=>g.path),view:host.children.length?view():null};
 await cleanup();const entry={name,expectation,result,error,durationMs:performance.now()-startedAt,requests:records,consoleErrors:issues,beforeCleanup,cleanup:{rootUnmounted:!host.children.length,fetchRestored:window.fetch===nativeFetch,pending:gates.length,hooksRestored:console.error===originalError}};results.push(entry);await record({kind:'case',...entry});output.textContent=JSON.stringify({completed:results.length,results:results.map(r=>({name:r.name,result:r.result,error:r.error}))},null,2);}
 const total=results.reduce((n,r)=>n+r.requests.filter((v:Rec)=>v.phase==='start').length,0);const summary={kind:'matrix-final',utc:new Date().toISOString(),pass:results.filter(r=>r.result==='PASS').length,fail:results.filter(r=>r.result==='FAIL').length,cases:results.length,requests:total,viewport:innerWidth,cleanup:true};await record(summary);output.textContent=JSON.stringify(summary,null,2);busy=false;
}
document.getElementById('run')!.addEventListener('click',()=>void run().catch(async e=>{await cleanup();busy=false;output.textContent='HARNESS_ERROR '+String(e);await record({kind:'harness-error',error:String(e)});}));
document.getElementById('focus-regression')!.addEventListener('click',()=>void (async()=>{
  if(busy)return;busy=true;const environment=await (await nativeFetch('/__p28/environment')).json();let result='PASS',error='';
  try{await mount();await click('Cấu hình');button('Lưu cấu hình').focus();await click('Lưu cấu hình');assert(started('PUT','admin/settings')===1&&text().includes('Đã lưu cấu hình'),'Save/refresh settled precondition');assert(document.activeElement===button('Lưu cấu hình')&&!button('Lưu cấu hình').disabled,'Save lost keyboard focus');}catch(e){result='FAIL';error=String(e);}
  const beforeCleanup={focus:document.activeElement?.tagName,focusText:document.activeElement?.tagName==='BUTTON'?document.activeElement.textContent:null,dom:text().slice(0,800)};await cleanup();const value={kind:'focus-regression',utc:new Date().toISOString(),environment,expected:focusExpected,result,error,beforeCleanup,requests:records,cleanup:{unmounted:!host.children.length,fetchRestored:window.fetch===nativeFetch,pending:gates.length,hooksRestored:console.error===originalError}};await record(value);output.textContent=JSON.stringify({kind:value.kind,result,error},null,2);busy=false;
})());
document.getElementById('smoke-login')!.addEventListener('click',()=>void mount(false));
document.getElementById('smoke-admin')!.addEventListener('click',()=>void mount(true,true).then(async()=>{state.campaigns=[campaign()];await click('Làm mới ↻');}));
document.getElementById('record-ui')!.addEventListener('click',()=>void record({kind:'manual-ui',utc:new Date().toISOString(),dom:text().slice(0,2000),view:view(),requests:records,issues}));
document.getElementById('dispose')!.addEventListener('click',()=>void cleanup().then(()=>record({kind:'smoke-cleanup',fetchRestored:window.fetch===nativeFetch,rootUnmounted:!host.children.length,pending:gates.length,hooksRestored:console.error===originalError})));
window.addEventListener('pagehide',()=>{dispose();window.fetch=nativeFetch;console.error=originalError;});
