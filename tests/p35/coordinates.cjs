const fs=require('node:fs');
if(process.env.P35_GUARD!=='wed-snap-worker-scheduler-lab')throw Error('Guard');
fs.mkdirSync('/tmp/p35',{recursive:true});let body='';
process.stdin.on('data',c=>{body+=c;if(body.length>16384)throw Error('Bound')});
process.stdin.on('end',()=>{JSON.parse(body);fs.writeFileSync('/tmp/p35/coordinates.json',body,{flag:'wx'});});


