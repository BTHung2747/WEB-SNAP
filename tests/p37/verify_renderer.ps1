# File/log/hash-only successor. Never launch browser/egress/source or change predecessor verifiers.
param([switch]$Capture)
$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
$ev='docs/evidence/p37-renderer-20261007';$old='docs/evidence/p37-4-r-20261007'
$docs=@('docs/PROGRESS.md','docs/ADAPTERS.md','docs/TEST_REPORT.md','docs/AUDIT_TIEN_DO.md')
function SHA([string]$p){(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLower()}
$oldSHA='cf4566b17c4eeebeb98d6da2ba9e3a35474591929201d59e596d0a5daefbd757'
if((SHA "$old/manifest.json") -cne $oldSHA -or (Get-Content "$old/manifest-sha256.txt" -Raw).Trim() -cne $oldSHA){throw 'Repair manifest/selfmetadata changed'}
$pred=@(Get-Content "$old/manifest.json" -Raw | ConvertFrom-Json)
$proof=Get-Content "$ev/predecessor.json" -Raw | ConvertFrom-Json
if($pred.Count -ne 108 -or $proof.entries -ne 108 -or $proof.preservedBefore -ne 107 -or $proof.manifestSHA -cne $oldSHA){throw 'Predecessor proof mismatch'}
foreach($r in $pred){
    $p=@($proof.rows | Where-Object {$_.path -ceq $r.path})
    if($p.Count -ne 1 -or $p[0].oldSHA -cne $r.sha256){throw 'Predecessor coverage mismatch'}
    if($r.path -ne 'docs/AUDIT_TIEN_DO.md' -and $p[0].currentSHA -cne $r.sha256){throw 'Pre-update107/107 mismatch'}
    if($r.path -notin $docs -and ((SHA $r.path) -cne $r.sha256 -or (Get-Item -LiteralPath $r.path).Length -ne $r.bytes)){throw "Historical source/raw mismatch $($r.path)"}
}
$before=@(Get-Content "$ev/before-all-sha.json" -Raw | ConvertFrom-Json)
if(@($before | Where-Object {$_.file -eq 'docs/AUDIT_TIEN_DO.md'})[0].sha256 -cne $proof.currentAuditSHA){throw 'Inherited audit SHA mismatch'}
$kept=0;$changed=@()
foreach($r in $before){
    if(-not(Test-Path -LiteralPath $r.file)){throw "Missing old path $($r.file)"}
    if($r.file -in $docs){if((SHA $r.file) -cne $r.sha256){$changed+=$r.file}}
    elseif((SHA $r.file) -cne $r.sha256 -or (Get-Item -LiteralPath $r.file).Length -ne $r.bytes){throw "Unscoped change $($r.file)"}
    else{$kept++}
}
$core="$ev/upstream/playwright-core-1.63.0.tgz"
if((SHA $core) -cne '208593d4e1bcd8f8fe5f869cad1cc332dc7f1d70dc1d58c102dc3ac36e30f26c'){throw 'Core tarball SHA mismatch'}
$dep=Get-Content "$ev/dependency-pin.json" -Raw | ConvertFrom-Json
$hasher=[Security.Cryptography.SHA512]::Create();$stream=[IO.File]::OpenRead((Join-Path (Get-Location) $core))
try{$sri='sha512-'+[Convert]::ToBase64String($hasher.ComputeHash($stream))}finally{$stream.Dispose();$hasher.Dispose()}
if($sri -cne $dep.integrity -or $dep.version -cne '1.63.0'){throw 'Official SRI/version mismatch'}
$sec=Get-Content "$ev/seccomp-pin.json" -Raw | ConvertFrom-Json
if((SHA 'infra/renderer-seccomp-1.63.json') -cne $sec.sha256){throw 'Official profile changed'}
$image=Get-Content "$ev/image-pin.json" -Raw | ConvertFrom-Json
if($image.actualImageID -cne 'sha256:e3e776372b598eb8eaf57dea5ce293f79a1c834e6e92dce9e6b9bb9a2bf2baf9' -or $image.baseLayersVerified -ne 11){throw 'Image pin/base mismatch'}
$build=@(Get-Content "$ev/build.jsonl" | ForEach-Object {$_ | ConvertFrom-Json})
if(@($build | Where-Object {$_.step -eq 'build-renderer' -and $_.actualExit -eq 0}).Count -ne 1){throw 'Expected one successful native image build'}
$cap=Get-Content "$ev/capability/capability.json" -Raw | ConvertFrom-Json
$interp=Get-Content "$ev/interpretation.json" -Raw | ConvertFrom-Json
$native=@(Get-Content "$ev/capability/native.jsonl" | ForEach-Object {$_ | ConvertFrom-Json})
$end=@($native | Where-Object {$_.step -eq 'end'})[-1]
$state=(@($native | Where-Object {$_.step -eq 'state'})[0].output | ConvertFrom-Json)
if($cap.capabilityStatus -cne 'FAIL' -or $cap.sourceNavigations -ne 0 -or $end.actualExit -ne 30 -or $end.ownResourcesLeft -ne 0 -or $state.ExitCode -ne 30 -or $state.Running){throw 'Capability stop/cleanup/native outcomes mismatch'}
if($interp.contextCreated -or $interp.metadata -cne 'NOT_RUN' -or $interp.download -cne 'NOT_RUN' -or -not $interp.actualSeccompMatchesOfficial){throw 'Interpretation/safety scope mismatch'}
$guard=Get-Content "$ev/capability/actual-guard.json" -Raw | ConvertFrom-Json
if($guard.Image -cne $image.actualImageID -or $guard.Config.User -cne '1000:1000' -or $guard.HostConfig.Memory -ne 928MB -or $guard.HostConfig.NetworkMode -cne 'none' -or -not $guard.HostConfig.ReadonlyRootfs){throw 'Actual guard proof mismatch'}
$final=@(Get-Content "$ev/final-docker-read.json" -Raw | ConvertFrom-Json)
if(@($final | Where-Object {$_.actualExit -ne 0}).Count -or $final[1].output.Trim() -or $final[2].output.Trim()){throw 'Final Docker read/cleanup proof unknown'}
$extra=@('infra/media-renderer-lab.Dockerfile','infra/renderer-seccomp-1.63.json',
    'tests/p37/build_renderer.ps1','tests/p37/run_renderer_capability.ps1','tests/p37/renderer_capability.js',
    'tests/p37/verify_renderer.ps1','docs/TIKTOK_RENDERER_HANDOFF.md')+$docs
$excluded=@("$ev/manifest.json","$ev/manifest-sha256.txt")
function ActualPaths{@(@(rg --files -uu $ev | ForEach-Object {$_.Replace('\','/')} | Where-Object {$_ -notin $excluded})+$extra | Sort-Object -Unique)}
if($Capture){
    if(Test-Path "$ev/manifest.json"){throw 'Refuse frozen successor overwrite'}
    @(foreach($f in $docs){@{file=$f;beforeSHA=@($before | Where-Object {$_.file -ceq $f})[0].sha256;acceptedAfterSHA=(SHA $f)}}) | ConvertTo-Json | Set-Content "$ev/accepted-doc-successor.json" -Encoding utf8
    @{utc=[DateTime]::UtcNow.ToString('o');vn=[DateTime]::UtcNow.AddHours(7).ToString('yyyy-MM-dd HH:mm:ss.fff');
        status='STOPPED_CAPABILITY_FAIL_PENDING_AUDIT';beforeFiles=$before.Count;exactPreserved=$kept;authorizedDocChanges=$changed;
        predecessorBefore=107;predecessorEntries=108;currentlyUnchangedNonDocs=104;
        imageBuilds=1;imageID=$image.actualImageID;playwright='1.63.0';baseKept=$true;
        capabilityNativeExit=30;capabilityRunnerExit=30;capability='FAIL';sourceNavigations=0;downloads=0;
        browserMetadata='NOT_RUN';sourceActualExit=$null;visualWatermark='NOT_RUN';byteBudgetVerified=$false;
        actualLimits=@{memoryMiB=928;CPU=1.0;PIDs=256;network='none'};usagePeakMeasured=$false;
        ownCreatedCleaned=1;ownResourcesLeft=0;actualSeccompMatched=$true;rootCause='UNKNOWN; raw stderr clipped';
        noProtectionDowngrade=$true;noProductionChange=$true;verificationScope='file/log/hash only; not runtime rerun'} | ConvertTo-Json -Depth 10 | Set-Content "$ev/completion.json" -Encoding utf8
    @(foreach($f in (ActualPaths)){@{path=$f;bytes=(Get-Item -LiteralPath $f).Length;sha256=(SHA $f)}}) | ConvertTo-Json -Depth 5 | Set-Content "$ev/manifest.json" -Encoding utf8
    SHA "$ev/manifest.json" | Set-Content "$ev/manifest-sha256.txt" -Encoding ascii
}
$accepted=@(Get-Content "$ev/accepted-doc-successor.json" -Raw | ConvertFrom-Json)
if($accepted.Count -ne 4 -or (Compare-Object $docs @($accepted.file))){throw 'Exact doc successor set mismatch'}
foreach($r in $accepted){if((SHA $r.file) -cne $r.acceptedAfterSHA -or @($before | Where-Object {$_.file -ceq $r.file})[0].sha256 -cne $r.beforeSHA){throw "Exact doc successor mismatch $($r.file)"}}
$m=@(Get-Content "$ev/manifest.json" -Raw | ConvertFrom-Json)
if(@($m.path | Sort-Object -Unique).Count -ne $m.Count -or (Compare-Object (ActualPaths) @($m.path | Sort-Object -Unique))){throw 'Distinct/full actual coverage failed'}
foreach($r in $m){if((SHA $r.path) -cne $r.sha256 -or (Get-Item -LiteralPath $r.path).Length -ne $r.bytes){throw "Artifact SHA/bytes mismatch $($r.path)"}}
if((SHA "$ev/manifest.json") -cne (Get-Content "$ev/manifest-sha256.txt" -Raw).Trim()){throw 'Manifest selfmetadata mismatch'}
Write-Output "PASS exactPreserved=$kept; authorizedDocs4; predecessor107/107 before-change/frozen; artifacts=$($m.Count)/$($m.Count) SHA/bytes/distinct/fullcoverage; build1; capabilityFAILexit30; navigation0/download0/NOT_RUN; cleanup0left"
