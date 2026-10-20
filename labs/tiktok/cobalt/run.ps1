param([Parameter(Mandatory=$true)][ValidateSet('benchmark','offline','live')][string]$Stage,
      [ValidateRange(1,3)][int]$Sample=3,[ValidateRange(1,4)][int]$FixtureAttempt=1)
$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
if($Sample -ne 3){throw 'Only the explicitly assigned sample3 longURL is authorized in this successor'}
$root='D:\WED SNAP';$ev='docs/evidence/tiktok-cobalt-connection-boundaries-20261009'
$sampleURL='https://www.tiktok.com/@nguye003/video/7692288554839313682';$expectedID='7692288554839313682'
. "$PSScriptRoot/hash_gate.ps1"
. "$PSScriptRoot/redact.ps1"
$pin=Get-Content 'docs/evidence/tiktok-cobalt-20261008/image-pin.json' -Raw|ConvertFrom-Json;$image=$pin.imageID
$hostBefore=CobaltHostHashes
$dir=if($Stage -eq 'offline'){"$ev/offline-$FixtureAttempt"}elseif($Stage -eq 'benchmark'){"$ev/benchmark-$FixtureAttempt"}else{"$ev/sample-$Sample"}
if(Test-Path -LiteralPath $dir){
    if($Stage -cne 'benchmark' -or @(Get-ChildItem -LiteralPath $dir -Force).Count -ne 1 -or
       -not(Test-Path "$dir/fixture-input.mp4") -or
       (Get-FileHash "$dir/fixture-input.mp4").Hash.ToLower() -cne 'f587381808e3f189ee0125e31a040d17d9f2c4100dde9738e169c93f7c3592bb'){throw 'Refuse repeated attempt/evidence'}
}
if($Stage -eq 'live'){
    $receipt=Get-Content "$ev/offline-$FixtureAttempt/receipt.json" -Raw|ConvertFrom-Json
    Assert-CobaltHashGate $receipt $hostBefore $image
    $offlineDir="$ev/offline-$FixtureAttempt"
    if((Get-FileHash "$offlineDir/native.jsonl").Hash.ToLower() -cne $receipt.nativeSHA -or
       (Get-FileHash "$offlineDir/runtime-inventory.json").Hash.ToLower() -cne $receipt.runtimeSHA){throw 'OFFLINE_EVIDENCE_HASH_MISMATCH'}
    $integration=Get-Content "$offlineDir/integration-result.json" -Raw|ConvertFrom-Json
    if($integration.status -cne 'FILE_NEEDS_VISUAL_REVIEW' -or $integration.workerActualExit -ne 0 -or
       $integration.parentActualExit -ne 0 -or -not $integration.metadataAccepted -or $integration.sourceAttempts -ne 0 -or
       $integration.metadataPacket.summary.id -cne $expectedID){
        throw 'FULL_OFFLINE_PIPELINE_EXIT_AND_FILE_CONTRACT_REQUIRED'
    }
    $diagnostics=Get-Content "$offlineDir/send-diagnostics-fixtures.json" -Raw|ConvertFrom-Json
    if($diagnostics.status -cne 'PASS' -or $diagnostics.sourceRequests -ne 0 -or -not $diagnostics.originalExceptionsPreserved){throw 'SEND_DIAGNOSTICS_OFFLINE_REQUIRED'}
    $boundaries=Get-Content "$offlineDir/connection-boundary-fixtures.json" -Raw|ConvertFrom-Json
    if($boundaries.status -cne 'PASS' -or $boundaries.sourceRequests -ne 0 -or -not $boundaries.exceptionIdentityPreserved -or -not $boundaries.reuseAndCrossOrigin){throw 'CONNECTION_BOUNDARIES_OFFLINE_GATE_REQUIRED'}
    $timeoutTests=Get-Content "$offlineDir/read20-fixtures.json" -Raw|ConvertFrom-Json
    if($timeoutTests.status -cne 'PASS' -or $timeoutTests.sourceRequests -ne 0 -or -not $timeoutTests.absoluteDeadlineIndependent -or -not $timeoutTests.absoluteDeadlineAdapterEntered){throw 'READ20_FORWARDING_AND_ABSOLUTE_DEADLINE_REQUIRED'}
    $operationTests=Get-Content "$offlineDir/operation-fixtures.json" -Raw|ConvertFrom-Json
    $decodeTests=Get-Content "$offlineDir/decode-budget-fixtures.json" -Raw|ConvertFrom-Json
    if($decodeTests.status -cne 'PASS' -or -not $decodeTests.exhaustedBeforeSpawn -or
       -not $decodeTests.nativeErrorsAndReap -or $decodeTests.reserveSeconds -ne 10){throw 'DECODE_REMAINING_BUDGET_GATE_REQUIRED'}
    $long=Get-Content "$ev/benchmark-3/long-integration-result.json" -Raw|ConvertFrom-Json
    if($operationTests.status -cne 'PASS' -or -not $operationTests.timeoutWhitelisted -or
       $long.workerActualExit -ne 0 -or $long.parentActualExit -ne 0 -or $long.sourceAttempts -ne 0 -or
       $long.status -cne 'FILE_NEEDS_VISUAL_REVIEW' -or
       (Get-FileHash "$ev/benchmark-3/runtime-inventory.json").Hash.ToLower() -cne $receipt.runtimeSHA){throw 'EXACT_LONG_PIPELINE_OPERATIONS_GATE_REQUIRED'}
}
if($Stage -eq 'live'){
    # Both frozen owner reviews supersede their historical NOT_REVIEWED observations.
    foreach($prior in @(@{sample=1;folder='tiktok-cobalt-candidate-live-audit-20261008';id='7692808825228807442'},
                       @{sample=2;folder='tiktok-cobalt-candidate-sample2-audit-20261008';id='7611475556395191573'})){
        $successorPath="docs/evidence/$($prior.folder)/successor.json"
        if((Get-FileHash $successorPath).Hash.ToLower() -cne (Get-FileHash "$ev/sample$($prior.sample)-successor-copy.json").Hash.ToLower()){throw 'PRIOR_SUCCESSOR_CHANGED'}
        $accepted=Get-Content $successorPath -Raw|ConvertFrom-Json
        if((Get-FileHash $accepted.humanReview).Hash.ToLower() -cne $accepted.humanReviewSHA -or
           $accepted.predecessorManifestSHA -cne (Get-FileHash $accepted.predecessorManifest).Hash.ToLower()){throw 'PRIOR_ACCEPTANCE_HASH_MISMATCH'}
        $previous=Get-Content $accepted.humanReview -Raw|ConvertFrom-Json
        if(-not $previous.accepted -or -not $previous.fullVideoReviewed -or -not $previous.perceptualAudioReviewed -or
           -not $previous.watermarkReviewed -or $previous.sourceVideoId -cne $prior.id -or
           $accepted.acceptedSourceSamples -ne $prior.sample -or $previous.originalSHA -cne $accepted.sourceFileSHA -or
           (Get-FileHash $previous.originalFile).Hash.ToLower() -cne $previous.originalSHA){throw 'BOTH_PRIOR_HUMAN_ACCEPTANCES_REQUIRED'}
    }
    if((Get-FileHash $accepted.sample1AcceptanceSuccessor).Hash.ToLower() -cne $accepted.sample1AcceptanceSuccessorSHA -or
       (Get-FileHash $accepted.sample3HistoricalTarget).Hash.ToLower() -cne $accepted.sample3HistoricalTargetSHA -or
       (Get-FileHash "$ev/sample3-target-copy.json").Hash.ToLower() -cne $accepted.sample3HistoricalTargetSHA){throw 'PRIOR_LINEAGE_OR_TARGET_HASH_MISMATCH'}
    $target=Get-Content $accepted.sample3HistoricalTarget -Raw|ConvertFrom-Json
    if($target.canonicalVideoId -cne $expectedID -or $target.canonicalAuthor -cne 'nguye003'){throw 'HISTORICAL_TARGET_MISMATCH'}
}
if(-not(Test-Path -LiteralPath $dir)){New-Item -ItemType Directory -Path $dir | Out-Null}
$output=(Resolve-Path $dir).Path;$source=(Resolve-Path labs/tiktok/cobalt/src).Path
ConvertTo-Json -InputObject @($hostBefore) -Depth 5 | Set-Content "$dir/host-before.json" -Encoding utf8
if($Stage -eq 'live'){Copy-Item -LiteralPath "$offlineDir/runtime-inventory.json" -Destination "$dir/offline-runtime.json"}
$run=[Guid]::NewGuid().ToString('N');$lab='cobalt-tiktok';$label="com.wed-snap.lab=$lab";$runLabel="com.wed-snap.run=$run"
$log="$dir/native.jsonl";$ids=@();$nets=@();$code=30
function N([string]$step,[string[]]$a,[switch]$AllowFail,[int]$Seconds=15){
    $s=[DateTime]::UtcNow;$info=[Diagnostics.ProcessStartInfo]::new();$info.FileName=(Get-Command docker.exe -CommandType Application|Select-Object -First 1).Source
    $info.UseShellExecute=$false;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true;foreach($v in $a){$info.ArgumentList.Add($v)}
    $p=[Diagnostics.Process]::Start($info);$o=$p.StandardOutput.ReadToEndAsync();$e=$p.StandardError.ReadToEndAsync()
    $timeout=-not $p.WaitForExit($Seconds*1000);if($timeout){$p.Kill($true);$p.WaitForExit()}
    $stdout=$o.GetAwaiter().GetResult();$stderr=$e.GetAwaiter().GetResult();$exit=$p.ExitCode;$p.Dispose()
    @{step=$step;argv=@($a|ForEach-Object {& Clean $_});startUTC=$s.ToString('o');startVN=$s.AddHours(7).ToString('yyyy-MM-dd HH:mm:ss.fff');endUTC=[DateTime]::UtcNow.ToString('o');endVN=[DateTime]::UtcNow.AddHours(7).ToString('yyyy-MM-dd HH:mm:ss.fff');actualExit=$exit;timeout=$timeout;stdout=(Clean $stdout);stderr=(Clean $stderr)}|ConvertTo-Json -Depth 10 -Compress|Add-Content $log -Encoding utf8
    Write-Host "[$step] exit=$exit";if($timeout -or ($exit -ne 0 -and -not $AllowFail)){throw "Native $step failed/timeout exit=$exit"};return @{out=$stdout.Trim();code=$exit}
}
function Check($condition,[string]$why){if(-not $condition){throw "GUARD: $why"}}
function Inspect([string]$id){@((N 'inspect' @('inspect',$id)).out|ConvertFrom-Json)[0]}
function Track {
    $script:ids=@((N 'track-containers' @('ps','-a','--no-trunc','--filter',"label=$label",'--filter',"label=$runLabel",'--format','{{.ID}}')).out -split "`r?`n"|Where-Object {$_})
    $script:nets=@((N 'track-networks' @('network','ls','--no-trunc','--filter',"label=$label",'--filter',"label=$runLabel",'--format','{{.ID}}')).out -split "`r?`n"|Where-Object {$_})
}
function Guard($id,$expectedImage,$user,$memory,$cpu,$pids,$network,$netNames,$mounts,$cmd,$entry){
    $c=Inspect $id
    Check ($c.Image -ceq $expectedImage -and $c.Config.User -ceq $user -and $c.Id -in $script:ids) 'actual image/user/ID'
    Check ($c.Config.Labels.'com.wed-snap.run' -ceq $run -and $c.Config.Labels.'com.wed-snap.lab' -ceq $lab) 'ownership'
    Check ($c.HostConfig.ReadonlyRootfs -and -not $c.HostConfig.Privileged -and -not $c.HostConfig.CapAdd -and $c.HostConfig.CapDrop -contains 'ALL' -and $c.HostConfig.SecurityOpt -contains 'no-new-privileges:true') 'rootfs/caps/no-new-privileges'
    Check (@($c.HostConfig.SecurityOpt|Where-Object {$_ -like 'seccomp=*'}).Count -eq 0 -and -not $c.HostConfig.PidMode -and $c.HostConfig.IpcMode -ceq 'private') 'default seccomp/private namespaces'
    Check ($c.HostConfig.Memory -eq $memory -and $c.HostConfig.MemorySwap -eq $memory -and $c.HostConfig.NanoCpus -eq $cpu -and $c.HostConfig.PidsLimit -eq $pids) 'resources'
    Check ($c.HostConfig.NetworkMode -ceq $network -and @($c.HostConfig.PortBindings.PSObject.Properties).Count -eq 0) 'network/ports'
    Check ((@($c.NetworkSettings.Networks.PSObject.Properties.Name|Sort-Object)-join ',') -ceq (($netNames|Sort-Object)-join ',')) 'network set'
    Check ((@($c.Config.Cmd)-join '|') -ceq ($cmd-join '|') -and (@($c.Config.Entrypoint)-join '|') -ceq ($entry-join '|')) 'command/entrypoint'
    $actual=@($c.Mounts|ForEach-Object {"$($_.Source.Replace('/','\').ToLowerInvariant())|$($_.Destination)|$($_.RW)"}|Sort-Object)
    Check (($actual-join ';') -ceq (($mounts|Sort-Object)-join ';')) 'exact mounts'
    & Clean ($c|ConvertTo-Json -Depth 40)|Set-Content "$dir/guard-$($c.Id).json" -Encoding utf8
    return $c
}
$oldEnv=@{};foreach($k in @('COBALT_RUN_ID','COBALT_IMAGE','COBALT_INPUT','COBALT_EXPECTED_ID','COBALT_SOURCE','COBALT_OUTPUT')){$oldEnv[$k]=[Environment]::GetEnvironmentVariable($k,'Process')}
try{
    Check (-not (N 'preexisting' @('ps','-a','--filter',"label=$label",'--format','{{.ID}}')).out) 'preexisting lab; preserve'
    Check ((N 'image' @('image','inspect',$image,'--format','{{.Id}}')).out -ceq $image) 'pinned image'
    $mounts=@("$($source.ToLowerInvariant())|/lab/src|False","$($output.ToLowerInvariant())|/out|True")
    if($Stage -in @('offline','benchmark')){
        $gateStart=[DateTime]::UtcNow
        & (Get-Process -Id $PID).Path -NoProfile -File "$PSScriptRoot/test_gate.ps1" *> "$dir/host-tests.log"
        $gateExit=$LASTEXITCODE
        @{step='host-gate-redaction-tests';actualExit=$gateExit;startUTC=$gateStart.ToString('o');endUTC=[DateTime]::UtcNow.ToString('o')}|ConvertTo-Json -Compress|Add-Content $log -Encoding utf8
        Check ($gateExit -eq 0) 'host hash/redaction tests'
        $cmd=if($Stage -eq 'benchmark'){@('/usr/bin/timeout','--signal=KILL','300s','python3','/lab/src/test_decode_budget_long.py')}else{@('/usr/bin/timeout','--signal=KILL','60s','python3','/lab/src/test_all.py')}
        try{N 'create-offline' (@('create','--name','wed-snap-cobalt-offline','--label',$label,'--label',$runLabel,'--network','none','--read-only','--user','1000:1000','--cap-drop','ALL','--security-opt','no-new-privileges:true','--memory','512m','--memory-swap','512m','--cpus','0.75','--pids-limit','96','--tmpfs','/tmp:size=32m,noexec,nosuid','--mount',"type=bind,source=$source,target=/lab/src,readonly",'--mount',"type=bind,source=$output,target=/out",'-e','HOME=/tmp','--pull','never',$image)+$cmd)|Out-Null}finally{Track}
        $c=Guard $script:ids[0] $image '1000:1000' 512MB 750000000 96 'none' @('none') $mounts $cmd @('/usr/bin/tini','-g','--')
        $waitSeconds=if($Stage -eq 'benchmark'){310}else{70}
        $r=N 'offline-tests' @('start','-a',$c.Id) -AllowFail -Seconds $waitSeconds;$state=(Inspect $c.Id).State
        Check (-not $state.Running -and -not $state.OOMKilled -and $state.ExitCode -eq $r.code) 'actual test result';$code=$r.code
        if($code -eq 0){
            $runtime=Get-Content "$dir/runtime-inventory.json" -Raw|ConvertFrom-Json
            foreach($name in @('package.json','package-lock.json')){
                Check (@($runtime.dependencies|Where-Object {$_.path -ceq "/opt/cobalt/$name" -and $_.sha256 -ceq (Get-FileHash "$PSScriptRoot/$name").Hash.ToLower()}).Count -eq 1) 'installed dependency lock/package differs from host'
            }
        }
    }else{
        $env:COBALT_RUN_ID=$run;$env:COBALT_IMAGE=$image;$env:COBALT_INPUT=$sampleURL;$env:COBALT_EXPECTED_ID=$expectedID;$env:COBALT_SOURCE=$source;$env:COBALT_OUTPUT=$output
        $empty="$output/compose.empty.env";[IO.File]::WriteAllText($empty,'')
        $dc=@('compose','--env-file',$empty,'--project-directory',$root,'-f',"$root/labs/tiktok/cobalt/compose.yaml")
        & Clean ((N 'render' ($dc+@('config'))).out)|Set-Content "$dir/resolved.yaml" -Encoding utf8
        try{N 'create-lab' ($dc+@('up','--no-start','--pull','never'))|Out-Null}finally{Track}
        $e=Guard 'wed-snap-cobalt-egress' 'sha256:8bc0a567955111ea3cfbab2dd3b14f40a602f2d10ac987e78eb465f9d48d7f10' '65534:65534' 96MB 250000000 64 'wed-snap-cobalt-tiktok-lab_outbound' @('wed-snap-cobalt-tiktok-lab_outbound','wed-snap-cobalt-tiktok-lab_private') @() @('python','egress.py') @()
        $cmd=@('/usr/bin/timeout','--signal=KILL','225s','python3','/lab/src/candidate_entry.py',$sampleURL,$expectedID)
        $p=Guard 'wed-snap-cobalt-resolver' $image '1000:1000' 512MB 750000000 96 'wed-snap-cobalt-tiktok-lab_private' @('wed-snap-cobalt-tiktok-lab_private') $mounts $cmd @('/usr/bin/tini','-g','--')
        Check (($e.HostConfig.Memory+$p.HostConfig.Memory) -eq 608MB) 'exact512+96MiB runtime'
        Check ($p.Config.Env -contains 'MEDIA_PROXY=http://egress:8888') 'proxy env'
        Assert-CobaltHashGate $receipt (CobaltHostHashes) $image
        $ns=(N 'network-actual' @('network','inspect','wed-snap-cobalt-tiktok-lab_private','wed-snap-cobalt-tiktok-lab_outbound')).out|ConvertFrom-Json
        foreach($n in $ns){Check ($n.Id -in $script:nets -and $n.Labels.'com.wed-snap.run' -ceq $run) 'network ownership'}
        Check (@($ns|Where-Object {$_.Name -eq 'wed-snap-cobalt-tiktok-lab_private' -and $_.Internal}).Count -eq 1) 'internal network'
        N 'start-egress' @('start',$e.Id)|Out-Null;Start-Sleep 1;Check ((Inspect $e.Id).State.Running) 'egress running'
        $r=N 'single-analyze-conditional-download' @('start','-a',$p.Id) -AllowFail -Seconds 235
        $state=(Inspect $p.Id).State;Check (-not $state.Running -and -not $state.OOMKilled -and $state.ExitCode -eq $r.code) 'native/container outcome';$code=$r.code
        N 'egress-stats' @('stats','--no-stream','--format','{{json .}}',$e.Id)|Out-Null
    }
    Assert-CobaltHashGate @{schema=1;actualExit=0;ownResourcesLeft=0;imageID=$image;hostHashes=$hostBefore} (CobaltHostHashes) $image
}catch{Write-Output (Clean $_.Exception.Message);@{step='ABORT';utc=[DateTime]::UtcNow.ToString('o');error=(Clean $_.Exception.Message)}|ConvertTo-Json -Compress|Add-Content $log -Encoding utf8;$code=30}
finally{
    foreach($k in $oldEnv.Keys){[Environment]::SetEnvironmentVariable($k,$oldEnv[$k],'Process')}
    foreach($id in $script:ids){$c=Inspect $id;Check ($c.Id -ceq $id -and $c.Config.Labels.'com.wed-snap.run' -ceq $run -and $c.Config.Labels.'com.wed-snap.lab' -ceq $lab) 'remove ownership';N 'remove-container' @('rm','-f',$id)|Out-Null}
    foreach($id in $script:nets){$n=@((N 'network-before-remove' @('network','inspect',$id)).out|ConvertFrom-Json)[0];Check ($n.Id -ceq $id -and $n.Labels.'com.wed-snap.run' -ceq $run) 'remove network ownership';N 'remove-network' @('network','rm',$id)|Out-Null}
    $left=(N 'run-containers-left' @('ps','-a','--filter',"label=$runLabel",'--format','{{.ID}}')).out
    $leftNet=(N 'run-networks-left' @('network','ls','--filter',"label=$runLabel",'--format','{{.ID}}')).out
    Check (-not $left -and -not $leftNet) 'cleanup incomplete'
    @{step='end';actualExit=$code;endUTC=[DateTime]::UtcNow.ToString('o');endVN=[DateTime]::UtcNow.AddHours(7).ToString('yyyy-MM-dd HH:mm:ss.fff');ownResourcesLeft=0;removedContainers=@($script:ids).Count;removedNetworks=@($script:nets).Count}|ConvertTo-Json -Compress|Add-Content $log -Encoding utf8
}
if($Stage -eq 'offline' -and $code -eq 0){
    [ordered]@{schema=1;actualExit=0;ownResourcesLeft=0;imageID=$image;hostHashes=$hostBefore;
        runtimeSHA=(Get-FileHash "$dir/runtime-inventory.json").Hash.ToLower();nativeSHA=(Get-FileHash $log).Hash.ToLower();
        utc=[DateTime]::UtcNow.ToString('o')}|ConvertTo-Json -Depth 6|Set-Content "$dir/receipt.json" -Encoding utf8
}
exit $code
