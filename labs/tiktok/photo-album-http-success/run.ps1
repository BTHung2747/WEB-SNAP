param([ValidateSet('disabled','offline')][string]$Stage='disabled',[ValidateSet('all2','all5','single','subset','fail-second','tail-missing','bad-dimension','all6','same-bytes','metadata50','collision','symlink','native-nonzero','native-hang','cancel','redirect-image','image-html','trace-cap','mock129','unique65','private-tail','closure-live')][string]$Case='all2',[int]$Attempt=1,[string]$FreezePath)
$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
if($Stage -cne 'offline'){Write-Output 'SOURCE_DISABLED_NO_CAPABILITY';exit 20}
. "$PSScriptRoot/lab_contract.ps1"
$root='docs/evidence/tiktok-photo-album-http-success-20261014'
if(-not $FreezePath -or $Attempt -lt 1){throw 'OFFLINE_FROZEN_HASH_REQUIRED'}
$frozen=Get-Content -LiteralPath $FreezePath -Raw|ConvertFrom-Json -DateKind String
$hashes=SourceSnapshot;$runtime=RuntimeExpected
if($frozen.sourceGate -cne $false -or (Canonical $frozen.sources) -cne (Canonical $hashes) -or (Canonical $frozen.runtime) -cne (Canonical $runtime)){throw 'OFFLINE_HASH_GATE'}
$dir="$root/attempt-$Attempt-$Case";if(Test-Path $dir){throw 'REFUSE_REUSE'}
New-Item -ItemType Directory "$dir/proxy","$dir/worker","$dir/control","$dir/validation"|Out-Null
Save "$dir/source-before.json" $hashes
$sentinel=[Text.Encoding]::UTF8.GetBytes('UNRELATED_ALBUM_SENTINEL');[IO.File]::WriteAllBytes("$((Resolve-Path "$dir/worker").Path)/keep.bin",$sentinel)
$prior=@();if($Case -eq 'collision'){[IO.File]::WriteAllBytes("$((Resolve-Path "$dir/worker").Path)/image-0001.jpg",$sentinel);$prior=@('image-0001.jpg')}
if($Case -eq 'symlink'){$prior=@('image-0001.jpg')}
$count=switch($Case){'all5'{5}'subset'{5}'fail-second'{3}'all6'{6}'metadata50'{50}default{2}}
$selectMode=switch($Case){'single'{'single'}'subset'{'subset'}'metadata50'{'subset'}default{'all'}}
$indices=$null
if($Case -eq 'single'){$indices=@(2)}elseif($Case -eq 'subset'){$indices=@(1,3,5)}elseif($Case -eq 'metadata50'){$indices=@(1,5)}
$imageQuota=if($null -ne $indices){$indices.Count}elseif($count -le 5){$count}else{0}
Save "$dir/control/control.json" @{stage='offline';sourceGate=$false;case=$Case;mode=$Case;phaseDeadline=0;imageCount=$count;selectionMode=$selectMode;indices=$indices;preexisting=$prior;sentinels=@{'keep.bin'=SHA "$dir/worker/keep.bin"}}
Save "$dir/budget.json" @{sourceGate=$false;sourceCalls=0;fixture=$true;metadataGET=2;metadataDescriptorCount=$count;metadataSeconds=30;metadataResponseBytes=8MB;metadataTotalBytes=16MB;imageGET=$imageQuota;selectedMax=5;prepareSeconds=180;itemMaxSeconds=60;reserveSeconds=10;imageInputBytes=20MB;imageOutputBytes=16MB;workflowInputBytes=((16+20*$imageQuota)*1MB);workflowOutputBytes=(16*$imageQuota*1MB);maxWorkflowInputBytes=116MB;maxOutputBytes=80MB;redirect=0;retry=0;HEAD=0;setupSeconds=10;connectSeconds=10;readSeconds=20;runtimeMiB=608;workerCPU=0.75;proxyCPU=0.25;helperLimit=1;watchdogSeconds=225;watchdogScope='ACTIVE_METADATA30_PREPARE180_END15';hostE2E225Claim=$false;readinessSeconds=35;validatorSeconds=15;cleanupNativeSeconds=20}
$image='sha256:31742091e95df2cc62669a6c6a9e0892dc09a34341eaeefc16959dcd4dfa417e';$run=[Guid]::NewGuid().ToString('N');$ids=@();$nets=@();$rc=20;$workerExit=$null;$proxyExit=$null;$validatorExit=$null;$main=$null
function Native($step,[string[]]$argv,[int]$Timeout=20,[switch]$AllowFailure){
 $start=[DateTime]::UtcNow;$si=[Diagnostics.ProcessStartInfo]::new('docker');$si.UseShellExecute=$false;$si.RedirectStandardOutput=$true;$si.RedirectStandardError=$true;$si.CreateNoWindow=$true
 foreach($arg in $argv){$si.ArgumentList.Add($arg)}
 $p=[Diagnostics.Process]::new();$p.StartInfo=$si;$null=$p.Start();$stdout=$p.StandardOutput.ReadToEndAsync();$stderr=$p.StandardError.ReadToEndAsync();$timedOut=-not $p.WaitForExit($Timeout*1000)
 if($timedOut){$p.Kill($true);$p.WaitForExit()};$text=$stdout.GetAwaiter().GetResult();$err=$stderr.GetAwaiter().GetResult();$exit=$p.ExitCode;$p.Dispose()
 SaveLine @{step=$step;actualExit=$exit;timeout=$Timeout;timedOut=$timedOut;utcStart=$start.ToString('o');utcEnd=[DateTime]::UtcNow.ToString('o');stdout=$text;stderr=$err}
 if($timedOut -or ($exit -ne 0 -and -not $AllowFailure)){throw 'DOCKER_NATIVE_FAIL'};return @{text=$text.Trim();exit=$exit}
}
function SaveLine($v){$v|ConvertTo-Json -Compress -Depth 8|Add-Content "$dir/native.jsonl"}
function ArgMount($p,$target,[switch]$RO){$s="type=bind,source=$((Resolve-Path $p).Path),target=$target";if($RO){$s+=',readonly'};return $s}
$sources=@('--mount',(ArgMount $PSScriptRoot /integration -RO),'--mount',(ArgMount $PSScriptRoot /poc -RO),'--mount',(ArgMount labs/tiktok/connect-poc/vendor /vendor -RO),'--mount',(ArgMount labs/tiktok/photo /app/apps/media/src/tiktok/photo_lab -RO),'--mount',(ArgMount labs/tiktok/setup-trace /trace_lab -RO),'--mount',(ArgMount apps/egress/src /stock -RO))
function Create($role,$uid,$ram,$cpu,$pids,$network,$out,[string[]]$extra,[string[]]$command){
 (Native "create-$role" (@('create','--pull','never','--label','com.wed-snap.lab=photo-album-http-success','--label',"com.wed-snap.run=$run",'--label',"com.wed-snap.role=$role",'--network',$network,'--read-only','--user',"${uid}:$uid",'--memory',"${ram}m",'--memory-swap',"${ram}m",'--cpus',$cpu,'--pids-limit',$pids,'--ipc','private','--cap-drop','ALL','--security-opt','no-new-privileges:true','--tmpfs',"/tmp:size=32m,uid=$uid,gid=$uid,noexec,nosuid",'--mount',(ArgMount $out /out),'-e','WHOLEPHOTO_STAGE=offline','-e','PYTHONPATH=/integration:/vendor:/app/apps/media/src','-e','PYTHONDONTWRITEBYTECODE=1','-e','PYTHONWARNINGS=ignore')+$sources+$extra+@($image)+$command)).text
}
function Guard($id,$role,$uid,$ram,$cpu,$networkCount){
 $g=@((Native "guard-$role" @('inspect',$id)).text|ConvertFrom-Json)[0];$h=$g.HostConfig
 if($g.Image -cne $image -or $g.Config.User -cne "${uid}:$uid" -or $h.Memory -ne $ram*1MB -or $h.MemorySwap -ne $ram*1MB -or $h.NanoCpus -ne $cpu -or -not $h.ReadonlyRootfs -or $h.Privileged -or $h.CapAdd -or 'ALL' -notin $h.CapDrop -or 'no-new-privileges:true' -notin $h.SecurityOpt -or $h.IpcMode -ne 'private' -or $h.PidMode){throw 'RESOURCE_GUARD'}
 if($h.PidsLimit -ne $(if($role -eq 'worker'){96}else{64}) -or @($h.PortBindings.psobject.Properties).Count -or @($g.NetworkSettings.Networks.psobject.Properties).Count -ne $networkCount){throw 'NETWORK_PIDS_GUARD'}
 if($h.SecurityOpt -match 'unconfined' -or ($role -eq 'worker' -and $h.NetworkMode -cne $private) -or ($role -eq 'validate' -and $h.NetworkMode -cne 'none')){throw 'ISOLATION_GUARD'}
 foreach($target in '/integration','/poc','/vendor','/trace_lab','/stock','/app/apps/media/src/tiktok/photo_lab'){$m=@($g.Mounts|Where-Object Destination -eq $target);if($m.Count -ne 1 -or $m[0].RW){throw 'MOUNT_GUARD'}}
 Save "$dir/guard-$role.json" $g
}
function RuntimeGate($p){
 $r=Get-Content -LiteralPath $p -Raw|ConvertFrom-Json
 if($r.python -cne '3.11.2' -or $r.versions.requests -cne '2.34.2' -or $r.versions.urllib3 -cne '2.8.0' -or $r.versions.aiohappyeyeballs -cne '2.7.1' -or $r.versions.'yt-dlp' -cne '2026.8.19' -or (Canonical $r.sources) -cne (Canonical $runtime)){throw 'RUNTIME_PIN_HASH'}
}
function State($id,$role){$s=@((Native "state-$role" @('inspect',$id)).text|ConvertFrom-Json)[0].State;Save "$dir/state-$role.json" $s;if($s.Running -or $s.OOMKilled){throw 'OOM_RUNNING'};return $s.ExitCode}
try{
 $main=(Native 'main-before' @('image','inspect','wed-snap-app:local','--format','{{.Id}}')).text
 if((Native 'image' @('image','inspect',$image,'--format','{{.Id}}')).text -cne $image){throw 'IMAGE_PIN'}
 $drive=Get-PSDrive -Name D;if($drive.Free -lt 112MB){throw 'DISK_PREFLIGHT'};Save "$dir/disk-preflight.json" @{freeBytes=$drive.Free;minimumBytes=112MB;maxFilesBytes=80MB;activePartBytes=16MB}
 $private=(Native 'private' @('network','create','--internal','--label',"com.wed-snap.run=$run","album-$run-private")).text;$nets+=$private
 $secondary=(Native 'secondary' @('network','create','--internal','--label',"com.wed-snap.run=$run","album-$run-secondary")).text;$nets+=$secondary
 foreach($net in $nets){$g=@((Native 'network-inspect' @('network','inspect',$net)).text|ConvertFrom-Json)[0];if(-not $g.Internal){throw 'OFFLINE_NETWORK'}}
 $proxy=Create 'proxy' 65534 96 '0.25' '64' $private "$dir/proxy" @('--network-alias','egress','--mount',(ArgMount "$dir/control" /control -RO),'--add-host','www.tiktok.com:1.1.1.1','--add-host','www.tiktok.com:1.1.1.2','--add-host','media.tiktokcdn.com:1.0.0.1') @('python3','/integration/proxy_entry.py');$ids+=$proxy
 Native 'connect-secondary' @('network','connect',$secondary,$proxy)|Out-Null;Guard $proxy 'proxy' 65534 96 250000000 2;Native 'start-proxy' @('start',$proxy)|Out-Null
 $readyEnd=[DateTime]::UtcNow.AddSeconds(35)
 while(-not(Test-Path "$dir/proxy/proxy-ready.json")){if([DateTime]::UtcNow -gt $readyEnd){Native 'proxy-failure-log' @('logs',$proxy)|Out-Null;throw 'READINESS_TIMEOUT'};Start-Sleep -Milliseconds 150}
 RuntimeGate "$dir/proxy/proxy-runtime.json"
 $worker=Create 'worker' 1000 512 '0.75' '96' $private "$dir/worker" @('--mount',(ArgMount "$dir/proxy" /proxy -RO),'--mount',(ArgMount "$dir/control" /control),'--mount',(ArgMount "$dir/proxy/fixture-ca.pem" /opt/media/lib/python3.11/site-packages/certifi/cacert.pem -RO)) @('/usr/bin/timeout','--signal=KILL','225s','python3','/integration/worker_entry.py');$ids+=$worker;Guard $worker 'worker' 1000 512 750000000 1
 Native 'start-worker' @('start',$worker)|Out-Null;$workerExit=[int](Native 'wait-worker' @('wait',$worker) -Timeout 230).text
 Native 'logs-worker' @('logs',$worker)|Out-Null;if((State $worker 'worker') -ne $workerExit){throw 'WORKER_NATIVE'};RuntimeGate "$dir/worker/worker-runtime.json"
 Native 'stop-proxy' @('stop','--time','15',$proxy) -Timeout 20|Out-Null;$proxyExit=State $proxy 'proxy';Native 'logs-proxy' @('logs',$proxy)|Out-Null
 $validator=Create 'validate' 65534 96 '0.25' '64' 'none' "$dir/validation" @('--mount',(ArgMount "$dir/proxy" /proxy -RO),'--mount',(ArgMount "$dir/worker" /worker),'--mount',(ArgMount "$dir/control" /control -RO)) @('/usr/bin/timeout','--signal=KILL','15s','python3','/integration/finalize.py');$ids+=$validator;Guard $validator 'validate' 65534 96 250000000 1
 $v=Native 'validate' @('start','-a',$validator) -Timeout 20 -AllowFailure;$validatorExit=State $validator 'validate';if($validatorExit -ne $v.exit){throw 'VALIDATOR_NATIVE'}
 $outcome=Get-Content "$dir/validation/album-result.json" -Raw|ConvertFrom-Json
 $expected=$Case -in @('all2','all5','single','subset','same-bytes','metadata50','mock129')
 if(($validatorExit -eq 0) -ne $expected -or ($outcome.status -ceq 'PASS_ALBUM_OFFLINE') -ne $expected){throw 'CASE_EXPECTATION'}
 if((Canonical (SourceSnapshot)) -cne (Canonical $hashes)){throw 'SOURCE_DRIFT'}
 $rc=0
}catch{Save "$dir/runner-failure.json" @{code='RUNNER_NATIVE_GUARD_OR_EXPECTATION';actualExit=20;sourceGate=$false;sourceCalls=0};$rc=20}
finally{
 foreach($id in $ids){$g=@((Native 'cleanup-owner' @('inspect',$id)).text|ConvertFrom-Json)[0];if($g.Config.Labels.'com.wed-snap.run' -cne $run){throw 'CLEANUP_OWNER'};Native 'remove-own' @('rm','-f',$id)|Out-Null}
 foreach($net in $nets){$g=@((Native 'cleanup-network' @('network','inspect',$net)).text|ConvertFrom-Json)[0];if($g.Labels.'com.wed-snap.run' -cne $run){throw 'CLEANUP_NETWORK_OWNER'};Native 'remove-network' @('network','rm',$net)|Out-Null}
 Save "$dir/completion.json" @{actualExit=$rc;workerActualExit=$workerExit;proxyActualExit=$proxyExit;validatorActualExit=$validatorExit;case=$Case;sourceGate=$false;sourceCalls=0;newClaims=0;ownContainerIDs=$ids;ownNetworkIDs=$nets;ownResourcesLeft=0;mainImage=$main;utc=[DateTime]::UtcNow.ToString('o');vn=[DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(7)).ToString('o')}
}
exit $rc
