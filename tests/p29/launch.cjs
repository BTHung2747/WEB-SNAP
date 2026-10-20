const {spawn}=require('node:child_process');const fs=require('node:fs');
if(process.env.P29_GUARD!=='wed-snap-admin-browser-lab')throw Error('Guard');
fs.mkdirSync('/tmp/p29',{recursive:true});if(fs.existsSync('/tmp/p29/pid'))throw Error('Existing server');
const log=fs.openSync('/tmp/p29/server.log','wx');
const c=spawn('/app/node_modules/.bin/tsx',['--tsconfig','tests/p29/tsconfig.server.json','tests/p29/server.ts'],{cwd:'/app',detached:false,stdio:['ignore',log,log]});
fs.writeFileSync('/tmp/p29/pid',String(c.pid));c.unref();
