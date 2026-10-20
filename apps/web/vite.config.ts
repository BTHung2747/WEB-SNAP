import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { randomBytes } from 'node:crypto';
const nonce = randomBytes(16).toString('base64');
export default defineConfig({
  html: { cspNonce: nonce },
  cacheDir: '/tmp/node_modules/.vite',
  plugins: [react()],
  server: {
    host: '0.0.0.0',
    port: 5173,
    strictPort: true,
    watch: { usePolling: true, interval: 1000 },
    proxy: {
      '/api': {
        target: 'http://api:3000',
        changeOrigin: false,
        configure(proxy) {
          proxy.on('proxyReq', (outgoing, incoming) => {
            for (const name of [
              'forwarded',
              'x-forwarded-for',
              'x-forwarded-host',
              'x-forwarded-proto',
              'x-real-ip',
            ])
              outgoing.removeHeader(name);
            if (incoming.socket.remoteAddress)
              outgoing.setHeader('x-forwarded-for', incoming.socket.remoteAddress);
          });
        },
      },
    },
    headers: {
      'X-Content-Type-Options': 'nosniff',
      'Referrer-Policy': 'no-referrer',
      'Content-Security-Policy': `default-src 'self'; script-src 'self' 'nonce-${nonce}'; style-src 'self' 'unsafe-inline'; img-src 'self' https: data:; connect-src 'self' ws://localhost:5173 ws://127.0.0.1:5173 ws://localhost:5174; frame-ancestors 'none'; base-uri 'self'; form-action 'self'`,
    },
  },
});
