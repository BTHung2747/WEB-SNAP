import { test, after } from 'node:test';
import assert from 'node:assert/strict';
import {
  validateUrl,
  parseRange,
  ownerExpired,
  assetExpired,
  filePath,
  redis,
  db,
  queue,
} from '../packages/shared/src/core';
test('URL allowlist blocks credentials, lookalikes, ports, internal and shell inputs', () => {
  for (const value of [
    'http://127.0.0.1',
    'https://169.254.169.254/latest',
    'https://youtube.com.evil.test/watch?v=YE7VzlLtp-4',
    'file:///etc/passwd',
    'https://user:pass@youtube.com/watch?v=YE7VzlLtp-4',
    'https://youtube.com:444/watch?v=YE7VzlLtp-4',
    'https://youtube.com/watch?v=YE7VzlLtp-4;touch /tmp/a',
  ])
    assert.throws(() => validateUrl(value));
  assert.equal(
    validateUrl('https://youtu.be/YE7VzlLtp-4?si=secret').url,
    'https://www.youtube.com/watch?v=YE7VzlLtp-4',
  );
});
test('Ranges: full, bounded, suffix, clamp; malformed/multiple/unsatisfiable 416', () => {
  assert.deepEqual(parseRange(undefined, 100), { start: 0, end: 99, partial: false });
  assert.deepEqual(parseRange('bytes=5-9', 100), { start: 5, end: 9, partial: true });
  assert.deepEqual(parseRange('bytes=-20', 100), { start: 80, end: 99, partial: true });
  assert.deepEqual(parseRange('bytes=95-200', 100), { start: 95, end: 99, partial: true });
  for (const h of ['bytes=100-', 'bytes=7-3', 'bytes=-0', 'bytes=0-1,2-3', 'bytes=-', 'bytes=a-b'])
    assert.throws(
      () => parseRange(h, 100),
      (e: any) => e.status === 416,
    );
});
test('Fake clock: release grace can be restored, hidden page is not release', () => {
  const now = new Date('2026-09-30T00:00:00Z');
  const job = {
    ownerUntil: new Date(now.getTime() + 120000),
    releaseAt: new Date(now.getTime() + 30000),
  };
  assert.equal(ownerExpired(job, now), false);
  assert.equal(ownerExpired(job, new Date(now.getTime() + 30001)), true);
  assert.equal(ownerExpired({ ...job, releaseAt: null }, new Date(now.getTime() + 30001)), false);
  assert.equal(ownerExpired({ ...job, releaseAt: null }, new Date(now.getTime() + 120000)), true);
});
test('Fake clock: transfer deadline/retry grace independent of expired page and ready TTL', () => {
  const now = new Date('2026-09-30T00:00:00Z');
  const ready = {
    readyUntil: new Date(now.getTime() + 600000),
    transferDeadline: null,
    retryUntil: null,
  };
  assert.equal(assetExpired(ready, false, now), false);
  assert.equal(assetExpired(ready, true, now), true);
  const active = {
    ...ready,
    readyUntil: new Date(now.getTime() - 1),
    transferDeadline: new Date(now.getTime() + 1800000),
  };
  assert.equal(assetExpired(active, true, now), false);
  assert.equal(
    assetExpired({ ...active, retryUntil: new Date(now.getTime() - 1) }, false, now),
    true,
  );
  assert.equal(assetExpired(active, false, new Date(now.getTime() + 1800001)), true);
});
test('Managed path rejects traversal and absolute paths', () => {
  assert.throws(() => filePath('../etc/passwd'));
  assert.throws(() => filePath('/etc/passwd'));
  assert.equal(filePath('abc/media.mp4'), '/media/abc/media.mp4');
});
after(async () => {
  await queue.close();
  redis.disconnect();
  await db.$disconnect();
});
