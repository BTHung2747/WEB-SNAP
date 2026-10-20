param([ValidateSet('disabled','offline','source')][string]$Stage='disabled',[int]$Attempt=1,[ValidateSet('normal','wrong-body','redirect','metadata-oversize','image-html','image-oversize','health-missing','closure-live','closure-missing','preexisting','parent-nonzero','parent-expiry')][string]$Case='normal',[string]$AllocationPath,[string]$GatePath)
$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
. "$PSScriptRoot/source_contract.ps1"
$root='docs/evidence/tiktok-photo-dns-source-wiring-20261011';$release=$null
if($Stage -eq 'disabled'){Write-Output 'SOURCE_OFF_NO_NETWORK';exit 20}
if($Stage -eq 'source'){
 try{
  if(-not $AllocationPath -or -not $GatePath -or $Case -cne 'normal'){throw 'SOURCE_PARAMETERS'}
  $reservation=AssertSourceAllocation $AllocationPath $GatePath
  $reviewedGate=$reservation.gate
  $dir=$reservation.parent
  foreach($name in @('proxy','worker','control','validation')){if(Test-Path "$dir/$name"){throw 'SOURCE_EVIDENCE_REUSE'}}
 }catch{Write-Output 'SOURCE_GATE_OR_HUMAN_TASK_REQUIRED_NO_NETWORK';exit 20}
}else{
 if($AllocationPath -or $GatePath -or $Attempt -lt 1){throw 'OFFLINE_PARAMETERS'}
 $dir="$root/offline-$Attempt-$Case";if(Test-Path $dir){throw 'Refuse evidence reuse'}
}
New-Item -ItemType Directory "$dir/proxy","$dir/worker","$dir/control","$dir/validation"|Out-Null
function SHA($p){(Get-FileHash -LiteralPath $p).Hash.ToLowerInvariant()}
function Save($p,$v){ConvertTo-Json -InputObject $v -Depth 40|Set-Content -LiteralPath $p}
$hashes=SourceSnapshot
Save "$dir/source-before.json" $hashes
if($Stage -eq 'source'){if($Case -cne 'normal'){throw 'SOURCE_FAULT_DENIED'};Save "$dir/control/control.json" @{stage='source';phaseDeadline=0}}else{Save "$dir/control/control.json" @{stage='offline';case=$Case;mode=$Case;phaseDeadline=0}}
Save "$dir/budget.json" @{fixture=($Stage -eq 'offline');sourceCalls=if($Stage -eq 'source'){'UNKNOWN_USE_REQUEST_ACCOUNTING'}else{0};target='https://www.tiktok.com/@adne_la.veil/photo/7678209751167110421';expectedID='7678209751167110421';preparedTarget='https://www.tiktok.com/@adne_la.veil/video/7678209751167110421';analyze=1;metadataGET=2;metadataSeconds=30;metadataResponseBytes=8MB;metadataTotalBytes=16MB;imageGET=1;prepareSeconds=60;imageInputBytes=20MB;imageOutputBytes=16MB;workflowBytes=36MB;pixels=16000000;dimension=8192;redirect=0;retry=0;HEAD=0;setupSeconds=10;reserveSeconds=1;connectSeconds=10;readSeconds=20;runtimeMiB=608;helperLimit=1;stage=$Stage;case=$Case}
$image='sha256:31742091e95df2cc62669a6c6a9e0892dc09a34341eaeefc16959dcd4dfa417e'
$run=[Guid]::NewGuid().ToString('N');$ids=@();$nets=@();$rc=1;$outcome=$null;$failureCode=$null
function Native($step,[string[]]$argv,[switch]$AllowFailure){
 $start=[DateTime]::UtcNow;$text=& docker @argv 2>&1|Out-String;$exit=$LASTEXITCODE
 SaveLine @{step=$step;actualExit=$exit;utcStart=$start.ToString('o');utcEnd=[DateTime]::UtcNow.ToString('o');stdout=$text}
 if($exit -and -not $AllowFailure){throw "DOCKER_$step"};return @{text=$text.Trim();exit=$exit}
}
function SaveLine($v){$v|ConvertTo-Json -Compress -Depth 8|Add-Content "$dir/native.jsonl"}
function ArgMount($path,$target,[switch]$RO){$v="type=bind,source=$((Resolve-Path $path).Path),target=$target";if($RO){$v+=',readonly'};return $v}
$sources=@('--mount',(ArgMount labs/tiktok/photo-dns-source-trial /integration -RO),'--mount',(ArgMount labs/tiktok/photo-dns-source-trial /poc -RO),
 '--mount',(ArgMount labs/tiktok/connect-poc/vendor /vendor -RO),'--mount',(ArgMount labs/tiktok/photo /app/apps/media/src/tiktok/photo_lab -RO),
 '--mount',(ArgMount labs/tiktok/setup-trace /trace_lab -RO),'--mount',(ArgMount apps/egress/src /stock -RO))
