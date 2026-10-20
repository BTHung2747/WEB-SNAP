import React from 'react';
import { createRoot, type Root } from 'react-dom/client';
import { flushSync } from 'react-dom';
import Home from '../../apps/web/src/pages/Home';
import { ApiError, messages } from '../../apps/web/src/lib/api';
import type { Job, Session } from '../../apps/web/src/types';
import '../../apps/web/src/style.css';
import '../../apps/web/src/styles/home.css';
import '../../apps/web/src/styles/layout.css';
import '../../apps/web/src/styles/responsive.css';

// Real React/DOM/Home/hooks/api. Only HTTP and interval clock are controlled.
const nativeFetch = window.fetch.bind(window);
const nativeTimeout = window.setTimeout.bind(window);
const nativeSetInterval = window.setInterval.bind(window), nativeClearInterval = window.clearInterval.bind(window);
const nativeBeacon = navigator.sendBeacon.bind(navigator);
const nativeAdd = EventTarget.prototype.addEventListener, nativeRemove = EventTarget.prototype.removeEventListener;
const session: Session = { csrf: 'p19-fixture-not-secret', supported: ['youtube'], productName: 'P19 fixture', contact: null, heartbeatSeconds: 15 };
const report = document.querySelector<HTMLPreElement>('#result')!;
const host = document.querySelector<HTMLDivElement>('#home')!;
const output: unknown[] = [];
function assert(value: unknown, why: string): asserts value { if (!value) throw new Error(why); }
const flush = async () => { for (let i = 0; i < 5; i++) await new Promise<void>(r => nativeTimeout(r, 0)); };
const json = (data: unknown, status = 200) => new Response(JSON.stringify(data), { status, headers: { 'Content-Type': 'application/json' } });
const fault = (status: number, code: string) => json({ error: { code } }, status);
const sample = (id: string, state = 'selectable', errorCode: string | null = null): Job => ({
  id, state, errorCode, title: id + ' fixture title', duration: 10, previewUrl: null,
  items: [{ id: 'fixture-item', kind: 'video', formats: [{ id: 'fixture-format', label: 'Fixture MP4', size: 1024 }] }],
});
const terminal = ['failed', 'cancelled', 'expired'];
const active = ['analyzing', 'selectable', 'queued', 'preparing', 'ready'];
const listeners = new Map<string, Set<EventListenerOrEventListenerObject>>();
const listenerKey = (target: EventTarget, type: string) =>
  (target === window && ['pageshow', 'pagehide'].includes(type)) || (target === document && type === 'visibilitychange')
    ? (target === window ? 'window:' : 'document:') + type : null;
let root: Root | null = null;
let now = 0, nextTimer = 900000, peakTimers = 0;
const timers = new Map<number, { run: () => void; period: number; next: number }>();
type RequestRecord = { order: number; at: number; method: string; path: string; outcome?: string | number };
let requests: RequestRecord[] = [];
let transport: (path: string, method: string, record: RequestRecord) => Response | Promise<Response>;
let originalMounted = false;

