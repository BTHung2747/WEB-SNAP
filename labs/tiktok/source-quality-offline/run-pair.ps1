param([ValidateSet('pair','short','short-close','preview')][string]$Mode='pair')
$ErrorActionPreference='Stop';Set-Location -LiteralPath 'D:\WED SNAP'
$workspace=(Get-Location).Path;$run=[guid]::NewGuid().ToString('N')
$out=Join-Path $workspace ('lab-runs\tiktok-quality-'+$Mode+'-offline-20261030-'+$run)
New-Item -ItemType Directory -Path $out | Out-Null
$docker='C:\Program Files\Docker\Docker\resources\bin\docker.exe'
$image='sha256:5b994d8c9c4ed29ce550f0d60539a8071a2f2e233d9c840013c45802c08a7ba3'
$inputs=Join-Path $workspace 'lab-runs\tiktok-source-quality-offline-20261030-abd685e3dbf84671bf708046c3140756'
$files=@('apps/media/src/media_adapter.py','apps/media/src/video_policy.py','apps/media/src/tiktok/core.py',
 'apps/media/src/tiktok/adapter.py','apps/media/src/tiktok/candidate_file.py','apps/media/src/tiktok/prepare_operations.py',
 'apps/media/src/tiktok/video_selection.py','apps/media/src/tiktok/validate_cobalt_body.mjs','apps/egress/src/tiktok_policy/control.py',
 'apps/worker/src/adapter.ts','apps/worker/src/processor.ts','apps/worker/src/proxy-phase.ts',
 'packages/shared/src/tiktok-video.ts','apps/api/src/services/jobs.service.ts',
 'apps/web/src/types.ts','apps/web/src/pages/Home.tsx','apps/web/src/lib/source-quality.ts',
 'labs/tiktok/source-quality-offline/test_pair.py','labs/tiktok/source-quality-offline/test_pair.cjs',
 'labs/tiktok/source-quality-offline/resources.py','labs/tiktok/source-quality-offline/run-pair.ps1')
if($Mode.StartsWith('short')){$files+=@('packages/shared/src/core.ts','packages/shared/src/tiktok-short.ts',
 'apps/media/src/tiktok/shortlink.py','apps/media/src/tiktok/photo_core.py','labs/tiktok/source-quality-offline/test_short.py','labs/tiktok/source-quality-offline/test_short.cjs')}
