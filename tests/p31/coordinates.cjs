const fs=require('node:fs');
if(process.env.P31_GUARD!=='wed-snap-ad-retention-lab')throw Error('Guard');
fs.mkdirSync('/tmp/p31',{recursive:true});let body='';
process.stdin.on('data',c=>{body+=c;if(body.length>16384)throw Error('Bound')});
process.stdin.on('end',()=>{JSON.parse(body);fs.writeFileSync('/tmp/p31/coordinates.json',body,{flag:'wx'});});
