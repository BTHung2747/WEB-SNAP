# Scoped support-only offline integration, cached images, private data/network.
param([switch]$Focused)
$ErrorActionPreference='Stop';$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$run=[guid]::NewGuid().ToString('N');$out=Join-Path $root ('lab-runs\support-offline-20261031-'+$run)
New-Item -ItemType Directory -Path $out|Out-Null
$docker='C:\Program Files\Docker\Docker\resources\bin\docker.exe'
$appImage='sha256:5b994d8c9c4ed29ce550f0d60539a8071a2f2e233d9c840013c45802c08a7ba3'
$pgImage='sha256:38471f330eb885e04de130b768d6db4e10469e2311879c7e5c699f6d2d8a1c74'
$prefix='ws-support-'+$run;$network=$null;$pg=$null;$api=$null;$failed=$true
$files=@('apps/api/src/app.module.ts','apps/api/src/openapi.ts','apps/api/src/controllers/support.controller.ts',
 'apps/api/src/services/support-contract.ts','apps/api/src/services/support-image.ts','apps/api/src/services/support.service.ts',
 'apps/api/src/security/support-upload.ts','apps/api/src/auth/session.ts','apps/api/src/filters/safe-errors.filter.ts',
 'apps/api/src/validation.ts','infra/production/Caddyfile','tests/support.cjs','scripts/test-support.ps1')
