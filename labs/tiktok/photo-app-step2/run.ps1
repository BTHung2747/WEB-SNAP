param([ValidateSet('cli','typecheck','api','api-extra')][string]$Mode='cli',[ValidateRange(1,20)][int]$Attempt=1)
$ErrorActionPreference='Stop'
Set-Location 'D:\WED SNAP'
$ev="docs/evidence/tiktok-photo-app-step2-20261015/$Mode-$Attempt"
if(Test-Path -LiteralPath $ev){throw 'Refuse evidence reuse'}
New-Item -ItemType Directory -Path $ev|Out-Null
$image='sha256:d4558b29dd379b16d4906fb9e618dfc4d045e3008a70e031ea3474b7b2218e4e'
$run=[Guid]::NewGuid().ToString('N');$ids=@();$nets=@()
function Native([string]$step,[string[]]$argv){
 $start=[DateTimeOffset]::UtcNow;$text=& docker @argv 2>&1|Out-String;$exit=$LASTEXITCODE
 @{step=$step;arguments=$argv;actualExit=$exit;utcStart=$start.ToString('o');utcEnd=[DateTimeOffset]::UtcNow.ToString('o');output=$text}|ConvertTo-Json -Depth 8 -Compress|Add-Content "$ev/native.jsonl"
 if($exit){throw "Native $step exit$exit"};return $text.Trim()
}
$source=@(foreach($path in @('apps/media/src','apps/worker/src','apps/api/src','packages/shared/src','prisma')){
 Get-ChildItem -LiteralPath $path -Recurse -File|Where-Object{$_.FullName -notmatch '[\\/](node_modules|__pycache__)[\\/]'}
})+@(Get-Item package.json,package-lock.json,tsconfig.json)
$hashes=@($source|Sort-Object FullName|ForEach-Object{@{path=[IO.Path]::GetRelativePath((Get-Location).Path,$_.FullName).Replace('\','/');sha256=(Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant()}})
$hashes|ConvertTo-Json|Set-Content "$ev/expected-source.json"
Get-ChildItem labs/tiktok/photo-app-step2 -File|ForEach-Object{@{path=$_.Name;sha256=(Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant()}}|ConvertTo-Json|Set-Content "$ev/test-source.json"
try{
 $mounts=@(foreach($file in $source|Where-Object{$_.FullName -like '*\apps\media\src\*'}){
  '--mount';"type=bind,source=$($file.FullName),target=/app/$([IO.Path]::GetRelativePath((Get-Location).Path,$file.FullName).Replace('\','/')),readonly"
 })
 foreach($pair in @(@('apps/media/src/media_adapter.py','/app/infra/media_adapter.py'),@('labs/tiktok/photo-app-step2','/fixture'),@('labs/tiktok/photo-core-step1','/corefixture'),@('labs/tiktok/app-integration','/legacyfixture'),@('apps/worker/src','/app/apps/worker/src'),@('apps/api/src','/app/apps/api/src'),@('packages/shared/src','/app/packages/shared/src'),@('prisma','/app/prisma'))){
  $mounts+=@('--mount',"type=bind,source=$((Resolve-Path $pair[0]).Path),target=$($pair[1]),readonly")
 }
 if($Mode.StartsWith('api')){
  $network=Native 'create-own-network' @('network','create','--internal','--label',"com.wed-snap.run=$run",("photo-step2-$run"))
  $nets+=,$network
  $pg=Native 'create-postgres' @('create','--pull=never','--label',"com.wed-snap.run=$run",'--network',$network,'--network-alias','postgres','--read-only','--user','999:999','--cap-drop','ALL','--security-opt','no-new-privileges:true','--memory','128m','--memory-swap','128m','--cpus','0.25','--pids-limit','64','--tmpfs','/var/lib/postgresql/data:size=128m,uid=999,gid=999,nosuid','--tmpfs','/var/run/postgresql:size=8m,uid=999,gid=999,nosuid','--tmpfs','/tmp:size=8m,uid=999,gid=999,nosuid','-e','POSTGRES_DB=tiktok_photo_step2','-e','POSTGRES_USER=photo_fixture','-e','POSTGRES_PASSWORD=lab-public-only-password','postgres:16.10-bookworm','postgres','-c','shared_buffers=16MB','-c','max_connections=20');$ids+=,$pg
  $redisID=Native 'create-redis' @('create','--pull=never','--label',"com.wed-snap.run=$run",'--network',$network,'--network-alias','redis','--read-only','--user','1000:1000','--cap-drop','ALL','--security-opt','no-new-privileges:true','--memory','64m','--memory-swap','64m','--cpus','0.25','--pids-limit','32','--tmpfs','/data:size=8m,uid=1000,gid=1000,nosuid','redis:7.4.6-bookworm','redis-server','--save','','--appendonly','no','--maxmemory','32mb','--maxmemory-policy','noeviction');$ids+=,$redisID
  Native 'start-db' @('start',$pg,$redisID)|Out-Null
  Native 'db-ready' @('exec',$pg,'bash','-c','for i in {1..40}; do pg_isready -U photo_fixture -d tiktok_photo_step2 && exit 0; sleep 0.25; done; exit 1')|Out-Null
 }else{$network='none'}
 $testPath=if($Mode -eq 'api-extra'){'/fixture/test_new_job.ts'}else{'/fixture/test_api.ts'}
 $id=Native 'create-app' (@('create','--pull=never','--label',"com.wed-snap.run=$run",'--network',$network,'--ipc','private','--read-only','--user','1000:1000','--cap-drop','ALL','--security-opt','no-new-privileges:true','--memory','512m','--memory-swap','512m','--cpus','0.75','--pids-limit','160','--tmpfs','/tmp:size=48m,uid=1000,gid=1000,nosuid','--tmpfs','/media:size=96m,uid=1000,gid=1000,nosuid,noexec','--tmpfs','/app/node_modules/.prisma:size=64m,uid=1000,gid=1000,nosuid,exec','-e',"PHOTO_STEP2_TEST=$testPath",
 '-e','DATABASE_URL=postgresql://photo_fixture:lab-public-only-password@postgres:5432/tiktok_photo_step2','-e','REDIS_URL=redis://redis:6379/7','-e','APP_ORIGIN=http://photo-step2-fixture.invalid','-e','ADMIN_SESSION_SECRET=photo-step2-public-lab-secret-32chars','-e','VERIFIED_PLATFORMS=youtube,tiktok','-e','TIKTOK_ADAPTER_ENABLED=1','-e','TIKTOK_PHOTO_ENABLED=1','-e','PHOTO_STEP2_FIXTURE=1','-e','PYTHONPATH=/fixture:/corefixture:/app/apps/media/src','-e','PYTHONDONTWRITEBYTECODE=1','-e','MEDIA_ROOT=/media','-e','MEDIA_PROXY=http://egress:8888','-e','NODE_OPTIONS=--max-old-space-size=128','-e','HOME=/tmp','--mount',"type=bind,source=$((Resolve-Path $ev).Path),target=/control")+$mounts+@($image,'/usr/bin/timeout','--signal=KILL','450s','python3','/fixture/gate.py',$Mode));$ids+=,$id
 foreach($ownID in $ids){
  $g=@((Native 'guard' @('inspect',$ownID)|ConvertFrom-Json))[0]
  if($g.Config.Labels.'com.wed-snap.run' -cne $run -or !$g.HostConfig.ReadonlyRootfs -or $g.HostConfig.Privileged -or $g.HostConfig.CapAdd -or $g.HostConfig.CapDrop -notcontains 'ALL' -or $g.HostConfig.SecurityOpt -notcontains 'no-new-privileges:true' -or $g.HostConfig.MemorySwap -ne $g.HostConfig.Memory -or $g.HostConfig.IpcMode -cne 'private' -or @($g.HostConfig.PortBindings.PSObject.Properties).Count){throw 'Guard mismatch'}
  $g|ConvertTo-Json -Depth 40|Set-Content "$ev/guard-$ownID.json"
 }
 if($Mode.StartsWith('api')){$n=@((Native 'network-guard' @('network','inspect',$network)|ConvertFrom-Json))[0];if(!$n.Internal){throw 'External network forbidden'}}
 Native 'test' @('start','-a',$id)|Out-Null
 $finished=@((Native 'state' @('inspect',$id)|ConvertFrom-Json))[0]
 if($finished.State.ExitCode -ne 0 -or $finished.State.OOMKilled){throw 'App test failed'}
 foreach($row in $hashes){if((Get-FileHash -LiteralPath $row.path).Hash.ToLowerInvariant() -cne $row.sha256){throw 'Source changed during test'}}
 @{status='PASS_OFFLINE_ONLY';actualExit=0;sourceCalls=0;mode=$Mode;image=$image;utc=[DateTimeOffset]::UtcNow.ToString('o');vn=[DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(7)).ToString('o')}|ConvertTo-Json|Set-Content "$ev/completion.json"
}finally{
 foreach($ownID in $ids){
  $c=@((Native 'cleanup-owner' @('inspect',$ownID)|ConvertFrom-Json))[0];if($c.Config.Labels.'com.wed-snap.run' -cne $run){throw 'Owner mismatch'}
  Native 'remove-own' @('rm','-f',$ownID)|Out-Null
 }
 foreach($netID in $nets){Native 'remove-own-network' @('network','rm',$netID)|Out-Null}
 $remaining=Native 'verify-absent' @('ps','-aq','--filter',"label=com.wed-snap.run=$run");if($remaining){throw 'Own containers remain'}
 @{run=$run;containers=$ids;networks=$nets;ownResourcesLeft=0;volumesCreated=0}|ConvertTo-Json|Set-Content "$ev/cleanup.json"
}
