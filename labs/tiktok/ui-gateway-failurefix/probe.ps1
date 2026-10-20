param([ValidateSet('masked','overlay')][string]$Mode)
$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
. (Join-Path $PSScriptRoot 'mounts.ps1')
$base='docs/evidence/ui-gateway-failurefix-20261016';$ev="$base/$Mode"
if(!$Mode -or (Test-Path -LiteralPath $ev)){throw 'PROBE_SCOPE_OR_REUSE'}
if($Mode -ceq 'overlay'){$prior=Get-Content "$base/masked/completion.json" -Raw|ConvertFrom-Json;if($prior.status -cne 'PASS_PROBE_ONLY'){throw 'PRIOR_PROBE_GATE'}}
New-Item -ItemType Directory -Path $ev|Out-Null;$end=[DateTimeOffset]::UtcNow.AddSeconds(60);$run=[Guid]::NewGuid().ToString('N');$id=$null;$closed=$false;$pass=$false
$image='sha256:d4558b29dd379b16d4906fb9e618dfc4d045e3008a70e031ea3474b7b2218e4e'
function Native([string]$Step,[string[]]$Arguments){
 $at=[DateTimeOffset]::UtcNow;$limit=[int][Math]::Min(45000,[Math]::Max(1,($end-$at).TotalMilliseconds));
 $info=[Diagnostics.ProcessStartInfo]::new('docker');$info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true;foreach($arg in $Arguments){$info.ArgumentList.Add($arg)}
 $p=[Diagnostics.Process]::new();$p.StartInfo=$info
 try{if(!$p.Start()){throw 'START'};$o=$p.StandardOutput.ReadToEndAsync();$e=$p.StandardError.ReadToEndAsync();$timeout=!$p.WaitForExit($limit);if($timeout){$p.Kill($true);$p.WaitForExit(1000)|Out-Null};$stdout=$o.GetAwaiter().GetResult();$stderr=$e.GetAwaiter().GetResult();$code=if($p.HasExited){$p.ExitCode}else{$null}
  if($stdout.Length -gt 131072){$stdout='OUTPUT_CAP'}
  @{step=$Step;arguments=$Arguments;actualExit=$code;timedOut=$timeout;stdout=$stdout;stderrBytes=[Text.Encoding]::UTF8.GetByteCount($stderr);utcStart=$at.ToString('o');utcEnd=[DateTimeOffset]::UtcNow.ToString('o')}|ConvertTo-Json -Depth 6 -Compress|Add-Content "$ev/native.jsonl"
  if($timeout -or $code -ne 0){throw 'NATIVE_FAILED'};return $stdout.Trim()
 }finally{$p.Dispose()}
}
try{
 $map=@([pscustomobject]@{source=$PSScriptRoot;target='/probe';type='directory';roles=@('probe');readOnly=$true},[pscustomobject]@{source=(Resolve-Path labs/tiktok/photo-app-source-executor/offline).Path;target='/fixtures';type='directory';roles=@('probe');readOnly=$true},[pscustomobject]@{source=(Resolve-Path $ev).Path;target='/control';type='directory';roles=@('probe');readOnly=$false})
 $media=@(Get-MediaLeafMounts @('probe'))
 if($Mode -ceq 'masked'){$map+=[pscustomobject]@{source=(Resolve-Path apps/media/src).Path;target='/app/apps/media/src';type='directory';roles=@('probe');readOnly=$true}}else{$map+=$media}
 foreach($m in $map){if(!(Test-Path -LiteralPath $m.source)){throw 'SOURCE'};if($m.source.Contains(',')){throw 'MOUNT_SOURCE'}}
 $pins=@($media|ForEach-Object{@{target=$_.target;path=[IO.Path]::GetRelativePath((Get-Location).Path,$_.source).Replace('\','/');sha256=(Get-FileHash -LiteralPath $_.source).Hash.ToLowerInvariant()}})
 $pins|ConvertTo-Json|Set-Content "$ev/source-pins.json"
 $codePins=@(Get-ChildItem $PSScriptRoot -File|ForEach-Object{@{path=[IO.Path]::GetRelativePath((Get-Location).Path,$_.FullName).Replace('\','/');sha256=(Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant()}})
 @{mounts=$map;implementation=$codePins;role='probe';sourceCalls=0}|ConvertTo-Json -Depth 6|Set-Content "$ev/preflight.json"
 if((Native 'cache' @('image','inspect',$image,'--format','{{.Id}}')) -cne $image){throw 'CACHE'}
 $command="node /probe/dependency-probe.cjs $Mode"
 if($Mode -ceq 'masked'){$command+=' && node --check /probe/gateway.cjs && node /probe/test-gateway.cjs'}
 $id=Native 'create' (@('create','--pull=never','--label',"com.wed-snap.run=$run",'--network','none','--ipc','private','--read-only','--user','1000:1000','--memory','256m','--memory-swap','256m','--cpus','0.75','--pids-limit','64','--cap-drop','ALL','--security-opt','no-new-privileges:true','--tmpfs','/tmp:size=8m,uid=1000,gid=1000,nosuid','-e','NODE_OPTIONS=--max-old-space-size=64')+@(Get-CombinedBindArgs $map 'probe')+@($image,'/usr/bin/timeout','--signal=KILL','40s','bash','-c',$command))
 $g=@((Native 'guard' @('inspect',$id)|ConvertFrom-Json))[0]
 if($g.HostConfig.Memory -ne 256MB -or $g.HostConfig.MemorySwap -ne 256MB -or $g.HostConfig.NetworkMode -cne 'none' -or !$g.HostConfig.ReadonlyRootfs -or $g.Config.User -cne '1000:1000' -or $g.HostConfig.Privileged -or $g.HostConfig.CapAdd -or $g.HostConfig.CapDrop -notcontains 'ALL' -or $g.HostConfig.SecurityOpt -notcontains 'no-new-privileges:true'){throw 'GUARD'}
 Native 'start' @('start','-a',$id)|Out-Null
 $g=@((Native 'exited' @('inspect',$id)|ConvertFrom-Json))[0]
 if($g.State.Running -or $g.State.ExitCode -ne 0 -or $g.State.OOMKilled){throw 'CONTAINER_EXIT'}
 foreach($p in @($pins)+@($codePins)){if((Get-FileHash -LiteralPath $p.path).Hash.ToLowerInvariant() -cne $p.sha256){throw 'HASH_CHANGED'}}
 $pass=$true
}catch{@{status='FAIL';code=$(if($_.Exception.Message -cmatch '^[A-Z_]{1,50}$'){$_.Exception.Message}else{'PROBE_ERROR'});utc=[DateTimeOffset]::UtcNow.ToString('o')}|ConvertTo-Json|Set-Content "$ev/error.json"}
finally{
 if($id){try{$g=@((Native 'cleanup-owner' @('inspect',$id)|ConvertFrom-Json))[0];if($g.Config.Labels.'com.wed-snap.run' -cne $run){throw 'OWNER'};Native 'remove-own' @('rm','-f',$id)|Out-Null;if(Native 'absence' @('ps','-aq','--filter',"label=com.wed-snap.run=$run")){throw 'LEFT'};$closed=$true}catch{$closed=$false}}
 @{status=$(if($pass -and $closed){'PASS_PROBE_ONLY'}else{'FAIL_PROBE'});mode=$Mode;runID=$run;ownContainer=$id;ownResourcesLeft=$(if($closed){0}else{'UNKNOWN'});deadlineSeconds=60;network='none';sourceCalls=0;utc=[DateTimeOffset]::UtcNow.ToString('o')}|ConvertTo-Json|Set-Content "$ev/completion.json"
}
if(!$pass -or !$closed){exit 1}
