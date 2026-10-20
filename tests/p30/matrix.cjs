const http=require('node:http'),fs=require('node:fs'),crypto=require('node:crypto');
if(process.env.P30_GUARD!=='wed-snap-ad-statistics-lab')throw Error('Guard');
const path=process.argv[2]==='baseline'?'/__p30/matrix?baseline=1':process.argv[2]==='generate'?'/__p30/openapi':'/__p30/matrix';
let firstSHA;
function call(){const r=http.get({hostname:'127.0.0.1',port:3000,path,agent:false},res=>{let b='';res.on('data',c=>b+=c);res.on('end',()=>{const data=JSON.parse(b);if(res.statusCode!==200||data.fail>0){console.log(b);process.exitCode=1;return;}
 if(process.argv[2]==='generate'){const sha=crypto.createHash('sha256').update(fs.readFileSync('/tmp/p30/openapi.json')).digest('hex');if(!firstSHA){firstSHA=sha;call();return;}console.log(JSON.stringify({ok:firstSHA===sha,generations:2,firstSHA,secondSHA:sha}));if(firstSHA!==sha)process.exitCode=1;}else console.log(b);
});});r.setTimeout(60000,()=>r.destroy(Error('Deadline')));r.on('error',()=>{console.error('Matrix transport failure');process.exitCode=1});}call();