function install() {
  assert(location.origin === 'http://localhost:5175', 'Refuse non-lab origin');
  window.setInterval = ((fn: TimerHandler, ms?: number) => {
    assert(typeof fn === 'function' && ms && ms > 0, 'Expected finite function interval');
    const id = nextTimer++; timers.set(id, { run: fn as () => void, period: ms, next: now + ms });
    peakTimers = Math.max(peakTimers, timers.size); return id;
  }) as typeof window.setInterval;
  window.clearInterval = ((id?: number) => { if (id !== undefined && timers.has(id)) timers.delete(id); else nativeClearInterval(id); }) as typeof window.clearInterval;
  EventTarget.prototype.addEventListener = function(type, callback, options) {
    const key = listenerKey(this, type);
    if (key && callback) { if (!listeners.has(key)) listeners.set(key, new Set()); listeners.get(key)!.add(callback); }
    nativeAdd.call(this, type, callback, options);
  };
  EventTarget.prototype.removeEventListener = function(type, callback, options) {
    const key = listenerKey(this, type); if (key && callback) listeners.get(key)?.delete(callback);
    nativeRemove.call(this, type, callback, options);
  };
  window.fetch = (async (input: RequestInfo | URL, options?: RequestInit) => {
    const path = String(input); const method = options?.method || 'GET';
    assert(path.startsWith('/api/v1/'), 'Unexpected fetch; network prohibited outside declared fixture');
    const record: RequestRecord = { order: requests.length + 1, at: now, method, path }; requests.push(record);
    try { const response = await transport(path.slice('/api/v1/'.length), method, record); record.outcome = response.status; return response; }
    catch (e) { record.outcome = 'network-error'; throw e; }
  }) as typeof fetch;
  navigator.sendBeacon = (url) => { requests.push({ order: requests.length + 1, at: now, method: 'BEACON', path: String(url), outcome: 'fixture' }); return true; };
  originalMounted = true;
}
function restore() {
  window.fetch = nativeFetch; window.setInterval = nativeSetInterval; window.clearInterval = nativeClearInterval;
  navigator.sendBeacon = nativeBeacon;
  EventTarget.prototype.addEventListener = nativeAdd; EventTarget.prototype.removeEventListener = nativeRemove;
  originalMounted = false;
}
const counts = () => ({ timers: timers.size, peakTimers, listeners: Object.fromEntries([...listeners].map(([k, v]) => [k, v.size])) });
const snapshot = () => ({ text: host.innerText, analyzeDisabled: host.querySelector<HTMLButtonElement>('button.analyze')?.disabled,
  processing: !!host.querySelector('.processing'), selection: host.querySelector('.selection h2')?.textContent || null, ...counts() });
