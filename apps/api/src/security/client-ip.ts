import type { NextFunction, Request, Response } from 'express';
import { lookup } from 'node:dns/promises';
import { isIP } from 'node:net';

/** Normalize IPv4-mapped IPv6 so one address cannot acquire two rate buckets. */
export function canonicalIp(value: string | undefined): string | null {
  if (!value || !isIP(value)) return null;
  if (isIP(value) === 4) return value;
  let normalized: string;
  try {
    normalized = new URL(`http://[${value}]/`).hostname.slice(1, -1);
  } catch {
    return null;
  }
  const mapped = /^::ffff:([a-f\d]+):([a-f\d]+)$/.exec(normalized);
  if (mapped) {
    const high = parseInt(mapped[1], 16),
      low = parseInt(mapped[2], 16);
    return `${high >> 8}.${high & 255}.${low >> 8}.${low & 255}`;
  }
  return normalized;
}

type Resolver = (host: string) => Promise<string[]>;
const resolveHost: Resolver = async (host) => {
  let timer: ReturnType<typeof setTimeout> | undefined;
  try {
    return await Promise.race([
      lookup(host, { all: true }).then((rows) => rows.map((row) => row.address)),
      new Promise<string[]>((resolve) => {
        timer = setTimeout(() => resolve([]), 1000);
        timer.unref();
      }),
    ]);
  } finally {
    if (timer) clearTimeout(timer);
  }
};

/** Trust exact configured proxy addresses, never a hop count or a whole private subnet. */
export function trustedProxyPolicy(
  hosts: string[],
  resolver: Resolver = resolveHost,
  now = Date.now,
) {
  for (const host of hosts) {
    if (!isIP(host) && !/^[a-z\d][a-z\d.-]{0,252}$/i.test(host))
      throw new Error('INVALID_TRUSTED_PROXY_HOST');
  }
  let addresses = new Set<string>();
  let expires = 0;
  let loading: Promise<Set<string>> | undefined;
  async function snapshot() {
    if (now() < expires) return addresses;
    if (!loading) {
      loading = (async () => {
        const results = await Promise.all(
          hosts.map(async (host) => {
            const literal = canonicalIp(host);
            if (literal) return [literal];
            try {
              return (await resolver(host)).map(canonicalIp).filter((ip): ip is string => !!ip);
            } catch {
              return [];
            }
          }),
        );
        addresses = new Set(results.flat());
        expires = now() + 5000;
        return addresses;
      })().finally(() => {
        loading = undefined;
      });
    }
    return loading;
  }
  return async (peer: string | undefined, forwarded: string | string[] | undefined) => {
    const socketIp = canonicalIp(peer) || 'unknown';
    const claimed = typeof forwarded === 'string' ? canonicalIp(forwarded.trim()) : null;
    // Only one hop is supported. Invalid/multi-value headers fall back to the socket.
    if (!claimed) return socketIp;
    const trusted = await snapshot();
    return trusted.has(socketIp) ? claimed : socketIp;
  };
}

const identities = new WeakMap<Request, string>();
export function clientIp(req: Request) {
  return identities.get(req) || canonicalIp(req.socket.remoteAddress) || 'unknown';
}
export function clientIdentityMiddleware(
  hosts = (process.env.TRUSTED_PROXY_HOSTS || '')
    .split(',')
    .map((h) => h.trim())
    .filter(Boolean),
) {
  const identify = trustedProxyPolicy(hosts);
  return (req: Request, _res: Response, next: NextFunction) => {
    identify(req.socket.remoteAddress, req.headers['x-forwarded-for'])
      .then((ip) => {
        identities.set(req, ip);
        next();
      })
      .catch(next);
  };
}
