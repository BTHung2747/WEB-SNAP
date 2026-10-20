param([ValidateSet('disabled','offline','source')][string]$Stage='disabled',[ValidateSet('all5','fail-second')][string]$Case='all5',[int]$Attempt=1,[string]$FreezePath,[string]$AllocationPath,[string]$GatePath,[string]$SourceReleasePath,[string]$ExecutionID)
$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
if($Stage -cne 'offline'){
 if($Stage -ceq 'disabled'){Write-Output 'SOURCE_DISABLED_NO_CAPABILITY';exit 20}
}
. "$PSScriptRoot/lab_contract.ps1"
. "$PSScriptRoot/album_authority.ps1"
. "$PSScriptRoot/live_contract.ps1"
SetAlbumExecution $ExecutionID -Offline:($Stage -ceq 'offline')
try{
 if($Stage -ceq 'source'){
  if($Case -cne 'all5' -or $AllocationPath -or $GatePath){throw 'SOURCE_PARAMETERS'}
  $bound=AssertAlbumSourceRelease $SourceReleasePath
  $release=ConsumeLiveBundle $bound.directory
 }else{$release=ConsumeAlbumMock $AllocationPath $GatePath}
}catch{Write-Output 'AUTHORITY_OR_SOURCE_BINDING_REFUSED_BEFORE_CAPABILITY';exit 20}
$root=AlbumRoot
if($Stage -ceq 'offline'){FixedPath $FreezePath (Join-Path (AlbumEvidenceRoot) 'freeze-1.json')}
if($Attempt -lt 1 -or ($Stage -ceq 'offline' -and -not $FreezePath)){throw 'FROZEN_HASH_REQUIRED'}
$frozen=if($Stage -ceq 'source'){SourceRead (Join-Path $release.directory 'preparation.json')}else{Get-Content -LiteralPath $FreezePath -Raw|ConvertFrom-Json -DateKind String}
$hashes=SourceSnapshot;$runtime=RuntimeExpected -Source:($Stage -ceq 'source')
if($frozen.sourceGate -cne $false -or (Canonical $frozen.sources) -cne (Canonical $hashes) -or (Canonical $frozen.runtime) -cne (Canonical $runtime)){throw 'OFFLINE_HASH_GATE'}
$dir=if($Stage -ceq 'source'){$release.parent}else{"$root/attempt-$Attempt-$Case"}
if($Stage -ceq 'offline' -and (Test-Path $dir)){throw 'REFUSE_REUSE'}
if($Stage -ceq 'source'){foreach($name in 'proxy','worker','control','validation'){if(Test-Path "$dir/$name"){throw 'REFUSE_SOURCE_EVIDENCE_REUSE'}}}
New-Item -ItemType Directory "$dir/proxy","$dir/worker","$dir/control","$dir/validation"|Out-Null
Save "$dir/source-before.json" $hashes
$sentinel=[Text.Encoding]::UTF8.GetBytes('UNRELATED_ALBUM_SENTINEL');[IO.File]::WriteAllBytes("$((Resolve-Path "$dir/worker").Path)/keep.bin",$sentinel)
$prior=@();if($Case -eq 'collision'){[IO.File]::WriteAllBytes("$((Resolve-Path "$dir/worker").Path)/image-0001.jpg",$sentinel);$prior=@('image-0001.jpg')}
if($Case -eq 'symlink'){$prior=@('image-0001.jpg')}
$count=5
$selectMode=switch($Case){'single'{'single'}'subset'{'subset'}'metadata50'{'subset'}default{'all'}}
$indices=$null
if($Case -eq 'single'){$indices=@(2)}elseif($Case -eq 'subset'){$indices=@(1,3,5)}elseif($Case -eq 'metadata50'){$indices=@(1,5)}
$imageQuota=if($null -ne $indices){$indices.Count}elseif($count -le 5){$count}else{0}
Save "$dir/control/control.json" @{stage=$Stage;sourceGate=($Stage -ceq 'source');case=$Case;mode=$Case;phaseDeadline=0;imageCount=$count;selectionMode=$selectMode;indices=$indices;preexisting=$prior;sentinels=@{'keep.bin'=SHA "$dir/worker/keep.bin"};admission=$release.admission}
$settings=SourceRead "$dir/control/control.json"
$candidates=@(foreach($i in 1..50){'image-{0:D4}.jpg' -f $i; 'image-{0:D4}.jpg.part' -f $i})
$priorHashes=@{};foreach($name in $prior){$priorHashes[$name]=SHA "$dir/worker/$name"}
$settings|Add-Member -NotePropertyName cleanupPolicy -NotePropertyValue @{version=1;policy='SOURCE_INDEX_1_TO_50';candidates=$candidates;preexisting=$prior;preexistingHashes=$priorHashes;sentinels=@{'keep.bin'=SHA "$dir/worker/keep.bin"}}
Save "$dir/control/control.json" $settings
if($Stage -ceq 'source'){$settings.PSObject.Properties.Remove('case');$settings.PSObject.Properties.Remove('mode');Save "$dir/control/control.json" $settings}
Save "$dir/budget.json" @{sourceGate=($Stage -ceq 'source');sourceCalls=$(if($Stage -ceq 'source'){'UNKNOWN_USE_REQUEST_ACCOUNTING'}else{0});fixture=($Stage -ceq 'offline');metadataGET=2;metadataDescriptorCount=$count;metadataSeconds=30;metadataResponseBytes=8MB;metadataTotalBytes=16MB;imageGET=$imageQuota;selectedMax=5;prepareSeconds=180;itemMaxSeconds=60;reserveSeconds=10;imageInputBytes=20MB;imageOutputBytes=16MB;workflowInputBytes=((16+20*$imageQuota)*1MB);workflowOutputBytes=(16*$imageQuota*1MB);maxWorkflowInputBytes=116MB;maxOutputBytes=80MB;redirect=0;retry=0;HEAD=0;setupSeconds=10;connectSeconds=10;readSeconds=20;runtimeMiB=608;workerCPU=0.75;proxyCPU=0.25;helperLimit=1;watchdogSeconds=225;watchdogScope='ACTIVE_METADATA30_PREPARE180_END15';hostE2E225Claim=$false;readinessSeconds=35;validatorSeconds=15;cleanupNativeSeconds=20}
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
$integration=if($Stage -ceq 'source'){Join-Path $PSScriptRoot 'runtime'}else{$PSScriptRoot}
$sources=@('--mount',(ArgMount $integration /integration -RO),'--mount',(ArgMount $integration /poc -RO),'--mount',(ArgMount labs/tiktok/connect-poc/vendor /vendor -RO),'--mount',(ArgMount "$PSScriptRoot/photo-runtime" /app/apps/media/src/tiktok/source_photo -RO),'--mount',(ArgMount labs/tiktok/setup-trace /trace_lab -RO),'--mount',(ArgMount apps/egress/src /stock -RO))
if($Stage -ceq 'source'){$sources+=@('--mount',(ArgMount $release.directory /authority -RO),'--mount',(ArgMount $release.claimPath /authority/source-claim.json -RO),'--mount',(ArgMount $release.taskClaimPath /authority/task-latch.json -RO))}
else{$sources+=@('--mount',(ArgMount labs/tiktok/photo /app/apps/media/src/tiktok/photo_lab -RO),'--mount',(ArgMount $release.gatePath /authority/gate.json -RO),'--mount',(ArgMount $release.claimPath /authority/claim-mock.json -RO),'--mount',(ArgMount $release.taskClaimPath /authority/task-latch-mock.json -RO))}
function Create($role,$uid,$ram,$cpu,$pids,$network,$out,[string[]]$extra,[string[]]$command){
 (Native "create-$role" (@('create','--pull','never','--label','com.wed-snap.lab=photo-album-execution-namespace','--label',"com.wed-snap.run=$run",'--label',"com.wed-snap.role=$role",'--network',$network,'--read-only','--user',"${uid}:$uid",'--memory',"${ram}m",'--memory-swap',"${ram}m",'--cpus',$cpu,'--pids-limit',$pids,'--ipc','private','--cap-drop','ALL','--security-opt','no-new-privileges:true','--tmpfs',"/tmp:size=32m,uid=$uid,gid=$uid,noexec,nosuid",'--mount',(ArgMount $out /out),'-e',"WHOLEPHOTO_STAGE=$Stage",'-e','PYTHONPATH=/integration:/vendor:/app/apps/media/src','-e','PYTHONDONTWRITEBYTECODE=1','-e','PYTHONWARNINGS=ignore')+$sources+$extra+@($image)+$command)).text
}
function Guard($id,$role,$uid,$ram,$cpu,$networkCount){
 $g=@((Native "guard-$role" @('inspect',$id)).text|ConvertFrom-Json)[0];$h=$g.HostConfig
 if($g.Image -cne $image -or $g.Config.User -cne "${uid}:$uid" -or $h.Memory -ne $ram*1MB -or $h.MemorySwap -ne $ram*1MB -or $h.NanoCpus -ne $cpu -or -not $h.ReadonlyRootfs -or $h.Privileged -or $h.CapAdd -or 'ALL' -notin $h.CapDrop -or 'no-new-privileges:true' -notin $h.SecurityOpt -or $h.IpcMode -ne 'private' -or $h.PidMode){throw 'RESOURCE_GUARD'}
 if($h.PidsLimit -ne $(if($role -eq 'worker'){96}else{64}) -or @($h.PortBindings.psobject.Properties).Count -or @($g.NetworkSettings.Networks.psobject.Properties).Count -ne $networkCount){throw 'NETWORK_PIDS_GUARD'}
 if($h.SecurityOpt -match 'unconfined' -or ($role -eq 'worker' -and $h.NetworkMode -cne $private) -or ($role -eq 'validate' -and $h.NetworkMode -cne 'none')){throw 'ISOLATION_GUARD'}
 foreach($target in '/integration','/poc','/vendor','/trace_lab','/stock','/app/apps/media/src/tiktok/source_photo'){$m=@($g.Mounts|Where-Object Destination -eq $target);if($m.Count -ne 1 -or $m[0].RW){throw 'MOUNT_GUARD'}}
 if($Stage -ceq 'source'){
  if($h.ExtraHosts -or @($g.Mounts|Where-Object {$_.Destination -match 'photo_lab|certifi|fixture' -or $_.Source -match 'fixture-ca|fixture-provider'}).Count -or @($g.Config.Env|Where-Object {$_ -match '(?i)^(FIXTURE_|TIKTOK_APP_FIXTURE=|SSL_CERT_FILE=|SSL_CERT_DIR=|REQUESTS_CA_BUNDLE=|CURL_CA_BUNDLE=|HTTP_PROXY=|HTTPS_PROXY=|ALL_PROXY=|NO_PROXY=|NETRC=|COOKIE|SOURCE_COOKIE|SOURCE_HEADER|BROWSER_|TIKTOK_COOKIE|TIKTOK_HEADER|YTDLP_COOKIE|YTDLP_HEADER)'}).Count){throw 'SOURCE_ISOLATION_GUARD'}
  $m=@($g.Mounts|Where-Object Destination -eq '/integration');if($m[0].Source -notmatch '[\\/]runtime$'){throw 'SOURCE_RUNTIME_BUNDLE'}
 }
 Save "$dir/guard-$role.json" $g
}
function RuntimeGate($p){
 $r=Get-Content -LiteralPath $p -Raw|ConvertFrom-Json
 if($r.python -cne '3.11.2' -or $r.versions.requests -cne '2.34.2' -or $r.versions.urllib3 -cne '2.8.0' -or $r.versions.aiohappyeyeballs -cne '2.7.1' -or $r.versions.'yt-dlp' -cne '2026.8.19' -or (Canonical $r.sources) -cne (Canonical $runtime)){throw 'RUNTIME_PIN_HASH'}
 if($Stage -ceq 'source' -and $r.trustSHA -cne (SourceTrust)){throw 'SOURCE_ORIGINAL_TRUST'}
}
function State($id,$role){$s=@((Native "state-$role" @('inspect',$id)).text|ConvertFrom-Json)[0].State;Save "$dir/state-$role.json" $s;if($s.Running -or $s.OOMKilled){throw 'OOM_RUNNING'};return $s.ExitCode}
try{
 if($Stage -ceq 'source'){$null=AssertLiveBundle $release.directory;if((SourceSHA $release.claimPath) -cne $release.admission.claimSHA -or (SourceSHA $release.taskClaimPath) -cne $release.admission.taskClaimSHA){throw 'CLAIM_DRIFT_BEFORE_CAPABILITY'}}
 $main=(Native 'main-before' @('image','inspect','wed-snap-app:local','--format','{{.Id}}')).text
 if((Native 'image' @('image','inspect',$image,'--format','{{.Id}}')).text -cne $image){throw 'IMAGE_PIN'}
 $drive=Get-PSDrive -Name D;if($drive.Free -lt 112MB){throw 'DISK_PREFLIGHT'};Save "$dir/disk-preflight.json" @{freeBytes=$drive.Free;minimumBytes=112MB;maxFilesBytes=80MB;activePartBytes=16MB}
 $private=(Native 'private' @('network','create','--internal','--label',"com.wed-snap.run=$run","album-$run-private")).text;$nets+=$private
 $secondaryArgs=@('network','create');if($Stage -ceq 'offline'){$secondaryArgs+='--internal'};$secondaryArgs+=@('--label',"com.wed-snap.run=$run","album-$run-secondary");$secondary=(Native 'secondary' $secondaryArgs).text;$nets+=$secondary
 foreach($net in $nets){$g=@((Native 'network-inspect' @('network','inspect',$net)).text|ConvertFrom-Json)[0];if(($net -eq $private -and -not $g.Internal) -or ($net -eq $secondary -and $g.Internal -ne ($Stage -ceq 'offline'))){throw 'NETWORK_SCOPE'}}
 $proxyExtra=@('--network-alias','egress','--mount',(ArgMount "$dir/control" /control -RO));if($Stage -ceq 'offline'){$proxyExtra+=@('--add-host','www.tiktok.com:1.1.1.1','--add-host','www.tiktok.com:1.1.1.2','--add-host','media.tiktokcdn.com:1.0.0.1')}
 $proxy=Create 'proxy' 65534 96 '0.25' '64' $private "$dir/proxy" $proxyExtra @('python3','/integration/proxy_entry.py');$ids+=$proxy
 Native 'connect-secondary' @('network','connect',$secondary,$proxy)|Out-Null;Guard $proxy 'proxy' 65534 96 250000000 2;Native 'start-proxy' @('start',$proxy)|Out-Null
 $readyEnd=[DateTime]::UtcNow.AddSeconds(35)
 while(-not(Test-Path "$dir/proxy/proxy-ready.json")){if([DateTime]::UtcNow -gt $readyEnd){Native 'proxy-failure-log' @('logs',$proxy)|Out-Null;throw 'READINESS_TIMEOUT'};Start-Sleep -Milliseconds 150}
 RuntimeGate "$dir/proxy/proxy-runtime.json"
 $workerExtra=@('--mount',(ArgMount "$dir/proxy" /proxy -RO),'--mount',(ArgMount "$dir/control" /control));if($Stage -ceq 'offline'){$workerExtra+=@('--mount',(ArgMount "$dir/proxy/fixture-ca.pem" /opt/media/lib/python3.11/site-packages/certifi/cacert.pem -RO))}
 $worker=Create 'worker' 1000 512 '0.75' '96' $private "$dir/worker" $workerExtra @('/usr/bin/timeout','--signal=KILL','225s','python3','/integration/worker_entry.py');$ids+=$worker;Guard $worker 'worker' 1000 512 750000000 1
 Native 'start-worker' @('start',$worker)|Out-Null;$workerExit=[int](Native 'wait-worker' @('wait',$worker) -Timeout 230).text
 Native 'logs-worker' @('logs',$worker)|Out-Null;if((State $worker 'worker') -ne $workerExit){throw 'WORKER_NATIVE'};RuntimeGate "$dir/worker/worker-runtime.json"
 Native 'stop-proxy' @('stop','--time','15',$proxy) -Timeout 20|Out-Null;$proxyExit=State $proxy 'proxy';Native 'logs-proxy' @('logs',$proxy)|Out-Null
 $validator=Create 'validate' 65534 96 '0.25' '64' 'none' "$dir/validation" @('--mount',(ArgMount "$dir/proxy" /proxy -RO),'--mount',(ArgMount "$dir/worker" /worker),'--mount',(ArgMount "$dir/control" /control -RO)) @('/usr/bin/timeout','--signal=KILL','15s','python3','/integration/finalize.py');$ids+=$validator;Guard $validator 'validate' 65534 96 250000000 1
 $v=Native 'validate' @('start','-a',$validator) -Timeout 20 -AllowFailure;$validatorExit=State $validator 'validate';if($validatorExit -ne $v.exit){throw 'VALIDATOR_NATIVE'}
 $outcome=Get-Content "$dir/validation/album-result.json" -Raw|ConvertFrom-Json
 $expected=$Case -ceq 'all5'
 if($Stage -ceq 'offline'){if(($validatorExit -eq 0) -ne $expected -or ($outcome.status -ceq 'PASS_ALBUM_OFFLINE') -ne $expected){throw 'CASE_EXPECTATION'}}
 if((Canonical (SourceSnapshot)) -cne (Canonical $hashes)){throw 'SOURCE_DRIFT'}
 $rc=if($Stage -ceq 'offline'){0}elseif($workerExit -eq 0 -and $proxyExit -eq 0 -and $validatorExit -eq 0 -and $outcome.status -ceq 'PASS_SOURCE_ALBUM_TECHNICAL_NEEDS_VISUAL_REVIEW'){0}else{20}
}catch{Save "$dir/runner-failure.json" @{code='RUNNER_NATIVE_GUARD_OR_EXPECTATION';actualExit=20;sourceGate=($Stage -ceq 'source');sourceCalls=$(if($Stage -ceq 'source'){'UNKNOWN_USE_REQUEST_ACCOUNTING'}else{0})};$rc=20}
finally{
 foreach($id in $ids){$g=@((Native 'cleanup-owner' @('inspect',$id)).text|ConvertFrom-Json)[0];if($g.Config.Labels.'com.wed-snap.run' -cne $run){throw 'CLEANUP_OWNER'};Native 'remove-own' @('rm','-f',$id)|Out-Null}
 foreach($net in $nets){$g=@((Native 'cleanup-network' @('network','inspect',$net)).text|ConvertFrom-Json)[0];if($g.Labels.'com.wed-snap.run' -cne $run){throw 'CLEANUP_NETWORK_OWNER'};Native 'remove-network' @('network','rm',$net)|Out-Null}
 Save "$dir/completion.json" @{actualExit=$rc;workerActualExit=$workerExit;proxyActualExit=$proxyExit;validatorActualExit=$validatorExit;case=$Case;stage=$Stage;sourceGate=($Stage -ceq 'source');sourceCalls=$(if($Stage -ceq 'source'){'UNKNOWN_USE_REQUEST_ACCOUNTING'}else{0});newClaims=$(if($Stage -ceq 'source'){1}else{0});ownContainerIDs=$ids;ownNetworkIDs=$nets;ownResourcesLeft=0;mainImage=$main;utc=[DateTime]::UtcNow.ToString('o');vn=[DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(7)).ToString('o')}
}
exit $rc