$pins=@($files|ForEach-Object {@{path=$_;sha256=(Get-FileHash -LiteralPath (Join-Path $root $_)).Hash.ToLowerInvariant()}})
$pins|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $out 'tested-files.json')
function Native([string]$step,[string[]]$argv,[bool]$required=$true){
 $start=[DateTime]::UtcNow;$result=(& $docker @argv 2>&1|Out-String);$exit=$LASTEXITCODE
 @{step=$step;actualExit=$exit;utcStart=$start.ToString('o');utcEnd=[DateTime]::UtcNow.ToString('o');output=$result}|ConvertTo-Json -Compress|Add-Content -LiteralPath (Join-Path $out 'native.jsonl')
 if($required -and $exit){throw ('SUPPORT_NATIVE_'+$step+'_EXIT_'+$exit)}
 return @{output=$result.Trim();exit=$exit}
}
function ContainerGuard([string]$cid,[long]$memory,[long]$cpu){
 $g=(Native 'guard' @('inspect',$cid,'--format','{{json .HostConfig}}')).output|ConvertFrom-Json
 if(!$g.ReadonlyRootfs -or $g.Memory -ne $memory -or $g.MemorySwap -ne $memory -or $g.NanoCpus -ne $cpu -or $g.CapDrop -notcontains 'ALL' -or $g.Privileged -or $g.PortBindings.PSObject.Properties.Name){throw 'CONTAINER_GUARD'}
}
try{
 $network=(Native 'network-create' @('network','create','--internal','--label',('com.wed-snap.support='+$run),$prefix)).output
 if($network -notmatch '^[a-f0-9]{64}$'){throw 'NETWORK_ID'}
 $pg=(Native 'pg-create' @('create','--name',($prefix+'-pg'),'--label',('com.wed-snap.support='+$run),'--network',$prefix,'--network-alias','postgres',
 '--user','999:999','--read-only','--cap-drop','ALL','--security-opt','no-new-privileges','--ipc','private','--memory','256m','--memory-swap','256m','--cpus','0.5','--pids-limit','64',
 '--tmpfs','/var/lib/postgresql/data:rw,nosuid,nodev,size=128m,uid=999,gid=999','--tmpfs','/var/run/postgresql:rw,nosuid,nodev,size=8m,uid=999,gid=999','--tmpfs','/tmp:rw,nosuid,nodev,size=8m,uid=999,gid=999',
 '--env','POSTGRES_USER=support_lab','--env','POSTGRES_DB=support_lab','--env','POSTGRES_PASSWORD=public-offline-fixture-not-a-secret',
 $pgImage,'postgres','-c','shared_buffers=16MB','-c','max_connections=20')).output
 if($pg -notmatch '^[a-f0-9]{64}$'){throw 'PG_ID'};ContainerGuard $pg 256MB 500000000
 Native 'pg-start' @('start',$pg)|Out-Null
 $ready=$false;$end=[DateTime]::UtcNow.AddSeconds(25)
 while([DateTime]::UtcNow -lt $end){$r=Native 'own-pg-ready' @('exec',$pg,'pg_isready','-U','support_lab','-d','support_lab') $false;if(!$r.exit){$ready=$true;break};Start-Sleep -Milliseconds 500}
 if(!$ready){throw 'PG_READY_DEADLINE'}
 $args=@('create','--name',($prefix+'-api'),'--label',('com.wed-snap.support='+$run),'--network',$prefix,'--read-only','--user','1000:1000','--cap-drop','ALL','--security-opt','no-new-privileges','--ipc','private',
 '--memory','384m','--memory-swap','384m','--cpus','0.75','--pids-limit','96','--tmpfs','/tmp:rw,noexec,nosuid,nodev,size=32m,uid=1000,gid=1000',
 '--env','SUPPORT_TEST_GUARD=own-support-offline','--env','DATABASE_URL=postgresql://support_lab:public-offline-fixture-not-a-secret@postgres:5432/support_lab',
 '--mount',('type=bind,source='+$out+',target=/out'))
 if($Focused){$args+=@('--env','SUPPORT_TEST_FOCUSED=1')}
 foreach($folder in @('apps/api/src','apps/worker/src','packages/shared/src')){$args+=@('--mount',('type=bind,source='+(Join-Path $root $folder)+',target=/app/'+$folder+',readonly'))}
 $args+=@('--mount',('type=bind,source='+(Join-Path $root 'tests/support.cjs')+',target=/app/tests/support.cjs,readonly'),$appImage,
 '/usr/bin/timeout','--signal=TERM','--kill-after=5s','150s','sh','-ec','set -eu; node node_modules/prisma/build/index.js migrate deploy; node node_modules/tsx/dist/cli.mjs tests/support.cjs; node_modules/.bin/tsc -p tsconfig.json --noEmit; node -e "const fs=require(''fs'');fs.writeFileSync(''/out/resources.json'',JSON.stringify(Object.fromEntries([''memory.peak'',''memory.max'',''pids.peak'',''cpu.max''].map(k=>[k,fs.readFileSync(''/sys/fs/cgroup/''+k,''utf8'').trim()]))))"')
 $api=(Native 'api-create' $args).output;if($api -notmatch '^[a-f0-9]{64}$'){throw 'API_ID'};ContainerGuard $api 384MB 750000000
 Native 'support-tests' @('start','-a',$api)|Out-Null
 $state=(Native 'api-state' @('inspect',$api,'--format','{{json .State}}')).output|ConvertFrom-Json
 if($state.ExitCode -ne 0 -or $state.OOMKilled){throw 'SUPPORT_TEST_STATE'}
 foreach($pin in $pins){if((Get-FileHash -LiteralPath (Join-Path $root $pin.path)).Hash.ToLowerInvariant() -ne $pin.sha256){throw 'TESTED_PIN_DRIFT'}}
 $failed=$false
}finally{
 foreach($cid in @($api,$pg)|Where-Object {$_}){
  $owner=(Native 'cleanup-owner' @('inspect',$cid,'--format','{{index .Config.Labels "com.wed-snap.support"}}')).output
  if($owner -cne $run){throw 'CLEANUP_OWNER'}
  Native 'final-state' @('inspect',$cid,'--format','{{json .State}}')|Out-Null
  Native 'remove-own' @('rm','-f',$cid)|Out-Null
 }
 if($network){
  $owner=(Native 'network-owner' @('network','inspect',$network,'--format','{{index .Labels "com.wed-snap.support"}}')).output
  if($owner -cne $run){throw 'NETWORK_OWNER'};Native 'remove-network' @('network','rm',$network)|Out-Null
 }
 $left=(Native 'absence' @('ps','-aq','--filter',('label=com.wed-snap.support='+$run))).output
 $nets=(Native 'network-absence' @('network','ls','-q','--filter',('label=com.wed-snap.support='+$run))).output
 if($left -or $nets){throw 'OWN_RESOURCE_LEFT'}
 @{testFailed=$failed;sourceRequests=0;ownResourcesLeft=0;utc=[DateTime]::UtcNow.ToString('o')}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $out 'cleanup.json')
 Write-Output ('Evidence: '+$out)
}