function Create($role,$user,$ram,$cpu,$pids,$network,$output,[string[]]$extra,[string[]]$command){
 return (Native "create-$role" (@('create','--label','com.wed-snap.lab=tiktok-photo-dns-source-trial','--label',"com.wed-snap.run=$run",'--label',"com.wed-snap.role=$role",'--network',$network,
  '--read-only','--user',"${user}:$user",'--memory',"${ram}m",'--memory-swap',"${ram}m",'--cpus',$cpu,'--pids-limit',$pids,'--ipc','private','--cap-drop','ALL','--security-opt','no-new-privileges:true',
  '--tmpfs',"/tmp:size=32m,uid=$user,gid=$user,noexec,nosuid",'--mount',(ArgMount $output /out),'-e',"WHOLEPHOTO_STAGE=$Stage",'-e','PYTHONPATH=/integration:/vendor:/app/apps/media/src',
  '-e','PYTHONDONTWRITEBYTECODE=1','-e','PYTHONWARNINGS=ignore')+$sources+$extra+@($image)+$command)).text
}
function Guard($id,$role,$user,$ram,$cpu){
 $g=@((Native "guard-$role" @('inspect',$id)).text|ConvertFrom-Json)[0];$h=$g.HostConfig
 if($g.Image -cne $image -or $g.Config.User -cne "${user}:$user" -or $h.Memory -ne ($ram*1MB) -or $h.MemorySwap -ne ($ram*1MB) -or $h.NanoCpus -ne $cpu -or -not $h.ReadonlyRootfs -or $h.Privileged -or $h.CapAdd -or 'ALL' -notin $h.CapDrop -or 'no-new-privileges:true' -notin $h.SecurityOpt -or $h.IpcMode -ne 'private'){throw 'GUARD_FAIL'}
 if($h.PidsLimit -ne $(if($role -eq 'worker'){96}else{64}) -or @($h.PortBindings.psobject.Properties).Count -or $g.Config.Cmd[-1] -cne $(switch($role){'proxy'{'/integration/proxy_entry.py'}'worker'{'/integration/worker_entry.py'}'validate'{'/integration/finalize.py'}})){throw 'ENTRYPOINT_RESOURCE_GUARD'}
 foreach($target in '/integration','/poc','/vendor','/trace_lab','/stock'){$m=@($g.Mounts|Where-Object Destination -eq $target);if($m.Count -ne 1 -or $m[0].RW){throw 'SOURCE_MOUNT_RO'}}
 if($Stage -eq 'source'){
  if($h.ExtraHosts -or @($g.Config.Env|Where-Object {$_ -match '(?i)^(FIXTURE_|TIKTOK_APP_FIXTURE=|SSL_CERT_FILE=|SSL_CERT_DIR=|REQUESTS_CA_BUNDLE=|CURL_CA_BUNDLE=|HTTP_PROXY=|HTTPS_PROXY=|ALL_PROXY=|NO_PROXY=|NETRC=|COOKIE|SOURCE_COOKIE|SOURCE_HEADER|BROWSER_|TIKTOK_COOKIE|TIKTOK_HEADER|YTDLP_COOKIE|YTDLP_HEADER)'}).Count -or @($g.Mounts|Where-Object {$_.Destination -match '(certifi|cacert|fixture)' -or $_.Source -match '(fixture-ca|fixture-provider|fixture-control)'}).Count){throw 'SOURCE_FIXTURE_GUARD'}
  if('WHOLEPHOTO_STAGE=source' -notin $g.Config.Env){throw 'SOURCE_STAGE_ENV'}
 }
 $netCount=@($g.NetworkSettings.Networks.psobject.Properties).Count
 if($netCount -ne $(switch($role){'proxy'{2}'worker'{1}'validate'{1}})){throw 'TOPOLOGY_GUARD'}
 if($role -eq 'worker' -and $h.NetworkMode -cne $private){throw 'WORKER_PRIVATE_ONLY'}
 if($role -eq 'validate' -and $h.NetworkMode -cne 'none'){throw 'VALIDATOR_NONE'}
 Save "$dir/guard-$role.json" $g
}
function State($id,$role){$s=@((Native "state-$role" @('inspect',$id)).text|ConvertFrom-Json)[0].State;Save "$dir/state-$role.json" $s;if($s.OOMKilled -or $s.Running){throw 'OOM_OR_RUNNING'};return $s.ExitCode}
function RuntimeGate($path){
 $r=Get-Content $path -Raw|ConvertFrom-Json
 if($r.python -cne '3.11.2' -or $r.versions.requests -cne '2.34.2' -or $r.versions.urllib3 -cne '2.8.0' -or $r.versions.aiohappyeyeballs -cne '2.7.1' -or $r.versions.'yt-dlp' -cne '2026.8.19'){throw 'RUNTIME_PIN'}
 $expected=if($Stage -eq 'source'){$reviewedGate.runtime}else{SourceRuntimeExpected}
 if((CanonicalSource $r.sources) -cne (CanonicalSource $expected)){throw 'FULL_RUNTIME_INVENTORY'}
 if($Stage -eq 'source' -and $r.trustSHA -cne '9cc2a774b5198dcff14d9be1e66091f538975d867ce029a96bce15a55dfd730f'){throw 'ORIGINAL_SOURCE_CA_PIN'}
}
try{

 $main=(Native 'main-before' @('image','inspect','wed-snap-app:local','--format','{{.Id}}')).text
 if((Native 'image' @('image','inspect',$image,'--format','{{.Id}}')).text -cne $image){throw 'IMAGE_PIN'}
 if($Stage -eq 'source'){
  # Recheck code/proofs/allocation/human review immediately before atomic consumption.
  $release=ClaimSourceAllocation $AllocationPath $GatePath
  if((SourceSHA $release.claimPath) -cne $release.claimSHA -or (SourceSHA $release.taskClaimPath) -cne $release.taskClaimSHA){throw 'CLAIM_RECEIPT_DRIFT'}
  $null=AssertSourceGate $GatePath
 }
 $private=(Native 'network-private' @('network','create','--internal','--label',"com.wed-snap.run=$run","wp-$run-private")).text;$nets+=$private
 $secondaryArgs=@('network','create');if($Stage -eq 'offline'){$secondaryArgs+='--internal'};$secondaryArgs+=@('--label',"com.wed-snap.run=$run","wps-$run-secondary");$secondary=(Native 'network-secondary' $secondaryArgs).text;$nets+=$secondary
 foreach($net in $nets){$info=@((Native 'network-inspect' @('network','inspect',$net)).text|ConvertFrom-Json)[0];if($info.Id -eq $private -and -not $info.Internal){throw 'NETWORK_PRIVATE'};if(($info.Id -eq $secondary) -and ($info.Internal -ne ($Stage -eq 'offline'))){throw 'NETWORK_SECONDARY'}}
 $extra=@('--network-alias','egress','--mount',(ArgMount "$dir/control" /control -RO));if($Stage -eq 'offline'){$extra+=@('--add-host','www.tiktok.com:1.1.1.1','--add-host','www.tiktok.com:1.1.1.2','--add-host','media.tiktokcdn.com:1.0.0.1')}
 $proxy=Create 'proxy' 65534 96 '0.25' '64' $private "$dir/proxy" $extra @('python3','/integration/proxy_entry.py');$ids+=$proxy
 Native 'network-connect' @('network','connect',$secondary,$proxy)|Out-Null;Guard $proxy 'proxy' 65534 96 250000000
 Native 'start-proxy' @('start',$proxy)|Out-Null
 $limit=[DateTime]::UtcNow.AddSeconds(35)
 while(-not(Test-Path "$dir/proxy/proxy-ready.json")){
  if([DateTime]::UtcNow -gt $limit){Native 'logs-proxy' @('logs',$proxy)|Out-Null;throw 'READINESS_TIMEOUT'}
  Start-Sleep -Milliseconds 150
 }
 RuntimeGate "$dir/proxy/proxy-runtime.json";if($Stage -eq 'source'){$iso=Get-Content "$dir/proxy/proxy-isolation.json" -Raw|ConvertFrom-Json;if(-not $iso.sourceSafe -or $iso.fixtureModulesLoaded.Count){throw 'SOURCE_PROXY_IMPORT'}}
 $extra=@('--mount',(ArgMount "$dir/proxy" /proxy -RO),'--mount',(ArgMount "$dir/control" /control));if($Stage -eq 'offline'){$extra+=@('--mount',(ArgMount "$dir/proxy/fixture-ca.pem" /opt/media/lib/python3.11/site-packages/certifi/cacert.pem -RO))}
 $worker=Create 'worker' 1000 512 '0.75' '96' $private "$dir/worker" $extra @('/usr/bin/timeout','--signal=KILL','95s','python3','/integration/worker_entry.py');$ids+=$worker;Guard $worker 'worker' 1000 512 750000000
 Native 'start-worker' @('start',$worker)|Out-Null;$workerExit=[int](Native 'wait-worker' @('wait',$worker)).text
 Native 'logs-worker' @('logs',$worker)|Out-Null;if((State $worker 'worker') -ne $workerExit){throw 'WORKER_EXIT'};RuntimeGate "$dir/worker/worker-runtime.json";if($Stage -eq 'source'){$pr=Get-Content "$dir/proxy/proxy-runtime.json" -Raw|ConvertFrom-Json;$wr=Get-Content "$dir/worker/worker-runtime.json" -Raw|ConvertFrom-Json;if($wr.trustSHA -cne $pr.trustSHA){throw 'SOURCE_CA_MISMATCH'}}
 Native 'stop-proxy' @('stop','--time','15',$proxy)|Out-Null;$proxyExit=State $proxy 'proxy';Native 'logs-proxy' @('logs',$proxy)|Out-Null
 $extra=@('--mount',(ArgMount "$dir/proxy" /proxy -RO),'--mount',(ArgMount "$dir/worker" /worker),'--mount',(ArgMount "$dir/control" /control -RO))
 $validate=Create 'validate' 65534 96 '0.25' '64' 'none' "$dir/validation" $extra @('python3','/integration/finalize.py');$ids+=$validate;Guard $validate 'validate' 65534 96 250000000
 $v=Native 'validate' @('start','-a',$validate) -AllowFailure;$validateExit=State $validate 'validate';if($v.exit -ne $validateExit){throw 'VALIDATE_NATIVE'}
 $outcome=Get-Content "$dir/validation/whole-result.json" -Raw|ConvertFrom-Json
 $expectedSuccess=$Case -in @('normal')
 if($Stage -eq 'offline'){
  if(($validateExit -eq 0) -ne $expectedSuccess -or ($outcome.status -eq 'PASS_WHOLEPHOTO_OFFLINE') -ne $expectedSuccess){throw 'CASE_EXPECTATION'}
  $rc=0
 }else{
  $rc=if($workerExit -eq 0 -and $proxyExit -eq 0 -and $validateExit -eq 0 -and $outcome.status -ceq 'PASS_SOURCE_TECHNICAL_NEEDS_REVIEW'){0}else{20}
 }
 foreach($f in $hashes){if((SHA $f.path) -cne $f.sha256){throw 'SOURCE_CHANGED'}}
 Save "$dir/source-after.json" $hashes
}catch{
 $failureCode='RUNNER_GUARD_OR_NATIVE_FAIL';$rc=20
 Save "$dir/runner-failure.json" @{code=$failureCode;actualExit=20;stage=$Stage;networkCause='UNKNOWN';sourceAllocationConsumed=($null -ne $release);utc=[DateTime]::UtcNow.ToString('o')}
}finally{
 foreach($id in $ids){$g=@((Native 'cleanup-owner' @('inspect',$id)).text|ConvertFrom-Json)[0];if($g.Config.Labels.'com.wed-snap.run' -cne $run){throw 'CLEANUP_OWNER'};Native 'remove' @('rm','-f',$id)|Out-Null}
 foreach($net in $nets){$g=@((Native 'cleanup-network' @('network','inspect',$net)).text|ConvertFrom-Json)[0];if($g.Labels.'com.wed-snap.run' -cne $run){throw 'NETWORK_OWNER'};Native 'network-remove' @('network','rm',$net)|Out-Null}
 $invocations='UNKNOWN'
 try{$workerReceipt=SourceRead "$dir/worker/result.json";if(($workerReceipt.analyzeInvocations -is [int] -or $workerReceipt.analyzeInvocations -is [long]) -and $workerReceipt.analyzeInvocations -in @(0,1)){$invocations=$workerReceipt.analyzeInvocations}}catch{}
 Save "$dir/completion.json" @{actualExit=$rc;workerActualExit=$workerExit;proxyActualExit=$proxyExit;validatorActualExit=$validateExit;case=$Case;stage=$Stage;sourceCalls=if($Stage -eq 'source'){'UNKNOWN_USE_REQUEST_ACCOUNTING'}else{0};workflowInvocations=$invocations;allocationID=if($release){$release.allocation.allocationID}else{$null};claimSHA=if($release){$release.claimSHA}else{$null};preparedGETAttempts=$outcome.requestAccounting.preparedGETAttempts;requestSendBeginObserved=$outcome.requestAccounting.requestSendBegin;failureCode=$failureCode;ownResourcesLeft=0;mainImage=$main;utc=[DateTime]::UtcNow.ToString('o');vn=[DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(7)).ToString('o')}
}
Write-Output "Stage=$Stage case=$Case actual=$rc worker=$workerExit proxy=$proxyExit validator=$validateExit";exit $rc
