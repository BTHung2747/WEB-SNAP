$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
$ev='docs/evidence/ui-gateway-reachability-20261016';if(Test-Path -LiteralPath $ev){throw 'REFUSE_REUSE'};New-Item -ItemType Directory -Path $ev|Out-Null
$begin=[DateTimeOffset]::UtcNow;$end=$begin.AddSeconds(120);$cleanupEnd=$null;$run=[Guid]::NewGuid().ToString('N');$id=$null;$net=$null;$cleanupOK=$true;$measured=$false
$image='sha256:d4558b29dd379b16d4906fb9e618dfc4d045e3008a70e031ea3474b7b2218e4e'
function Native([string]$step,[string]$executable,[string[]]$arguments,[int]$cap=15000,[bool]$allowFail=$false){
 $at=[DateTimeOffset]::UtcNow;$until=if($cleanupEnd){$cleanupEnd}else{$end.AddSeconds(-20)};$wait=[int][Math]::Floor([Math]::Min($cap,($until-$at).TotalMilliseconds));if($wait -le 0){throw 'DEADLINE'}
 $info=[Diagnostics.ProcessStartInfo]::new($executable);$info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true;foreach($arg in $arguments){$info.ArgumentList.Add($arg)}
 $p=[Diagnostics.Process]::new();$p.StartInfo=$info
 try{if(!$p.Start()){throw 'NATIVE_START'};$o=$p.StandardOutput.ReadToEndAsync();$e=$p.StandardError.ReadToEndAsync();$timeout=!$p.WaitForExit($wait);if($timeout){$p.Kill($true);$p.WaitForExit(1000)|Out-Null};$output=$o.GetAwaiter().GetResult()+$e.GetAwaiter().GetResult();$exit=if($p.HasExited){$p.ExitCode}else{$null};if($output.Length -gt 262144){$output='OUTPUT_CAP';$timeout=$true}
  @{step=$step;executable=$executable;arguments=$arguments;actualExit=$exit;timedOut=$timeout;waitMs=$wait;utcStart=$at.ToString('o');utcEnd=[DateTimeOffset]::UtcNow.ToString('o');output=$output}|ConvertTo-Json -Depth 6 -Compress|Add-Content -LiteralPath "$ev/native.jsonl"
  if(($timeout -or $exit -ne 0) -and !$allowFail){throw 'NATIVE_FAILED'};return $output.Trim()
 }finally{$p.Dispose()}
}
try{
 $listeners=@(Get-NetTCPConnection -State Listen -LocalPort 5206 -ErrorAction SilentlyContinue);@{port=5206;listeners=$listeners.Count;utc=[DateTimeOffset]::UtcNow.ToString('o')}|ConvertTo-Json|Set-Content "$ev/port.json";if($listeners.Count){throw 'PORT_BUSY'}
 $cached=Native 'cache' 'docker' @('image','inspect',$image,'--format','{{.Id}}');if($cached -cne $image){throw 'IMAGE_ID'}
 $pins=@(Get-ChildItem labs/tiktok/gateway-reachability -File|Sort-Object Name|ForEach-Object{@{path=[IO.Path]::GetRelativePath((Get-Location).Path,$_.FullName).Replace('\','/');sha256=(Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant()}});$pins|ConvertTo-Json|Set-Content "$ev/implementation.json"
 $net=Native 'network-create' 'docker' @('network','create','--internal','--label',"com.wed-snap.run=$run",("gateway-reachability-$run"))
 $id=Native 'container-create' 'docker' @('create','--pull=never','--label',"com.wed-snap.run=$run",'--network',$net,'--ipc','private','--read-only','--user','1000:1000','--memory','128m','--memory-swap','128m','--cpus','0.25','--pids-limit','48','--cap-drop','ALL','--security-opt','no-new-privileges:true','--tmpfs','/tmp:size=8m,nosuid','-p','127.0.0.1:5206:5206','-e',"PROBE_RUN=$run",'-e','NODE_OPTIONS=--max-old-space-size=48','--mount',"type=bind,source=$((Resolve-Path labs/tiktok/gateway-reachability).Path),target=/probe,readonly",'--mount',"type=bind,source=$((Resolve-Path $ev).Path),target=/control",$image,'node','/probe/server.cjs')
 $g=@((Native 'container-guard' 'docker' @('inspect',$id)|ConvertFrom-Json))[0];$n=@((Native 'network-guard' 'docker' @('network','inspect',$net)|ConvertFrom-Json))[0]
 $port=$g.HostConfig.PortBindings.'5206/tcp'[0]
 if(!$n.Internal -or $g.Config.Labels.'com.wed-snap.run' -cne $run -or $g.Config.User -cne '1000:1000' -or !$g.HostConfig.ReadonlyRootfs -or $g.HostConfig.Privileged -or $g.HostConfig.CapAdd -or $g.HostConfig.CapDrop -notcontains 'ALL' -or $g.HostConfig.SecurityOpt -notcontains 'no-new-privileges:true' -or $g.HostConfig.Memory -ne 128MB -or $g.HostConfig.MemorySwap -ne 128MB -or @($g.NetworkSettings.Networks.PSObject.Properties).Count -ne 1 -or @($g.HostConfig.PortBindings.PSObject.Properties).Count -ne 1 -or $port.HostIp -cne '127.0.0.1' -or $port.HostPort -cne '5206'){throw 'GUARD'}
 @{id=$id;network=$net;internal=$n.Internal;user=$g.Config.User;readonly=$g.HostConfig.ReadonlyRootfs;capDrop=$g.HostConfig.CapDrop;security=$g.HostConfig.SecurityOpt;memory=$g.HostConfig.Memory;memorySwap=$g.HostConfig.MemorySwap;CPUNanos=$g.HostConfig.NanoCpus;pids=$g.HostConfig.PidsLimit;IPC=$g.HostConfig.IpcMode;publish=$port}|ConvertTo-Json -Depth 4|Set-Content "$ev/guard.json"
 Native 'start' 'docker' @('start',$id)|Out-Null
 $ready=[DateTimeOffset]::UtcNow.AddSeconds(10);while(!(Test-Path "$ev/listen.json") -and [DateTimeOffset]::UtcNow -lt $ready){Start-Sleep -Milliseconds 100};if(!(Test-Path "$ev/listen.json")){throw 'LISTEN_NOT_OBSERVED'}
 Native 'container-http-once' 'docker' @('exec',$id,'node','/probe/client.cjs') 7000 $true|Out-Null
 $shell=(Get-Process -Id $PID).Path
 Native 'windows-http-once' $shell @('-NoProfile','-File',((Resolve-Path labs/tiktok/gateway-reachability/host.ps1).Path),'-RunID',$run,'-Evidence',((Resolve-Path $ev).Path)) 5000 $true|Out-Null
 if(!(Test-Path "$ev/host.json")){@{status='FAIL';code='HOST_WATCHDOG_OR_PROCESS';timeoutSeconds=5;httpStatus=$null;markerMatch=$false}|ConvertTo-Json|Set-Content "$ev/host.json"}
 $hostResult=Get-Content "$ev/host.json" -Raw|ConvertFrom-Json
 if($hostResult.status -ceq 'PASS'){
  @{origin='http://127.0.0.1:5206';url='http://127.0.0.1:5206/reachability';marker="WED_SNAP_REACHABILITY_$run"}|ConvertTo-Json|Set-Content "$ev/browser.ready";Write-Output 'BROWSER_READY http://127.0.0.1:5206/reachability'
  while(!(Test-Path "$ev/browser.json") -and [DateTimeOffset]::UtcNow -lt $end.AddSeconds(-25)){Start-Sleep -Milliseconds 100}
  if(!(Test-Path "$ev/browser.json")){@{status='NOT_OBSERVED';code='BROWSER_DEADLINE';tabCleanup='UNKNOWN'}|ConvertTo-Json|Set-Content "$ev/browser.json"}
 }else{@{status='NOT_RUN';reason='HOST_HTTP_FAILED';tabCreated=$false;tabCleanup='NOT_APPLICABLE'}|ConvertTo-Json|Set-Content "$ev/browser.json"}
 $measured=$true
}catch{
 @{code=$(if($_.Exception.Message -cmatch '^[A-Z_]{1,50}$'){$_.Exception.Message}else{'ORCHESTRATOR_ERROR'});utc=[DateTimeOffset]::UtcNow.ToString('o')}|ConvertTo-Json|Set-Content "$ev/error.json"
}finally{
 $cleanupAt=[DateTimeOffset]::UtcNow;$cleanupEnd=$cleanupAt.AddSeconds(20);if($cleanupEnd -gt $end){$cleanupEnd=$end}
 if($id){try{$g=@((Native 'owner' 'docker' @('inspect',$id)|ConvertFrom-Json))[0];if($g.Config.Labels.'com.wed-snap.run' -cne $run){throw 'OWNER'};Native 'stop' 'docker' @('stop','--time','3',$id)|Out-Null;$s=@((Native 'state' 'docker' @('inspect',$id)|ConvertFrom-Json))[0];@{exit=$s.State.ExitCode;running=$s.State.Running;OOM=$s.State.OOMKilled;started=$s.State.StartedAt;finished=$s.State.FinishedAt}|ConvertTo-Json|Set-Content "$ev/state.json";Native 'remove' 'docker' @('rm',$id)|Out-Null}catch{$cleanupOK=$false}}
 if($net){try{$n=@((Native 'network-owner' 'docker' @('network','inspect',$net)|ConvertFrom-Json))[0];if($n.Labels.'com.wed-snap.run' -cne $run){throw 'OWNER'};Native 'network-remove' 'docker' @('network','rm',$net)|Out-Null}catch{$cleanupOK=$false}}
 try{if((Native 'absent' 'docker' @('ps','-aq','--filter',"label=com.wed-snap.run=$run")) -or (Native 'networks-absent' 'docker' @('network','ls','-q','--filter',"label=com.wed-snap.run=$run"))){$cleanupOK=$false}}catch{$cleanupOK=$false}
 @{runID=$run;container=$id;network=$net;ownResourcesLeft=$(if($cleanupOK){0}else{'UNKNOWN'});elapsedSeconds=([DateTimeOffset]::UtcNow-$cleanupAt).TotalSeconds;limitSeconds=20}|ConvertTo-Json|Set-Content "$ev/cleanup.json"
 $elapsed=([DateTimeOffset]::UtcNow-$begin).TotalSeconds
 @{status=$(if($measured -and $cleanupOK -and $elapsed -le 120){'MEASURED_SEE_THREE_POINTS_NOT_E2E'}else{'FAIL_OR_UNKNOWN'});nativeOrchestratorExit=$(if($measured -and $cleanupOK -and $elapsed -le 120){0}else{1});totalElapsedSeconds=$elapsed;limitSeconds=120;sourceCalls=0;claimsCreated=0;publicDNSQueries=0;utc=[DateTimeOffset]::UtcNow.ToString('o');vn=[DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(7)).ToString('o')}|ConvertTo-Json|Set-Content "$ev/completion.json"
}
if(!$measured -or !$cleanupOK -or $elapsed -gt 120){exit 1}
