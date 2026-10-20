import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { writeFile } from 'node:fs/promises';
import { execFileSync } from 'node:child_process';

// Run explicitly with compose.test.yaml + compose.smoke.yaml, never in routine unit tests.
async function main() {
  assert.equal(process.env.APP_ORIGIN, 'http://localhost:5174');
  const base = 'http://api:3000/api/v1/';
  const sessionResponse = await fetch(base + 'session');
  const session = (await sessionResponse.json()) as any;
  const cookie = sessionResponse.headers.get('set-cookie')!.split(';')[0];
  const headers = {
    cookie,
    origin: process.env.APP_ORIGIN!,
    'x-csrf-token': session.csrf,
    'content-type': 'application/json',
  };
  async function call(path: string, body?: unknown) {
    const r = await fetch(base + path, {
      method: body === undefined ? 'GET' : 'POST',
      headers,
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    const value = (await r.json()) as any;
    assert.ok(r.ok, `${path}: ${r.status} ${value.errorCode}`);
    return value;
  }
  const start = Date.now();
  const { jobId } = await call('jobs/analyze', {
    url: 'https://www.youtube.com/watch?v=PVGeM40dABA',
  });
  const heartbeat = setInterval(() => {
    void call(`jobs/${jobId}/heartbeat`, {}).catch(() => {});
  }, 15000);
  try {
    async function wait(state: string, seconds: number) {
      const until = Date.now() + seconds * 1000;
      while (Date.now() < until) {
        const job = await call(`jobs/${jobId}`);
        if (job.state === state) return job;
        assert.ok(
          !['failed', 'expired', 'cancelled'].includes(job.state),
          `${job.state}: ${job.errorCode}`,
        );
        await new Promise((r) => setTimeout(r, 500));
      }
      throw new Error(`Deadline waiting for ${state}`);
    }
    const job = await wait('selectable', 40);
    const formatId = job.items[0].formats[0].id;
    const selection = { itemId: job.items[0].id, formatId, idempotencyKey: randomUUID() };
    await call(`jobs/${jobId}/prepare`, selection);
    await call(`jobs/${jobId}/prepare`, selection);
    await wait('ready', 190);
    const ticket = await call(`jobs/${jobId}/download-ticket`, {});
    const range = await fetch('http://api:3000' + ticket.url, {
      headers: { cookie, range: 'bytes=0-99' },
    });
    assert.equal(range.status, 206);
    assert.equal((await range.arrayBuffer()).byteLength, 100);
    const file = await fetch('http://api:3000' + ticket.url, { headers: { cookie } });
    assert.equal(file.status, 200);
    const bytes = Buffer.from(await file.arrayBuffer());
    assert.equal(bytes.length, Number(file.headers.get('content-length')));
    await writeFile('/evidence/youtube-coffee-api.mp4', bytes);
    const probe = JSON.parse(
      execFileSync(
        'ffprobe',
        [
          '-v',
          'error',
          '-show_entries',
          'stream=codec_type,codec_name:format=duration,size',
          '-of',
          'json',
          '/evidence/youtube-coffee-api.mp4',
        ],
        { encoding: 'utf8' },
      ),
    );
    assert.ok(probe.streams.some((s: any) => s.codec_type === 'video'));
    assert.ok(probe.streams.some((s: any) => s.codec_type === 'audio'));
    const report = {
      date: new Date().toISOString(),
      fixtureOnly: false,
      url: 'https://www.youtube.com/watch?v=PVGeM40dABA',
      formatId,
      bytes: bytes.length,
      elapsedMs: Date.now() - start,
      doublePrepare: 'PASS',
      range: 'PASS',
      fullDownload: 'PASS',
      probe,
    };
    await writeFile('/evidence/p0-api-smoke.json', JSON.stringify(report, null, 2));
    console.log(JSON.stringify(report, null, 2));
    await call(`jobs/${jobId}/release`, {});
  } finally {
    clearInterval(heartbeat);
  }
}
main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
