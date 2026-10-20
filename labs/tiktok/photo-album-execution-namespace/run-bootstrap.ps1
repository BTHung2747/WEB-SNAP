param([switch]$SelfTest,[string]$ExecutionID)
$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
. "$PSScriptRoot/bootstrap_contract.ps1"
SetAlbumExecution $ExecutionID -Offline:$SelfTest
$root=AlbumRoot;$inputDir=Join-Path $root $(if($SelfTest){'self-test/input'}else{'reviewed/input'})
# No Docker, issuance or source operation before this exact candidate/review gate.
$a=AssertBootstrap $inputDir -SelfTest:$SelfTest
$out=Join-Path $root $(if($SelfTest){'self-test/cold'}else{'reviewed/cold'})
$null=AlbumExecutionPath $out
if(Test-Path $out){throw 'BOOTSTRAP_REUSE'}
New-Item -ItemType Directory "$out/result","$out/control"|Out-Null;FixedPath $out $out
Copy-Item "$inputDir/bootstrap-control.json" "$out/control/control.json"
$run=[Guid]::NewGuid().ToString('N');$id=$null;$rc=20;$removed=$false
function Native($step,[string[]]$argv){
 $begin=[DateTime]::UtcNow;$text=& docker @argv 2>&1|Out-String;$nativeExit=$LASTEXITCODE
 BootstrapWrite "$out/native-$step.json" @{step=$step;actualExit=$nativeExit;stdout=$text;utcStart=$begin.ToString('o');utcEnd=[DateTime]::UtcNow.ToString('o')}
 return @{text=$text.Trim();exit=$nativeExit}
}
function MountArg($path,$dest,[switch]$RO){$s="type=bind,source=$((Resolve-Path $path).Path),target=$dest";if($RO){$s+=',readonly'};return $s}
try{
 $mounts=@();foreach($pair in @(@("$PSScriptRoot/runtime",'/integration'),@("$PSScriptRoot/runtime",'/poc'),@('labs/tiktok/connect-poc/vendor','/vendor'),@('labs/tiktok/setup-trace','/trace_lab'),@('apps/egress/src','/stock'),@("$PSScriptRoot/photo-runtime",'/app/apps/media/src/tiktok/source_photo'),@($inputDir,'/authority'),@("$out/control",'/control'))){$mounts+=@('--mount',(MountArg $pair[0] $pair[1] -RO))}
 $n=Native 'create' (@('create','--pull','never','--network','none','--read-only','--user','65534:65534','--memory','96m','--memory-swap','96m','--cpus','0.25','--pids-limit','64','--ipc','private','--cap-drop','ALL','--security-opt','no-new-privileges:true','--tmpfs','/tmp:size=16m,uid=65534,gid=65534,noexec,nosuid','--label',"com.wed-snap.album-bootstrap=$run",'-e','WHOLEPHOTO_STAGE=bootstrap','-e','PYTHONPATH=/integration:/vendor:/app/apps/media/src','-e','PYTHONDONTWRITEBYTECODE=1','-e','PYTHONWARNINGS=ignore','--mount',(MountArg "$out/result" '/out'))+$mounts+@((SourceImage),'/usr/bin/timeout','--signal=KILL','30s','python3','/integration/bootstrap_probe.py'))
 if($n.exit){throw 'BOOTSTRAP_CREATE'};$id=$n.text
 $n=Native 'guard' @('inspect',$id);if($n.exit){throw 'BOOTSTRAP_INSPECT'};$g=@($n.text|ConvertFrom-Json -DateKind String)[0]
 BootstrapGuard $g;BootstrapWrite "$out/cold-guard.json" $g;BootstrapWrite "$out/cold-mounts.json" $g.Mounts
 $n=Native 'start' @('start','-a',$id);$rc=$n.exit
 $n=Native 'state' @('inspect',$id);if($n.exit){throw 'BOOTSTRAP_STATE'};$s=@($n.text|ConvertFrom-Json -DateKind String)[0].State;BootstrapWrite "$out/cold-state.json" $s
 if($rc -ne 0 -or $s.ExitCode -ne $rc -or $s.OOMKilled -or $s.Running){throw 'BOOTSTRAP_NATIVE_FAIL'}
 $r=SourceRead "$out/result/cold-report.json";AssertVersions $r
 if($r.scope -cne $a.scope -or $r.controlSHA -cne (SourceSHA "$inputDir/bootstrap-control.json") -or $r.uid -ne 65534 -or $r.fdDelta -ne 0 -or $r.threadsBefore -ne 1 -or $r.threadsAfter -ne 1 -or (Canonical $r.sources) -cne (Canonical (RuntimeExpected -Source)) -or $r.trustSHA -cne (SourceTrust)){throw 'BOOTSTRAP_REPORT'}
}finally{
 if($id){$n=Native 'owner' @('inspect',$id);if($n.exit){throw 'BOOTSTRAP_OWNER'};$owner=@($n.text|ConvertFrom-Json)[0];if($owner.Config.Labels.'com.wed-snap.album-bootstrap' -cne $run){throw 'BOOTSTRAP_OWNER'};$n=Native 'remove' @('rm','-f',$id);$removed=$n.exit -eq 0}
 BootstrapWrite "$out/cleanup.json" @{actualExit=$rc;ownID=$id;ownResourcesLeft=$(if($removed){0}else{1});sourceCalls=0;realClaims=0;utc=[DateTime]::UtcNow.ToString('o');vn=[DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(7)).ToString('o')}
}
if(-not $removed){throw 'BOOTSTRAP_CLEANUP'}
foreach($name in 'preparation.json','review.json','bootstrap-control.json'){Copy-Item "$inputDir/$name" "$out/$name"}
Copy-Item "$out/result/cold-report.json" "$out/cold-report.json"
Copy-Item "$out/native-start.json" "$out/cold-native.json"
BootstrapWrite "$out/cold-completion.json" @{actualExit=$rc;sourceCalls=0;ownResourcesLeft=0;producerScope=$a.scope;controlSHA=SourceSHA "$out/bootstrap-control.json";reportSHA=SourceSHA "$out/cold-report.json";stateSHA=SourceSHA "$out/cold-state.json";mountsSHA=SourceSHA "$out/cold-mounts.json";nativeSHA=SourceSHA "$out/cold-native.json";utc=[DateTime]::UtcNow.ToString('o')}
BootstrapWrite "$out/cold.json" @{version=4;scope=$(if($SelfTest){'OFFLINE_BOOTSTRAP_SELF_TEST_V1'}else{'ALBUM_SOURCE_COLD_ATTESTATION_V1'});status=$(if($SelfTest){'SELF_TEST_NOT_REVIEW_ATTESTATION'}else{'PASS_SOURCE_ONLY_COLD_NETWORK_NONE'});sourceCalls=0;actualExit=0;sources=$r.sources;versions=$r.versions;python=$r.python;trustSHA=$r.trustSHA;fixtureModules=@();network='none';sourceMainInvoked=$false;utc=$r.utc;guardSHA=SourceSHA "$out/cold-guard.json";completionSHA=SourceSHA "$out/cold-completion.json"}
Write-Output 'BOOTSTRAP_COMPLETE_NO_SOURCE_RIGHTS';exit 0
