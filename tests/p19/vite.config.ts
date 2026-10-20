import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { createHash } from 'node:crypto';
import { readFileSync, readlinkSync } from 'node:fs';
export default defineConfig({
  root: '/app/tests/p19', cacheDir: '/tmp/p19-vite', html: { cspNonce: 'p19-local-fixture' }, plugins: [react(), {
    name: 'guarded-ui-fixture-evidence',
    configureServer(server) {
      if (process.env.P19_UI_GUARD !== 'wed-snap-ui-lab' || process.env.DATABASE_URL || process.env.REDIS_URL)
        throw new Error('Refuse UI lab with data services');
      server.middlewares.use((req, res, next) => {
        if (req.url === '/api/v1/downloads/p20-fixture-ticket' && req.method === 'GET') {
          const bytes = Buffer.from('P20_NATIVE_DOWNLOAD_FIXTURE\n');
          res.setHeader('Content-Type', 'application/octet-stream');
          res.setHeader('Content-Disposition', 'attachment; filename="p20-fixture.txt"');
          res.setHeader('Content-Length', bytes.length);
          res.setHeader('Cache-Control', 'no-store');
          console.log('P20_NATIVE_DOWNLOAD ' + JSON.stringify({ utc:new Date().toISOString(), method:req.method, path:req.url, status:200, bytes:bytes.length, sha256:createHash('sha256').update(bytes).digest('hex'), fixture:'Vite deterministic text bytes; not backend/lease/media/platform' }));
          res.end(bytes); return;
        }
        if (req.url === '/__p19/environment') {
          const files = ['pages/Home.tsx', 'components/Advertising.tsx', 'hooks/useJobLifecycle.ts', 'hooks/useDownloadLink.ts', 'lib/api.ts', 'types.ts'];
          const hashes = Object.fromEntries(files.map(f => [f, createHash('sha256').update(readFileSync('/app/apps/web/src/' + f)).digest('hex')]));
          res.setHeader('Content-Type', 'application/json');
          res.end(JSON.stringify({ guard: process.env.P19_UI_GUARD, expectedHomeSha: process.env.P19_SOURCE_SHA,
            hashes, node: process.version, pid: process.pid, namespace: readlinkSync('/proc/self/ns/pid'),
            API: 'browser fetch fixture only; no backend/DB/Redis', network: 'dedicated Docker frontend bridge, host loopback port5175; CSP self only' })); return;
        }
        if (req.url === '/__p19/record' && req.method === 'POST') {
          let body = ''; req.on('data', chunk => { body += chunk; if (body.length > 262144) req.destroy(); });
          req.on('end', () => { try { console.log('P19_RAW ' + JSON.stringify(JSON.parse(body))); res.end('OK'); }
            catch { res.statusCode = 400; res.end('Invalid test record'); } }); return;
        }
        if (req.url?.startsWith('/api/')) { res.statusCode = 503; res.end('No real API in P19 lab'); return; }
        next();
      });
    },
  }],
  server: { host: '0.0.0.0', port: 5175, strictPort: true, fs: { allow: ['/app/apps/web', '/app/tests/p19', '/app/tests/p20', '/app/node_modules'] },
    watch: { usePolling: true, interval: 1000 }, headers: {
      'Content-Security-Policy': "default-src 'self'; script-src 'self' 'nonce-p19-local-fixture'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self' ws://localhost:5175; base-uri 'none'; form-action 'self'; frame-ancestors 'none'",
    } },
});
