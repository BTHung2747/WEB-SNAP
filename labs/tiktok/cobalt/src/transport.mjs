// WED SNAP integration under AGPL-3.0: transport remains Undici, not a custom HTTP client.
import { fetch as undiciFetch, ProxyAgent } from 'undici';
import { Readable } from 'node:stream';
import { createHash } from 'node:crypto';
import { classifyHTML } from './classify.mjs';
import { createStages } from './stages.mjs';
export const RESPONSE_CAP = 8 * 1024 * 1024, AGG_CAP = 16 * 1024 * 1024;
export function safe(value) {
  return String(value).replace(/https?:\/\/[^\s'"<>]+/gi, '[url-redacted]')
    .replace(/\b(cookie|set-cookie|authorization|proxy-authorization)\s*:[^\r\n]*/gi, '$1: [redacted]')
    .replace(/\b(msToken|token|signature|_signature|x-bogus|sessionid|secret|password)=[^\s&'";]+/gi, '$1=[redacted]');
}
function validate(url) {
  const u = new URL(url);
  if (u.protocol !== 'https:' || (u.port && u.port !== '443') || u.username || u.password) throw new Error('INVALID_HTTPS_URL');
  return u;
}
async function ready(stream) {
  if (stream.readableEnded) return;
  await new Promise((resolve, reject) => {
    const cleanup = () => { stream.off('readable', ok); stream.off('end', ok); stream.off('error', fail); };
    const ok = () => { cleanup(); resolve(); }; const fail = error => { cleanup(); reject(error); };
    stream.once('readable', ok); stream.once('end', ok); stream.once('error', fail);
  });
}
export async function boundedText(body, budget, row, stages=null) {
  stages?.readStart();
  const stream = Readable.fromWeb(body, { highWaterMark: 16384 });
  const chunks = []; let n = 0;
  try {
    while (!stream.readableEnded) {
      const remaining = Math.min(budget.responseCap - n, budget.aggregateCap - budget.total);
      // Drain a short available chunk instead of waiting for a full requested block.
      // Otherwise a readable-but-short network body can repeatedly resolve 'readable' and starve timers.
      const available = stream.readableLength || 16384;
      const want = Math.min(16384, remaining + 1, available);
      if (want <= 0) throw new Error('LIMIT_EXCEEDED');
      const data = stream.read(want);
      if (data === null) { if (stream.readableEnded) break; await ready(stream); await new Promise(resolve => setImmediate(resolve)); continue; }
      n += data.length; budget.total += data.length; row.decodedBytes = n;
      stages?.firstDecoded();
      if (n > budget.responseCap || budget.total > budget.aggregateCap) throw new Error('LIMIT_EXCEEDED');
      chunks.push(data);
    }
    stages?.bodyComplete(n);
    const buffer = Buffer.concat(chunks, n), text = buffer.toString('utf8');
    row.decodedBodySHA256 = createHash('sha256').update(buffer).digest('hex');
    row.markers = { rehydration: text.includes('__UNIVERSAL_DATA_FOR_REHYDRATION__'), maintenance: /site maintenance/i.test(text),
      captcha: /id=["'](?:captcha|verify-center)/i.test(text) };
    if(row.headers?.['content-type']?.toLowerCase().includes('text/html')) row.classification = classifyHTML(text);
    return text;
  } catch(error){stages?.failed(error);throw error} finally { stream.destroy(); }
}
export function createTransport({ report, signal, dispatcher, fetchImpl = undiciFetch,
  responseCap = RESPONSE_CAP, aggregateCap = AGG_CAP, stages, onStageUpdate }) {
  const observed=stages||createStages({report,onUpdate:onStageUpdate});
  const ownAgent = dispatcher ? null : new ProxyAgent({ uri: 'http://egress:8888', requestTls: { rejectUnauthorized: true }, proxyTls: { rejectUnauthorized: true },clientFactory:observed.clientFactory,factory:observed.originFactory });
  const agent = dispatcher || ownAgent;
  const budget = { responseCap, aggregateCap, total: 0 };
  async function fetchControlled(input, options = {}) {
    let url = validate(input).href; let headers = { ...options.headers }; let redirects = 0;
    for (;;) {
      const row = { requestedURL: safe(url), method: options.method || 'GET', decodedBytes: 0 };
      report.requests.push(row);
      const hop=observed.begin(url);
      let response;
      try {
        response = await fetchImpl(url, { ...options, headers, signal, dispatcher: agent, redirect: 'manual' });
        hop.headers();
        row.status = response.status; row.finalURL = safe(response.url || url);
        row.headers = Object.fromEntries(['content-type', 'content-encoding', 'content-length'].map(k => [k, safe(response.headers.get(k) || '')]));
        if(response.headers.get('location')) row.headers.location = safe(new URL(response.headers.get('location'), url).href);
        if ([301,302,303,307,308].includes(response.status) && options.redirect !== 'manual') {
          // Drain through the same bounded reader; every redirect uses the same proxy and budget.
          const text = await boundedText(response.body, budget, row, hop); void text;
          if (++redirects > 5) throw new Error('REDIRECT_LIMIT');
          const next = validate(new URL(response.headers.get('location'), url)).href;
          if (new URL(next).origin !== new URL(url).origin) { delete headers.cookie; delete headers.Cookie; delete headers.authorization; }
          url = next; continue;
        }
        return { status: response.status, headers: response.headers, url: response.url || url,
          text: () => boundedText(response.body, budget, row, hop) };
      } catch (error) { hop.failed(error);row.error = safe(error.message); if(response?.body) await response.body.cancel().catch(() => {}); throw error; }
    }
  }
  return { fetch: fetchControlled, budget, close: async () => { try{if(ownAgent) await ownAgent.destroy()}finally{observed.close()} } };
}
