$ErrorActionPreference='Stop'
$workspace='D:\WED SNAP'
Set-Location -LiteralPath $workspace
$docker='C:\Program Files\Docker\Docker\resources\bin\docker.exe'
$image='sha256:5b994d8c9c4ed29ce550f0d60539a8071a2f2e233d9c840013c45802c08a7ba3'
$run=[guid]::NewGuid().ToString('N')
$out=Join-Path $workspace ('lab-runs\tiktok-source-quality-offline-20261030-'+$run)
New-Item -ItemType Directory -Path $out | Out-Null
$cid=$null;$failed=$false
$files=@('apps/media/src/tiktok/core.py','apps/media/src/tiktok/adapter.py',
 'apps/media/src/tiktok/candidate_file.py','apps/media/src/tiktok/prepare_operations.py',
 'labs/tiktok/source-quality-offline/test_quality.py','labs/tiktok/source-quality-offline/run.ps1')
$pins=@($files | ForEach-Object {@{path=$_;sha256=(Get-FileHash -LiteralPath $_ -Algorithm SHA256).Hash.ToLowerInvariant()}})
$pins | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $out 'tested-files.json')
function Native([string]$step,[string[]]$argv) {
  $start=[DateTime]::UtcNow
  $output=(& $docker @argv 2>&1 | Out-String);$exit=$LASTEXITCODE
  @{step=$step;actualExit=$exit;utcStart=$start.ToString('o');utcEnd=[DateTime]::UtcNow.ToString('o');output=$output} |
    ConvertTo-Json -Compress | Add-Content -LiteralPath (Join-Path $out 'native.jsonl')
  if($exit -ne 0){throw ('NATIVE_'+$step+'_EXIT_'+$exit)}
  return $output.Trim()
}
try {
  $argv=@('create','--name',('ws-source-quality-'+$run),'--label','com.wed-snap.lab=source-quality-offline',
    '--label',('com.wed-snap.run='+$run),'--network','none','--read-only','--user','1000:1000',
    '--cap-drop','ALL','--security-opt','no-new-privileges','--ipc','private',
    '--cpus','0.75','--memory','512m','--memory-swap','512m','--pids-limit','96',
    '--tmpfs','/tmp:rw,noexec,nosuid,size=32m,uid=1000,gid=1000',
    '--env','PYTHONDONTWRITEBYTECODE=1','--env','PYTHONUNBUFFERED=1',
    '--env','MEDIA_ROOT=/out/media',
    '--mount',('type=bind,source='+$workspace+'\labs\tiktok\source-quality-offline,target=/fixture,readonly'),
    '--mount',('type=bind,source='+$out+',target=/out'))
  foreach($file in $files | Where-Object { $_.StartsWith('apps/') }) {
    $argv+=@('--mount',('type=bind,source='+(Join-Path $workspace $file)+',target=/app/'+$file+',readonly'))
  }
  $argv+=@($image,'/usr/bin/timeout','--signal=TERM','--kill-after=5s','150s','python3','/fixture/test_quality.py')
  $cid=Native 'create' $argv
  if($cid -notmatch '^[0-9a-f]{64}$'){throw 'CONTAINER_ID'}
  $state=Native 'guard' @('inspect',$cid,'--format','{{json .HostConfig}}') | ConvertFrom-Json
  if($state.NetworkMode -ne 'none' -or -not $state.ReadonlyRootfs -or $state.Memory -ne 512MB -or
     $state.NanoCpus -ne 750000000 -or $state.CapDrop -notcontains 'ALL' -or
     -not ($state.SecurityOpt -match '^no-new-privileges')){throw 'GUARD'}
  Native 'test' @('start','-a',$cid) | Write-Output
  $state=Native 'state' @('inspect',$cid,'--format','{{json .State}}') | ConvertFrom-Json
  if($state.Status -ne 'exited' -or $state.ExitCode -ne 0 -or $state.OOMKilled){throw 'CONTAINER_TEST_EXIT'}
  if((Get-Content -LiteralPath (Join-Path $out 'result.json') -Raw | ConvertFrom-Json).status -ne 'PASS'){throw 'RESULT'}
  foreach($pin in $pins) {
    if((Get-FileHash -LiteralPath $pin.path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $pin.sha256){throw 'TESTED_SOURCE_CHANGED'}
  }
} catch {
  $failed=$true
  throw
} finally {
  if($cid -and $cid -match '^[0-9a-f]{64}$') {
    $owner=Native 'owner' @('inspect',$cid,'--format','{{index .Config.Labels "com.wed-snap.run"}}')
    if($owner -cne $run){throw 'CLEANUP_OWNER'}
    Native 'final-state' @('inspect',$cid,'--format','{{json .State}}') | Out-Null
    Native 'remove' @('rm','-f',$cid) | Out-Null
    $left=Native 'absence' @('ps','-a','--filter',('label=com.wed-snap.run='+$run),'-q')
    if($left){throw 'CLEANUP_INCOMPLETE'}
    @{ownResourcesLeft=0;removed=$cid;sourceRequests=0;testFailed=$failed;utc=[DateTime]::UtcNow.ToString('o')} |
      ConvertTo-Json | Set-Content -LiteralPath (Join-Path $out 'cleanup.json')
  }
  Write-Output ('Evidence: '+$out)
}
