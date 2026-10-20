. (Join-Path $PSScriptRoot '../ui-source-readiness/plan.ps1')
. (Join-Path $PSScriptRoot '../ui-source-glue/wiring.ps1')
function Get-PrelaunchPlan {
 $base=Get-SourceReadinessPlan;$delta=Get-SourceGlueDelta
 $map=@($base.mounts|Where-Object{$_.target -cnotin $delta.replaceReadinessHelperTargets})+@($delta.mounts)
 if($map.Count -ne 123){throw 'RUNTIME_LEAF_COVERAGE'}
 $seen=@{};foreach($m in $map){
  if(!$m.readOnly -or !(Test-Path -LiteralPath $m.source -PathType Leaf)){throw 'READONLY_LEAF'}
  if($m.target -cmatch '^/app/node_modules(/|$)' -or $m.target -ceq '/app/apps/media/src' -or $m.source -match 'sitecustomize|media_site|generate.py|expectation|workflow.ts|driver.ts'){throw 'FIXTURE_OR_CACHE_SHADOW'}
  foreach($role in $m.roles){$key=$role+':'+$m.target;if($seen.ContainsKey($key)){throw 'MOUNT_COLLISION'};$seen[$key]=$true}
 }
 # Frozen supervisor verifies /repo/<path>. Mirror app source leaves without
 # mounting a directory over cache dependencies; expected-source is that projection.
 $projection=@($map|Where-Object{$_.roles -contains 'app'}|Select-Object -ExpandProperty source -Unique)
 $mirrors=@(foreach($s in $projection){@{source=$s;target='/repo/'+$s;roles=@('app');readOnly=$true}})
 $pins=@(Get-Content -LiteralPath 'docs/evidence/ui-source-glue-fix-20261016/backend/final-source-pins.json' -Raw|ConvertFrom-Json)
 foreach($p in $pins){if((Get-FileHash -LiteralPath $p.path).Hash.ToLowerInvariant() -cne $p.sha256){throw 'ACCEPTED_PIN_DRIFT'}}
 $paths=@($pins.path)+@($map.source)+@('docs/tasks/UI_SOURCE_PRELAUNCH_OFFLINE_20261016.md')+@(Get-ChildItem $PSScriptRoot -File|ForEach-Object{[IO.Path]::GetRelativePath((Get-Location).Path,$_.FullName).Replace('\','/')})
 $current=@(foreach($s in $paths|Sort-Object -Unique){@{path=$s;sha256=(Get-FileHash -LiteralPath $s).Hash.ToLowerInvariant();bytes=(Get-Item -LiteralPath $s).Length}})
 $build=@($map|Where-Object{$_.target -clike '/build/*'});if($build.Count -ne 3){throw 'BUILD_PIN_COVERAGE'}
 $target=Get-Content -LiteralPath 'docs/tasks/UI_SOURCE_TARGET_20261016.json' -Raw|ConvertFrom-Json
 if($target.executionPermittedByThisRecord -or $target.newLiveGrantCreated -or $target.newLiveClaimCreated -or $target.newLiveRunID){throw 'TARGET_IS_NOT_AUTHORITY'}
 $roles=@(
  @{role='app';image=$base.images.app;memoryMiB=512;cpu=0.75;user='1000:1000';pids=160;networks=@('internal');argv=$delta.app},
  @{role='proxy';image=$base.images.proxy;memoryMiB=96;cpu=0.25;user='65534:65534';pids=96;networks=@('internal','source-egress');argv=@('/usr/bin/timeout','--signal=KILL','340s')+$delta.proxy},
  @{role='postgres';image=$base.images.postgres;memoryMiB=128;cpu=0.25;user='999:999';pids=64;networks=@('internal');argv=@('postgres','-c','shared_buffers=16MB','-c','max_connections=20')},
  @{role='redis';image=$base.images.redis;memoryMiB=64;cpu=0.25;user='1000:1000';pids=32;networks=@('internal');argv=@('redis-server','--save','','--appendonly','no','--maxmemory','32mb')},
  @{role='gateway';image=$base.images.gateway;memoryMiB=128;cpu=0.25;user='1000:1000';pids=48;networks=@('internal','ingress');argv=$delta.gateway}
 )
 if(($roles|Measure-Object memoryMiB -Sum).Sum -ne 928){throw 'MEMORY_POLICY'}
 $control=@(@{source='<OWN_CONTROL>';target='/control';roles=@('app','proxy','gateway');readOnly=$false;owner='backend receipts'})
 foreach($name in @('browser-contract.json','source-decision.json','source-budget.json')){$control+=@{source="<OWN_CONTROL>/$name";target="/control/$name";roles=@('app','gateway');readOnly=$true;owner='host owner only'}}
 $control+=@{source='<OWN_CONTROL>/expected-source.json';target='/control/expected-source.json';roles=@('app');readOnly=$true;owner='host hash projection only'}
 $fullTargets=@{};foreach($m in @($map)+@($mirrors)+@($control)){foreach($role in $m.roles){$key=$role+':'+$m.target;if($fullTargets.ContainsKey($key)){throw 'FULL_MOUNT_COLLISION'};$fullTargets[$key]=$true}}
 $resources=@{networks=@(@{name='<OWN_INTERNAL>';internal=$true},@{name='<OWN_INGRESS>';internal=$false;members=@('gateway')},@{name='<OWN_SOURCE_EGRESS>';internal=$false;members=@('proxy')});roles=$roles;commonGuard=@('--pull=never','--ipc','private','--read-only','--cap-drop','ALL','--security-opt','no-new-privileges:true');memorySwap='equal memory';label='com.wed-snap.run=<OWN_RUN>';publish='gateway only 127.0.0.1:5206:5206';media='app tmpfs /media64MiB';tmpfs=@{appTmp=32;prisma=64;proxyTmp=32;gatewayTmp=8;postgresData=128;postgresRun=8;postgresTmp=8;redisData=8}}
 $environment=@{app=@('STEP5_EXECUTE_SOURCE=1','PYTHONDONTWRITEBYTECODE=1','TIKTOK_EGRESS_POLICY_ENABLED=1','PYTHONPATH=/app/apps/media/src','MEDIA_ROOT=/media','MEDIA_PROXY=http://egress:8888','APP_ORIGIN=http://127.0.0.1:5206','TIKTOK_PHOTO_ENABLED=1','TIKTOK_ADAPTER_ENABLED=1','VERIFIED_PLATFORMS=tiktok,youtube','NODE_OPTIONS=--max-old-space-size=128','DATABASE_URL=<OWN_LAB_DATABASE>','REDIS_URL=<OWN_LAB_REDIS>','ADMIN_SESSION_SECRET=<RAM_SECRET>','TIKTOK_EGRESS_CONTROL_SECRET=<PARENT_PROXY_ONLY_SECRET>');proxy=@('STEP5_EXECUTE_SOURCE=1','PYTHONDONTWRITEBYTECODE=1','TIKTOK_EGRESS_POLICY_ENABLED=1','TIKTOK_EGRESS_CONTROL_NETWORKS=<EXACT_INTERNAL_CIDR>','TIKTOK_EGRESS_CONTROL_SECRET=<PARENT_PROXY_ONLY_SECRET>');gateway=@('STEP5_EXECUTE_SOURCE=1','APP_ORIGIN=http://127.0.0.1:5206','API_IPV4=<INSPECTED_NUMERIC_INTERNAL_IP>','NODE_OPTIONS=--max-old-space-size=64');postgres=@('POSTGRES_DB=step5_executor','POSTGRES_USER=gate_fixture','POSTGRES_PASSWORD=<OWN_LAB_PASSWORD>');redis=@();forbidden=@('STEP5_OFFLINE_TEST','STEP5_OFFLINE_DNS','fixture CA','sitecustomize');secretLogging='redact at native boundary; never render real secrets'}
 $create=@{}
 foreach($role in $roles){
  $name=$role.role;$network=if($name -ceq 'gateway'){'<OWN_INGRESS>'}else{'<OWN_INTERNAL>'}
  $argv=@('create')+$resources.commonGuard+@('--label',$resources.label,'--name',"<OWN_$name>",'--network',$network,'--user',$role.user,'--memory',"$($role.memoryMiB)m",'--memory-swap',"$($role.memoryMiB)m",'--cpus',$role.cpu.ToString([Globalization.CultureInfo]::InvariantCulture),'--pids-limit',[string]$role.pids)
  if($name -in @('postgres','redis','proxy')){$alias=if($name -ceq 'proxy'){'egress'}else{$name};$argv+=@('--network-alias',$alias)}
  foreach($envValue in $environment[$name]){$argv+=@('-e',$envValue)}
  foreach($m in @($map)+@($mirrors)+@($control)|Where-Object{$_.roles -contains $name}){$src=if($m.source.StartsWith('<')){$m.source}else{(Resolve-Path -LiteralPath $m.source).Path};$bind="type=bind,source=$src,target=$($m.target)";if($m.readOnly){$bind+=',readonly'};$argv+=@('--mount',$bind)}
  $tmp= switch($name){app{@('/tmp:size=32m,mode=1777,nosuid','/media:size=64m,uid=1000,gid=1000,nosuid,noexec','/app/node_modules/.prisma:size=64m,uid=1000,gid=1000,nosuid,exec')}proxy{@('/tmp:size=32m,mode=1777,nosuid')}gateway{@('/tmp:size=8m,nosuid')}postgres{@('/var/lib/postgresql/data:size=128m,uid=999,gid=999,nosuid','/var/run/postgresql:size=8m,uid=999,gid=999,nosuid','/tmp:size=8m,uid=999,gid=999,nosuid')}redis{@('/data:size=8m,uid=1000,gid=1000,nosuid')}}
  foreach($t in $tmp){$argv+=@('--tmpfs',$t)}
  if($name -ceq 'gateway'){$argv+=@('-p','127.0.0.1:5206:5206')}
  $create[$name]=@($argv)+@($role.image)+@($role.argv)
 }
 [ordered]@{schema='wed-ui-source-prelaunch-plan-v1';sourceGate=$false;launchReady=$false;liveEngineEnabled=$false;staticStatus='PASS_STATIC_PLAN_ONLY';target=$target;mounts=$map;supervisorMirrors=$mirrors;expectedSourceProjection=@($current|Where-Object{$_.path -cin $projection});controlMounts=$control;hostPrivate='<OWN_EVIDENCE>/owner-private never mounted into containers';resources=$resources;createArgvTemplates=$create;environment=$environment;pins=$current;buildPins=@($current|Where-Object{$_.path -cin $build.source});budget=@{overallMax=480;proposedOwnerSeconds=320;startup=60;analyze=30;prepare=180;cleanup=20;seal=1;availableBrowserSeconds=29;approvedBrowserMinimum=$null;watchdogs=@{controller=280;gateway=390;app=340;supervisor=320;proxy=340};status='BROWSER_ALLOCATION_AND_REAL_CLOCKS_PENDING'};requiredNotRun=@('NODE22_LINUX_IMPORTS','CACHE_IMAGE_IDENTITIES','PUBLIC_PHOTO_SCHEMA_INTEGRATION','UTC_HOST_CONTAINER_SKEW','CGROUP_AND_ISOLATION','OWNED_EGRESS_TLS_AND_PHASE_CLOSURE','NATIVE_EXECUTOR_INTEGRATION');publisher=@('python','-I','-B','labs/tiktok/ui-source-prelaunch/publisher.py','--root','<HOST_OWN_CONTROL>','--input','<HOST_OBSERVATION_JSON>');finalGate=@('node','--max-old-space-size=64','labs/tiktok/ui-source-prelaunch/final-gate.cjs','<HOST_OWN_CONTROL>','<HOST_OWNER_PRIVATE>/native-exits.json');nativeRecipe='ui-final-fixture/run.ps1 + photo-source-fixed/run.ps1; no invocation';workflowOwner='FRONTEND_BROWSER_ONLY'}
}
