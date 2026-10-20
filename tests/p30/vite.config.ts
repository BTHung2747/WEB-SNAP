import {defineConfig} from 'vite';
import react from '@vitejs/plugin-react';
export default defineConfig({root:'/app/tests/p30',cacheDir:'/tmp/p30-vite',plugins:[react()],server:{host:'0.0.0.0',port:5181,strictPort:true,fs:{allow:['/app/apps/web','/app/tests/p30','/app/node_modules']},watch:{usePolling:true,interval:1000},proxy:{'/api':{target:'http://api:3000',changeOrigin:false},'/__p30':{target:'http://api:3000',changeOrigin:false}},headers:{'Content-Security-Policy':"default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self' ws://localhost:5181; base-uri 'none'; form-action 'self'; frame-ancestors 'none'"}}});

