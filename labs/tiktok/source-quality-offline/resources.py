"""Read only this container cgroup usage; no host-wide performance claims."""
import json,pathlib,time
root=pathlib.Path('/sys/fs/cgroup');result={'utcEpoch':time.time(),'scope':'own cgroup v2'}
for name in ('memory.peak','memory.max','cpu.stat','cpu.max','pids.peak'):
    try:result[name]=(root/name).read_text().strip()
    except OSError:result[name]='UNKNOWN'
pathlib.Path('/out/resources.json').write_text(json.dumps(result,indent=2))
