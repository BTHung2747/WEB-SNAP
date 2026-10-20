const fs=require('node:fs');if(process.env.P30_GUARD!=='wed-snap-ad-statistics-lab')throw Error('Guard');fs.mkdirSync('/tmp/p30',{recursive:true});let b='';process.stdin.on('data',c=>{b+=c;if(b.length>16384)throw Error('Bound')});process.stdin.on('end',()=>{JSON.parse(b);fs.writeFileSync('/tmp/p30/coordinates.json',b,{flag:'wx'})});