async function advance(ms: number) {
  const end = now + ms;
  while (true) {
    const entry = [...timers].filter(([, t]) => t.next <= end).sort((a, b) => a[1].next - b[1].next)[0];
    if (!entry) break;
    now = entry[1].next; entry[1].next += entry[1].period; entry[1].run(); await flush();
  }
  now = end; await flush();
}
async function events() {
  window.dispatchEvent(new Event('pageshow')); document.dispatchEvent(new Event('visibilitychange'));
  window.dispatchEvent(new Event('pagehide')); await flush();
}
async function mount() {
  root = createRoot(host); flushSync(() => root!.render(<Home session={session} />)); await flush();
}
async function unmount() { if (root) { flushSync(() => root!.unmount()); root = null; await flush(); } }
async function submit() {
  const input = host.querySelector<HTMLInputElement>('#video-url')!;
  Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value')!.set!.call(input, 'https://www.youtube.com/watch?v=p19-fixture');
  input.dispatchEvent(new Event('input', { bubbles: true })); await flush();
  host.querySelector<HTMLFormElement>('form')!.dispatchEvent(new Event('submit', { bubbles: true, cancelable: true })); await flush();
}
function fixture(overrides?: (path: string, method: string, record: RequestRecord) => Response | Promise<Response> | undefined) {
  let created = 0;
  transport = (path, method, record) => {
    const custom = overrides?.(path, method, record); if (custom !== undefined) return custom;
    if (path.startsWith('ads?')) return json(null);
    if (path === 'jobs/analyze') { assert(method === 'POST', 'Analyze must be POST'); return json({ jobId: ++created === 1 ? 'old' : 'new' }, 202); }
    if (path.endsWith('/cancel') || path.endsWith('/heartbeat')) return json({ ok: true });
    if (path.endsWith('/download-ticket')) return json({ url: '/api/v1/downloads/p19-fixture-ticket' });
    if (path === 'jobs/old' || path === 'jobs/new') return json(sample(path.slice(5)));
    throw new Error('Undeclared fixture endpoint: ' + path);
  };
}
async function record(data: Record<string, unknown>) {
  const line = { utc: new Date().toISOString(), vietnam: new Date().toLocaleString('sv-SE', { timeZone: 'Asia/Ho_Chi_Minh' }), ...data };
  output.push(line); console.log('P19', line);
  const result = await nativeFetch('/__p19/record', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(line) });
  assert(result.ok, 'Raw logging failed');
}
const cases: { name: string; expected: string; run: () => Promise<void> }[] = [];
const add = (name: string, expected: string, run: () => Promise<void>) => cases.push({ name, expected, run });
for (const state of terminal) add('terminal-' + state, 'visible final;0 old requests/30s+events;0 timers', async () => {
  fixture(p => p === 'jobs/old' ? json(sample('old', state, state === 'failed' ? 'SOURCE_TIMEOUT' : null)) : undefined);
  await mount(); await submit(); const before = requests.length; const text = host.innerText;
  await advance(30000); await events();
  assert(requests.length === before, 'Terminal sent requests: ' + JSON.stringify(requests.slice(before)));
  assert(timers.size === 0 && !snapshot().processing && !snapshot().analyzeDisabled, 'Terminal tracking/busy stuck');
  assert(host.innerText === text && (state === 'failed' ? text.includes(messages.SOURCE_TIMEOUT) : text.includes(state === 'expired' ? 'Tệp đã hết hạn' : 'Tác vụ đã được hủy')), 'Final message missing/changed');
});
add('failed-without-error-code', 'failed final message visible, analyze enabled', async () => {
  fixture(p => p === 'jobs/old' ? json(sample('old', 'failed')) : undefined); await mount(); await submit();
  assert(host.innerText.includes('Không lấy được nội dung') && !snapshot().analyzeDisabled, 'Failed has no visible final message');
});
for (const [status, code] of [[404, 'JOB_NOT_FOUND'], [410, 'JOB_EXPIRED']] as const) {
  add('missing-poll-' + status, 'expired message;0 old requests/30s+events;not busy', async () => {
    fixture(p => p === 'jobs/old' ? fault(status, code) : undefined); await mount(); await submit();
    const before = requests.length; await advance(30000); await events();
    assert(requests.length === before && timers.size === 0, 'Missing ID still tracked');
    assert(!snapshot().processing && !snapshot().analyzeDisabled && host.innerText.toLocaleLowerCase().includes('phân tích lại'), 'Missing job stuck analyzing/message absent');
  });
  add('missing-heartbeat-' + status, 'expired on heartbeat;0 old requests after30s+events', async () => {
    fixture(p => p === 'jobs/old/heartbeat' ? fault(status, code) : undefined); await mount(); await submit();
    await advance(15000); const before = requests.length; await advance(30000); await events();
    assert(requests.length === before && timers.size === 0 && !snapshot().processing && host.innerText.toLocaleLowerCase().includes('phân tích lại'), 'Heartbeat missing ID keeps tracking');
  });
  add('analyze-after-cancel-' + status, 'cancel missing→exactly1 new POST→new selection', async () => {
    fixture(p => p === 'jobs/old/cancel' ? fault(status, code) : undefined); await mount(); await submit(); await submit();
    assert(requests.filter(r => r.path === '/api/v1/jobs/analyze').length === 2, 'Cancel missing blocked new analyze or duplicate POST');
    assert(snapshot().selection === 'new fixture title' && !snapshot().analyzeDisabled, 'New job not selectable');
    const before = requests.length; await advance(30000);
    assert(!requests.slice(before).some(r => r.path.includes('/jobs/old')), 'Replaced old ID timer survives');
    assert(timers.size === 2 && peakTimers <= 2, 'Duplicate active timers');
  });
}
for (const state of active) add('active-' + state, 'poll/heartbeat continue30s;2 timers/3 lifecycle listeners', async () => {
  fixture(p => p === 'jobs/old' ? json(sample('old', state)) : undefined); await mount(); await submit();
  await advance(30000); await events();
  assert(requests.filter(r => r.path === '/api/v1/jobs/old' && r.method === 'GET').length === 16, 'Active poll count wrong');
  assert(requests.filter(r => r.path === '/api/v1/jobs/old/heartbeat').length === 4, 'Active periodic/restore heartbeat count wrong');
  assert(timers.size === 2 && Object.values(counts().listeners).every(v => v === 1), 'Active timer/listener duplication');
});
const negative = [[403, 'CSRF_INVALID'], [403, 'SESSION_REQUIRED'], [500, 'INTERNAL_ERROR'], [429, 'RATE_LIMITED'],
  [403, 'JOB_NOT_FOUND'], [500, 'JOB_EXPIRED'], [404, 'INTERNAL_ERROR'], [0, 'network']] as const;
