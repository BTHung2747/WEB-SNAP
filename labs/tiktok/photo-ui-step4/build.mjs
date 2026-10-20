import { build } from '/app/node_modules/vite/dist/node/index.js';
import { copyFile, readFile, writeFile } from 'node:fs/promises';
// Old bytes only in this disposable build process, never copied onto the host source.
const before=process.argv[2]==='build-before';
await build({configFile:'/app/apps/web/vite.config.ts',configLoader:'runner',root:'/app/apps/web',build:{outDir:'/control/web',emptyOutDir:false}});
const lock=JSON.parse(await readFile('/app/package-lock.json','utf8'));
await writeFile('/control/build-result.json',JSON.stringify({status:'PASS_VITE_PRODUCTION_BUILD',sourceCalls:0,react:lock.packages['node_modules/react'].version,vite:lock.packages['node_modules/vite'].version,tailwind:lock.packages['node_modules/tailwindcss'].version},null,2));
