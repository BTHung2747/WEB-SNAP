const fs=require('node:fs');
if(process.env.P34_GUARD!=='wed-snap-worker-metrics-retention-lab')throw Error('Guard');
fs.mkdirSync('/tmp/p34',{recursive:true});let body='';
process.stdin.on('data',c=>{body+=c;if(body.length>16384)throw Error('Bound')});
process.stdin.on('end',()=>{JSON.parse(body);fs.writeFileSync('/tmp/p34/coordinates.json',body,{flag:'wx'});});

