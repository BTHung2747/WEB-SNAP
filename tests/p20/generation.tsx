import React from 'react';
import { createRoot, type Root } from 'react-dom/client';
import { flushSync } from 'react-dom';
import Home from '../../apps/web/src/pages/Home';
import type { Ad, Job, Session } from '../../apps/web/src/types';
import '../../apps/web/src/style.css';
import '../../apps/web/src/styles/home.css';
import '../../apps/web/src/styles/layout.css';
import '../../apps/web/src/styles/responsive.css';

// Production Home/hooks/API/React. HTTP and interval/timeout clock doubles only.
// Observer/listener instrumentation delegates to native APIs, never fabricates entries.
const nativeFetch = window.fetch.bind(window), nativeTimeout = window.setTimeout.bind(window);
const nativeClear = window.clearTimeout.bind(window), nativeInterval = window.setInterval.bind(window);
const nativeClearInterval = window.clearInterval.bind(window), nativeBeacon = navigator.sendBeacon.bind(navigator);
const nativeObserver = window.IntersectionObserver;
const nativeAdd = EventTarget.prototype.addEventListener, nativeRemove = EventTarget.prototype.removeEventListener;
const host = document.querySelector<HTMLDivElement>('#home')!, report = document.querySelector('#result')!;
const button = document.querySelector<HTMLButtonElement>('#run')!;
const session: Session = { csrf: 'p21-http-fixture', productName: 'P21 fixture', supported: ['youtube'], contact: null, heartbeatSeconds: 15 };
const A: Ad = { id: '00000000-0000-4000-8000-00000000000a', title: 'OLD grant A fixture', imageUrl: null, targetUrl: 'https://example.invalid/p21-a', placement: 'sponsor', linkType: 'sponsored' };
const B: Ad = { ...A, id: '00000000-0000-4000-8000-00000000000b', title: 'NEW grant B fixture', targetUrl: 'https://example.invalid/p21-b' };
const sample = (id: string, state = 'selectable'): Job => ({ id, state, errorCode: null, title: id + ' fixture', duration: 10, previewUrl: null, items: [{ id: 'fixture-item', kind: 'video', formats: [{ id: 'fixture-format', label: 'Fixture MP4', size: 1024 }] }] });
function assert(value: unknown, why: string): asserts value { if (!value) throw new Error(why); }
const json = (data: unknown, status = 200) => new Response(JSON.stringify(data), { status, headers: { 'Content-Type': 'application/json' } });
const flush = async () => { for (let i = 0; i < 5; i++) await new Promise<void>(r => nativeTimeout(r, 0)); };
async function until(predicate: () => boolean, why: string) {
  const deadline = performance.now() + 5000;
  while (!predicate() && performance.now() < deadline) await flush();
  assert(predicate(), 'Bound5000ms: ' + why); await flush();
}
let root: Root | null = null, now = 0, serial = 0, nextTimer = 910000, installed = false;
type Req = { startOrder: number; finishOrder?: number; startClock: number; finishClock?: number; path: string; method: string; status?: number | string; pendingResponse: boolean; payload?: unknown };
let requests: Req[] = [], timeline: object[] = [];
let transport: (path: string, method: string) => Response | Promise<Response>;
const timers = new Map<number, { run: () => void; next: number; period?: number }>();
const listeners = new Map<string, Set<EventListenerOrEventListenerObject>>();
const observers: TrackedObserver[] = [];
class TrackedObserver extends nativeObserver {
  live = true;
  constructor(callback: IntersectionObserverCallback, options?: IntersectionObserverInit) { super(callback, options); observers.push(this); }
  disconnect() { this.live = false; super.disconnect(); }
}
const listenerKey = (target: EventTarget, type: string) =>
  (target === window && ['pageshow', 'pagehide'].includes(type)) || (target === document && type === 'visibilitychange')
    ? (target === window ? 'window:' : 'document:') + type : null;
