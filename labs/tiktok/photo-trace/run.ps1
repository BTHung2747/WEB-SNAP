param([ValidateSet('offline','live')][string]$Stage='offline',[int]$Attempt=1)
$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
. "$PSScriptRoot/hash_gate.ps1"
$root='docs/evidence/tiktok-photo-trace-integration-20261010'
$dir=if($Stage -eq 'offline'){"$root/offline-$Attempt"}else{"$root/sample-1"}
$image='sha256:31742091e95df2cc62669a6c6a9e0892dc09a34341eaeefc16959dcd4dfa417e'
function SHA($p){(Get-FileHash -LiteralPath $p).Hash.ToLower()}
function Save($p,$obj){$obj|ConvertTo-Json -Depth 40|Set-Content -LiteralPath $p}
function Snapshot{
 return @(foreach($p in @(rg --files labs/tiktok/photo-trace labs/tiktok/photo labs/tiktok/setup-trace apps/media/src/tiktok apps/media/requirements.lock apps/egress/src/egress.py)){
  [pscustomobject][ordered]@{path=$p.Replace('\','/');sha256=SHA $p}
 })|Sort-Object path
}
$hashes=@(Snapshot);$snapshotJSON=Convert-TraceSnapshot $hashes
if(Test-Path $dir){throw 'Refuse evidence/source trial reuse'}
if($Stage -eq 'live'){
 $receipt=Get-Content "$root/offline-$Attempt/receipt.json" -Raw|ConvertFrom-Json
 if($receipt.actualExit -ne 0 -or $receipt.image -cne $image -or $receipt.snapshotJSON -cne $snapshotJSON){throw 'Exact whole wiring offline source hash gate'}
 foreach($f in $receipt.artifacts){if((SHA "$root/offline-$Attempt/$($f.path)") -cne $f.sha256){throw 'Offline receipt artifact gate'}}
 $offline=Get-Content "$root/offline-$Attempt/worker/integration-result.json" -Raw|ConvertFrom-Json
 $trace=Get-Content "$root/offline-$Attempt/validation/trace-validation.json" -Raw|ConvertFrom-Json
 if($offline.status -cne 'PASS' -or $offline.sourceCalls -ne 0 -or $trace.status -cne 'PASS' -or -not $trace.proxySummaryComplete){throw 'Integration/trace gate'}
}
New-Item -ItemType Directory "$dir/proxy","$dir/worker","$dir/control","$dir/validation"|Out-Null
Save "$dir/source-hashes.json" $hashes
if($Stage -eq 'offline'){& "$PSScriptRoot/test-hash-gate.ps1" -Output "$dir/hash-gate-test.json"}
Save "$dir/budget.json" @{stage=$Stage;input='https://www.tiktok.com/@adne_la.veil/photo/7678209751167110421';expectedID='7678209751167110421';analyze=1;metadataGET=2;metadataDeadlineSeconds=30;metadataResponseBytes=8MB;metadataAggregateBytes=16MB;conditionalImageGET=1;prepareSeconds=60;imageInputBytes=20MB;imageOutputBytes=16MB;workflowInputBytes=36MB;connectSeconds=10;readSeconds=20;redirect=0;retry=0;HEAD=0;runtimeMiB=608;traceTotalCap=256;traceConnectionCap=32;image=$image;utc=[DateTime]::UtcNow.ToString('o')}
Save "$dir/control/control.json" @{case='network-normal';mode='normal'}
$run=[Guid]::NewGuid().ToString('N');$ids=@();$nets=@();$rc=1;$workerStarted=$false
function Native($step,[string[]]$argv,[switch]$AllowFailure){
 $start=[DateTime]::UtcNow;$text=& docker @argv 2>&1|Out-String;$exit=$LASTEXITCODE
 @{step=$step;actualExit=$exit;utcStart=$start.ToString('o');utcEnd=[DateTime]::UtcNow.ToString('o');stdout=$text}|ConvertTo-Json -Compress|Add-Content "$dir/native.jsonl"
 if($exit -and -not $AllowFailure){throw ('Docker:{0}:{1}' -f $step,$exit)}
 return @{text=$text.Trim();exit=$exit}
}
function TraceMountArg($path,$target,[switch]$RO){
 $value="type=bind,source=$((Resolve-Path -LiteralPath $path).Path),target=$target";if($RO){$value+=',readonly'};return $value
}
$sourceMounts=@('--mount',(TraceMountArg labs/tiktok/photo-trace /integration -RO),'--mount',(TraceMountArg labs/tiktok/photo /app/apps/media/src/tiktok/photo_lab -RO),'--mount',(TraceMountArg labs/tiktok/setup-trace /trace_lab -RO))
function Create($role,$ram,$cpu,$user,$pids,$network,$output,[string[]]$extra,[string[]]$command){
 $argv=@('create','--label','com.wed-snap.lab=tiktok-photo-trace','--label',"com.wed-snap.run=$run",'--label',"com.wed-snap.role=$role",
  '--network',$network,'--read-only','--user',$user,'--cap-drop','ALL','--security-opt','no-new-privileges:true','--memory',$ram,'--memory-swap',$ram,'--cpus',$cpu,'--pids-limit',$pids,'--ipc','private',
  '--tmpfs',$(if($user.StartsWith('65534')){'/tmp:size=32m,uid=65534,gid=65534,noexec,nosuid'}else{'/tmp:size=32m,uid=1000,gid=1000,noexec,nosuid'}),
  '--mount',(TraceMountArg $output /out),'-e','PYTHONDONTWRITEBYTECODE=1','-e','PYTHONWARNINGS=ignore','-e',"PHOTO_TRACE_STAGE=$Stage")+$sourceMounts+$extra+@($image)+$command
 return (Native "create-$role" $argv).text
}
function Guard($id,$role,$memory,$cpu,$user,$pids,$networkCount){
 $c=@((Native "inspect-$role" @('inspect',$id)).text|ConvertFrom-Json)[0]
 if($c.Image -cne $image -or $c.Config.User -cne $user -or $c.Config.Labels.'com.wed-snap.run' -cne $run -or -not $c.HostConfig.ReadonlyRootfs -or $c.HostConfig.Privileged -or $c.HostConfig.CapAdd -or
  $c.HostConfig.CapDrop -notcontains 'ALL' -or $c.HostConfig.SecurityOpt -notcontains 'no-new-privileges:true' -or $c.HostConfig.Memory -ne $memory -or $c.HostConfig.MemorySwap -ne $memory -or
  $c.HostConfig.NanoCpus -ne $cpu -or $c.HostConfig.PidsLimit -ne $pids -or $c.HostConfig.IpcMode -cne 'private' -or @($c.NetworkSettings.Networks.PSObject.Properties).Count -ne $networkCount -or $c.HostConfig.PortBindings.PSObject.Properties.Count){
  throw 'Runtime/ownership/resource guard'}
 foreach($m in @($c.Mounts|Where-Object Destination -in @('/integration','/trace_lab','/app/apps/media/src/tiktok/photo_lab'))){if($m.RW){throw 'Source mount not RO'}}
 if(@($c.Mounts|Where-Object Destination -in @('/integration','/trace_lab','/app/apps/media/src/tiktok/photo_lab')).Count -ne 3){throw 'Source mounts'}
 Save "$dir/guard-$role.json" $c
}
function State($id,$role){
 $c=@((Native "state-$role" @('inspect',$id)).text|ConvertFrom-Json)[0];Save "$dir/state-$role.json" $c.State
 if($c.State.Running -or $c.State.OOMKilled){throw 'Runtime still running/OOM'}
 return $c.State.ExitCode
}
function RuntimeGate($p){
 $r=Get-Content $p -Raw|ConvertFrom-Json
 if($r.python -cne '3.11.2' -or $r.versions.requests -cne '2.34.2' -or $r.versions.urllib3 -cne '2.8.0'){throw 'Runtime library pins'}
 foreach($f in $r.sources){
  $part=$f.path.Split('/',2);$base=switch($part[0]){'integration'{'labs/tiktok/photo-trace'}'photo'{'labs/tiktok/photo'}'trace'{'labs/tiktok/setup-trace'}'core'{'apps/media/src/tiktok'}default{throw 'Runtime source root'}}
  if((SHA "$base/$($part[1])") -cne $f.sha256){throw 'Runtime mounted source mismatch'}
 }
}
try{
 if((Native 'image' @('image','inspect',$image,'--format','{{.Id}}')).text -cne $image){throw 'Image pin'}
 $private=(Native 'network-private' @('network','create','--internal','--label','com.wed-snap.lab=tiktok-photo-trace','--label',"com.wed-snap.run=$run","tpt-$run-private")).text;$nets+=$private
 $netargv=@('network','create','--label','com.wed-snap.lab=tiktok-photo-trace','--label',"com.wed-snap.run=$run");if($Stage -eq 'offline'){$netargv+='--internal'}
 $secondary=(Native 'network-secondary' ($netargv+@("tpt-$run-secondary"))).text;$nets+=$secondary
 foreach($n in $nets){
  $info=@((Native 'network-inspect' @('network','inspect',$n)).text|ConvertFrom-Json)[0]
  if($info.Labels.'com.wed-snap.run' -cne $run -or ($n -eq $private -and -not $info.Internal) -or ($n -eq $secondary -and $info.Internal -ne ($Stage -eq 'offline'))){throw 'Network ownership/isolation'}
 }
 $extra=@('--network-alias','egress');if($Stage -eq 'offline'){$extra+=@('--mount',(TraceMountArg "$dir/control" /control -RO))}
 $proxy=Create 'proxy' '96m' '0.25' '65534:65534' '64' $private "$dir/proxy" $extra @('python3','/integration/proxy_entry.py');$ids+=$proxy
 Native 'network-connect' @('network','connect',$secondary,$proxy)|Out-Null
 Guard $proxy 'proxy' 96MB 250000000 '65534:65534' 64 2
 Native 'start-proxy' @('start',$proxy)|Out-Null
 $readyLimit=[DateTime]::UtcNow.AddSeconds(35)
 while(-not(Test-Path "$dir/proxy/proxy-ready.json")){
  if([DateTime]::UtcNow -ge $readyLimit){throw 'Proxy readiness deadline'}
  Start-Sleep -Milliseconds 200
 }
 $ready=Get-Content "$dir/proxy/proxy-ready.json" -Raw|ConvertFrom-Json
 if($ready.uid -ne 65534 -or $ready.stage -cne $Stage -or $ready.fixture -ne ($Stage -eq 'offline')){throw 'Readiness/fixture gate'}
 RuntimeGate "$dir/proxy/proxy-runtime.json"
 $extra=@('--mount',(TraceMountArg "$dir/proxy" /proxy -RO))
 if($Stage -eq 'offline'){
  $ca=(Get-Content "$root/preflight/runtime.json" -Raw|ConvertFrom-Json).caBundle
  if($ca -cne '/opt/media/lib/python3.11/site-packages/certifi/cacert.pem'){throw 'Fixture CA mount pin'}
  $extra+=@('--mount',(TraceMountArg "$dir/proxy/fixture-ca.pem" $ca -RO),'--mount',(TraceMountArg "$dir/control" /control))
 }
 $outer=if($Stage -eq 'offline'){'240s'}else{'95s'}
 $worker=Create 'worker' '512m' '0.75' '1000:1000' '96' $private "$dir/worker" $extra @('/usr/bin/timeout','--signal=KILL',$outer,'python3','/integration/worker_entry.py');$ids+=$worker
 Guard $worker 'worker' 512MB 750000000 '1000:1000' 96 1
 Native 'start-worker' @('start',$worker)|Out-Null;$workerStarted=$true
 $rc=[int](Native 'wait-worker' @('wait',$worker)).text
 $log=Native 'logs-worker' @('logs',$worker);Write-Output $log.text
 if((State $worker 'worker') -ne $rc){throw 'Worker native exit disagreement'}
 RuntimeGate "$dir/worker/worker-runtime.json"
 Native 'stop-proxy' @('stop','--time','20',$proxy)|Out-Null
 $proxyExit=State $proxy 'proxy';Native 'logs-proxy' @('logs',$proxy)|Out-Null
 if($proxyExit -ne 0 -or -not(Test-Path "$dir/proxy/proxy-summary.json")){throw 'Missing/incomplete actual proxy shutdown summary'}
 $extra=@('--mount',(TraceMountArg "$dir/proxy" /proxy -RO),'--mount',(TraceMountArg "$dir/worker" /worker -RO))
 $validate=Create 'validate' '96m' '0.25' '65534:65534' '64' 'none' "$dir/validation" $extra @('python3','/integration/finalize.py');$ids+=$validate
 Guard $validate 'validate' 96MB 250000000 '65534:65534' 64 1
 $r=Native 'validate' @('start','-a',$validate) -AllowFailure
 if((State $validate 'validate') -ne $r.exit -or $r.exit -ne 0){throw 'Final trace validator failed'}
 foreach($f in $hashes){if((SHA $f.path) -cne $f.sha256){throw 'Source changed while running'}}
}finally{
 foreach($id in $ids){
  $c=@((Native 'cleanup-inspect' @('inspect',$id)).text|ConvertFrom-Json)[0]
  if($c.Config.Labels.'com.wed-snap.run' -cne $run){throw 'Wrong container ownership'}
  Native 'remove' @('rm','-f',$id)|Out-Null
 }
 foreach($n in $nets){
  $info=@((Native 'cleanup-network-inspect' @('network','inspect',$n)).text|ConvertFrom-Json)[0]
  if($info.Labels.'com.wed-snap.run' -cne $run){throw 'Wrong network ownership'}
  Native 'network-remove' @('network','rm',$n)|Out-Null
 }
 Save "$dir/completion.json" @{actualExit=$rc;image=$image;ownResourcesLeft=0;workerStarted=$workerStarted;sourceAnalyzeAttempts=$(if($Stage -eq 'live' -and $workerStarted){1}else{0});utc=[DateTime]::UtcNow.ToString('o');vn=[DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(7)).ToString('o')}
}
if($Stage -eq 'offline' -and $rc -eq 0){
 $artifacts=@(foreach($p in @(rg --files $dir)){
  [ordered]@{path=$p.Substring($dir.Length+1).Replace('\','/');sha256=SHA $p}
 })
 Save "$dir/receipt.json" @{actualExit=0;image=$image;snapshotJSON=$snapshotJSON;artifacts=$artifacts;utc=[DateTime]::UtcNow.ToString('o')}
}
exit $rc

