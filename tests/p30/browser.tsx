import React from 'react';
import {createRoot} from 'react-dom/client';
import Admin from '../../apps/web/src/pages/Admin';
import {api} from '../../apps/web/src/lib/api';
import type {Session} from '../../apps/web/src/types';
import '../../apps/web/src/style.css';
import '../../apps/web/src/styles/admin.css';
import '../../apps/web/src/styles/home.css';
import '../../apps/web/src/styles/layout.css';
import '../../apps/web/src/styles/legal.css';
import '../../apps/web/src/styles/responsive.css';
const host=document.getElementById('root')!,root=createRoot(host),tools=document.getElementById('tools')!;
let session:Session;const realFetch=window.fetch.bind(window),trace:any[]=[],observed:any[]=[],results:any[]=[];
const pause=()=>new Promise<void>(r=>setTimeout(r,25));
const assert=(v:unknown,m:string)=>{if(!v)throw Error(m);};
async function until(fn:()=>boolean,label:string){const end=performance.now()+8000;while(!fn()){if(performance.now()>end)throw Error('Deadline '+label);await pause();}}
async function diag(path:string){const r=await realFetch('/__p30/'+path);assert(r.ok,'diagnostic');return r.json();}
async function record(name:string,fn:()=>Promise<any>){try{const evidence=await fn();results.push({name,result:'PASS',evidence});}catch(e){results.push({name,result:'FAIL',error:(e as Error).message});}const r=results.at(-1);await realFetch('/__p30/record',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({kind:'case',...r,viewport:{width:innerWidth,height:innerHeight},trace})});if(r.result==='FAIL')throw Error(r.error);}
function button(label:string){const b=[...host.querySelectorAll<HTMLButtonElement>('button')].find(b=>b.textContent?.trim()===label);assert(b,'button '+label);return b!;}
function input(label:string){const l=[...host.querySelectorAll('label')].find(l=>l.textContent?.trim()===label),i=l?.querySelector<HTMLInputElement>('input');assert(i,'input '+label);return i!;}
async function fill(label:string,value:string){const i=input(label);Object.getOwnPropertyDescriptor(HTMLInputElement.prototype,'value')!.set!.call(i,value);i.dispatchEvent(new Event('input',{bubbles:true}));await pause();}
const text=()=>host.textContent||'';
const label=()=>host.querySelector('.ad-window-label')?.textContent||'';
async function windowQuery(from:string,to:string){await fill('Từ (ISO có múi giờ)',from);await fill('Đến (ISO có múi giờ)',to);button('Xem thống kê').click();}
let holdNext=false,held:(()=>void)|undefined,holdStarted=false,order=0;
window.fetch=async(...args:Parameters<typeof fetch>)=>{
 const url=String(args[0]);assert(url.startsWith('/api/')||url.startsWith('/__p30/'),'same-origin fence');
 const n=++order,hold=holdNext&&url.includes('/admin/ad-statistics');if(hold){holdNext=false;holdStarted=true;}
 trace.push({n,stage:'request',url,hold});const r=await realFetch(...args);trace.push({n,stage:'network-finish',status:r.status});
 if(hold){await new Promise<void>(resolve=>{held=resolve;});trace.push({n,stage:'deferred-release',fixture:'real HTTP response delayed only; no business payload substitution'});}
 return r;
};
const observer=new MutationObserver(()=>{observed.push({label:label(),loading:text().includes('Đang tải thống kê'),table:host.querySelector('tbody')?.textContent});});observer.observe(host,{subtree:true,childList:true,characterData:true});
const focus:any[]=[];document.addEventListener('focusin',e=>{const el=e.target as HTMLElement;if(host.contains(el))focus.push({tag:el.tagName,label:el.closest('label')?.textContent||el.textContent?.slice(0,80)});});
function tool(title:string,fn:()=>Promise<void>){const b=document.createElement('button');b.textContent=title;b.onclick=()=>{b.disabled=true;void fn().then(()=>{b.textContent=title+' PASS';}).catch(e=>{b.textContent=title+' FAIL '+e.message;}).finally(()=>{b.disabled=false;});};tools.append(b);}
tool('Điền đăng nhập test',async()=>{const c=await diag('credentials');await fill('Email',c.email);await fill('Mật khẩu',c.password);input('Mật khẩu').focus();});
tool('Chạy browser30 live',async()=>{
 await until(()=>!!host.querySelector('.admin-tabs'),'logged');button('Quảng cáo').click();await until(()=>!!label(),'default stats');
 await record('browser-live-window',async()=>{const begin=observed.length;await windowQuery('2026-01-01T07:00:00+07:00','2026-01-02T07:00:00+07:00');await until(()=>label().includes('2026-01-01T00:00:00.000Z'),'UTC label');assert(text().includes('3 / 150.0%')&&text().includes('1 / —'),'counts/CTR');assert(!observed.slice(begin).some(o=>o.loading&&o.label),'no relabel while loading');return {window:label(),table:host.querySelector('tbody')?.textContent,observed:observed.slice(begin)};});
 await record('browser-invalid',async()=>{await windowQuery('2026-02-30T00:00:00Z','2026-03-01T00:00:00Z');await until(()=>!!host.querySelector('[role=alert]'),'invalid');assert(!label(),'old data/window cleared');return {error:host.querySelector('[role=alert]')?.textContent};});
 await record('browser-empty',async()=>{await windowQuery('2026-02-01T00:00:00Z','2026-02-02T00:00:00Z');await until(()=>label().includes('2026-02-01'),'empty');assert(text().includes('Không có sự kiện trong khoảng này.')&&text().includes('0 / —'),'zero controls');return {window:label(),table:host.querySelector('tbody')?.textContent};});
});
tool('Kiểm narrow focus30',async()=>{await record('browser-narrow-focus',async()=>{assert(innerWidth===360||innerWidth===1280,'viewport');const i=input('Từ (ISO có múi giờ)');i.focus();assert(document.activeElement===i,'input focus');assert(document.documentElement.scrollWidth<=innerWidth,'page bounds');const el=host.querySelector('.ad-window') as HTMLElement;return {viewport:innerWidth,page:document.documentElement.scrollWidth,controlsWidth:el.getBoundingClientRect().width,focus,reducedMotion:matchMedia('(prefers-reduced-motion: reduce)').matches};});});
tool('Kiểm active tab30',async()=>{await record('active-tab-preserve',async()=>{const before=label();assert(before,'accepted window before action');button('Quảng cáo').click();await pause();assert(label()===before,'current tab keeps accepted window');return {before,after:label()};});});
tool('Chạy race30',async()=>{
 await record('race-new-window',async()=>{holdNext=true;holdStarted=false;await windowQuery('2026-01-01T00:00:00Z','2026-01-02T00:00:00Z');await until(()=>!!held&&holdStarted,'old pending');assert(!label()&&text().includes('Đang tải thống kê'),'pending no old stats');await windowQuery('2026-02-01T00:00:00Z','2026-02-02T00:00:00Z');await until(()=>label().includes('2026-02-01'),'new response');held!();held=undefined;await pause();await pause();assert(label().includes('2026-02-01')&&!text().includes('150.0%'),'late old ignored');return {window:label(),fixture:'deferred real response',trace};});
 await record('race-logout',async()=>{holdNext=true;holdStarted=false;await windowQuery('2026-01-01T00:00:00Z','2026-01-02T00:00:00Z');await until(()=>!!held,'stats pending');button('Đăng xuất').click();await until(()=>!!host.querySelector('.admin-login'),'logout');held!();held=undefined;await pause();await pause();assert(!host.querySelector('.admin-tabs')&&!label(),'late response cannot restore');return {login:true,trace};});
});
tool('Kiểm unmount30',async()=>{await record('race-unmount',async()=>{assert(host.querySelector('.admin-tabs'),'login again for unmount');button('Quảng cáo').click();await until(()=>!!label(),'stats');holdNext=true;await windowQuery('2026-01-01T00:00:00Z','2026-01-02T00:00:00Z');await until(()=>!!held,'pending');root.unmount();held!();held=undefined;await pause();await pause();assert(!host.textContent,'root remains empty');observer.disconnect();window.fetch=realFetch;return {unmounted:true,fetchRestored:true,observerClosed:true,trace};});});
async function boot(){session=await api('session','');root.render(<Admin session={session}/>);}void boot();
