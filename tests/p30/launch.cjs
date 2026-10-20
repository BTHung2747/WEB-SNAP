const {spawn}=require('node:child_process');const fs=require('node:fs');
if(process.env.P30_GUARD!=='wed-snap-ad-statistics-lab')throw Error('Guard');
fs.mkdirSync('/tmp/p30',{recursive:true});if(fs.existsSync('/tmp/p30/pid'))throw Error('Existing server');
const log=fs.openSync('/tmp/p30/server.log','wx');
const c=spawn('/app/node_modules/.bin/tsx',['--tsconfig','tests/p30/tsconfig.server.json','tests/p30/server.ts'],{cwd:'/app',detached:false,stdio:['ignore',log,log]});
fs.writeFileSync('/tmp/p30/pid',String(c.pid));c.unref();

