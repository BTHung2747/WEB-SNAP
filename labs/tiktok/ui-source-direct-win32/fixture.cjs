'use strict';
// Fixed harmless offline fixture. Every long-lived process self-expires <5s.
const {spawn}=require('node:child_process');
const child=(mode,stdio='ignore')=>{const p=spawn(process.execPath,['--max-old-space-size=32',__filename,mode],{detached:true,windowsHide:true,stdio});p.unref();return p;};
switch(process.argv[2]){
 case 'pass':console.log('{"status":"PASS"}');break;
 case 'exit20':console.log('{"status":"PASS"}');process.exitCode=20;break;
 case 'argv':console.log(JSON.stringify(process.argv.slice(3)));break;
 case 'stderr':process.stderr.write('OFFLINE_TEST_ONLY_SECRET https://offline.invalid/TOKEN_PATH?q=TOKEN_QUERY');console.log('{"status":"PASS"}');break;
 case 'orphan':{const c=child('expires');console.log(JSON.stringify({child:c.pid}));break;}
 case 'grandparent':{const c=child('middle',['ignore','pipe','ignore']);c.stdout.once('data',d=>{console.log(JSON.stringify({child:c.pid}));process.stdout.write(d,()=>process.exit(0));});setTimeout(()=>process.exit(78),4500);break;}
 case 'middle':{const c=child('expires');console.log(JSON.stringify({grandchild:c.pid}));setTimeout(()=>{},4500);break;}
 case 'latepipe':{const c=child('latewrite',['ignore',process.stdout,process.stderr]);console.log(JSON.stringify({child:c.pid}));break;}
 case 'latewrite':setTimeout(()=>console.log('OFFLINE_LATE_OUTPUT'),1500);setTimeout(()=>{},4500);break;
 case 'hold':{const c=child('expires');console.log(JSON.stringify({root:process.pid,child:c.pid}));setTimeout(()=>{},4500);break;}
 case 'expires':case 'timeout':setTimeout(()=>{},4500);break;
 case 'flood':{const b=Buffer.alloc(4096,65);const pump=()=>{process.stdout.write(b);setImmediate(pump);};pump();setTimeout(()=>process.exit(0),4500);break;}
 default:process.exitCode=78;
}
