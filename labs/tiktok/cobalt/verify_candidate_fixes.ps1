param([switch]$Capture)
$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
$root='D:\WED SNAP';$ev='docs/evidence/tiktok-cobalt-candidate-fixes-20261008';$old='docs/evidence/tiktok-cobalt-origin-challenge-20261008'
. "$PSScriptRoot/hash_gate.ps1"
function SHA($p){(Get-FileHash -LiteralPath $p).Hash.ToLower()}
function Require($ok,$why){if(-not $ok){throw $why}}
$docs=@('docs/AUDIT_TIEN_DO.md','docs/PROGRESS.md')
$allowed=$docs+@('labs/tiktok/cobalt/run.ps1','labs/tiktok/cobalt/NOTICE.md','labs/tiktok/cobalt/src/yt_candidate.py','labs/tiktok/cobalt/src/yt_candidate_driver.py','labs/tiktok/cobalt/src/test_all.py')
$before=@(Get-Content "$ev/before-all.json" -Raw|ConvertFrom-Json);$kept=0;$changed=@()
foreach($r in $before){
 Require (Test-Path -LiteralPath $r.path) "Missing baseline $($r.path)"
 if((SHA $r.path) -cne $r.sha256){Require ($r.path -cin $allowed) "Unscoped change $($r.path)";$changed+=$r.path}
 else{Require ((Get-Item -LiteralPath $r.path).Length -eq $r.bytes) 'Baseline bytes';$kept++}
}
Require (-not(Compare-Object ($allowed|Sort-Object) ($changed|Sort-Object))) 'Exact five lab/two docs'
$accepted=Get-Content "$ev/prior-audit-successor-copy.json" -Raw|ConvertFrom-Json
Require ((SHA "$ev/prior-audit-successor-copy.json") -ceq (SHA 'docs/evidence/tiktok-cobalt-candidate-audit-20261008/successor.json') -and (SHA "$old/manifest.json") -ceq $accepted.predecessorManifestSHA) 'Unchanged predecessor golden/provenance'
$mOld=@(Get-Content "$old/manifest.json" -Raw|ConvertFrom-Json)
foreach($r in $mOld){
 $b=@($before|Where-Object {$_.path -ceq $r.path})[0];$doc=@($accepted.changedDocs|Where-Object {$_.path -ceq $r.path})
 if($doc.Count){Require ($r.sha256 -ceq $doc[0].beforeSHA -and $b.sha256 -ceq $doc[0].afterSHA) 'Exact audit doc successor'}
 else{Require ($r.sha256 -ceq $b.sha256 -and $r.bytes -eq $b.bytes) 'Predecessor baseline mismatch'}
 if($r.path -cnotin $allowed){Require ((SHA $r.path) -ceq $r.sha256) 'Frozen predecessor changed'}
}
$receipt=Get-Content "$ev/offline-1/receipt.json" -Raw|ConvertFrom-Json
Assert-CobaltHashGate $receipt (CobaltHostHashes) 'sha256:5fcc01bb22ca5a264327f4bce4140b07c70d22b0a861ef41ff982d7d0fb3f3a6'
Require ((SHA "$ev/offline-1/native.jsonl") -ceq $receipt.nativeSHA -and (SHA "$ev/offline-1/runtime-inventory.json") -ceq $receipt.runtimeSHA) 'Actual tested source/deps receipt'
$runtime=Get-Content "$ev/offline-1/runtime-inventory.json" -Raw|ConvertFrom-Json
$prior=Get-Content "$old/offline-4/runtime-inventory.json" -Raw|ConvertFrom-Json
Require ((ConvertTo-Json -InputObject $runtime.dependencies -Depth 5 -Compress) -ceq (ConvertTo-Json -InputObject $prior.dependencies -Depth 5 -Compress)) 'Existing dependencies unchanged'
$rows=@(Get-Content "$ev/offline-1/native.jsonl"|ForEach-Object {$_|ConvertFrom-Json});$end=@($rows|Where-Object {$_.step -eq 'end'})[0]
Require ($end.actualExit -eq 0 -and $end.ownResourcesLeft -eq 0 -and $end.removedContainers -eq 1 -and $end.removedNetworks -eq 0) 'Actual native exit/own cleanup'
Require (@($rows|Where-Object {$_.step -in @('single-analyze-conditional-download','create-lab')}).Count -eq 0) 'No live/egress'
$fixture=Get-Content "$ev/offline-1/finding-fixtures.json" -Raw|ConvertFrom-Json
Require ($fixture.sourceRequests -eq 0 -and $fixture.sourceDownloads -eq 0 -and $fixture.results.Count -eq 11) 'Targeted offline fixtures'
foreach($mode in @('metadata','prepare')){
 foreach($behavior in @('exit0','exit20','hang')){
  $case=@($fixture.results|Where-Object {$_.finding -ceq 'F-CANDIDATE-EXIT' -and $_.mode -ceq $mode -and $_.behavior -ceq $behavior})[0]
  Require ($case.packetStatus -ceq 'PASS' -and $case.preexistingPreserved) 'PASS packet/ownership fixture'
  if($behavior -eq 'exit0'){Require ($case.parentActualExit -eq 0 -and $case.workerActualExit -eq 0) 'Success only native exit0'}
  else{
   $workerExit=if($behavior -eq 'exit20'){20}else{-9}
   Require ($case.parentActualExit -ne 0 -and $case.workerActualExit -eq $workerExit -and $case.status -ceq 'FAIL' -and $case.newOutputsCleaned) 'Worker fail/kill cannot be success'
  }
 }
}
foreach($name in @('correct.mp4','near-duration.mp4','matroska-named.mp4','quicktime-named.mp4','truncated.mp4')){
 $case=@($fixture.results|Where-Object {$_.fixture -ceq $name})[0]
 Require ($null -ne $case -and (SHA "$ev/offline-1/media-fixtures/$name") -ceq $case.sha256 -and (Get-Item "$ev/offline-1/media-fixtures/$name").Length -eq $case.bytes) 'Real fixture file SHA/size'
 if($name -in @('correct.mp4','near-duration.mp4')){
  Require ($case.accepted -and $case.inspection.container -ceq 'MP4_ISO_BMFF' -and $case.inspection.decode -ceq 'PASS' -and [math]::Abs($case.inspection.containerDuration-$case.expectedDuration) -le $case.tolerance) 'Accepted MP4/decode/duration'
 }else{
  $why=if($name -eq 'truncated.mp4'){'FILE_METADATA_DURATION_MISMATCH'}else{'MP4_CONTAINER_REQUIRED'}
  Require (-not $case.accepted -and $case.error -ceq $why) 'Rejected wrong container/duration'
 }
}
$native=@(Get-Content "$ev/offline-1/media-native.json" -Raw|ConvertFrom-Json)
Require (@($native|Where-Object {$_.actualExit -ne 0}).Count -eq 0 -and $native[0].stdout -match '5.1.9' -and $native[1].stdout -match '5.1.9') 'Pinned FFprobe/FFmpeg actual commands'
Require (-not(Test-Path "$ev/sample-1") -and -not(Test-Path "$ev/sample-2") -and -not(Test-Path "$ev/sample-3")) 'No source artifacts'
$exclude=@("$ev/manifest.json","$ev/manifest-sha256.txt")
function Paths{@(@(rg --files -uu $ev labs/tiktok/cobalt|ForEach-Object {$_.Replace('\','/')}|Where-Object {$_ -cnotin $exclude})+$docs+@('docs/TIKTOK_COBALT_CANDIDATE_FIXES_HANDOFF.md')|Sort-Object -Unique)}
if($Capture){
 Require (-not(Test-Path "$ev/manifest.json")) 'No manifest overwrite'
 @(foreach($f in $allowed){@{path=$f;beforeSHA=@($before|Where-Object {$_.path -ceq $f})[0].sha256;afterSHA=(SHA $f)}})|ConvertTo-Json -Depth 4|Set-Content "$ev/successor.json" -Encoding utf8
 @{utc=[DateTime]::UtcNow.ToString('o');vn=[DateTime]::UtcNow.AddHours(7).ToString('yyyy-MM-dd HH:mm:ss.fff');baseline=$before.Count;preserved=$kept;exactChanges=$changed;
   findings=@('F-CANDIDATE-EXIT_CLOSED_OFFLINE','F-CANDIDATE-FILE_CLOSED_OFFLINE');fakeWorkerCases=6;syntheticMediaCases=5;sourceAttempts=0;sourceDownloads=0;actualTikTokFile='NOT_RUN';actualTikTokWatermark='NOT_RUN';
   nativeOfflineExit=0;cleanupLeft=0;mainApply=$false;builds=0;scope='Lifecycle and real synthetic-file contract; no source or feature acceptance'}|ConvertTo-Json -Depth 5|Set-Content "$ev/completion.json" -Encoding utf8
 @(foreach($f in (Paths)){@{path=$f;bytes=(Get-Item -LiteralPath $f).Length;sha256=(SHA $f)}})|ConvertTo-Json -Depth 5|Set-Content "$ev/manifest.json" -Encoding utf8
 SHA "$ev/manifest.json"|Set-Content "$ev/manifest-sha256.txt" -Encoding ascii
}
$successor=@(Get-Content "$ev/successor.json" -Raw|ConvertFrom-Json)
Require (-not(Compare-Object ($allowed|Sort-Object) (@($successor.path)|Sort-Object))) 'Successor exact scope'
foreach($r in $successor){Require ((SHA $r.path) -ceq $r.afterSHA -and @($before|Where-Object {$_.path -ceq $r.path})[0].sha256 -ceq $r.beforeSHA) 'Exact successor SHA'}
$m=@(Get-Content "$ev/manifest.json" -Raw|ConvertFrom-Json)
Require ((SHA "$ev/manifest.json") -ceq (Get-Content "$ev/manifest-sha256.txt" -Raw).Trim()) 'Manifest self SHA'
Require (@($m.path|Sort-Object -Unique).Count -eq $m.Count -and -not(Compare-Object (Paths) @($m.path|Sort-Object))) 'Full distinct coverage'
foreach($r in $m){Require ((SHA $r.path) -ceq $r.sha256 -and (Get-Item -LiteralPath $r.path).Length -eq $r.bytes) 'Artifact SHA/size'}
Write-Output "PASS baseline=$($before.Count); preserved=$kept; scoped changes=$($changed.Count); artifacts=$($m.Count)/$($m.Count); EXIT6/FILE5 offline PASS; actual exit0; source0; synthetic files only; cleanup0; old golden/raw untouched"
