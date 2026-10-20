'use strict';
const fs = require('node:fs');
const childProcess = require('node:child_process');
function sanitize(value) {
  return String(value).replace(/\u001b\[[0-9;]*m/g, '')
    .replace(/https?:\/\/[^\s'"<>]+/gi, raw => {
      try { const url = new URL(raw); return `${url.protocol}//${url.host}${url.pathname}${url.search || url.hash ? '[query-redacted]' : ''}`; }
      catch { return '[invalid-url-redacted]'; }
    })
    .replace(/\b(authorization|proxy-authorization|cookie|set-cookie)\s*:[^\r\n]*/gi, '$1: [redacted]')
    .replace(/\b(msToken|token|signature|_signature|x-bogus|sessionid|password|secret|bearer)=[^\s&'";]+/gi, '$1=[redacted]');
}
class BoundedLog {
  constructor(cap = 1024 * 1024) { this.cap = cap; this.received = 0; this.buffer = Buffer.alloc(0); this.head = null; }
  push(chunk) {
    const b = Buffer.isBuffer(chunk) ? chunk : Buffer.from(String(chunk)); this.received += b.length;
    const half = Math.floor(this.cap / 2);
    if (this.head === null && this.buffer.length + b.length <= this.cap) { this.buffer = Buffer.concat([this.buffer, b]); return; }
    if (this.head === null) { const all = Buffer.concat([this.buffer, b]); this.head = all.subarray(0, half); this.buffer = all.subarray(-half); }
    else { this.buffer = Buffer.concat([this.buffer, b]).subarray(-half); }
  }
  report() {
    const truncated = this.head !== null;
    const text = truncated ? `${this.head.toString('utf8')}\n[LOG MIDDLE OMITTED: ${this.received - this.head.length - this.buffer.length} bytes]\n${this.buffer.toString('utf8')}` : this.buffer.toString('utf8');
    const safe = sanitize(text);
    return { bytesReceived: this.received, retainedBytes: this.buffer.length + (this.head ? this.head.length : 0),
      sanitizedBytes: Buffer.byteLength(safe), truncated, retention: truncated ? 'head+tail' : 'full', text: safe };
  }
}
function observeChromium() {
  const original = childProcess.spawn; const records = [];
  childProcess.spawn = function(command, ...args) {
    const proc = Reflect.apply(original, this, [command, ...args]);
    if (/\/(chrome-headless-shell|chrome)$/.test(String(command))) {
      const stdout = new BoundedLog(); const stderr = new BoundedLog();
      const record = { executable: String(command), pid: proc.pid ?? null, startUTC: new Date().toISOString(),
        exitObserved: false, closeObserved: false, exitCode: null, signal: null, stdout, stderr };
      records.push(record);
      proc.stdout?.on('data', data => stdout.push(data)); proc.stderr?.on('data', data => stderr.push(data));
      proc.once('error', error => { record.spawnError = sanitize(error.message); });
      proc.once('exit', (code, signal) => { Object.assign(record, { exitObserved: true, exitCode: code, signal, exitUTC: new Date().toISOString() }); });
      proc.once('close', (code, signal) => { Object.assign(record, { closeObserved: true, closeExitCode: code, closeSignal: signal, closeUTC: new Date().toISOString() }); });
    }
    return proc;
  };
  return { finish: () => { childProcess.spawn = original; return records.map(r => ({ ...r, stdout: r.stdout.report(), stderr: r.stderr.report() })); } };
}
function readOptional(path) {
  try { return { status: 'OBSERVED', value: fs.readFileSync(path, 'utf8').trim() }; }
  catch (error) { return { status: 'UNKNOWN', errorCode: error.code || 'UNKNOWN' }; }
}
function cgroupSnapshot() {
  return Object.fromEntries(['memory.current', 'memory.peak', 'memory.events', 'pids.current', 'pids.events', 'cpu.stat'].map(name => [name, readOptional(`/sys/fs/cgroup/${name}`)]));
}
function namespaceSnapshot() {
  return Object.fromEntries(['/proc/sys/user/max_user_namespaces', '/proc/sys/kernel/unprivileged_userns_clone',
    '/proc/sys/kernel/apparmor_restrict_unprivileged_userns', '/proc/self/attr/current'].map(path => [path, readOptional(path)]));
}
function selfTest() {
  const assert = require('node:assert/strict');
  const small = new BoundedLog(128); small.push('first\n'); small.push('FATAL cause tail\n');
  assert.equal(small.report().truncated, false); assert.match(small.report().text, /FATAL cause tail/);
  const large = new BoundedLog(64); large.push('head '.repeat(40)); large.push('fatal-at-tail');
  assert.equal(large.report().truncated, true); assert.ok(large.report().retainedBytes <= 64); assert.match(large.report().text, /fatal-at-tail/);
  const clean = sanitize('https://FAKEUSER:FAKEPASS@example.invalid/p?token=FAKEQUERY\nCookie: FAKECOOKIE\nsecret=FAKESECRET');
  assert.doesNotMatch(clean, /FAKEUSER|FAKEPASS|FAKEQUERY|FAKECOOKIE|FAKESECRET/);
  return { status: 'PASS', cases: 3, scope: 'synthetic log-only fixtures; no browser launch' };
}
module.exports = { sanitize, BoundedLog, observeChromium, cgroupSnapshot, namespaceSnapshot, selfTest };