for (const [status, code] of negative) add('cancel-block-' + status + '-' + code, 'non-missing failure→0 new POST;error shown;busy cleared', async () => {
  fixture(p => p === 'jobs/old/cancel' ? (status ? fault(status, code) : Promise.reject(new TypeError('fixture network failure'))) : undefined);
  await mount(); await submit(); await submit();
  assert(requests.filter(r => r.path === '/api/v1/jobs/analyze').length === 1, 'Unsafe cancel error swallowed');
  assert(!!host.querySelector('[role=alert]') && !snapshot().analyzeDisabled && snapshot().selection === 'old fixture title', 'Cancel error/busy preservation failed');
});
for (const [status, code] of [[500, 'INTERNAL_ERROR'], [429, 'RATE_LIMITED'], [403, 'SESSION_REQUIRED'], [0, 'network']] as const)
  add('poll-transient-' + status, 'temporary error keeps valid selection/monitor;later poll recovers', async () => {
    let reads = 0;
    fixture(p => p === 'jobs/old' && ++reads === 2 ? (status ? fault(status, code) : Promise.reject(new TypeError('fixture network failure'))) : undefined);
    await mount(); await submit(); await advance(2000);
    assert(snapshot().selection === 'old fixture title' && timers.size === 2 && !!host.querySelector('[role=alert]'), 'Transient error expired valid job');
    await advance(28000); assert(reads === 16 && snapshot().selection === 'old fixture title', 'Polling did not recover');
  });
