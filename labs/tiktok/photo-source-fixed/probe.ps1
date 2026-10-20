param([ValidateRange(1,20)][int]$Probe=1)
$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
$lab='labs/tiktok/photo-source-fixed';$ev="docs/evidence/tiktok-photo-source-fixed-20261015/probe-$Probe"
if(Test-Path $ev){throw 'Refuse reuse'}
foreach($r in @((Get-Content "$lab/source-pins.json" -Raw|ConvertFrom-Json)+(Get-Content "$lab/tool-dependencies.json" -Raw|ConvertFrom-Json))){if((Get-FileHash -LiteralPath $r.path).Hash.ToLowerInvariant() -cne $r.sha256){throw 'PIN_MISMATCH'}}
. "$lab/mounts.ps1"
New-Item -ItemType Directory $ev|Out-Null;$run=[Guid]::NewGuid().ToString('N');$id=$null
function Native([string]$step,[string[]]$argv){
 $start=[DateTimeOffset]::UtcNow;$s=[Diagnostics.ProcessStartInfo]::new('docker');$s.UseShellExecute=$false;$s.CreateNoWindow=$true;$s.RedirectStandardOutput=$true;$s.RedirectStandardError=$true;foreach($a in $argv){$s.ArgumentList.Add($a)};$p=[Diagnostics.Process]::Start($s)
 try{$o=$p.StandardOutput.ReadToEndAsync();$e=$p.StandardError.ReadToEndAsync();$timeout=!$p.WaitForExit(30000);if($timeout){$p.Kill($true);$p.WaitForExit(1000)|Out-Null};$out=$o.GetAwaiter().GetResult()+$e.GetAwaiter().GetResult();$exit=if($p.HasExited){$p.ExitCode}else{$null};@{step=$step;arguments=$argv;actualExit=$exit;timedOut=$timeout;utcStart=$start.ToString('o');utcEnd=[DateTimeOffset]::UtcNow.ToString('o');output=$out}|ConvertTo-Json -Compress -Depth 7|Add-Content "$ev/native.jsonl";if($timeout -or $exit -ne 0){throw "NATIVE_$step"};return $out.Trim()}finally{$p.Dispose()}
}
try{
 $tools=@(Get-ChildItem $lab -File|ForEach-Object{@{path=[IO.Path]::GetRelativePath((Resolve-Path $lab).Path,$_.FullName).Replace('\','/');sha256=(Get-FileHash $_.FullName).Hash.ToLowerInvariant()}});$tools|ConvertTo-Json|Set-Content "$ev/test-source.json";New-Item -ItemType Directory "$ev/tested-tools"|Out-Null;foreach($r in $tools){Copy-Item "$lab/$($r.path)" "$ev/tested-tools/$($r.path)"}
 $image='sha256:8bc0a567955111ea3cfbab2dd3b14f40a602f2d10ac987e78eb465f9d48d7f10';Native 'cache' @('image','inspect',$image)|Set-Content "$ev/cache.json"
 $mounts=@(ProxyMounts)+@(FrozenMount $lab '/probe')+@('--mount',"type=bind,source=$((Resolve-Path $ev).Path),target=/control")
 $id=Native 'create' (@('create','--pull=never','--label',"com.wed-snap.run=$run",'--network','none','--ipc','private','--read-only','--user','65534:65534','--memory','96m','--memory-swap','96m','--cpus','0.25','--pids-limit','96','--cap-drop','ALL','--security-opt','no-new-privileges:true','--tmpfs','/tmp:size=8m,nosuid','--workdir','/app','-e','PYTHONDONTWRITEBYTECODE=1','-e','TIKTOK_EGRESS_POLICY_ENABLED=1')+$mounts+@($image,'/usr/bin/timeout','--signal=KILL','28s','python','-I','/probe/wiring_probe.py'))
 Native 'guard' @('inspect',$id)|Set-Content "$ev/guard.json";Native 'test' @('start','-a',$id)|Out-Null;Native 'state' @('inspect',$id)|Set-Content "$ev/state.json"
 foreach($r in $tools){if((Get-FileHash "$lab/$($r.path)").Hash.ToLowerInvariant() -cne $r.sha256){throw 'Tool changed'}}
 @{actualExit=0;status='PASS_WIRING_OFFLINE_ONLY';sourceRequestsNew=0;sourceGrantNew=$false;utc=[DateTimeOffset]::UtcNow.ToString('o');vn=[DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(7)).ToString('o')}|ConvertTo-Json|Set-Content "$ev/completion.json"
}finally{
 $at=[DateTimeOffset]::UtcNow
 if($id){$g=@((Native 'owner' @('inspect',$id)|ConvertFrom-Json))[0];if($g.Config.Labels.'com.wed-snap.run' -cne $run){throw 'Owner mismatch'};Native 'remove' @('rm','-f',$id)|Out-Null}
 $left=Native 'absent' @('ps','-aq','--filter',"label=com.wed-snap.run=$run");if($left){throw 'Owned resources remain'}
 @{ownResourcesLeft=0;networksCreated=0;container=$id;run=$run;cleanupSeconds=([DateTimeOffset]::UtcNow-$at).TotalSeconds;sourceRequestsNew=0}|ConvertTo-Json|Set-Content "$ev/cleanup.json"
}
