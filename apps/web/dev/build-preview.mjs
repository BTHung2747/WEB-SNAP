// Frontend-only build with the repository's cached Vite dependencies.
import { build } from '/app/node_modules/vite/dist/node/index.js';
await build({ configFile: '/app/apps/web/vite.config.ts', configLoader: 'runner', root: '/app/apps/web', build: { outDir: '/output/web', emptyOutDir: false } });