if($Mode -eq 'short-close'){$files+='labs/tiktok/source-quality-offline/test_short_close.py'}
if($Mode -eq 'preview'){
 $files=@('apps/media/src/media_adapter.py','apps/media/src/video_policy.py','apps/media/src/tiktok/core.py','apps/media/src/tiktok/adapter.py',
 'apps/media/src/tiktok/candidate_file.py','apps/media/src/tiktok/prepare_operations.py','apps/media/src/tiktok/video_selection.py','apps/media/src/tiktok/validate_cobalt_body.mjs',
 'apps/media/src/tiktok/shortlink.py','apps/media/src/tiktok/photo_core.py','apps/media/src/tiktok/photo_proxy.py','apps/media/src/tiktok/preview_cache.py',
 'apps/egress/src/tiktok_policy/control.py','apps/worker/src/adapter.ts','apps/worker/src/proxy-phase.ts',
 'packages/shared/src/tiktok-video.ts','packages/shared/src/tiktok-short.ts','packages/shared/src/core.ts',
 'apps/api/src/services/jobs.service.ts','apps/api/src/services/preview-cache.ts','apps/api/src/controllers/jobs.controller.ts',
 'labs/tiktok/source-quality-offline/test_preview.py','labs/tiktok/source-quality-offline/test_preview.cjs','labs/tiktok/source-quality-offline/resources.py','labs/tiktok/source-quality-offline/run-pair.ps1')
}
$pins=@($files | ForEach-Object {@{path=$_;sha256=(Get-FileHash -LiteralPath $_).Hash.ToLowerInvariant()}})
$pins|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $out 'tested-files.json')
$cid=$null;$failed=$false
function Native([string]$step,[string[]]$argv){
 $start=[DateTime]::UtcNow;$output=(& $docker @argv 2>&1|Out-String);$exit=$LASTEXITCODE
 @{step=$step;actualExit=$exit;utcStart=$start.ToString('o');utcEnd=[DateTime]::UtcNow.ToString('o');output=$output}|ConvertTo-Json -Compress|Add-Content -LiteralPath (Join-Path $out 'native.jsonl')
 if($exit -ne 0){throw ('NATIVE_'+$step+'_EXIT_'+$exit)};return $output.Trim()
}
try{
 $argv=@('create','--name',('ws-quality-pair-'+$run),'--label',('com.wed-snap.run='+$run),'--network','none',
 '--read-only','--user','1000:1000','--cap-drop','ALL','--security-opt','no-new-privileges','--ipc','private',
 '--cpus','0.75','--memory','512m','--memory-swap','512m','--pids-limit','96',
 '--tmpfs','/tmp:rw,noexec,nosuid,size=32m,uid=1000,gid=1000','--env','PYTHONDONTWRITEBYTECODE=1','--env','MEDIA_ROOT=/out/media',
 '--mount',('type=bind,source='+$inputs+',target=/inputs,readonly'),
 '--mount',('type=bind,source='+$out+',target=/out'),
 '--mount',('type=bind,source='+$workspace+'\labs\tiktok\source-quality-offline,target=/fixture,readonly'))
 foreach($file in $files|Where-Object {$_.StartsWith('apps/') -or $_.StartsWith('packages/')}){
   $target=if($file -eq 'apps/media/src/media_adapter.py'){'/app/infra/media_adapter.py'}else{'/app/'+$file}
   $argv+=@('--mount',('type=bind,source='+(Join-Path $workspace $file)+',target='+$target+',readonly'))
 }
 $script='set -eu; trap "python3 /fixture/resources.py" EXIT; python3 /fixture/test_pair.py; node --require /app/node_modules/tsx/dist/cjs/index.cjs /fixture/test_pair.cjs; cd /app; node_modules/.bin/tsc -p tsconfig.json --noEmit; node_modules/.bin/tsc -p apps/web/tsconfig.json --noEmit'
 if($Mode -eq 'short'){$script='set -eu; trap "python3 /fixture/resources.py" EXIT; python3 /fixture/test_short.py; node /app/node_modules/tsx/dist/cli.mjs /fixture/test_short.cjs; cd /app; node_modules/.bin/tsc -p tsconfig.json --noEmit'}
 if($Mode -eq 'short-close'){$script='set -eu; trap "python3 /fixture/resources.py" EXIT; PYTHONPATH=/app/apps/media/src python3 /fixture/test_short_close.py'}
 if($Mode -eq 'preview'){$script='set -eu; trap "python3 /fixture/resources.py" EXIT; python3 /fixture/test_preview.py; node /app/node_modules/tsx/dist/cli.mjs /fixture/test_preview.cjs; cd /app; node_modules/.bin/tsc -p tsconfig.json --noEmit'}
 $argv+=@($image,'/usr/bin/timeout','--signal=TERM','--kill-after=5s','150s','sh','-ec',$script)
 $cid=Native 'create' $argv;if($cid -notmatch '^[0-9a-f]{64}$'){throw 'CID'}
 $guard=Native 'guard' @('inspect',$cid,'--format','{{json .HostConfig}}')|ConvertFrom-Json
 if($guard.NetworkMode -ne 'none' -or -not $guard.ReadonlyRootfs -or $guard.Memory -ne 512MB -or $guard.NanoCpus -ne 750000000 -or $guard.CapDrop -notcontains 'ALL'){throw 'GUARD'}
 Native 'test' @('start','-a',$cid)|Write-Output
 $state=Native 'state' @('inspect',$cid,'--format','{{json .State}}')|ConvertFrom-Json
 if($state.ExitCode -ne 0 -or $state.OOMKilled){throw 'TEST_EXIT'}
 foreach($pin in $pins){if((Get-FileHash -LiteralPath $pin.path).Hash.ToLowerInvariant() -ne $pin.sha256){throw 'PIN_CHANGED'}}
}catch{$failed=$true;throw}finally{
 if($cid -and $cid -match '^[0-9a-f]{64}$'){
   $owner=Native 'owner' @('inspect',$cid,'--format','{{index .Config.Labels "com.wed-snap.run"}}')
   if($owner -cne $run){throw 'CLEANUP_OWNER'}
   Native 'final-state' @('inspect',$cid,'--format','{{json .State}}')|Out-Null
   Native 'remove' @('rm','-f',$cid)|Out-Null
   if(Native 'absence' @('ps','-a','--filter',('label=com.wed-snap.run='+$run),'-q')){throw 'RESOURCES_LEFT'}
   @{ownResourcesLeft=0;testFailed=$failed;sourceRequests=0;utc=[DateTime]::UtcNow.ToString('o')}|ConvertTo-Json|Set-Content -LiteralPath (Join-Path $out 'cleanup.json')
 };Write-Output ('Evidence: '+$out)
}