add('late-old-poll-after-replace', 'in-flight old response cannot change new job;no duplicate timers', async () => {
  let reads = 0, resolve!: (r: Response) => void;
  fixture(p => p === 'jobs/old' && ++reads === 2 ? new Promise<Response>(r => { resolve = r; }) : undefined);
  await mount(); await submit(); await advance(2000); assert(resolve, 'Missing pending old poll precondition');
  await submit(); assert(snapshot().selection === 'new fixture title', 'New pre-state missing');
  resolve(json(sample('old', 'ready'))); await flush(); await advance(30000);
  assert(snapshot().selection === 'new fixture title' && !requests.some(r => r.path === '/api/v1/jobs/old/download-ticket'), 'Late old response overwrote new job');
  assert(timers.size === 2 && peakTimers <= 2, 'Replace duplicated timer');
});
add('late-same-id-response-after-cancel', 'old ready response cannot revive cancelled job', async () => {
  let reads = 0, resolve!: (r: Response) => void;
  fixture(p => p === 'jobs/old' ? (++reads === 1 ? json(sample('old', 'preparing')) : new Promise<Response>(r => { resolve = r; })) : undefined);
  await mount(); await submit(); await advance(2000); assert(resolve, 'Missing pending poll');
  host.querySelector<HTMLButtonElement>('.processing .text-btn')!.click(); await flush();
  resolve(json(sample('old', 'ready'))); await flush(); const before = requests.length; await advance(30000); await events();
  assert(!snapshot().selection && host.innerText.includes('Tác vụ đã được hủy') && requests.length === before, 'Late response revived cancelled ID');
});
add('unmount-remount', 'cleanup0 timers/listeners,0 requests after unmount;new mount one monitor', async () => {
  fixture(); await mount(); await submit(); await unmount(); const before = requests.length;
  assert(timers.size === 0 && Object.values(counts().listeners).every(v => v === 0), 'Unmount leaked resources');
  await advance(30000); await events(); assert(requests.length === before, 'Unmount still sends request');
  await mount(); await submit(); await advance(30000);
  assert(Number(timers.size) === 2 && Object.values(counts().listeners).every(v => v === 1) && peakTimers <= 2, 'Remount duplicate monitoring');
});
add('late-ticket-after-replace', 'ticket for old ready cannot appear for new ready', async () => {
  let resolve!: (r: Response) => void;
  fixture(p => p === 'jobs/old' || p === 'jobs/new' ? json(sample(p.slice(5), 'ready')) : p === 'jobs/old/download-ticket' ? new Promise<Response>(r => { resolve = r; }) : undefined);
  await mount(); await submit(); assert(resolve, 'Missing old pending ticket'); await submit();
  resolve(json({ url: '/api/v1/downloads/old-late-ticket' })); await flush();
  assert(snapshot().selection === 'new fixture title' && !host.querySelector('a[href*="old-late-ticket"]'), 'Late old ticket applied');
});
add('ApiError-contract', 'code/message remain + HTTP status available', async () => {
  const e = new ApiError('RATE_LIMITED'); assert(e.code === 'RATE_LIMITED' && e.message === messages.RATE_LIMITED, 'ApiError caller contract broken');
  fixture(); transport = () => fault(404, 'JOB_NOT_FOUND');
  const { api } = await import('../../apps/web/src/lib/api');
  let caught: unknown; try { await api('jobs/old', session.csrf); } catch (error) { caught = error; }
  assert(caught instanceof ApiError && caught.code === 'JOB_NOT_FOUND' && (caught as ApiError & { status?: number }).status === 404, 'HTTP status not retained');
});
for (const end of [...terminal, '404', '410']) add('pending-prepare-terminal-' + end, 'terminal clears busy before pending HTTP returns;late prepare cannot revive', async () => {
  let reads = 0, resolve!: (r: Response) => void;
  fixture(p => p === 'jobs/old' ? (++reads === 1 ? json(sample('old')) : end === '404' ? fault(404, 'JOB_NOT_FOUND') : end === '410' ? fault(410, 'JOB_EXPIRED') : json(sample('old', end)))
    : p === 'jobs/old/prepare' ? new Promise<Response>(r => { resolve = r; }) : undefined);
  await mount(); await submit(); host.querySelector<HTMLButtonElement>('.selection button.primary')!.click(); await flush();
  assert(typeof resolve === 'function' && snapshot().analyzeDisabled, 'Pending prepare/busy precondition absent');
  try {
    await advance(2000);
    await record({ stage: 'pending-prepare-terminal-prestate', name: end, state: snapshot(), pendingResponse: true, requests });
    assert(!snapshot().analyzeDisabled && !snapshot().processing && timers.size === 0, 'Terminal remains busy while prepare HTTP pending');
  } finally { resolve(json({ state: 'queued' })); await flush(); }
  const before = requests.length; await advance(30000); await events();
  assert(!snapshot().selection && !snapshot().processing && requests.length === before, 'Late prepare revived terminal job');
});
add('unmount-with-inflight-poll', 'inflight response after unmount creates no state/ticket/timer/requests', async () => {
  let reads = 0, resolve!: (r: Response) => void;
  fixture(p => p === 'jobs/old' && ++reads === 2 ? new Promise<Response>(r => { resolve = r; }) : undefined);
  await mount(); await submit(); await advance(2000); assert(resolve, 'Missing inflight poll'); await unmount();
  const before = requests.length; resolve(json(sample('old', 'ready'))); await flush(); await advance(30000); await events();
  assert(!host.innerText && requests.length === before && timers.size === 0, 'Unmount inflight response survived');
});
add('duplicate-submit-during-missing-cancel', 'two submits during pending cancel404 produce one cancel/one new analyze', async () => {
  let resolve!: (r: Response) => void;
  fixture(p => p === 'jobs/old/cancel' ? new Promise<Response>(r => { resolve = r; }) : undefined);
  await mount(); await submit(); await submit(); assert(typeof resolve === 'function' && snapshot().analyzeDisabled, 'Missing pending cancel precondition');
  await submit(); resolve(fault(404, 'JOB_NOT_FOUND')); await flush();
  assert(requests.filter(r => r.path === '/api/v1/jobs/old/cancel').length === 1 && requests.filter(r => r.path === '/api/v1/jobs/analyze').length === 2,
    'Repeated submit duplicated replacement');
  assert(snapshot().selection === 'new fixture title', 'Replacement missing');
});

