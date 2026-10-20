param([switch]$Capture)
$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
$root='D:\WED SNAP';$ev='docs/evidence/tiktok-cobalt-candidate-live-20261008';$old='docs/evidence/tiktok-cobalt-candidate-fixes-20261008'
. "$PSScriptRoot/hash_gate.ps1"
function SHA($p){(Get-FileHash -LiteralPath $p).Hash.ToLower()}
function Require($ok,$why){if(-not $ok){throw $why}}
$docs=@('docs/AUDIT_TIEN_DO.md','docs/PROGRESS.md')
$allowed=$docs+@('labs/tiktok/cobalt/run.ps1','labs/tiktok/cobalt/compose.yaml','labs/tiktok/cobalt/NOTICE.md','labs/tiktok/cobalt/src/yt_candidate.py','labs/tiktok/cobalt/src/yt_candidate_driver.py','labs/tiktok/cobalt/src/test_all.py')
$before=@(Get-Content "$ev/before-all.json" -Raw|ConvertFrom-Json);$kept=0;$changed=@()
foreach($r in $before){
 Require (Test-Path -LiteralPath $r.path) "Missing baseline $($r.path)"
 if((SHA $r.path) -cne $r.sha256){Require ($r.path -cin $allowed) "Unscoped change $($r.path)";$changed+=$r.path}
 else{Require ((Get-Item -LiteralPath $r.path).Length -eq $r.bytes) 'Baseline bytes';$kept++}
}
Require (-not(Compare-Object ($allowed|Sort-Object) ($changed|Sort-Object))) 'Exact six lab/two docs'
$accepted=Get-Content "$ev/prior-audit-successor-copy.json" -Raw|ConvertFrom-Json
Require ((SHA "$ev/prior-audit-successor-copy.json") -ceq (SHA 'docs/evidence/tiktok-cobalt-candidate-fixes-audit-20261008/successor.json') -and (SHA "$old/manifest.json") -ceq $accepted.predecessorManifestSHA) 'Frozen predecessor/golden'
$mOld=@(Get-Content "$old/manifest.json" -Raw|ConvertFrom-Json)
foreach($r in $mOld){
 $b=@($before|Where-Object {$_.path -ceq $r.path})[0];$doc=@($accepted.changedDocs|Where-Object {$_.path -ceq $r.path})
 if($doc.Count){Require ($r.sha256 -ceq $doc[0].beforeSHA -and $b.sha256 -ceq $doc[0].afterSHA) 'Independent doc successor'}
 else{Require ($r.sha256 -ceq $b.sha256 -and $r.bytes -eq $b.bytes) 'Old baseline mismatch'}
 if($r.path -cnotin $allowed){Require ((SHA $r.path) -ceq $r.sha256) 'Frozen artifact changed'}
}
$receipt=Get-Content "$ev/offline-3/receipt.json" -Raw|ConvertFrom-Json
Assert-CobaltHashGate $receipt (CobaltHostHashes) 'sha256:5fcc01bb22ca5a264327f4bce4140b07c70d22b0a861ef41ff982d7d0fb3f3a6'
Require ((SHA "$ev/offline-3/native.jsonl") -ceq $receipt.nativeSHA -and (SHA "$ev/offline-3/runtime-inventory.json") -ceq $receipt.runtimeSHA) 'Final offline receipt'
Require ((SHA "$ev/sample-1/runtime-inventory.json") -ceq $receipt.runtimeSHA -and (SHA "$ev/sample-1/offline-runtime.json") -ceq $receipt.runtimeSHA) 'Exact actual live runtime'
$rt=Get-Content "$ev/sample-1/runtime-inventory.json" -Raw|ConvertFrom-Json
$prior=Get-Content "$old/offline-1/runtime-inventory.json" -Raw|ConvertFrom-Json
Require ((ConvertTo-Json -InputObject $rt.dependencies -Depth 5 -Compress) -ceq (ConvertTo-Json -InputObject $prior.dependencies -Depth 5 -Compress)) 'Dependencies unchanged'
foreach($phase in @(@{dir='offline-1';exit=1;c=1;n=0},@{dir='offline-2';exit=1;c=1;n=0},@{dir='offline-3';exit=0;c=1;n=0},@{dir='sample-1';exit=0;c=2;n=2})){
 $rows=@(Get-Content "$ev/$($phase.dir)/native.jsonl"|ForEach-Object {$_|ConvertFrom-Json});$end=@($rows|Where-Object {$_.step -eq 'end'})[0]
 Require ($end.actualExit -eq $phase.exit -and $end.ownResourcesLeft -eq 0 -and $end.removedContainers -eq $phase.c -and $end.removedNetworks -eq $phase.n) 'Actual FAIL/PASS exits/ownership cleanup'
}
$integration=Get-Content "$ev/offline-3/integration-result.json" -Raw|ConvertFrom-Json
Require ($integration.workerActualExit -eq 0 -and $integration.parentActualExit -eq 0 -and $integration.metadataAccepted -and $integration.status -ceq 'FILE_NEEDS_VISUAL_REVIEW' -and $integration.sourceAttempts -eq 0) 'Full fake pipeline/exit0'
$synthetic=$integration.preparePacket.result
Require ($integration.metadataPacket.summary.requestCount -eq 2 -and $synthetic.requestCount -eq 1 -and $synthetic.container -ceq 'MP4_ISO_BMFF' -and $synthetic.decode -ceq 'PASS') 'Actual extractor/downloader/file contract'
Require ((SHA "$ev/offline-3/video.mp4") -ceq $synthetic.sha256 -and (SHA "$ev/offline-3/fixture-input.mp4") -ceq $synthetic.sha256) 'Synthetic MP4 unchanged by downloader'
$rows=@(Get-Content "$ev/sample-1/native.jsonl"|ForEach-Object {$_|ConvertFrom-Json});$calls=@($rows|Where-Object {$_.step -eq 'single-analyze-conditional-download'})
Require ($calls.Count -eq 1 -and $calls[0].actualExit -eq 0 -and -not $calls[0].timeout) 'One source analyze'
$r=Get-Content "$ev/sample-1/candidate-result.json" -Raw|ConvertFrom-Json
$meta=$r.metadataPacket.summary;$file=$r.preparePacket.result
Require ($r.parentActualExit -eq 0 -and $r.workerActualExit -eq 0 -and $r.metadataAccepted -and $r.runtimeHashGate -ceq 'PASS' -and $r.status -ceq 'FILE_NEEDS_VISUAL_REVIEW') 'Packets plus actual exit0'
Require ($meta.metadata -ceq 'PASS' -and $meta.id -ceq '7692808825228807442' -and $meta.bodyIdAndTypeVerifiedByCobalt -and $meta.requestCount -eq 2 -and $r.metadataSeconds -lt 30) 'Real bounded metadata'
Require ($file.requestCount -eq 1 -and $r.prepareSeconds -lt 180 -and $file.inputBytes -le 250MB -and $file.bytes -le 200MB -and $file.container -ceq 'MP4_ISO_BMFF' -and $file.decode -ceq 'PASS') 'Real bounded file'
Require (@($meta.requests|Where-Object {$_.status -ne 200 -or $_.decodedBytes -gt 8MB}).Count -eq 0 -and $meta.decodedBytes -le 16MB -and @($file.requests|Where-Object {$_.phase -eq 'prepare' -and $_.status -eq 200}).Count -eq 1) 'HTTP budget/bytes'
Require ((SHA "$ev/sample-1/video.mp4") -ceq $file.sha256 -and (Get-Item "$ev/sample-1/video.mp4").Length -eq $file.bytes) 'Real file SHA/bytes'
$visual=Get-Content "$ev/visual-assessment.json" -Raw|ConvertFrom-Json
Require ($visual.status -ceq 'NEEDS_VISUAL_REVIEW' -and -not $visual.accepted -and -not $visual.perceptualAudioReviewed -and -not $visual.fullVideoReviewed -and $r.visualAudioWatermark -ceq 'NEEDS_VISUAL_REVIEW') 'No false visual/audio/watermark acceptance'
$review=Get-Content "$ev/review-2/review-native.json" -Raw|ConvertFrom-Json
Require ($review.originalUnchanged -and $review.originalSHA -ceq $file.sha256 -and @($review.native|Where-Object {$_.actualExit -ne 0}).Count -eq 0) 'Review original unchanged/actual commands'
$reviewEnd=Get-Content "$ev/review-2/completion.json" -Raw|ConvertFrom-Json
Require ($reviewEnd.actualExit -eq 0 -and $reviewEnd.ownResourcesLeft -eq 0 -and $reviewEnd.sourceRequests -eq 0) 'Review cleanup/no source'
Require (-not(Test-Path "$ev/sample-2") -and -not(Test-Path "$ev/sample-3")) 'No extra samples'
$exclude=@("$ev/manifest.json","$ev/manifest-sha256.txt")
function Paths{@(@(rg --files -uu $ev labs/tiktok/cobalt|ForEach-Object {$_.Replace('\','/')}|Where-Object {$_ -cnotin $exclude})+$docs+@('docs/TIKTOK_COBALT_CANDIDATE_LIVE_HANDOFF.md')|Sort-Object -Unique)}
if($Capture){
 Require (-not(Test-Path "$ev/manifest.json")) 'No manifest overwrite'
 @(foreach($f in $allowed){@{path=$f;beforeSHA=@($before|Where-Object {$_.path -ceq $f})[0].sha256;afterSHA=(SHA $f)}})|ConvertTo-Json -Depth 4|Set-Content "$ev/successor.json" -Encoding utf8
 @{utc=[DateTime]::UtcNow.ToString('o');vn=[DateTime]::UtcNow.AddHours(7).ToString('yyyy-MM-dd HH:mm:ss.fff');baseline=$before.Count;preserved=$kept;exactChanges=$changed;
  sourceAnalyzes=1;metadataGET=2;prepareGET=1;parentExit=0;workerExit=0;metadata='PASS';fileContract='PASS';visualAudioWatermark='NEEDS_VISUAL_REVIEW';sourceFileSHA=$file.sha256;
  offlineExits=@(1,1,0);sourceExit=0;cleanupLeft=0;builds=0;mainApply=$false;scope='Integrated offline pipeline plus one actual source MP4, no three-sample/visual/E2E acceptance'}|ConvertTo-Json -Depth 5|Set-Content "$ev/completion.json" -Encoding utf8
 @(foreach($f in (Paths)){@{path=$f;bytes=(Get-Item -LiteralPath $f).Length;sha256=(SHA $f)}})|ConvertTo-Json -Depth 5|Set-Content "$ev/manifest.json" -Encoding utf8
 SHA "$ev/manifest.json"|Set-Content "$ev/manifest-sha256.txt" -Encoding ascii
}
$successor=@(Get-Content "$ev/successor.json" -Raw|ConvertFrom-Json)
Require (-not(Compare-Object ($allowed|Sort-Object) (@($successor.path)|Sort-Object))) 'Exact successor scope'
foreach($r in $successor){Require ((SHA $r.path) -ceq $r.afterSHA -and @($before|Where-Object {$_.path -ceq $r.path})[0].sha256 -ceq $r.beforeSHA) 'Exact successor SHA'}
$m=@(Get-Content "$ev/manifest.json" -Raw|ConvertFrom-Json)
Require ((SHA "$ev/manifest.json") -ceq (Get-Content "$ev/manifest-sha256.txt" -Raw).Trim()) 'Manifest self SHA'
Require (@($m.path|Sort-Object -Unique).Count -eq $m.Count -and -not(Compare-Object (Paths) @($m.path|Sort-Object))) 'Full distinct coverage'
foreach($r in $m){Require ((SHA $r.path) -ceq $r.sha256 -and (Get-Item -LiteralPath $r.path).Length -eq $r.bytes) 'Artifact SHA/size'}
Write-Output "PASS baseline=$($before.Count); preserved=$kept; scoped changes=$($changed.Count); artifacts=$($m.Count)/$($m.Count); offline FAIL1/1->PASS0 integrated pipeline; one source2+1GET; actual parent/worker0; real MP4/decode/SHA PASS; NEEDS_VISUAL_REVIEW; cleanup0; old golden/raw untouched"
