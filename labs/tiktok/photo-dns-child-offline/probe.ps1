param([ValidateSet('baseline','corrected','negative')][string]$Mode='baseline',[ValidateRange(1,20)][int]$Attempt=1)
$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
$ev="docs/evidence/tiktok-dns-child-offline-20261015/$Mode-$Attempt";if(Test-Path $ev){throw 'Refuse reuse'};New-Item -ItemType Directory $ev|Out-Null
$run=[Guid]::NewGuid().ToString('N');$id=$null;$image='sha256:8bc0a567955111ea3cfbab2dd3b14f40a602f2d10ac987e78eb465f9d48d7f10'
function Native([string]$step,[string[]]$argv){
 $start=[DateTimeOffset]::UtcNow;$p=[Diagnostics.ProcessStartInfo]::new('docker');$p.UseShellExecute=$false;$p.CreateNoWindow=$true;$p.RedirectStandardOutput=$true;$p.RedirectStandardError=$true;foreach($a in $argv){$p.ArgumentList.Add($a)};$c=[Diagnostics.Process]::Start($p)
 try{$o=$c.StandardOutput.ReadToEndAsync();$e=$c.StandardError.ReadToEndAsync();$timeout=!$c.WaitForExit(30000);if($timeout){$c.Kill($true);$c.WaitForExit(1000)|Out-Null};$out=$o.GetAwaiter().GetResult()+$e.GetAwaiter().GetResult();$exit=if($c.HasExited){$c.ExitCode}else{$null};@{step=$step;arguments=$argv;actualExit=$exit;timedOut=$timeout;utcStart=$start.ToString('o');utcEnd=[DateTimeOffset]::UtcNow.ToString('o');output=$out}|ConvertTo-Json -Compress -Depth 6|Add-Content "$ev/native.jsonl";if($timeout -or $exit -ne 0){throw "NATIVE_$step"};return $out.Trim()}finally{$c.Dispose()}
}
try{
 $tools=@(Get-ChildItem labs/tiktok/photo-dns-child-offline -Recurse -File|ForEach-Object{@{path=[IO.Path]::GetRelativePath((Resolve-Path labs/tiktok/photo-dns-child-offline).Path,$_.FullName).Replace('\','/');sha256=(Get-FileHash $_.FullName).Hash.ToLowerInvariant()}});$tools|ConvertTo-Json|Set-Content "$ev/test-source.json"
 New-Item -ItemType Directory "$ev/tested-tools"|Out-Null;foreach($r in $tools){$to="$ev/tested-tools/$($r.path)";New-Item -ItemType Directory -Force (Split-Path $to)|Out-Null;Copy-Item "labs/tiktok/photo-dns-child-offline/$($r.path)" $to}
 Native 'cache' @('image','inspect',$image)|Set-Content "$ev/cache.json"
 $envArgs=@('-e','PYTHONDONTWRITEBYTECODE=1','-e','TIKTOK_EGRESS_POLICY_ENABLED=1')
 if($Mode -eq 'negative'){$envArgs+=@('-e','PYTHONPATH=/nonexistent-pinned-path')}
 $mounts=@();foreach($pair in @(@('apps/egress','/repo/apps/egress'),@('labs/tiktok/photo-dns-child-offline/common','/lab'),@('labs/tiktok/photo-dns-child-offline/probe','/probe'))){$mounts+=@('--mount',"type=bind,source=$((Resolve-Path $pair[0]).Path),target=$($pair[1]),readonly")}
 $mounts+=@('--mount',"type=bind,source=$((Resolve-Path $ev).Path),target=/control")
 $id=Native 'create' (@('create','--pull=never','--label',"com.wed-snap.run=$run",'--network','none','--ipc','private','--read-only','--user','65534:65534','--memory','96m','--memory-swap','96m','--cpus','0.25','--pids-limit','96','--cap-drop','ALL','--security-opt','no-new-privileges:true','--tmpfs','/tmp:size=8m,nosuid','--workdir','/app')+$envArgs+$mounts+@($image,'/usr/bin/timeout','--signal=KILL','25s','python','-I','/probe/main.py',$Mode))
 Native 'guard' @('inspect',$id)|Set-Content "$ev/guard.json"
 Native 'test' @('start','-a',$id)|Out-Null
 Native 'state' @('inspect',$id)|Set-Content "$ev/state.json"
 foreach($r in $tools){if((Get-FileHash "labs/tiktok/photo-dns-child-offline/$($r.path)").Hash.ToLowerInvariant() -cne $r.sha256){throw 'Tool changed'}}
 @{status='PASS_PROBE_EXECUTED_NOT_DNS_NETWORK_PASS';actualExit=0;mode=$Mode;sourceRequests=0;utc=[DateTimeOffset]::UtcNow.ToString('o');vn=[DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(7)).ToString('o')}|ConvertTo-Json|Set-Content "$ev/completion.json"
}finally{
 $begin=[DateTimeOffset]::UtcNow
 if($id){$g=@((Native 'owner' @('inspect',$id)|ConvertFrom-Json))[0];if($g.Config.Labels.'com.wed-snap.run' -cne $run){throw 'Owner mismatch'};Native 'remove' @('rm','-f',$id)|Out-Null}
 $left=Native 'absent' @('ps','-aq','--filter',"label=com.wed-snap.run=$run");if($left){throw 'Resources remain'}
 @{ownResourcesLeft=0;container=$id;run=$run;networksCreated=0;cleanupSeconds=([DateTimeOffset]::UtcNow-$begin).TotalSeconds;sourceRequests=0}|ConvertTo-Json|Set-Content "$ev/cleanup.json"
}