async function matrix() {
  (document.querySelector('#run') as HTMLButtonElement).disabled = true;
  (document.querySelector('#smoke') as HTMLButtonElement).disabled = true;
  report.textContent = 'Đang chạy…'; output.length = 0;
  const environment = await (await nativeFetch('/__p19/environment')).json();
  assert(environment.guard === 'wed-snap-ui-lab' && environment.hashes['pages/Home.tsx'] === environment.expectedHomeSha, 'Lab source guard mismatch');
  await record({ stage: 'matrix-before-tests', environment, userAgent: navigator.userAgent,
    stubs: ['HTTP fetch/Beacon fixture', 'controlled setInterval clock; actual window/document events'],
    production: ['React19/ReactDOM', 'Home', 'useJobLifecycle', 'useDownloadLink', 'api/ApiError'],
    advanceMs: 30000, cases: cases.map(({ name, expected }) => ({ name, expected })) });
  install(); let passed = 0, failed = 0;
  try {
    for (const c of cases) {
      now = 0; requests = []; peakTimers = 0; let error: string | null = null;
      try { await c.run(); passed++; } catch (e) { error = String(e); failed++; }
      const state = snapshot(); const preCleanup = counts(); await unmount();
      const cleanup = counts();
      if (timers.size || Object.values(cleanup.listeners).some(v => v !== 0)) { if (!error) { passed--; failed++; } error = (error || '') + ' cleanup resource leak'; }
      await record({ stage: 'case-result', name: c.name, expected: c.expected, result: error ? 'FAIL' : 'PASS', error,
        clockMs: now, state, preCleanup, cleanup, requests: [...requests] });
      assert(timers.size === 0, 'Cannot safely continue after leaked timers');
    }
  } finally { await unmount(); restore(); }
  await record({ stage: 'summary', passed, failed, result: failed ? 'FAIL' : 'PASS', clockRestored: !originalMounted,
    timers: timers.size, listeners: counts().listeners, realBackend: false, platformDownloadCertified: false });
  report.textContent = `${failed ? 'FAIL' : 'PASS'} ${passed}/${cases.length}, ${failed} FAIL — raw lưu trong Docker logs`;
  (document.querySelector('#run') as HTMLButtonElement).disabled = false;
  (document.querySelector('#smoke') as HTMLButtonElement).disabled = false;
}
document.querySelector('#run')!.addEventListener('click', () => matrix().catch(async e => {
  report.textContent = 'Harness FAIL: ' + String(e); if (root) await unmount(); if (originalMounted) restore();
  await record({ stage: 'harness-failure', error: String(e) });
}));
document.querySelector('#smoke')!.addEventListener('click', async () => {
  await unmount(); if (originalMounted) restore(); now = 0; requests = []; peakTimers = 0;
  install(); let reads = 0;
  fixture(p => p === 'jobs/old' && ++reads > 1 ? fault(404, 'JOB_NOT_FOUND') : p === 'jobs/old/cancel' ? fault(404, 'JOB_NOT_FOUND') : undefined);
  await mount(); await submit(); await advance(2000);
  report.textContent = 'Smoke: job cũ404. Hãy nhấn Phân tích link để tạo fixture mới (không gọi nguồn thật).';
});
document.querySelector('#smoke-save')!.addEventListener('click', () => record({ stage: 'manual-browser-smoke', state: snapshot(), requests, clockMs: now,
  fixture: 'Home actual + 404 poll/cancel responses; no real backend/platform' }));
window.addEventListener('pagehide', (event) => { if (!event.isTrusted) return; if (root) flushSync(() => root!.unmount()); root = null; if (originalMounted) restore(); });
