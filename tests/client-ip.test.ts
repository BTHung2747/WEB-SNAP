import { test } from 'node:test';
import assert from 'node:assert/strict';
import { canonicalIp, trustedProxyPolicy } from '../apps/api/src/security/client-ip';

test('IP identity canonicalizes IPv4, mapped IPv6 and compressed IPv6', () => {
  assert.equal(canonicalIp('192.0.2.1'), '192.0.2.1');
  assert.equal(canonicalIp('::ffff:192.0.2.1'), '192.0.2.1');
  assert.equal(canonicalIp('::ffff:c000:201'), '192.0.2.1');
  assert.equal(canonicalIp('2001:0db8:0000:0000:0000:0000:0000:0001'), '2001:db8::1');
  for (const value of [
    'localhost',
    '192.0.2.1,192.0.2.2',
    '192.0.2.1:1234',
    '[::1]',
    'fe80::1%eth0',
  ])
    assert.equal(canonicalIp(value), null);
});
test('Only exact configured proxy peer may forward a single IP', async () => {
  const identify = trustedProxyPolicy(['web'], async () => ['172.20.0.5']);
  assert.equal(await identify('::ffff:172.20.0.5', '192.0.2.1'), '192.0.2.1');
  assert.equal(await identify('172.20.0.6', '192.0.2.1'), '172.20.0.6');
  assert.equal(await identify('127.0.0.1', '192.0.2.1'), '127.0.0.1');
});
test('Multi-hop, repeated and malformed forwarding values fall back to socket IP', async () => {
  const identify = trustedProxyPolicy(['172.20.0.5']);
  for (const value of ['192.0.2.1, 192.0.2.2', 'bad', ['192.0.2.1', '192.0.2.2'], undefined])
    assert.equal(await identify('172.20.0.5', value), '172.20.0.5');
});
test('Empty trust configuration and DNS failure never accept forwarded IP', async () => {
  assert.equal(await trustedProxyPolicy([])('172.20.0.5', '192.0.2.1'), '172.20.0.5');
  const identify = trustedProxyPolicy(['web'], async () => {
    throw new Error('DNS unavailable');
  });
  assert.equal(await identify('172.20.0.5', '192.0.2.1'), '172.20.0.5');
  assert.throws(() => trustedProxyPolicy(['172.20.0.0/16']));
});
test('DNS cache coalesces lookup, refreshes exact peer and discards stale trust on failure', async () => {
  let now = 1000,
    calls = 0,
    result: string[] | null = ['172.20.0.5'];
  const identify = trustedProxyPolicy(
    ['web'],
    async () => {
      calls++;
      if (!result) throw new Error('DNS unavailable');
      return result;
    },
    () => now,
  );
  await Promise.all([identify('172.20.0.5', '192.0.2.1'), identify('172.20.0.5', '192.0.2.2')]);
  assert.equal(calls, 1);
  now += 5001;
  result = ['172.20.0.7'];
  assert.equal(await identify('172.20.0.5', '192.0.2.1'), '172.20.0.5');
  assert.equal(await identify('172.20.0.7', '192.0.2.1'), '192.0.2.1');
  now += 5001;
  result = null;
  assert.equal(await identify('172.20.0.7', '192.0.2.1'), '172.20.0.7');
});
