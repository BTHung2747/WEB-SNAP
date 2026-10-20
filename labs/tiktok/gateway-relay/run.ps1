$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
$ev='docs/evidence/ui-gateway-relay-20261016';if(Test-Path -LiteralPath $ev){throw 'REFUSE_REUSE'};New-Item -ItemType Directory -Path "$ev/backend","$ev/gateway"|Out-Null
$begin=[DateTimeOffset]::UtcNow;$end=$begin.AddSeconds(150);$cleanupEnd=$null;$run=[Guid]::NewGuid().ToString('N');$ids=@();$nets=@();$cleanupOK=$true;$measured=$false;$nativeClosed=$true
$image='sha256:d4558b29dd379b16d4906fb9e618dfc4d045e3008a70e031ea3474b7b2218e4e'
function Native([string]$step,[string]$exe,[string[]]$arguments,[int]$cap=15000,[bool]$allowFail=$false){
 $at=[DateTimeOffset]::UtcNow;$until=if($cleanupEnd){$cleanupEnd}else{$end.AddSeconds(-20)};$wait=[int][Math]::Floor([Math]::Min($cap,($until-$at).TotalMilliseconds));if($wait -le 0){throw 'DEADLINE'}
 $info=[Diagnostics.ProcessStartInfo]::new($exe);$info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true;foreach($arg in $arguments){$info.ArgumentList.Add($arg)};$p=[Diagnostics.Process]::new();$p.StartInfo=$info
 try{if(!$p.Start()){throw 'NATIVE_START'};$o=$p.StandardOutput.ReadToEndAsync();$e=$p.StandardError.ReadToEndAsync();$timeout=!$p.WaitForExit($wait);if($timeout){$p.Kill($true);$p.WaitForExit(1000)|Out-Null};$output=$o.GetAwaiter().GetResult()+$e.GetAwaiter().GetResult();$exit=if($p.HasExited){$p.ExitCode}else{$null};if($output.Length -gt 262144){$output='OUTPUT_CAP';$timeout=$true}
  @{step=$step;executable=$exe;arguments=$arguments;actualExit=$exit;timedOut=$timeout;waitMs=$wait;utcStart=$at.ToString('o');utcEnd=[DateTimeOffset]::UtcNow.ToString('o');output=$output}|ConvertTo-Json -Depth 6 -Compress|Add-Content -LiteralPath "$ev/native.jsonl"
  if(($timeout -or $exit -ne 0) -and !$allowFail){throw 'NATIVE_FAILED'};return $output.Trim()
 }finally{$p.Dispose()}
}
function Inspect([string]$step,[string]$id){return @((Native $step 'docker' @('inspect',$id)|ConvertFrom-Json))[0]}
function Guard($g,[int]$networks,[bool]$publish){
 if($g.Config.Labels.'com.wed-snap.run' -cne $run -or $g.Config.User -cne '1000:1000' -or !$g.HostConfig.ReadonlyRootfs -or $g.HostConfig.Privileged -or $g.HostConfig.CapAdd -or $g.HostConfig.CapDrop -notcontains 'ALL' -or $g.HostConfig.SecurityOpt -notcontains 'no-new-privileges:true' -or $g.HostConfig.Memory -ne 128MB -or $g.HostConfig.MemorySwap -ne 128MB -or @($g.NetworkSettings.Networks.PSObject.Properties).Count -ne $networks){throw 'CONTAINER_GUARD'}
 $ports=@($g.HostConfig.PortBindings.PSObject.Properties);if($publish){if($ports.Count -ne 1 -or $ports[0].Value[0].HostIp -cne '127.0.0.1' -or $ports[0].Value[0].HostPort -cne '5206'){throw 'PUBLISH_GUARD'}}elseif($ports.Count){throw 'BACKEND_PUBLISH'}
}
function Create([string]$role,[string]$network,[string]$script,[string[]]$extra){
 Native "create-$role" 'docker' (@('create','--pull=never','--label',"com.wed-snap.run=$run",'--network',$network,'--ipc','private','--read-only','--user','1000:1000','--memory','128m','--memory-swap','128m','--cpus','0.25','--pids-limit','48','--cap-drop','ALL','--security-opt','no-new-privileges:true','--tmpfs','/tmp:size=8m,nosuid','-e',"PROBE_RUN=$run",'-e','NODE_OPTIONS=--max-old-space-size=48','--mount',"type=bind,source=$((Resolve-Path labs/tiktok/gateway-reachability).Path),target=/probe,readonly",'--mount',"type=bind,source=$((Resolve-Path labs/tiktok/gateway-relay).Path),target=/relay,readonly",'--mount',"type=bind,source=$((Resolve-Path "$ev/$role").Path),target=/control")+$extra+@($image,'node',$script))
}
try{
 $listeners=@(Get-NetTCPConnection -State Listen -LocalPort 5206 -ErrorAction SilentlyContinue);@{port=5206;listeners=$listeners.Count;utc=[DateTimeOffset]::UtcNow.ToString('o')}|ConvertTo-Json|Set-Content "$ev/port.json";if($listeners.Count){throw 'PORT_BUSY'}
 if((Native 'cache' 'docker' @('image','inspect',$image,'--format','{{.Id}}')) -cne $image){throw 'IMAGE_ID'}
 $oldManifest=Get-Content docs/evidence/ui-gateway-reachability-20261016/manifest.json -Raw|ConvertFrom-Json;foreach($pin in $oldManifest.implementation){if((Get-FileHash -LiteralPath $pin.path).Hash.ToLowerInvariant() -cne $pin.sha256){throw 'HISTORY_CHANGED'}}
 $files=@(Get-ChildItem labs/tiktok/gateway-relay -File)+@(Get-Item labs/tiktok/gateway-reachability/server.cjs,labs/tiktok/gateway-reachability/client.cjs,labs/tiktok/gateway-reachability/host.ps1)
 $pins=@($files|Sort-Object FullName|ForEach-Object{@{path=[IO.Path]::GetRelativePath((Get-Location).Path,$_.FullName).Replace('\','/');sha256=(Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant()}});$pins|ConvertTo-Json|Set-Content "$ev/implementation.json"
 $internal=Native 'internal-create' 'docker' @('network','create','--internal','--label',"com.wed-snap.run=$run",("relay-backend-$run"));$nets+=,$internal
 $ingress=Native 'ingress-create' 'docker' @('network','create','--driver','bridge','--label',"com.wed-snap.run=$run",("relay-ingress-$run"));$nets+=,$ingress
 $backend=Create 'backend' $internal '/probe/server.cjs' @();$ids+=,$backend;Guard (Inspect 'guard-backend' $backend) 1 $false
 Native 'start-backend' 'docker' @('start',$backend)|Out-Null
 $ready=[DateTimeOffset]::UtcNow.AddSeconds(10);while(!(Test-Path "$ev/backend/listen.json") -and [DateTimeOffset]::UtcNow -lt $ready){Start-Sleep -Milliseconds 100};if(!(Test-Path "$ev/backend/listen.json")){throw 'BACKEND_LISTEN'}
 $g=Inspect 'backend-running' $backend;$backendNetwork=@($g.NetworkSettings.Networks.PSObject.Properties|Where-Object{$_.Value.NetworkID -ceq $internal});if($backendNetwork.Count -ne 1){throw 'INTERNAL_ID'};$upstream=$backendNetwork[0].Value.IPAddress;$address=$null;if(![Net.IPAddress]::TryParse($upstream,[ref]$address) -or $address.AddressFamily -ne [Net.Sockets.AddressFamily]::InterNetwork){throw 'UPSTREAM_IP'}
 Native 'backend-http-once' 'docker' @('exec',$backend,'node','/probe/client.cjs') 7000 $true|Out-Null
 $gateway=Create 'gateway' $ingress '/relay/gateway.cjs' @('-p','127.0.0.1:5206:5206','-e',"MARKER_IPV4=$upstream");$ids+=,$gateway
 Native 'gateway-internal-connect' 'docker' @('network','connect',$internal,$gateway)|Out-Null;Guard (Inspect 'guard-gateway' $gateway) 2 $true
 Native 'start-gateway' 'docker' @('start',$gateway)|Out-Null
 $ready=[DateTimeOffset]::UtcNow.AddSeconds(10);while(!(Test-Path "$ev/gateway/listen.json") -and [DateTimeOffset]::UtcNow -lt $ready){Start-Sleep -Milliseconds 100};if(!(Test-Path "$ev/gateway/listen.json")){throw 'GATEWAY_LISTEN'}
 $g=Inspect 'gateway-running' $gateway;Guard $g 2 $true;$runtimePorts=@($g.NetworkSettings.Ports.'5206/tcp');if($runtimePorts.Count -ne 1 -or $runtimePorts[0].HostIp -cne '127.0.0.1' -or $runtimePorts[0].HostPort -cne '5206'){throw 'RUNTIME_PUBLISH_MISSING'}
 $ni=@((Native 'internal-members' 'docker' @('network','inspect',$internal)|ConvertFrom-Json))[0];$ne=@((Native 'ingress-members' 'docker' @('network','inspect',$ingress)|ConvertFrom-Json))[0]
 $members=@($ni.Containers.PSObject.Properties.Name);$outer=@($ne.Containers.PSObject.Properties.Name)
 if(!$ni.Internal -or $ne.Internal -or $members.Count -ne 2 -or $members -cnotcontains $backend -or $members -cnotcontains $gateway -or $outer.Count -ne 1 -or $outer[0] -cne $gateway){throw 'NETWORK_MEMBERS'}
 @{backend=$backend;gateway=$gateway;internal=$internal;ingress=$ingress;backendIPv4=$upstream;runtimePublish=$runtimePorts;internalMembers=$members;ingressMembers=$outer;containerLimitMiB=256;user='1000:1000';rootfsRO=$true;capDrop='ALL';NNP=$true;memorySwapEqualsMemory=$true;ingressHasOutsideRoute=$true;outsideNetworkIsolationProof='NOT_CLAIMED';sourceCalls=0;publicDNSQueries=0;claimsCreated=0}|ConvertTo-Json -Depth 5|Set-Content "$ev/topology.json"
 Native 'windows-http-once' (Get-Process -Id $PID).Path @('-NoProfile','-File',((Resolve-Path labs/tiktok/gateway-reachability/host.ps1).Path),'-RunID',$run,'-Evidence',((Resolve-Path $ev).Path)) 5000 $true|Out-Null
 if(!(Test-Path "$ev/host.json")){@{status='FAIL';code='HOST_WATCHDOG_OR_PROCESS';timeoutSeconds=5}|ConvertTo-Json|Set-Content "$ev/host.json"}
 if((Get-Content "$ev/host.json" -Raw|ConvertFrom-Json).status -ceq 'PASS'){
  @{url='http://127.0.0.1:5206/reachability';marker="WED_SNAP_REACHABILITY_$run";runID=$run}|ConvertTo-Json|Set-Content "$ev/browser.ready";Write-Output 'BROWSER_READY http://127.0.0.1:5206/reachability'
  $browserEnd=[DateTimeOffset]::UtcNow.AddSeconds(45);while(!(Test-Path "$ev/browser.json") -and [DateTimeOffset]::UtcNow -lt $browserEnd){Start-Sleep -Milliseconds 100}
  if(!(Test-Path "$ev/browser.json")){@{status='NOT_OBSERVED';code='BROWSER_DEADLINE';tabCleanup='UNKNOWN'}|ConvertTo-Json|Set-Content "$ev/browser.json"}
 }else{@{status='NOT_RUN';reason='HOST_HTTP_FAILED';tabCreated=$false}|ConvertTo-Json|Set-Content "$ev/browser.json"}
 $measured=$true
 foreach($pin in $pins){if((Get-FileHash -LiteralPath $pin.path).Hash.ToLowerInvariant() -cne $pin.sha256){throw 'SOURCE_CHANGED'}}
}catch{@{code=$(if($_.Exception.Message -cmatch '^[A-Z_]{1,50}$'){$_.Exception.Message}else{'ORCHESTRATOR_ERROR'});utc=[DateTimeOffset]::UtcNow.ToString('o')}|ConvertTo-Json|Set-Content "$ev/error.json";$measured=$false
}finally{
 $cleanupAt=[DateTimeOffset]::UtcNow;$cleanupEnd=$cleanupAt.AddSeconds(20);if($cleanupEnd -gt $end){$cleanupEnd=$end}
 foreach($id in @($ids|Select-Object -Last 1)+@($ids|Select-Object -First 1)|Select-Object -Unique){try{$g=Inspect 'owner' $id;if($g.Config.Labels.'com.wed-snap.run' -cne $run){throw 'OWNER'};Native 'stop' 'docker' @('stop','--time','3',$id)|Out-Null;$s=Inspect 'state' $id;@{id=$id;exit=$s.State.ExitCode;running=$s.State.Running;OOM=$s.State.OOMKilled;started=$s.State.StartedAt;finished=$s.State.FinishedAt}|ConvertTo-Json|Set-Content "$ev/state-$id.json";if($s.State.ExitCode -ne 0 -or $s.State.OOMKilled){$nativeClosed=$false};Native 'remove' 'docker' @('rm',$id)|Out-Null}catch{$cleanupOK=$false}}
 foreach($net in $nets){try{$n=@((Native 'network-owner' 'docker' @('network','inspect',$net)|ConvertFrom-Json))[0];if($n.Labels.'com.wed-snap.run' -cne $run){throw 'OWNER'};Native 'network-remove' 'docker' @('network','rm',$net)|Out-Null}catch{$cleanupOK=$false}}
 try{if((Native 'absent' 'docker' @('ps','-aq','--filter',"label=com.wed-snap.run=$run")) -or (Native 'networks-absent' 'docker' @('network','ls','-q','--filter',"label=com.wed-snap.run=$run"))){$cleanupOK=$false}}catch{$cleanupOK=$false}
 @{runID=$run;containers=$ids;networks=$nets;ownResourcesLeft=$(if($cleanupOK){0}else{'UNKNOWN'});elapsedSeconds=([DateTimeOffset]::UtcNow-$cleanupAt).TotalSeconds;limitSeconds=20}|ConvertTo-Json -Depth 4|Set-Content "$ev/cleanup.json"
 $elapsed=([DateTimeOffset]::UtcNow-$begin).TotalSeconds
 @{status=$(if($measured -and $cleanupOK -and $nativeClosed -and $elapsed -le 150){'MEASURED_MARKER_RELAY_ONLY'}else{'FAIL_OR_UNKNOWN'});nativeOrchestratorExit=$(if($measured -and $cleanupOK -and $nativeClosed -and $elapsed -le 150){0}else{1});elapsedSeconds=$elapsed;limitSeconds=150;sourceCalls=0;publicDNSQueries=0;claimsCreated=0;utc=[DateTimeOffset]::UtcNow.ToString('o');vn=[DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(7)).ToString('o')}|ConvertTo-Json|Set-Content "$ev/completion.json"
}
if(!$measured -or !$cleanupOK -or !$nativeClosed -or $elapsed -gt 150){exit 1}
