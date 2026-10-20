const fs=require('node:fs');if(process.env.P30_GUARD!=='wed-snap-ad-statistics-lab')throw Error('Guard');
console.log('P30_RUNTIME '+JSON.stringify({utc:new Date().toISOString(),node:process.version,namespace:fs.readlinkSync('/proc/self/ns/pid'),versions:Object.fromEntries(['react','react-dom','vite','typescript','tailwindcss','@nestjs/core','@prisma/client','ioredis','bullmq'].map(p=>[p,JSON.parse(fs.readFileSync('/app/node_modules/'+p+'/package.json','utf8')).version])),sourceRO:true,privateTmpfsClient:true,businessFixtures:false}));

