// Internal, bounded control glue. Never return credentials in adapter/public data.
import { request } from 'node:http';
import { createHmac, randomBytes } from 'node:crypto';
import { performance } from 'node:perf_hooks';
import { AppError } from '../../../packages/shared/src/core';
const hex = (s: unknown): s is string => typeof s === 'string' && /^[a-f0-9]{64}$/.test(s);
export class ProxyProofError extends AppError {
  constructor(readonly reason: string) { super(reason === 'TIMEOUT' ? 'SOURCE_TIMEOUT' : 'CONTENT_UNAVAILABLE'); }
}
export class ProxyPhase {
  private nonce = randomBytes(32).toString('hex');
  private job: string;
  private epoch = '';
  private cap = '';
  private aborted = false;
  private controller = new AbortController();
  private constructor(private phase: string, id: string, token: string, private deadline: number, private secret: string) {
    this.job = createHmac('sha256', secret).update(JSON.stringify([id, token, phase, this.nonce])).digest('hex');
  }
  static async open(phase: string, id: string, token: string, deadline: number) {
    const secret = process.env.TIKTOK_EGRESS_CONTROL_SECRET;
    if (process.env.TIKTOK_EGRESS_POLICY_ENABLED !== '1' || !hex(secret) || !['analyze', 'prepare'].includes(phase)) throw new ProxyProofError('CONFIG');
    const handle = new ProxyPhase(phase, id, token, deadline, secret);
    const reply = await handle.post('open');
    if (reply.state !== 'OPEN' || !hex(reply.epoch) || !hex(reply.connectKey) || reply.connections !== 0) throw new ProxyProofError('OPEN');
    handle.epoch = reply.epoch; handle.cap = reply.connectKey;
    return handle;
  }
  childEnv() { return { WED_EGRESS_PHASE: this.nonce, WED_EGRESS_CAP: this.cap }; }
  interrupt() { this.aborted = true; this.controller.abort(); }
  private post(op: string, cleanup = false): Promise<any> {
    const remaining = this.deadline - performance.now();
    if (remaining <= 0 || (!cleanup && this.aborted)) return Promise.reject(new ProxyProofError('TIMEOUT'));
    const body = JSON.stringify({ op, id: this.nonce, job: this.job, phase: this.phase,
      ...(op === 'open' ? { deadline: Math.floor(Date.now() + remaining) } : { epoch: this.epoch }) });
    return new Promise((resolve, reject) => {
      let finished = false, expired = false, bytes = 0;
      const chunks: Buffer[] = [];
      const done = (error?: ProxyProofError, data?: any) => {
        if (finished) return; finished = true; clearTimeout(timer);
        if (error) reject(error); else resolve(data);
      };
      const req = request({ hostname: 'egress', port: 8888, path: '/_wed/phase', method: 'POST', agent: false,
        maxHeaderSize: 4096, signal: cleanup ? undefined : this.controller.signal,
        headers: { authorization: 'Bearer ' + this.secret, 'content-type': 'application/json', 'content-length': Buffer.byteLength(body) } }, res => {
        if (res.statusCode !== 200) { res.destroy(); req.destroy(); done(new ProxyProofError('CHANNEL')); return; }
        res.on('data', (chunk: Buffer) => {
          bytes += chunk.length;
          if (bytes > 2048) { res.destroy(); req.destroy(); done(new ProxyProofError('OVERFLOW')); }
          else chunks.push(chunk);
        });
        res.on('error', () => done(new ProxyProofError('CHANNEL')));
        res.on('aborted', () => done(new ProxyProofError('CHANNEL')));
        res.on('end', () => {
          try {
            const raw = Buffer.concat(chunks).toString('utf8'), p = JSON.parse(raw);
            const keys = ['v','id','job','phase','epoch','state','connections', ...(op === 'open' ? ['connectKey'] : [])].sort();
            if (JSON.stringify(p) !== raw || JSON.stringify(Object.keys(p).sort()) !== JSON.stringify(keys) || p.v !== 1 ||
                p.id !== this.nonce || p.job !== this.job || p.phase !== this.phase || (op !== 'open' && p.epoch !== this.epoch) ||
                !Number.isSafeInteger(p.connections) || p.connections < 0 || p.connections > (this.phase === 'analyze' ? 2 : 3) ||
                !['OPEN','PENDING','ACCEPTED','REJECTED','UNKNOWN','EXPIRED'].includes(p.state)) throw new ProxyProofError('MISMATCH');
            done(undefined, p);
          } catch { done(new ProxyProofError('MISMATCH')); }
        });
      });
      const timer = setTimeout(() => { expired = true; req.destroy(); done(new ProxyProofError('TIMEOUT')); }, Math.max(1, Math.min(cleanup ? 300 : 1000, remaining)));
      req.on('error', () => done(new ProxyProofError(expired ? 'TIMEOUT' : 'CHANNEL')));
      req.end(body);
    });
  }
  async finish(stopped: () => boolean): Promise<number> {
    let p = await this.post('seal');
    const end = Math.min(this.deadline, performance.now() + 5000);
    for (let n = 0; p.state === 'PENDING' && n < 24 && performance.now() < end; n++) {
      if (stopped()) throw new ProxyProofError('CANCELLED');
      await new Promise(r => setTimeout(r, Math.max(1, Math.min(100, end - performance.now()))));
      p = await this.post('poll');
    }
    if (p.state !== 'ACCEPTED' || p.connections < 1 || stopped() || performance.now() >= this.deadline) throw new ProxyProofError(p.state === 'PENDING' ? 'TIMEOUT' : 'REJECTED');
    const taken = await this.post('take');
    if (taken.state !== 'ACCEPTED' || taken.connections !== p.connections || stopped() || performance.now() >= this.deadline) throw new ProxyProofError('MISMATCH');
    this.cap = ''; return taken.connections;
  }
  async abort() {
    if (!this.epoch) return;
    try { await this.post('abort', true); } catch { /* Bounded expiry revokes the same phase; no fallback. */ }
    this.cap = '';
  }
}
