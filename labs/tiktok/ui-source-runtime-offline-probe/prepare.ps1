. (Join-Path $PSScriptRoot 'common.ps1')
if(Test-Path (Join-Path $script:Root 'plan.json')){throw 'FRESH_PLAN_REQUIRED'}
No-Overrides
# Keep POSIX probe files LF, before hashing; never normalize baseline source.
foreach($f in Get-ChildItem $PSScriptRoot -File){if($f.Extension -cin @('.sh','.py','.ts','.cjs')){$text=[IO.File]::ReadAllText($f.FullName);if($text.Contains("`r")){[IO.File]::WriteAllText($f.FullName,$text.Replace("`r`n","`n"),[Text.UTF8Encoding]::new($false))}}}
Save (Join-Path $script:Root 'frozen-before.json') (Frozen)
. (Join-Path (Get-Location).Path 'labs/tiktok/ui-source-prelaunch/wiring.ps1')
$base=Get-PrelaunchPlan;$run=[Guid]::NewGuid().ToString('N')
$roles=@();New-Item -ItemType Directory -Path (Join-Path $script:Root 'data')|Out-Null
foreach($role in $base.resources.roles){
 $name=$role.role;$dir=Join-Path $script:Root $name;New-Item -ItemType Directory -Path $dir|Out-Null
 $mounts=@(foreach($m in $base.mounts|Where-Object roles -Contains $name){@{source=(Resolve-Path $m.source).Path;target=$m.target;sha256=(Get-FileHash $m.source).Hash.ToLowerInvariant();kind='SOURCE_PRELAUNCH_LEAF'}})
 $files=@('guard.sh','one.sh','sentinel.txt')+$(switch($name){app{@('media.py','app.ts')}proxy{@('proxy.py')}gateway{@('gateway.cjs')}default{@()}})
 foreach($file in $files){$path=(Resolve-Path (Join-Path $PSScriptRoot $file)).Path;$mounts+=@{source=$path;target=('/probe/'+$file);sha256=(Get-FileHash $path).Hash.ToLowerInvariant();kind='SYNTHETIC_OFFLINE_PROBE'}}
 $tsv=Join-Path $script:Root ('data/'+$name+'.tsv');$sha=Join-Path $script:Root ('data/'+$name+'.sha256')
 [IO.File]::WriteAllText($tsv,(($mounts|ForEach-Object{$_.sha256+"`t"+$_.target}) -join "`n")+"`n",[Text.UTF8Encoding]::new($false))
 [IO.File]::WriteAllText($sha,(($mounts|ForEach-Object{$_.sha256+'  '+$_.target}) -join "`n")+"`n",[Text.UTF8Encoding]::new($false))
 $count=$mounts.Count
 $mounts+=@(@{source=$tsv;target='/probe/expected.tsv';sha256=(Get-FileHash $tsv).Hash.ToLowerInvariant();kind='SYNTHETIC_HASH_PROJECTION'},@{source=$sha;target='/probe/expected.sha256';sha256=(Get-FileHash $sha).Hash.ToLowerInvariant();kind='SYNTHETIC_HASH_PROJECTION'})
 $tmp=switch($name){app{@('/tmp:size=32m,mode=1777,nosuid','/media:size=64m,uid=1000,gid=1000,nosuid,noexec','/app/node_modules/.prisma:size=64m,uid=1000,gid=1000,nosuid,exec')}proxy{@('/tmp:size=32m,mode=1777,nosuid')}gateway{@('/tmp:size=8m,mode=1777,nosuid')}postgres{@('/var/lib/postgresql/data:size=128m,uid=999,gid=999,nosuid','/var/run/postgresql:size=8m,uid=999,gid=999,nosuid','/tmp:size=8m,mode=1777,uid=999,gid=999,nosuid')}redis{@('/data:size=8m,uid=1000,gid=1000,nosuid','/tmp:size=8m,mode=1777,nosuid')}}
 # Redis source plan has no /tmp override: keep its writable probe sentinel in
 # the source-plan /data tmpfs by env below, not an added tmpfs policy.
 if($name -ceq 'redis'){$tmp=@('/data:size=8m,uid=1000,gid=1000,nosuid')}
 $envs=@('PROBE_OFFLINE_ONLY=1','STEP5_EXECUTE_SOURCE=0','TIKTOK_PHOTO_ENABLED=0','TIKTOK_ADAPTER_ENABLED=0','TIKTOK_EGRESS_POLICY_ENABLED=0','VERIFIED_PLATFORMS=','PYTHONDONTWRITEBYTECODE=1',('PROBE_UID='+$role.user),('PROBE_MEM='+($role.memoryMiB*1MB)),('PROBE_PIDS='+$role.pids),('PROBE_CPU='+$role.cpu.ToString([Globalization.CultureInfo]::InvariantCulture)),('PROBE_MAP_COUNT='+$count),('PROBE_TMP='+$(if($name -ceq 'redis'){'/data'}else{'/tmp'})))
 if($name -cin @('app','gateway')){$envs+=('NODE_OPTIONS=--max-old-space-size='+$(if($name -ceq 'app'){128}else{64}))}
 if($name -ceq 'app'){$envs+=@('DATABASE_URL=postgresql://offline_probe@127.0.0.1:1/offline_probe','REDIS_URL=redis://127.0.0.1:1/0')}
 $containerName='wed-source-'+$run+'-offline-'+$name
 $argv=@('create','--pull=never','--platform','linux/amd64','--name',$containerName,'--label',('com.wed-snap.run='+$run),'--label',('com.wed-snap.task='+$script:TaskMarker),'--network','none','--ipc','private','--cgroupns','private','--read-only','--user',$role.user,'--memory',($role.memoryMiB.ToString()+'m'),'--memory-swap',($role.memoryMiB.ToString()+'m'),'--cpus',$role.cpu.ToString([Globalization.CultureInfo]::InvariantCulture),'--pids-limit',$role.pids.ToString(),'--cap-drop','ALL','--security-opt','no-new-privileges:true','--restart','no','--entrypoint','/bin/sh')
 if($name -cin @('app','gateway','proxy')){$argv+=@('--workdir','/app')}
 foreach($m in $mounts){$argv+=@('--mount',('type=bind,source='+$m.source+',target='+$m.target+',readonly'))};foreach($t in $tmp){$argv+=@('--tmpfs',$t)};foreach($e in $envs){$argv+=@('-e',$e)};$argv+=@($role.image,'/probe/one.sh',$name)
 if(@($argv|Where-Object{$_ -match '"'}).Count -or (($argv|ForEach-Object{$_.Length+3}|Measure-Object -Sum).Sum+$script:Docker.Length+3) -ge 32767){throw 'WINDOWS_COMMAND_LINE_CAP'}
 $roles+=@{role=$name;name=$containerName;image=$role.image;user=$role.user;memoryMiB=$role.memoryMiB;cpu=$role.cpu;pids=$role.pids;tmpfs=$tmp;mounts=$mounts;hashRows=$count;argv=$argv;sourceMountCount=@($mounts|Where-Object kind -CEQ SOURCE_PRELAUNCH_LEAF).Count}
}
if($roles.Count -ne 5 -or @($roles.image|Sort-Object -Unique).Count -ne 4){throw 'ROLE_IMAGE_CONTRACT'}
$source=(Resolve-Path 'labs/tiktok/ui-source-owner-native/Win32Adapter.cs').Path
if((Get-FileHash $source).Hash.ToLowerInvariant() -cne $script:HelperSHA -or (Get-FileHash $script:Docker).Hash.ToLowerInvariant() -cne $script:DockerSHA -or ('WedOwnerWin32.Engine' -as [type])){throw 'EXECUTOR_PIN'}
New-Item -ItemType Directory -Path (Join-Path $script:Root 'helper')|Out-Null;$dll=Join-Path $script:Root 'helper/RuntimeBoundary.dll';$watch=[Diagnostics.Stopwatch]::StartNew()
Add-Type -Path $source -OutputAssembly $dll;if(!('WedOwnerWin32.Engine' -as [type])){Add-Type -Path $dll};$type='WedOwnerWin32.Engine' -as [type];$layout=$type::Layout()
$plan=@{schema='wed-runtime-offline-probe-v1';runID=$run;task=$script:TaskMarker;roles=$roles;sourceGate=$false;endpoint=$script:Endpoint;docker=$script:Docker;dockerSHA=$script:DockerSHA;helperSource=$source;helperSHA=$script:HelperSHA;binary=$dll;binarySHA=(Get-FileHash $dll).Hash.ToLowerInvariant();MVID=$type.Module.ModuleVersionId.ToString();layout=$layout;compileMs=$watch.ElapsedMilliseconds;compileHardCancel='NOT_CLAIMED';sourcePins=Pins;baselinePins=$base.pins;workSeconds=240;cleanupReserveSeconds=60;metadataChildMs=15000;attachChildMs=20000;internalWatchdogSeconds=15;combinedOutputCap=65536;maxRunning=1;customNetworks=0;ports=0;delta=@{entrypoint='/bin/sh /probe/one.sh <role>, existing timeout -s KILL15';sourceRecipeInvoked=$false;sourceMirrors='OMITTED_SUPERVISOR_NOT_RUN_HASH_AT_REAL_TARGET';networks='none';services='NO_SERVER_WORKER_DB_REDIS_SERVICE';sourceFlags='DISABLED_NOT_AUTHORITY';prisma='APP_ONLY_CACHE_CLI_NO_ENGINE_NO_HINTS_TMPFS_OUTPUT_NO_INSTALL';clients='ACTUAL_CORE_EAGER_CLIENTS_PRIVATE_LOOPBACK_PORT1_PUBLIC_API_CLOSE';clockPort='NOT_RUN';roleTmpfs='SOURCE_PLAN_SIZES_UIDS_RETAINED'};utc=[DateTimeOffset]::UtcNow.ToString('o')}
Save (Join-Path $script:Root 'plan.json') $plan;Write-Output ('PREPARED_ZERO_DAEMON_CALLS PlanSHA='+(Get-FileHash (Join-Path $script:Root 'plan.json')).Hash.ToLowerInvariant());exit 0
