'use strict';
const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto'),{createRequire}=require('node:module'),{spawnSync}=require('node:child_process'),assert=require('node:assert/strict');
const MODE=process.argv[2],OUT='/control',BASE='/app/apps/media/src/tiktok',lock=JSON.parse(fs.readFileSync(BASE+'/package-lock.json'));
const names=['set-cookie-parser','@imput/psl','url-pattern','punycode','undici'];
const hash=p=>crypto.createHash('sha256').update(fs.readFileSync(p)).digest('hex');
function classify(bytes){const text=bytes.toString();const allowed=['ERR_MODULE_NOT_FOUND','ERR_PACKAGE_PATH_NOT_EXPORTED','ERR_REQUIRE_ESM','ERR_UNKNOWN_FILE_EXTENSION'];return{code:allowed.find(c=>text.includes(c))||'UNKNOWN',package:names.find(n=>text.includes("'"+n+"'")||text.includes('"'+n+'"'))||'UNKNOWN'};}
function child(argv,input){
 const begin=performance.now(),r=spawnSync(process.execPath,argv,{input,timeout:5000,maxBuffer:131072,env:{...process.env,NODE_OPTIONS:'--max-old-space-size=64'}});
 return {r,receipt:{actualExit:r.status,actualSignal:r.signal,timedOut:r.error?.code==='ETIMEDOUT',stdoutBytes:r.stdout?.length||0,stderrBytes:r.stderr?.length||0,elapsedMs:Math.round(performance.now()-begin),diagnostic:classify(r.stderr||Buffer.alloc(0))}};
}
async function main(){
 assert.equal(process.versions.node,'22.22.3');assert.ok(['masked','overlay'].includes(MODE));
 const requireHere=createRequire(BASE+'/photo_picker.mjs');const packages=[];
 for(const name of names){
  try{const resolved=requireHere.resolve(name==='punycode'?'punycode/':name);let dir=path.dirname(resolved),found;
   for(let i=0;i<12;i++){const f=path.join(dir,'package.json');if(fs.existsSync(f)){const pkg=JSON.parse(fs.readFileSync(f));if(pkg.name===name){found={name,version:pkg.version,entry:resolved,packageSHA256:hash(f),expectedVersion:lock.packages['node_modules/'+name].version};break;}}const up=path.dirname(dir);if(up===dir)break;dir=up;}
   assert.ok(found);assert.equal(found.version,found.expectedVersion);packages.push({...found,status:'VISIBLE_VERSION_MATCH'});
  }catch(error){packages.push({name,status:'MISSING_OR_MISMATCH',code:['MODULE_NOT_FOUND','ERR_PACKAGE_PATH_NOT_EXPORTED'].includes(error.code)?error.code:'UNKNOWN'});}
 }
 const imported=child(['--input-type=module','--eval',`import('file://${BASE}/vendor/tiktok.js').then(()=>process.stdout.write('IMPORT_OK'))`]);
 const fixture=spawnSync('python3',['-I','/probe/fixture-body.py'],{timeout:3000,maxBuffer:8192});assert.equal(fixture.status,0);assert.ok(fixture.stdout.length<=8192);
 const picker=child([BASE+'/photo_picker.mjs','7000000000000000001'],fixture.stdout);
 let packet={status:'NOT_PARSED'};if(picker.r.status===0){const value=JSON.parse(picker.r.stdout);assert.equal(value.id,'7000000000000000001');assert.equal(value.type,'photo');assert.equal(value.images.length,5);assert.ok(value.images.every((x,i)=>x.index===i+1&&x.width===64&&x.height===64));packet={status:'PASS_SYNTHETIC_PACKET',id:value.id,type:value.type,imageCount:value.images.length};}
 const pins=JSON.parse(fs.readFileSync('/control/source-pins.json'));assert.ok(pins.length);for(const p of pins)assert.equal(hash(p.target),p.sha256);
 const result={mode:MODE,node:process.versions.node,packages,import:imported.receipt,picker:picker.receipt,packet,currentSourceHashesChecked:pins.length,lockSHA256:hash(BASE+'/package-lock.json'),sourceCalls:0,network:'none'};
 fs.writeFileSync(OUT+'/dependency-'+MODE+'.json',JSON.stringify(result,null,2),{flag:'wx'});
 if(MODE==='masked'){assert.notEqual(imported.r.status,0);assert.equal(imported.receipt.diagnostic.code,'ERR_MODULE_NOT_FOUND');assert.notEqual(picker.r.status,0);assert.equal(picker.receipt.diagnostic.code,'ERR_MODULE_NOT_FOUND');}
 else{assert.ok(packages.every(p=>p.status==='VISIBLE_VERSION_MATCH'));assert.equal(imported.r.status,0);assert.equal(picker.r.status,0);assert.equal(packet.status,'PASS_SYNTHETIC_PACKET');}
 console.log(JSON.stringify({status:'PASS_PROBE_EXPECTATIONS_ONLY',mode:MODE,importExit:imported.r.status,pickerExit:picker.r.status}));
}
main().catch(()=>{console.log('{"status":"FAIL_PROBE_EXPECTATIONS"}');process.exitCode=1;});
