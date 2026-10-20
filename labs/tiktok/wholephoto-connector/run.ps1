param([int]$Attempt=1,[ValidateSet('normal','candidate-latency','image-dns-failure','image-tcp-failure','image-cert-failure','image-tls-stall','image-html','wrong-body','redirect','dns-private','health-missing','health-incomplete','trace-cap','trace-open','trace-write','helper-crash','helper-cap','helper-late','helper-answer-cap','handoff-fail','owner-abort','final-close-fail','summary-missing','postfile-diagnostic','preexisting','parent-nonzero','parent-expiry','guards','ssrf-literal','ssrf-host','cancel','proxy-parent-block')][string]$Case='normal')
$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
$root='docs/evidence/tiktok-wholephoto-connector-20261010';$dir="$root/run-$Attempt-$Case"
if(Test-Path $dir){throw 'Refuse evidence reuse'}
New-Item -ItemType Directory "$dir/proxy","$dir/worker","$dir/control","$dir/validation"|Out-Null
function SHA($p){(Get-FileHash -LiteralPath $p).Hash.ToLowerInvariant()}
function Save($p,$v){ConvertTo-Json -InputObject $v -Depth 40|Set-Content -LiteralPath $p}
$files=@(rg --files labs/tiktok/wholephoto-connector labs/tiktok/trace-cleanup labs/tiktok/connect-closure-dns labs/tiktok/connect-poc labs/tiktok/photo-trace labs/tiktok/photo labs/tiktok/setup-trace apps/media/src/tiktok apps/media/requirements.lock apps/egress/src/egress.py)
$hashes=@(foreach($p in $files){[pscustomobject]@{path=$p.Replace('\','/');sha256=SHA $p}})|Sort-Object path
Save "$dir/source-before.json" $hashes
Save "$dir/control/control.json" @{case=$Case;mode=$Case;phaseDeadline=0}
Save "$dir/budget.json" @{fixture=$true;sourceCalls=0;analyze=1;metadataGET=2;metadataSeconds=30;metadataResponseBytes=8MB;metadataTotalBytes=16MB;imageGET=1;prepareSeconds=60;imageInputBytes=20MB;imageOutputBytes=16MB;workflowBytes=36MB;pixels=16000000;dimension=8192;redirect=0;retry=0;HEAD=0;setupSeconds=10;reserveSeconds=1;connectSeconds=10;readSeconds=20;runtimeMiB=608;helperLimit=1;stage='OFFLINE_ONLY';case=$Case}
$image='sha256:31742091e95df2cc62669a6c6a9e0892dc09a34341eaeefc16959dcd4dfa417e'
$run=[Guid]::NewGuid().ToString('N');$ids=@();$nets=@();$rc=1;$outcome=$null
function Native($step,[string[]]$argv,[switch]$AllowFailure){
 $start=[DateTime]::UtcNow;$text=& docker @argv 2>&1|Out-String;$exit=$LASTEXITCODE
 SaveLine @{step=$step;actualExit=$exit;utcStart=$start.ToString('o');utcEnd=[DateTime]::UtcNow.ToString('o');stdout=$text}
 if($exit -and -not $AllowFailure){throw "DOCKER_$step"};return @{text=$text.Trim();exit=$exit}
}
function SaveLine($v){$v|ConvertTo-Json -Compress -Depth 8|Add-Content "$dir/native.jsonl"}
function ArgMount($path,$target,[switch]$RO){$v="type=bind,source=$((Resolve-Path $path).Path),target=$target";if($RO){$v+=',readonly'};return $v}
$sources=@('--mount',(ArgMount labs/tiktok/wholephoto-connector /integration -RO),'--mount',(ArgMount labs/tiktok/wholephoto-connector /poc -RO),
 '--mount',(ArgMount labs/tiktok/connect-poc/vendor /vendor -RO),'--mount',(ArgMount labs/tiktok/photo /app/apps/media/src/tiktok/photo_lab -RO),
 '--mount',(ArgMount labs/tiktok/setup-trace /trace_lab -RO),'--mount',(ArgMount apps/egress/src /stock -RO))
function Create($role,$user,$ram,$cpu,$pids,$network,$output,[string[]]$extra,[string[]]$command){
 return (Native "create-$role" (@('create','--label','com.wed-snap.lab=tiktok-wholephoto-connector','--label',"com.wed-snap.run=$run",'--label',"com.wed-snap.role=$role",'--network',$network,
  '--read-only','--user',"${user}:$user",'--memory',"${ram}m",'--memory-swap',"${ram}m",'--cpus',$cpu,'--pids-limit',$pids,'--ipc','private','--cap-drop','ALL','--security-opt','no-new-privileges:true',
  '--tmpfs',"/tmp:size=32m,uid=$user,gid=$user,noexec,nosuid",'--mount',(ArgMount $output /out),'-e','WHOLEPHOTO_STAGE=offline','-e','PYTHONPATH=/integration:/vendor:/app/apps/media/src',
  '-e','PYTHONDONTWRITEBYTECODE=1','-e','PYTHONWARNINGS=ignore')+$sources+$extra+@($image)+$command)).text
}
function Guard($id,$role,$user,$ram,$cpu){
 $g=@((Native "guard-$role" @('inspect',$id)).text|ConvertFrom-Json)[0];$h=$g.HostConfig
 if($g.Image -cne $image -or $g.Config.User -cne "${user}:$user" -or $h.Memory -ne ($ram*1MB) -or $h.MemorySwap -ne ($ram*1MB) -or $h.NanoCpus -ne $cpu -or -not $h.ReadonlyRootfs -or $h.Privileged -or $h.CapAdd -or 'ALL' -notin $h.CapDrop -or 'no-new-privileges:true' -notin $h.SecurityOpt -or $h.IpcMode -ne 'private'){throw 'GUARD_FAIL'}
 Save "$dir/guard-$role.json" $g
}
function State($id,$role){$s=@((Native "state-$role" @('inspect',$id)).text|ConvertFrom-Json)[0].State;Save "$dir/state-$role.json" $s;if($s.OOMKilled -or $s.Running){throw 'OOM_OR_RUNNING'};return $s.ExitCode}
function RuntimeGate($path){
 $r=Get-Content $path -Raw|ConvertFrom-Json
 if($r.python -cne '3.11.2' -or $r.versions.requests -cne '2.34.2' -or $r.versions.urllib3 -cne '2.8.0' -or $r.versions.aiohappyeyeballs -cne '2.7.1'){throw 'RUNTIME_PIN'}
 foreach($f in $r.sources){$part=$f.path.Split('/',2);$base=switch($part[0]){'integration'{'labs/tiktok/wholephoto-connector'}'photo'{'labs/tiktok/photo'}'trace'{'labs/tiktok/setup-trace'}'vendor'{'labs/tiktok/connect-poc/vendor'}'core'{'apps/media/src/tiktok'}default{throw 'SOURCE_ROOT'}};if((SHA "$base/$($part[1])") -cne $f.sha256){throw 'RUNTIME_SOURCE'}}
}
try{
 $main=(Native 'main-before' @('image','inspect','wed-snap-app:local','--format','{{.Id}}')).text
 if((Native 'image' @('image','inspect',$image,'--format','{{.Id}}')).text -cne $image){throw 'IMAGE_PIN'}
 $private=(Native 'network-private' @('network','create','--internal','--label',"com.wed-snap.run=$run","wp-$run-private")).text;$nets+=$private
 $secondary=(Native 'network-secondary' @('network','create','--internal','--label',"com.wed-snap.run=$run","wp-$run-fixture")).text;$nets+=$secondary
 foreach($net in $nets){$info=@((Native 'network-inspect' @('network','inspect',$net)).text|ConvertFrom-Json)[0];if(-not $info.Internal){throw 'NETWORK_OUTBOUND'}}
 $extra=@('--network-alias','egress','--mount',(ArgMount "$dir/control" /control -RO),'--add-host','www.tiktok.com:1.1.1.1','--add-host','www.tiktok.com:1.1.1.2','--add-host','media.tiktokcdn.com:1.0.0.1')
 $proxy=Create 'proxy' 65534 96 '0.25' '64' $private "$dir/proxy" $extra @('python3','/integration/proxy_entry.py');$ids+=$proxy
 Native 'network-connect' @('network','connect',$secondary,$proxy)|Out-Null;Guard $proxy 'proxy' 65534 96 250000000
 Native 'start-proxy' @('start',$proxy)|Out-Null
 $limit=[DateTime]::UtcNow.AddSeconds(35)
 while(-not(Test-Path "$dir/proxy/proxy-ready.json")){
  if([DateTime]::UtcNow -gt $limit){Native 'logs-proxy' @('logs',$proxy)|Out-Null;throw 'READINESS_TIMEOUT'}
  Start-Sleep -Milliseconds 150
 }
 RuntimeGate "$dir/proxy/proxy-runtime.json"
 $extra=@('--mount',(ArgMount "$dir/proxy" /proxy -RO),'--mount',(ArgMount "$dir/control" /control),'--mount',(ArgMount "$dir/proxy/fixture-ca.pem" /opt/media/lib/python3.11/site-packages/certifi/cacert.pem -RO))
 $worker=Create 'worker' 1000 512 '0.75' '96' $private "$dir/worker" $extra @('/usr/bin/timeout','--signal=KILL','95s','python3','/integration/worker_entry.py');$ids+=$worker;Guard $worker 'worker' 1000 512 750000000
 Native 'start-worker' @('start',$worker)|Out-Null;$workerExit=[int](Native 'wait-worker' @('wait',$worker)).text
 Native 'logs-worker' @('logs',$worker)|Out-Null;if((State $worker 'worker') -ne $workerExit){throw 'WORKER_EXIT'};RuntimeGate "$dir/worker/worker-runtime.json"
 Native 'stop-proxy' @('stop','--time','15',$proxy)|Out-Null;$proxyExit=State $proxy 'proxy';Native 'logs-proxy' @('logs',$proxy)|Out-Null
 $extra=@('--mount',(ArgMount "$dir/proxy" /proxy -RO),'--mount',(ArgMount "$dir/worker" /worker))
 $validate=Create 'validate' 65534 96 '0.25' '64' 'none' "$dir/validation" $extra @('python3','/integration/finalize.py');$ids+=$validate;Guard $validate 'validate' 65534 96 250000000
 $v=Native 'validate' @('start','-a',$validate) -AllowFailure;$validateExit=State $validate 'validate';if($v.exit -ne $validateExit){throw 'VALIDATE_NATIVE'}
 $outcome=Get-Content "$dir/validation/whole-result.json" -Raw|ConvertFrom-Json
 $expectedSuccess=$Case -in @('normal','candidate-latency')
 if(($validateExit -eq 0) -ne $expectedSuccess -or ($outcome.status -eq 'PASS_WHOLEPHOTO_OFFLINE') -ne $expectedSuccess){throw 'CASE_EXPECTATION'}
 foreach($f in $hashes){if((SHA $f.path) -cne $f.sha256){throw 'SOURCE_CHANGED'}}
 Save "$dir/source-after.json" $hashes;$rc=0
}finally{
 foreach($id in $ids){$g=@((Native 'cleanup-owner' @('inspect',$id)).text|ConvertFrom-Json)[0];if($g.Config.Labels.'com.wed-snap.run' -cne $run){throw 'CLEANUP_OWNER'};Native 'remove' @('rm','-f',$id)|Out-Null}
 foreach($net in $nets){$g=@((Native 'cleanup-network' @('network','inspect',$net)).text|ConvertFrom-Json)[0];if($g.Labels.'com.wed-snap.run' -cne $run){throw 'NETWORK_OWNER'};Native 'network-remove' @('network','rm',$net)|Out-Null}
 Save "$dir/completion.json" @{actualExit=$rc;workerActualExit=$workerExit;proxyActualExit=$proxyExit;validatorActualExit=$validateExit;case=$Case;sourceCalls=0;ownResourcesLeft=0;mainImage=$main;utc=[DateTime]::UtcNow.ToString('o');vn=[DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(7)).ToString('o')}
}
Write-Output "PASS expectation $Case; worker=$workerExit proxy=$proxyExit validator=$validateExit";exit $rc
