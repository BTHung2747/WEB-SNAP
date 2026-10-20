param([ValidateSet('offline','source')][string]$Stage='offline',[int]$Attempt=1,[ValidateSet('normal','candidate-latency','image-dns-failure','image-tcp-failure','image-cert-failure','image-tls-stall','image-html','wrong-body','redirect','dns-private','health-missing','health-incomplete','trace-cap','trace-open','trace-write','helper-crash','helper-cap','helper-late','helper-answer-cap','handoff-fail','owner-abort','final-close-fail','summary-missing','postfile-diagnostic','preexisting','parent-nonzero','parent-expiry','guards','ssrf-literal','ssrf-host','cancel','proxy-parent-block','observer-disjoint','observer-extra','observer-extra-preexisting','observer-order-send','observer-order-header','observer-order-header-preexisting','observer-order-setup','observer-order-reopen','batch-stall-third','batch-fast7','batch-fast45','batch-fast64','batch-admission-postfile','batch-admission-preexisting','batch-phase-missing','batch-epoch-postfile','batchval-groups0','batchval-records-empty','batchval-owner-disjoint','batchval-registry-disjoint','batchval-duplicate-owner','batchval-missing-operation','batchval-record-mismatch','batchval-preexisting','closure-idempotent','closure-live','closure-missing','closure-terminal','closure-error','closure-owner','closure-before-winner','closure-before-handoff','closure-late','closure-extra','closure-preexisting')][string]$Case='normal')
$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
$root='docs/evidence/tiktok-registry-closure-20261011';$dir=if($Stage -eq 'offline'){"$root/run-$Attempt-$Case"}else{"$root/source-1"}
if(Test-Path $dir){throw 'Refuse evidence reuse'}
if($Stage -eq 'source'){throw 'SOURCE_NOT_AUTHORIZED_DIAGNOSTIC_TASK'}
if($Stage -eq 'source'){
 if(Test-Path "$root/source-claim.json"){throw 'Source budget already claimed'}
 & "$PSScriptRoot/gate.ps1" -Verify
 if($LASTEXITCODE -ne 0){throw 'EXACT_OFFLINE_GATE'}
 # Atomic ownership receipt: never clear it on failure, and never allow a second source run.
 $claim=[IO.File]::Open("$root/source-claim.json",[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
 try{$bytes=[Text.Encoding]::UTF8.GetBytes((@{analyze=1;target='https://www.tiktok.com/@adne_la.veil/photo/7678209751167110421';expectedID='7678209751167110421';utc=[DateTime]::UtcNow.ToString('o')}|ConvertTo-Json));$claim.Write($bytes,0,$bytes.Length)}finally{$claim.Dispose()}
}
New-Item -ItemType Directory "$dir/proxy","$dir/worker","$dir/control","$dir/validation"|Out-Null
function SHA($p){(Get-FileHash -LiteralPath $p).Hash.ToLowerInvariant()}
function Save($p,$v){ConvertTo-Json -InputObject $v -Depth 40|Set-Content -LiteralPath $p}
$files=@(rg --files labs/tiktok/wholephoto-registry-closure labs/tiktok/wholephoto-batch-validation labs/tiktok/wholephoto-batch labs/tiktok/wholephoto-order labs/tiktok/wholephoto-linkage labs/tiktok/wholephoto-diagnostics labs/tiktok/wholephoto-source labs/tiktok/wholephoto-connector labs/tiktok/trace-cleanup labs/tiktok/connect-closure-dns labs/tiktok/connect-poc labs/tiktok/photo-trace labs/tiktok/photo labs/tiktok/setup-trace apps/media/src/tiktok apps/media/requirements.lock apps/egress/src/egress.py)
$hashes=@(foreach($p in $files){[pscustomobject]@{path=$p.Replace('\','/');sha256=SHA $p}})|Sort-Object path
Save "$dir/source-before.json" $hashes
if($Stage -eq 'source'){if($Case -cne 'normal'){throw 'SOURCE_FAULT_DENIED'};Save "$dir/control/control.json" @{stage='source';phaseDeadline=0}}else{Save "$dir/control/control.json" @{stage='offline';case=$Case;mode=$Case;phaseDeadline=0}}
Save "$dir/budget.json" @{fixture=($Stage -eq 'offline');sourceCalls=0;target='https://www.tiktok.com/@adne_la.veil/photo/7678209751167110421';expectedID='7678209751167110421';preparedTarget='https://www.tiktok.com/@adne_la.veil/video/7678209751167110421';analyze=1;metadataGET=2;metadataSeconds=30;metadataResponseBytes=8MB;metadataTotalBytes=16MB;imageGET=1;prepareSeconds=60;imageInputBytes=20MB;imageOutputBytes=16MB;workflowBytes=36MB;pixels=16000000;dimension=8192;redirect=0;retry=0;HEAD=0;setupSeconds=10;reserveSeconds=1;connectSeconds=10;readSeconds=20;runtimeMiB=608;helperLimit=1;stage=$Stage;case=$Case}
$image='sha256:31742091e95df2cc62669a6c6a9e0892dc09a34341eaeefc16959dcd4dfa417e'
$run=[Guid]::NewGuid().ToString('N');$ids=@();$nets=@();$rc=1;$outcome=$null
function Native($step,[string[]]$argv,[switch]$AllowFailure){
 $start=[DateTime]::UtcNow;$text=& docker @argv 2>&1|Out-String;$exit=$LASTEXITCODE
 SaveLine @{step=$step;actualExit=$exit;utcStart=$start.ToString('o');utcEnd=[DateTime]::UtcNow.ToString('o');stdout=$text}
 if($exit -and -not $AllowFailure){throw "DOCKER_$step"};return @{text=$text.Trim();exit=$exit}
}
function SaveLine($v){$v|ConvertTo-Json -Compress -Depth 8|Add-Content "$dir/native.jsonl"}
function ArgMount($path,$target,[switch]$RO){$v="type=bind,source=$((Resolve-Path $path).Path),target=$target";if($RO){$v+=',readonly'};return $v}
$sources=@('--mount',(ArgMount labs/tiktok/wholephoto-registry-closure /integration -RO),'--mount',(ArgMount labs/tiktok/wholephoto-registry-closure /poc -RO),
 '--mount',(ArgMount labs/tiktok/connect-poc/vendor /vendor -RO),'--mount',(ArgMount labs/tiktok/photo /app/apps/media/src/tiktok/photo_lab -RO),
 '--mount',(ArgMount labs/tiktok/setup-trace /trace_lab -RO),'--mount',(ArgMount apps/egress/src /stock -RO))
function Create($role,$user,$ram,$cpu,$pids,$network,$output,[string[]]$extra,[string[]]$command){
 return (Native "create-$role" (@('create','--label','com.wed-snap.lab=tiktok-batch-validation','--label',"com.wed-snap.run=$run",'--label',"com.wed-snap.role=$role",'--network',$network,
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
  if($h.ExtraHosts -or @($g.Config.Env|Where-Object {$_ -match '^(FIXTURE_|TIKTOK_APP_FIXTURE=|SSL_CERT_FILE=|SSL_CERT_DIR=|REQUESTS_CA_BUNDLE=|CURL_CA_BUNDLE=)'}).Count -or @($g.Mounts|Where-Object {$_.Destination -match '(certifi|cacert|fixture)' -or $_.Source -match '(fixture-ca|fixture-provider|fixture-control)'}).Count){throw 'SOURCE_FIXTURE_GUARD'}
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
 foreach($f in $r.sources){$part=$f.path.Split('/',2);$base=switch($part[0]){'integration'{'labs/tiktok/wholephoto-registry-closure'}'photo'{'labs/tiktok/photo'}'trace'{'labs/tiktok/setup-trace'}'vendor'{'labs/tiktok/connect-poc/vendor'}'core'{'apps/media/src/tiktok'}default{throw 'SOURCE_ROOT'}};if((SHA "$base/$($part[1])") -cne $f.sha256){throw 'RUNTIME_SOURCE'}}
}
try{
 $main=(Native 'main-before' @('image','inspect','wed-snap-app:local','--format','{{.Id}}')).text
 if((Native 'image' @('image','inspect',$image,'--format','{{.Id}}')).text -cne $image){throw 'IMAGE_PIN'}
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
 $expectedSuccess=$Case -in @('normal','candidate-latency','batch-stall-third','batch-fast7','closure-idempotent')
 if($Stage -eq 'offline'){
  if(($validateExit -eq 0) -ne $expectedSuccess -or ($outcome.status -eq 'PASS_WHOLEPHOTO_OFFLINE') -ne $expectedSuccess){throw 'CASE_EXPECTATION'}
  $rc=0
 }else{
  $rc=if($workerExit -eq 0 -and $proxyExit -eq 0 -and $validateExit -eq 0 -and $outcome.status -ceq 'PASS_SOURCE_TECHNICAL_NEEDS_REVIEW'){0}else{20}
 }
 foreach($f in $hashes){if((SHA $f.path) -cne $f.sha256){throw 'SOURCE_CHANGED'}}
 Save "$dir/source-after.json" $hashes
}finally{
 foreach($id in $ids){$g=@((Native 'cleanup-owner' @('inspect',$id)).text|ConvertFrom-Json)[0];if($g.Config.Labels.'com.wed-snap.run' -cne $run){throw 'CLEANUP_OWNER'};Native 'remove' @('rm','-f',$id)|Out-Null}
 foreach($net in $nets){$g=@((Native 'cleanup-network' @('network','inspect',$net)).text|ConvertFrom-Json)[0];if($g.Labels.'com.wed-snap.run' -cne $run){throw 'NETWORK_OWNER'};Native 'network-remove' @('network','rm',$net)|Out-Null}
 Save "$dir/completion.json" @{actualExit=$rc;workerActualExit=$workerExit;proxyActualExit=$proxyExit;validatorActualExit=$validateExit;case=$Case;stage=$Stage;sourceCalls=if($Stage -eq 'source'){$outcome.sourceCalls}else{0};ownResourcesLeft=0;mainImage=$main;utc=[DateTime]::UtcNow.ToString('o');vn=[DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(7)).ToString('o')}
}
Write-Output "Stage=$Stage case=$Case actual=$rc worker=$workerExit proxy=$proxyExit validator=$validateExit";exit $rc
