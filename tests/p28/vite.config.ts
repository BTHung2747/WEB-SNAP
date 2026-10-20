import {defineConfig} from 'vite';
import react from '@vitejs/plugin-react';
import {createHash} from 'node:crypto';
import {readFileSync,readlinkSync} from 'node:fs';
const files=['pages/Admin.tsx','lib/api.ts','styles/admin.css','style.css','styles/responsive.css','styles/layout.css','types.ts','lib/platforms.ts'];
export default defineConfig({root:'/app/tests/p28',cacheDir:'/tmp/p28-vite',html:{cspNonce:'p28-local-fixture'},plugins:[react(),{
  name:'p28-guarded-fixture-records',
  configureServer(server){
    if(process.env.P28_GUARD!=='wed-snap-admin-ui-lab'||process.env.DATABASE_URL||process.env.REDIS_URL||process.env.ADMIN_SESSION_SECRET)throw Error('UI isolation guard');
    server.middlewares.use((req,res,next)=>{
      if(req.url==='/__p28/environment'){
        const hashes=Object.fromEntries(files.map(p=>[p,createHash('sha256').update(readFileSync('/app/apps/web/src/'+p)).digest('hex')]));
        res.setHeader('Content-Type','application/json');res.setHeader('Cache-Control','no-store');
        res.end(JSON.stringify({guard:process.env.P28_GUARD,sourceSha:process.env.P28_SOURCE_SHA,hashes,node:process.version,pid:process.pid,namespace:readlinkSync('/proc/self/ns/pid'),
          versions:Object.fromEntries(['react','react-dom','vite','typescript','tailwindcss'].map(p=>[p,JSON.parse(readFileSync('/app/node_modules/'+p+'/package.json','utf8')).version])),
          scope:'production Admin/api/styles with browser API transport fixture only; no DB/Redis/main/media; dedicated frontend bridge, CSP self/fetch fence'}));return;
      }
      if(req.url==='/__p28/record'&&req.method==='POST'){
        let body='';req.on('data',c=>{body+=c;if(Buffer.byteLength(body)>262144)req.destroy();});
        req.on('end',()=>{try{console.log('P28_RAW '+JSON.stringify(JSON.parse(body)));res.end('OK');}catch{res.statusCode=400;res.end('Invalid fixture record');}});return;
      }
      if(req.url?.startsWith('/api/')){console.log('P28_SERVER_API_REFUSED '+JSON.stringify({method:req.method,path:req.url}));res.statusCode=503;res.end('No live API in lab28');return;}
      next();
    });
  }
}],server:{host:'0.0.0.0',port:5177,strictPort:true,fs:{allow:['/app/apps/web','/app/tests/p28','/app/node_modules']},watch:{usePolling:true,interval:1000},headers:{
  'Content-Security-Policy':"default-src 'self'; script-src 'self' 'nonce-p28-local-fixture'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self' ws://localhost:5177; base-uri 'none'; form-action 'self'; frame-ancestors 'none'",
}}});
