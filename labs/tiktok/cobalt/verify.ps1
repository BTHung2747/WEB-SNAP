param([switch]$Capture)
$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
$ev='docs/evidence/tiktok-cobalt-20261008';$lab='labs/tiktok/cobalt'
$allowed=@('docs/PROGRESS.md','docs/AUDIT_TIEN_DO.md','docs/ADAPTERS.md','docs/TEST_REPORT.md','docs/STRUCTURE.md')
function SHA([string]$p){(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLower()}
$before=@(Get-Content "$ev/before-all-sha.json" -Raw|ConvertFrom-Json);$kept=0;$changed=@()
foreach($r in $before){
    if(-not(Test-Path -LiteralPath $r.file)){throw "Old path missing $($r.file)"}
    if($r.file -in $allowed){if((SHA $r.file) -cne $r.sha256){$changed+=$r.file}}
    elseif((SHA $r.file) -cne $r.sha256 -or (Get-Item -LiteralPath $r.file).Length -ne $r.bytes){throw "Unscoped old change $($r.file)"}
    else{$kept++}
}
$provenance=Get-Content "$ev/provenance-final.json" -Raw|ConvertFrom-Json
if($provenance.commit -cne 'a636575b09de1fc55d9b8cd98cac88f5f2f16b42'){throw 'Commit changed'}
foreach($r in $provenance.originalFiles){if((SHA $r.path) -cne $r.sha256){throw 'Upstream original changed'}}
if((SHA "$lab/LICENSE") -cne (SHA "$lab/upstream/LICENSE")){throw 'License copy changed'}
$pin=Get-Content "$ev/image-pin.json" -Raw|ConvertFrom-Json
if($pin.imageID -cne 'sha256:5fcc01bb22ca5a264327f4bce4140b07c70d22b0a861ef41ff982d7d0fb3f3a6' -or $pin.basePrefixLayers -ne 11 -or (SHA "$lab/package-lock.json") -cne $pin.lockSHA){throw 'Image/lock pin changed'}
$archive=Get-Content "$ev/archive-verify.json" -Raw|ConvertFrom-Json;if($archive.actualExit -ne 0){throw 'Archive lossless verify failed'}
$phase=@{}
foreach($dir in @('offline-1','offline-2','offline-3','sample-1')){
    $logs=@(Get-Content "$ev/$dir/native.jsonl"|ForEach-Object {$_|ConvertFrom-Json})
    $end=@($logs|Where-Object {$_.step -eq 'end'})[-1]
    if($end.ownResourcesLeft -ne 0){throw 'Own cleanup failed'}
    $expected=if($dir -eq 'offline-1'){1}elseif($dir -eq 'sample-1'){137}else{0}
    if($end.actualExit -ne $expected){throw 'Actual outcomes changed'}
    $phase[$dir]=@{actualExit=$end.actualExit;cleanupLeft=$end.ownResourcesLeft;containers=$end.removedContainers;networks=$end.removedNetworks}
}
$source=@(Get-Content "$ev/sample-1/native.jsonl"|ForEach-Object {$_|ConvertFrom-Json}|Where-Object {$_.step -eq 'single-analyze-conditional-download'})
if($source.Count -ne 1 -or $source[0].actualExit -ne 137){throw 'Expected exactly one failed live source attempt'}
if(Test-Path "$ev/sample-1/result.json"){throw 'Do not manufacture retrospective metadata result'}
if((Test-Path "$ev/sample-2") -or (Test-Path "$ev/sample-3")){throw 'No more samples authorized after failure'}
$interp=Get-Content "$ev/live-interpretation.json" -Raw|ConvertFrom-Json
if($interp.deadline30EnforcedInFirstLive -or $interp.downloads -ne 0 -or $interp.actualSourceAttempts -ne 1){throw 'Live deadline violation/limits mislabelled'}
$final=@(Get-Content "$ev/final-docker-read.json" -Raw|ConvertFrom-Json)
if(@($final|Where-Object {$_.actualExit -ne 0}).Count -or $final[1].output.Trim() -or $final[2].output.Trim()){throw 'Final pins/cleanup unknown'}
$exclude=@("$ev/manifest.json","$ev/manifest-sha256.txt")
function ActualPaths{@(@(rg --files -uu $ev $lab|ForEach-Object {$_.Replace('\','/')}|Where-Object {$_ -notin $exclude})+$allowed+@('docs/TIKTOK_COBALT_HANDOFF.md')|Sort-Object -Unique)}
if($Capture){
    if(Test-Path "$ev/manifest.json"){throw 'Refuse manifest overwrite'}
    @(foreach($f in $allowed){@{file=$f;beforeSHA=@($before|Where-Object {$_.file -ceq $f})[0].sha256;acceptedAfterSHA=(SHA $f)}})|ConvertTo-Json|Set-Content "$ev/accepted-doc-successor.json" -Encoding utf8
    @{utc=[DateTime]::UtcNow.ToString('o');vn=[DateTime]::UtcNow.AddHours(7).ToString('yyyy-MM-dd HH:mm:ss.fff');
      status='LAB_IMPLEMENTED_LIVE_INTEGRATION_TIMEOUT_NOT_ACCEPTED';beforeFiles=$before.Count;exactPreserved=$kept;authorizedDocChanges=$changed;
      cobaltCommit=$provenance.commit;upstreamFiles=@($provenance.originalFiles).Count;originalLicenseKept=$true;AGPLmodificationNotice=$true;
      imageID=$pin.imageID;nativeBuilds=1;phase=$phase;sourceAnalyzes=1;liveNativeExit=137;liveDeadline30Enforced=$false;
      metadata='UNKNOWN_NOT_COMPLETED';HTTPstatus='UNKNOWN_NOT_RETAINED';decodedSourceBytes='UNKNOWN_NOT_RETAINED';
      downloads=0;file='NOT_RUN';watermark='NOT_RUN';sample2='NOT_RUN';sample3='NOT_RUN';
      finalOfflinePASS=7;correctedCodeRetestedOnSource=$false;browserUsed=$false;securityProfileChanged=$false;mainApply=$false;
      oldEvidenceManifestsUntouched=$true;compressedArchiveVerifiedReadOnly=$true;actualCleanupLeft=0;
      verificationScope='file/log/hash only; seven offline cases are not live metadata/file acceptance'}|ConvertTo-Json -Depth 10|Set-Content "$ev/completion.json" -Encoding utf8
    @(foreach($f in (ActualPaths)){@{path=$f;bytes=(Get-Item -LiteralPath $f).Length;sha256=(SHA $f)}})|ConvertTo-Json -Depth 5|Set-Content "$ev/manifest.json" -Encoding utf8
    SHA "$ev/manifest.json"|Set-Content "$ev/manifest-sha256.txt" -Encoding ascii
}
$accepted=@(Get-Content "$ev/accepted-doc-successor.json" -Raw|ConvertFrom-Json)
if($accepted.Count -ne 5 -or (Compare-Object $allowed @($accepted.file))){throw 'Exact doc scope mismatch'}
foreach($r in $accepted){if((SHA $r.file) -cne $r.acceptedAfterSHA -or @($before|Where-Object {$_.file -ceq $r.file})[0].sha256 -cne $r.beforeSHA){throw 'Exact successor doc SHA failed'}}
$m=@(Get-Content "$ev/manifest.json" -Raw|ConvertFrom-Json)
if(@($m.path|Sort-Object -Unique).Count -ne $m.Count -or (Compare-Object (ActualPaths) @($m.path|Sort-Object -Unique))){throw 'Full distinct artifact coverage failed'}
foreach($r in $m){if((SHA $r.path) -cne $r.sha256 -or (Get-Item -LiteralPath $r.path).Length -ne $r.bytes){throw "SHA/bytes failed $($r.path)"}}
if((SHA "$ev/manifest.json") -cne (Get-Content "$ev/manifest-sha256.txt" -Raw).Trim()){throw 'Selfmetadata failed'}
Write-Output "PASS preserved=$kept; exactDocs5; CobaltSHA/licence/pins; artifacts=$($m.Count)/$($m.Count) SHA/bytes/distinct/fullcoverage; source1 native137/deadlineVIOLATION; finalOffline7PASS; metadata/file/watermark NOT_ACCEPTED; cleanup0left"
