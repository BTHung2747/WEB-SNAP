'use strict';
// Owned offline fixture: no HTTP/DNS/socket/library/service or arbitrary eval.
const fs=require('node:fs'),{spawn}=require('node:child_process');
switch(process.argv[2]){
 case 'pass':process.stdout.write('{"status":"PASS"}\n');break;
 case 'exit20':process.stdout.write('{"status":"PASS"}\n');process.exitCode=20;break;
 case 'stderr':process.stderr.write(process.argv[3]+'\nOFFLINE_TEST_ONLY_SECRET https://offline.invalid/path/TOKEN_PATH?q=TOKEN_QUERY\n');process.stdout.write('{"status":"PASS"}\n');break;
 case 'invalid':process.stdout.write('not-json');break;
 case 'missing':break;
 case 'late':setTimeout(()=>process.stdout.write('{"status":"PASS"}\n'),4500);break;
 case 'flood':{const b=Buffer.alloc(4096,65);const next=()=>{process.stdout.write(b);setImmediate(next);};next();setTimeout(()=>process.exit(0),4500);break;}
 case 'tree':{const c=spawn(process.execPath,['--max-old-space-size=32',__filename,'idle'],{stdio:'ignore'});process.stdout.write(JSON.stringify({childPID:c.pid})+'\n');setTimeout(()=>{},4500);break;}
 case 'idle':setTimeout(()=>{},4500);break;
 case 'orphan':{const c=spawn(process.execPath,['--max-old-space-size=32',__filename,'expires'],{detached:true,windowsHide:true,stdio:'ignore'});c.unref();process.stdout.write(JSON.stringify({childPID:c.pid})+'\n');break;}
 case 'expires':setTimeout(()=>{},3500);break;
 case 'latepipe':{const c=spawn(process.execPath,['--max-old-space-size=32',__filename,'expires'],{detached:true,windowsHide:true,stdio:['ignore',process.stdout,process.stderr]});c.unref();process.stdout.write(JSON.stringify({childPID:c.pid})+'\n');break;}
 case 'argv':console.log(JSON.stringify({args:process.argv.slice(3),cwd:process.cwd(),env:process.env.WED_NATIVE_OFFLINE_TEST}));break;
 case 'stdin':{let n=0;process.stdin.on('data',d=>n+=d.length);process.stdin.on('end',()=>console.log(JSON.stringify({eof:true,n})));break;}
 case 'cross':process.stdout.write('O'.repeat(700));process.stderr.write('E'.repeat(700));setTimeout(()=>{},4500);break;
 case 'pipeclosed':fs.closeSync(1);fs.closeSync(2);setTimeout(()=>{},4500);break;
 case 'grandparent':{const c=spawn(process.execPath,['--max-old-space-size=32',__filename,'middle'],{detached:true,windowsHide:true,stdio:['ignore','pipe','ignore']});c.unref();c.stdout.once('data',d=>process.stdout.write(d,()=>process.exit(0)));setTimeout(()=>process.exit(78),4500);break;}
 case 'middle':{const c=spawn(process.execPath,['--max-old-space-size=32',__filename,'expires'],{detached:true,windowsHide:true,stdio:'ignore'});c.unref();console.log(JSON.stringify({grandchildPID:c.pid}));setTimeout(()=>{},4500);break;}
 case 'natural':{const c=spawn(process.execPath,['--max-old-space-size=32',__filename,'brief'],{windowsHide:true,stdio:'ignore'});c.on('exit',()=>console.log('{"status":"PASS"}'));break;}
 case 'brief':setTimeout(()=>{},120);break;
 case 'crashhold':{const c=spawn(process.execPath,['--max-old-space-size=32',__filename,'expires'],{detached:true,windowsHide:true,stdio:'ignore'});c.unref();console.log(process.pid+':'+c.pid);setTimeout(()=>{},4500);break;}
 default:process.exitCode=78;
}