function install() {
  assert(location.origin === 'http://localhost:5175', 'Refuse non-lab origin');
  installed = true; window.IntersectionObserver = TrackedObserver;
  window.setTimeout = ((fn: TimerHandler, ms = 0) => { assert(typeof fn === 'function', 'Function timer required'); const id = nextTimer++; timers.set(id, { run: fn as () => void, next: now + ms }); return id; }) as typeof window.setTimeout;
  window.clearTimeout = ((id?: number) => { if (id !== undefined && timers.has(id)) timers.delete(id); else nativeClear(id); }) as typeof window.clearTimeout;
  window.setInterval = ((fn: TimerHandler, ms = 0) => { assert(typeof fn === 'function' && ms > 0, 'Finite interval required'); const id = nextTimer++; timers.set(id, { run: fn as () => void, next: now + ms, period: ms }); return id; }) as typeof window.setInterval;
  window.clearInterval = ((id?: number) => { if (id !== undefined && timers.has(id)) timers.delete(id); else nativeClearInterval(id); }) as typeof window.clearInterval;
  EventTarget.prototype.addEventListener = function(type, callback, options) {
    const key = listenerKey(this, type); if (key && callback) { if (!listeners.has(key)) listeners.set(key, new Set()); listeners.get(key)!.add(callback); }
    nativeAdd.call(this, type, callback, options);
  };
  EventTarget.prototype.removeEventListener = function(type, callback, options) {
    const key = listenerKey(this, type); if (key && callback) listeners.get(key)?.delete(callback);
    nativeRemove.call(this, type, callback, options);
  };
  window.fetch = (async (input: RequestInfo | URL, options?: RequestInit) => {
    const path = String(input), method = options?.method || 'GET';
    assert(path.startsWith('/api/v1/'), 'Undeclared outbound fetch prohibited');
    const req: Req = { startOrder: ++serial, startClock: now, path, method, pendingResponse: true };
    requests.push(req); timeline.push({ order: serial, event: 'request-start', path, method, pendingResponse: true });
    try {
      const response = await transport(path.slice(8), method);
      req.status = response.status; const payload = await response.clone().json();
      req.payload = payload?.items ? { id: payload.id, state: payload.state, errorCode: payload.errorCode, title: payload.title } : payload;
      return response;
    } catch (e) { req.status = 'network-error'; throw e; }
    finally { req.pendingResponse = false; req.finishClock = now; req.finishOrder = ++serial; timeline.push({ order: serial, event: 'request-finish', path, method, status: req.status, pendingResponse: false }); }
  }) as typeof window.fetch;
  navigator.sendBeacon = url => { const req: Req = { startOrder: ++serial, finishOrder: serial, startClock: now, finishClock: now, path: String(url), method: 'BEACON', pendingResponse: false, status: 'fixture' }; requests.push(req); return true; };
}
function restore() {
  window.fetch = nativeFetch; window.setTimeout = nativeTimeout; window.clearTimeout = nativeClear;
  window.setInterval = nativeInterval; window.clearInterval = nativeClearInterval;
  window.IntersectionObserver = nativeObserver; navigator.sendBeacon = nativeBeacon;
  EventTarget.prototype.addEventListener = nativeAdd; EventTarget.prototype.removeEventListener = nativeRemove; installed = false;
}
const counts = () => ({ timers: timers.size, intervals: [...timers.values()].filter(t => t.period).length, liveObservers: observers.filter(o => o.live).length, listeners: Object.fromEntries([...listeners].map(([k, v]) => [k, v.size])) });
const state = () => ({ text: host.querySelector<HTMLElement>('.job-panel')?.innerText || '', selection: host.querySelector('.selection h2')?.textContent || null, sponsorTitle: host.querySelector('.sponsor-box strong')?.textContent || null, analyzeDisabled: host.querySelector<HTMLButtonElement>('button.analyze')?.disabled, ...counts() });
async function record(data: object) {
  const utc = new Date();
  const response = await nativeFetch('/__p19/record', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ suite: 'P21', utc: utc.toISOString(), vn: new Date(utc.getTime() + 7 * 3600000).toISOString().replace('Z', '+07:00'), ...data }) });
  assert(response.ok, 'Raw record failed');
}
function mark(event: string, details: object = {}) { const order = ++serial; timeline.push({ order, event, clock: now, ...details }); return order; }
async function advance(ms: number) {
  const end = now + ms;
  while (true) {
    const entry = [...timers].filter(([, t]) => t.next <= end).sort((a, b) => a[1].next - b[1].next)[0]; if (!entry) break;
    now = entry[1].next; if (entry[1].period) entry[1].next += entry[1].period; else timers.delete(entry[0]);
    entry[1].run(); await flush();
  }
  now = end; await flush();
}
async function home() { root = createRoot(host); flushSync(() => root!.render(<Home session={session} />)); await flush(); }
async function unmount() { if (root) { flushSync(() => root!.unmount()); root = null; await flush(); } }
async function submit() {
  const input = host.querySelector<HTMLInputElement>('#video-url')!;
  Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value')!.set!.call(input, 'https://www.youtube.com/watch?v=p21-http-fixture');
  input.dispatchEvent(new Event('input', { bubbles: true })); await flush();
  assert(!host.querySelector<HTMLButtonElement>('button.analyze')!.disabled, 'Submit must be enabled');
  host.querySelector('form')!.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true })); await flush();
}
const find = (path: string, method = 'GET') => requests.filter(r => r.path === '/api/v1/' + path && r.method === method);
const modes = ['terminal', '404', '410', 'active-control'] as const;
type Mode = typeof modes[number];
const matrix = modes.flatMap(mode => [false, true].map(lateOld => ({ name: `${mode}${lateOld ? '-late-old-after-new' : ''}`, mode, lateOld, expected: 'cancel pending → old poll processed → cancel200 → exactly1 replacement analyze and new sponsor200 non-null B; new selectable/B visible; late A cannot overwrite B; cleanup0' })));
async function runCase(mode: Mode, lateOld: boolean, name: string) {
  let created = 0, sponsorCalls = 0, oldReads = 0;
  let resolveCancel!: (r: Response) => void, resolveOld!: (r: Response) => void;
  let cancelSettled = false, oldSettled = !lateOld;
  transport = (path, method) => {
    if (path === 'ads?placement=banner') return json(null);
    if (path === 'ads?placement=sponsor') return ++sponsorCalls === 1
      ? lateOld ? new Promise<Response>(resolve => { resolveOld = resolve; }) : json(null)
      : json(B);
    if (path === 'jobs/analyze' && method === 'POST') return json({ jobId: ++created === 1 ? 'old' : 'new' }, 202);
    if (path === 'jobs/old/cancel' && method === 'POST') return new Promise<Response>(resolve => { resolveCancel = resolve; });
    if (path === 'jobs/old') {
      if (++oldReads === 1 || mode === 'active-control') return json(sample('old'));
      return mode === 'terminal' ? json(sample('old', 'failed')) : json({ error: { code: mode === '404' ? 'JOB_NOT_FOUND' : 'JOB_EXPIRED' } }, Number(mode));
    }
    if (path === 'jobs/new') return json(sample('new'));
    if (path.endsWith('/heartbeat')) return json({ ok: true });
    if (path === 'ad-events') return json({ ok: true }, 201);
    throw new Error('Undeclared fixture ' + method + ' ' + path);
  };
  try {
    await home(); await submit();
    assert(state().selection === 'old fixture' && counts().intervals === 2, 'Old selectable/monitor precondition');
    assert(sponsorCalls === 1 && (!lateOld || find('ads?placement=sponsor')[0].pendingResponse), 'Initial sponsor identity/pending precondition');
    await submit(); const cancel = find('jobs/old/cancel', 'POST')[0];
    assert(cancel && cancel.pendingResponse && typeof resolveCancel === 'function' && created === 1, 'Cancel not pending before old poll');
    await record({ stage: 'precondition', name, pendingResponse: true, oldJobId: 'old', newJobId: null, state: state(), requests, timeline });
    await advance(2000);
    assert(cancel.pendingResponse && cancel.finishOrder === undefined && created === 1, 'Cancel settled before callback');
    const poll = find('jobs/old').at(-1)!;
    assert(poll.finishOrder && !poll.pendingResponse, 'Old poll must finish');
    if (mode === 'active-control') assert(state().selection === 'old fixture' && counts().intervals === 2, 'Active old control stopped');
    else assert(counts().intervals === 0 && state().text.includes(mode === 'terminal' ? 'Không lấy được nội dung' : 'Tệp đã hết hạn'), 'Old terminal/missing callback did not update production UI');
    const callbackOrder = mark('old-callback-observed-before-cancel-finish', { mode, pendingResponse: cancel.pendingResponse, state: state() });
    await record({ stage: 'old-callback-before-cancel', name, pendingResponse: true, callbackOrder, pollFinishOrder: poll.finishOrder, state: state(), requests, timeline });
    cancelSettled = true; resolveCancel(json({ ok: true })); await flush();
    await until(() => cancel.finishOrder !== undefined, 'cancel response finish');
    await until(() => state().selection === 'new fixture' && find('ads?placement=sponsor')[1]?.finishOrder !== undefined, 'new selection and sponsor response finish');
    const analyzes = find('jobs/analyze', 'POST'), grants = find('ads?placement=sponsor');
    assert(!cancel.pendingResponse && cancel.finishOrder! > callbackOrder, 'Old callback must precede cancel finish');
    assert(analyzes.length === 2 && analyzes[1].startOrder > cancel.finishOrder! && Number(created) === 2, 'Exactly1 replacement analyze after cancel200');
    assert(grants.length === 2 && grants[1].startOrder > analyzes[1].finishOrder! && grants[1].status === 200 && (grants[1].payload as Ad).id === B.id, 'Exactly1 new sponsor200 non-null B grant after analyze');
    assert(state().selection === 'new fixture' && !state().analyzeDisabled && counts().intervals === 2, 'New selectable active job precondition');
    await record({ stage: 'new-grant-delivered', name, oldJobId: 'old', newJobId: 'new', grant: B, pendingResponse: grants[1].pendingResponse, callbackOrder, state: state(), requests, timeline });
    assert(state().sponsorTitle === B.title, 'Legitimate new B grant discarded after old callback/cancel pending');
    if (lateOld) {
      assert(grants[0].pendingResponse && typeof resolveOld === 'function', 'Old sponsor must remain pending until after new grant');
      mark('old-sponsor-resolve-after-new-grant', { newSponsor: state().sponsorTitle, pendingResponse: grants[0].pendingResponse });
      oldSettled = true; resolveOld(json(A)); await flush();
      await until(() => grants[0].finishOrder !== undefined, 'late old sponsor response finish');
      assert(grants[0].finishOrder! > grants[1].finishOrder!, 'Old response did not arrive after new grant');
      assert(state().sponsorTitle === B.title && !state().text.includes(A.title), 'Late old grant opened/overwrote B');
    }
    const oldCount = requests.filter(r => r.path.startsWith('/api/v1/jobs/old')).length;
    await advance(30000); window.dispatchEvent(new Event('pageshow')); document.dispatchEvent(new Event('visibilitychange')); await flush();
    assert(requests.filter(r => r.path.startsWith('/api/v1/jobs/old')).length === oldCount, 'Old monitor/listener survived replacement');
    assert(find('jobs/analyze', 'POST').length === 2 && find('ads?placement=sponsor').length === 2 && state().sponsorTitle === B.title, 'Duplicate analyze/sponsor retry or new grant lost');
    assert(find('jobs/new').length > 1 && find('jobs/new/heartbeat', 'POST').length > 0, 'New active monitor stopped');
  } finally {
    // Resolve held HTTP only after unmount on FAIL, so teardown cannot create a false runtime PASS.
    const before = state(); await unmount();
    if (!cancelSettled && resolveCancel) resolveCancel(json({ ok: true }));
    if (!oldSettled && resolveOld) resolveOld(json(A));
    await flush();
    await record({ stage: 'teardown', name, before, cleanup: state(), heldResponseCleanupAfterUnmount: !cancelSettled || !oldSettled, requests, timeline });
    assert(timers.size === 0 && observers.every(o => !o.live) && [...listeners.values()].every(s => !s.size), 'Cleanup leaked timer/observer/listener');
    assert(requests.every(r => !r.pendingResponse), 'Fixture HTTP remained pending after teardown');
  }
}
async function runMatrix() {
  button.disabled = true; report.textContent = 'Đang chạy P21';
  const env = await (await nativeFetch('/__p19/environment')).json();
  assert(env.guard === 'wed-snap-ui-lab' && env.expectedHomeSha === env.hashes['pages/Home.tsx'], 'Source/container guard mismatch');
  await record({ stage: 'matrix-before-tests', env, userAgent: navigator.userAgent, stubs: ['fetch/Beacon HTTP', 'timeout/interval clock'], instrumentation: ['native IntersectionObserver subclass delegates entries/disconnect', 'native EventTarget listener registration'], production: ['Home', 'useJobLifecycle', 'api', 'Advertising', 'ReactDOM'], matrix });
  install(); let passed = 0, failed = 0;
  try {
    for (const test of matrix) {
      now = 0; serial = 0; requests = []; timeline = []; observers.length = 0; listeners.clear();
      let error: string | null = null;
      try { await runCase(test.mode, test.lateOld, test.name); passed++; }
      catch (e) { error = String(e); failed++; }
      await record({ stage: 'case-result', name: test.name, expected: test.expected, result: error ? 'FAIL' : 'PASS', error, requests, timeline, cleanup: state() });
      assert(timers.size === 0 && [...listeners.values()].every(s => !s.size), 'Cannot continue with leaked resources');
    }
  } finally { await unmount(); restore(); button.disabled = false; }
  await record({ stage: 'summary', passed, failed, result: failed ? 'FAIL' : 'PASS', restored: !installed, cleanup: state() });
  report.textContent = `${failed ? 'FAIL' : 'PASS'} ${passed}/${matrix.length}, ${failed} FAIL\n` + matrix.map(t => t.name).join('\n');
}
button.addEventListener('click', () => runMatrix().catch(async e => { await unmount(); if (installed) restore(); button.disabled = false; report.textContent = String(e); await record({ stage: 'harness-failure', error: String(e), cleanup: state() }); }));
