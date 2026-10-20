'use strict';
const fs = require('node:fs');
const { once } = require('node:events');
const RECORDS = 512;
const WIDTH = 1024;
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
async function write(text) {
  if (!process.stdout.write(text)) await once(process.stdout, 'drain');
}
async function main() {
  // No output until the host has validated this exact own container.
  const deadline = Date.now() + 60000;
  while (!fs.existsSync('/tmp/p33-emit')) {
    if (Date.now() >= deadline) throw new Error('P33_GATE_TIMEOUT');
    await delay(50);
  }
  if (fs.readFileSync('/tmp/p33-emit', 'utf8') !== 'p33-granted') throw new Error('P33_GATE_INVALID');
  const startUTC = new Date().toISOString();
  let sequenceBytes = 0;
  for (let n = 1; n <= RECORDS; n++) {
    const prefix = 'P33_SEQ ' + String(n).padStart(6, '0') + ' ';
    const line = prefix + 'x'.repeat(WIDTH - prefix.length - 1) + '\n';
    sequenceBytes += Buffer.byteLength(line);
    await write(line);
  }
  const done = 'P33_DONE ' + JSON.stringify({ records: RECORDS, recordBytes: WIDTH, sequenceBytes, node: process.version, startUTC, finishUTC: new Date().toISOString(), stderrRecords: 0 }) + '\n';
  if (sequenceBytes + Buffer.byteLength(done) > 1048576) throw new Error('P33_FIXTURE_BOUND');
  await write(done);
  await new Promise((resolve, reject) => process.stdout.write('', err => err ? reject(err) : resolve()));
  fs.unlinkSync('/tmp/p33-emit');
  // Natural process exit after stdout drain, no pending gate timers.
}
main().catch(err => { console.error('P33_HARNESS_ERROR ' + err.message); process.exitCode = 7; });
