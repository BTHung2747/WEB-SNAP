const fs=require('node:fs');
if(process.env.P35_GUARD!=='wed-snap-worker-scheduler-lab')throw Error('Ownlab35 only');
for(const path of ['/sys/fs/cgroup/pids.current','/sys/fs/cgroup/pids.max','/sys/fs/cgroup/pids.events','/sys/fs/cgroup/memory.current','/sys/fs/cgroup/memory.peak','/sys/fs/cgroup/memory.events']){
 console.log(JSON.stringify({utc:new Date().toISOString(),path,value:fs.readFileSync(path,'utf8')}));
}
