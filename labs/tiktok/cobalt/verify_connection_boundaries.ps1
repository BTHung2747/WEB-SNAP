param([switch]$Capture)
$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
$root='D:\WED SNAP';$ev='docs/evidence/tiktok-cobalt-connection-boundaries-20261009'
. "$PSScriptRoot/hash_gate.ps1"
function SHA($p){(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLower()}
function Require($ok,$why){if(-not $ok){throw $why}}
$docs=@('docs/AUDIT_TIEN_DO.md','docs/PROGRESS.md')
$allowed=$docs+@('labs/tiktok/cobalt/run.ps1','labs/tiktok/cobalt/NOTICE.md','labs/tiktok/cobalt/src/yt_candidate.py','labs/tiktok/cobalt/src/send_diagnostics.py','labs/tiktok/cobalt/src/test_all.py')
$before=@(Get-Content "$ev/before-all.json" -Raw|ConvertFrom-Json);$baseline=@{};$kept=0;$changed=@()
foreach($r in $before){
 $baseline[$r.path]=$r;Require (Test-Path -LiteralPath $r.path) "Missing baseline $($r.path)"
 if((SHA $r.path) -cne $r.sha256){Require ($r.path -cin $allowed) "Unscoped change $($r.path)";$changed+=$r.path}
 else{Require ((Get-Item -LiteralPath $r.path).Length -eq $r.bytes) 'Baseline bytes';$kept++}
}
Require (-not(Compare-Object ($allowed|Sort-Object) ($changed|Sort-Object))) 'Exact five lab/two docs changes'
$audit=Get-Content "$ev/prior-audit-successor-copy.json" -Raw|ConvertFrom-Json
Require ((SHA "$ev/prior-audit-successor-copy.json") -ceq (SHA 'docs/evidence/tiktok-cobalt-decode-budget-audit-20261009/successor.json') -and (SHA $audit.predecessorManifest) -ceq $audit.predecessorManifestSHA) 'Frozen predecessor audit/golden'
foreach($r in @(Get-Content $audit.predecessorManifest -Raw|ConvertFrom-Json)){
 $b=$baseline[$r.path];Require ($null -ne $b) 'Predecessor baseline coverage'
 $doc=@($audit.changedDocs|Where-Object {$_.path -ceq $r.path})
 if($doc.Count){Require ($r.sha256 -ceq $doc[0].beforeSHA -and $b.sha256 -ceq $doc[0].afterSHA) 'Doc-only audit lineage'}
 else{Require ($r.sha256 -ceq $b.sha256 -and $r.bytes -eq $b.bytes) 'Golden baseline SHA'}
 if($r.path -cnotin $allowed){Require ((SHA $r.path) -ceq $r.sha256) 'Frozen raw/golden/verifier modified'}
}
foreach($path in @($allowed|Where-Object {$_ -like 'labs/*'})){
 Require ((SHA "$ev/before/$($path.Substring('labs/tiktok/cobalt/'.Length).Replace('/','--'))") -ceq $baseline[$path].sha256) 'Exact before snapshots'
}
foreach($p in @(@{sample=1;folder='tiktok-cobalt-candidate-live-audit-20261008'},@{sample=2;folder='tiktok-cobalt-candidate-sample2-audit-20261008'})){
 $sPath="docs/evidence/$($p.folder)/successor.json";$s=Get-Content $sPath -Raw|ConvertFrom-Json
 Require ((SHA $sPath) -ceq (SHA "$ev/sample$($p.sample)-successor-copy.json") -and (SHA $s.humanReview) -ceq $s.humanReviewSHA -and (SHA "$ev/sample$($p.sample)-human-review-copy.json") -ceq $s.humanReviewSHA -and (SHA $s.predecessorManifest) -ceq $s.predecessorManifestSHA) 'Prior accepted records frozen'
 $h=Get-Content $s.humanReview -Raw|ConvertFrom-Json
 Require ($h.accepted -and $h.fullVideoReviewed -and $h.perceptualAudioReviewed -and $h.watermarkReviewed -and (SHA $h.originalFile) -ceq $h.originalSHA) 'Accepted originals preserved'
}
Require ((SHA "$ev/sample3-target-copy.json") -ceq $s.sample3HistoricalTargetSHA) 'Historical target unchanged'
$image='sha256:5fcc01bb22ca5a264327f4bce4140b07c70d22b0a861ef41ff982d7d0fb3f3a6'
$receipt=Get-Content "$ev/offline-1/receipt.json" -Raw|ConvertFrom-Json
Assert-CobaltHashGate $receipt (CobaltHostHashes) $image
Require ((SHA "$ev/offline-1/native.jsonl") -ceq $receipt.nativeSHA -and (SHA "$ev/offline-1/runtime-inventory.json") -ceq $receipt.runtimeSHA) 'Fresh exact offline receipt'
foreach($dir in @('benchmark-3','sample-3')){Require ((SHA "$ev/$dir/runtime-inventory.json") -ceq $receipt.runtimeSHA) 'Exact long/offline/live installed runtime'}
Require ((SHA "$ev/sample-3/offline-runtime.json") -ceq $receipt.runtimeSHA) 'Entry hash gate'
$oldRt=Get-Content 'docs/evidence/tiktok-cobalt-decode-budget-20261009/offline-1/runtime-inventory.json' -Raw|ConvertFrom-Json
foreach($phase in @(@{dir='offline-1';c=1;n=0},@{dir='benchmark-3';c=1;n=0},@{dir='sample-3';c=2;n=2})){
 $rt=Get-Content "$ev/$($phase.dir)/runtime-inventory.json" -Raw|ConvertFrom-Json
 Require ((ConvertTo-Json -InputObject $rt.dependencies -Depth 5 -Compress) -ceq (ConvertTo-Json -InputObject $oldRt.dependencies -Depth 5 -Compress)) 'Pinned installed dependencies unchanged'
 $rows=@(Get-Content "$ev/$($phase.dir)/native.jsonl"|ForEach-Object {$_|ConvertFrom-Json});$end=@($rows|Where-Object {$_.step -ceq 'end'})[0]
 Require ($end.actualExit -eq 0 -and $end.ownResourcesLeft -eq 0 -and $end.removedContainers -eq $phase.c -and $end.removedNetworks -eq $phase.n -and @($rows|Where-Object {$_.timeout -eq $true}).Count -eq 0) 'Actual exits0/ownership cleanup'
 $guards=@(Get-ChildItem "$ev/$($phase.dir)/guard-*.json"|ForEach-Object {Get-Content $_.FullName -Raw|ConvertFrom-Json})
 Require ($guards.Count -eq $phase.c) 'Actual task count'
 foreach($g in $guards){Require ($g.HostConfig.ReadonlyRootfs -and -not $g.HostConfig.Privileged -and -not $g.HostConfig.CapAdd -and $g.HostConfig.CapDrop -contains 'ALL' -and $g.HostConfig.SecurityOpt -contains 'no-new-privileges:true' -and $g.HostConfig.MemorySwap -eq $g.HostConfig.Memory -and $g.HostConfig.IpcMode -ceq 'private' -and -not $g.HostConfig.PidMode -and @($g.HostConfig.SecurityOpt|Where-Object {$_ -like 'seccomp=*'}).Count -eq 0 -and @($g.HostConfig.PortBindings.PSObject.Properties).Count -eq 0) 'Actual security guards'}
 $resolver=@($guards|Where-Object {$_.Config.User -ceq '1000:1000'})[0]
 Require ($resolver.Image -ceq $image -and $resolver.HostConfig.Memory -eq 512MB -and $resolver.HostConfig.NanoCpus -eq 750000000 -and $resolver.HostConfig.PidsLimit -eq 96) 'Exact512MiB/CPU0.75'
 if($phase.dir -cne 'sample-3'){Require ($resolver.HostConfig.NetworkMode -ceq 'none') 'Offline network-none'}
 else{
  $e=@($guards|Where-Object {$_.Config.User -ceq '65534:65534'})[0]
  Require (($guards.HostConfig.Memory|Measure-Object -Sum).Sum -eq 608MB -and $e.Image -ceq 'sha256:8bc0a567955111ea3cfbab2dd3b14f40a602f2d10ac987e78eb465f9d48d7f10' -and $e.HostConfig.Memory -eq 96MB -and $resolver.Config.Cmd[-1] -ceq '7692288554839313682' -and $resolver.Config.Env -contains 'MEDIA_PROXY=[url-redacted]') 'Pinned608MiB source wiring'
 }
}
$loop=Get-Content "$ev/offline-1/connection-boundary-fixtures.json" -Raw|ConvertFrom-Json
Require ($loop.status -ceq 'PASS' -and $loop.sourceRequests -eq 0 -and $loop.exceptionIdentityPreserved -and $loop.reuseAndCrossOrigin -and $loop.stockBehaviorEqual -and -not $loop.privateMonkeypatch -and $loop.serverActualExit -eq 0 -and $loop.results.Count -eq 5) 'Real loopback observer boundary/identity/behavior gates'
$reuse=$loop.results[0].rows
Require ($reuse[0].boundaries.connectionID -ceq $reuse[1].boundaries.connectionID -and $reuse[0].boundaries.connectionID -cne $reuse[2].boundaries.connectionID -and $reuse[1].boundaries.reused -and -not $reuse[2].boundaries.reused -and ($reuse[1].boundaries.terminal.boundary -join ',') -ceq 'REQUEST_SEND,RESPONSE_HEADERS') 'Reuse/cross-origin no stale setup'
foreach($f in @($loop.results|Select-Object -Skip 1)){
 $last=$f.row.boundaries.terminal[-1]
 Require ($f.stockBehaviorEqual -and $last.event -ceq 'ERROR' -and $last.boundary -ceq $f.boundary) 'Measured failure boundaries versus stock'
}
Require ((ConvertTo-Json -InputObject $loop -Depth 20 -Compress) -notmatch 'FAKEPATH|FAKEQUERY|FAKECOOKIE|FAKEPAYLOAD|https?://') 'No loopback payload/URI leaked'
$known=Get-Content "$ev/benchmark-3/known-valid-result.json" -Raw|ConvertFrom-Json
$long=Get-Content "$ev/benchmark-3/long-integration-result.json" -Raw|ConvertFrom-Json
$expected='f587381808e3f189ee0125e31a040d17d9f2c4100dde9738e169c93f7c3592bb'
Require ($known.status -ceq 'PASS' -and $known.sha256 -ceq $expected -and $known.inspection.decode -ceq 'PASS' -and (SHA "$ev/benchmark-3/fixture-input.mp4") -ceq $expected -and (SHA "$ev/benchmark-3/video.mp4") -ceq $expected -and $long.workerActualExit -eq 0 -and $long.parentActualExit -eq 0 -and $long.sourceAttempts -eq 0 -and $long.prepareSeconds -lt 180 -and $long.preparePacket.result.decode -ceq 'PASS') 'Exact486 full pipeline/contract/SHA0'
$budget=Get-Content "$ev/offline-1/decode-budget-fixtures.json" -Raw|ConvertFrom-Json
$read=Get-Content "$ev/offline-1/read20-fixtures.json" -Raw|ConvertFrom-Json
Require ($budget.status -ceq 'PASS' -and $budget.reserveSeconds -eq 10 -and $budget.exhaustedBeforeSpawn -and $budget.nativeErrorsAndReap -and $read.status -ceq 'PASS' -and $read.absoluteDeadlineAdapterEntered -and $read.connectCeiling -eq 10 -and $read.readCeiling -eq 20) 'Read/decode/deadline limits retained'
$rows=@(Get-Content "$ev/sample-3/native.jsonl"|ForEach-Object {$_|ConvertFrom-Json});$calls=@($rows|Where-Object {$_.step -ceq 'single-analyze-conditional-download'})
Require ($calls.Count -eq 1 -and $calls[0].actualExit -eq 0 -and -not $calls[0].timeout) 'Exactly one source analyze0'
$r=Get-Content "$ev/sample-3/candidate-result.json" -Raw|ConvertFrom-Json;$m=$r.metadataPacket.summary;$file=$r.preparePacket.result
Require ($r.status -ceq 'FILE_NEEDS_VISUAL_REVIEW' -and $r.metadataAccepted -and $r.workerActualExit -eq 0 -and $r.parentActualExit -eq 0 -and $null -eq $r.workerSignal -and $r.runtimeHashGate -ceq 'PASS') 'Worker0 plus packets required'
Require ($m.id -ceq '7692288554839313682' -and $m.bodyIdAndTypeVerifiedByCobalt -and $m.requestCount -eq 2 -and $m.decodedBytes -le 16MB -and $m.duration -le 600 -and $r.metadataSeconds -lt 30 -and @($m.requests|Where-Object {$_.status -ne 200 -or $_.decodedBytes -gt 8MB}).Count -eq 0) 'Fresh bounded real bodyID metadata'
Require ($file.file -ceq 'PASS' -and $file.container -ceq 'MP4_ISO_BMFF' -and $file.decode -ceq 'PASS' -and $file.requestCount -eq 1 -and $file.inputBytes -le 250MB -and $file.bytes -le 200MB -and $r.prepareSeconds -lt 180 -and $file.durationToleranceSeconds -le .75 -and [Math]::Abs($file.containerDuration-$m.duration) -le $file.durationToleranceSeconds -and @($file.ffprobe.streams|Where-Object {$_.codec_name -ceq 'h264'}).Count -eq 1 -and @($file.ffprobe.streams|Where-Object {$_.codec_type -ceq 'audio'}).Count -eq 1) 'Actual bounded MP4/duration/H264/audio/full decode'
Require ((SHA "$ev/sample-3/video.mp4") -ceq $file.sha256 -and (Get-Item "$ev/sample-3/video.mp4").Length -eq $file.bytes) 'Real original file SHA/bytes'
$reqs=@($file.requests)
Require ($reqs.Count -eq 3 -and @($reqs|Where-Object {$_.phase -ceq 'prepare'}).Count -eq 1 -and $reqs[0].boundaries.connectionID -ceq $reqs[1].boundaries.connectionID -and $reqs[1].boundaries.reused -and $reqs[2].boundaries.connectionID -cne $reqs[1].boundaries.connectionID -and -not $reqs[2].boundaries.reused) 'Measured actual source reuse/new-origin connection'
$events=@(Get-Content "$ev/sample-3/connection-boundaries.jsonl"|ForEach-Object {$_|ConvertFrom-Json})
$schema=@('requestID','connectionID','phase','boundary','event','elapsed','timeout','code','classes')
Require ($events.Count -eq 16 -and @($events.requestID|Sort-Object -Unique).Count -eq 3 -and @($events.connectionID|Sort-Object -Unique).Count -eq 2) 'Full16events/3request/2connection coverage'
foreach($e in $events){
 Require ($e.requestID -cmatch '^[0-9a-f]{16}$' -and $e.connectionID -cmatch '^[0-9a-f]{16}$' -and $e.phase -cin @('metadata','prepare') -and $e.boundary -cin @('CONNECTION_SETUP','REQUEST_SEND','RESPONSE_HEADERS') -and $e.event -cin @('BEGIN','END') -and $e.elapsed -ge 0 -and $e.timeout -gt 0 -and $e.timeout -le 20 -and $e.classes.Count -eq 0 -and -not(Compare-Object ($schema|Sort-Object) @($e.PSObject.Properties.Name|Sort-Object))) 'Opaque safe source schema/numeric observed timeouts'
}
foreach($q in $reqs){
 $t=$q.effectiveTimeout
 Require ($q.status -eq 200 -and $q.url -ceq '[url-redacted]' -and $q.TLSverify -and -not $q.actualImpersonation -and $q.method -ceq 'GET' -and $t.connectSeconds -le 10 -and $t.readCeilingSeconds -le 20 -and $t.totalSeconds -eq $t.phaseRemainingSeconds -and -not $q.boundaries.incomplete -and @($q.boundaries.terminal|Where-Object {$_.event -cne 'END' -or $_.code -cne 'OK'}).Count -eq 0) 'HTTP/TLS/timeout/source boundaries complete'
 $trace=@($events|Where-Object {$_.requestID -ceq $q.boundaries.requestID -and $_.event -ceq 'END'})
 Require (($trace.boundary -join ',') -ceq ($q.boundaries.terminal.boundary -join ',')) 'Raw boundary summary coverage'
}
Require (($file.operations.operation -join ',') -ceq 'DOWNLOADER,OUTPUT_CHECK,FFPROBE,CONTRACT,DECODE,HASH' -and @($file.operations|Where-Object {$_.code -cne 'OK'}).Count -eq 0) 'All real prepare operations completed'
$decode=@($file.operations|Where-Object {$_.operation -ceq 'DECODE'})[0]
Require ($decode.returncode -eq 0 -and $decode.elapsed -gt 30 -and $decode.timeout -le 170) 'Full native source decode remaining-minus10'
$visual=Get-Content "$ev/visual-assessment.json" -Raw|ConvertFrom-Json
Require ($visual.status -ceq 'NEEDS_VISUAL_REVIEW' -and -not $visual.accepted -and -not $visual.fullVideoReviewed -and -not $visual.perceptualAudioReviewed -and -not $visual.watermarkReviewed -and $visual.sha256 -ceq $file.sha256 -and $visual.acceptedSourceSamples -eq 2 -and $r.visualAudioWatermark -ceq 'NEEDS_VISUAL_REVIEW') 'No inferred3/3/watermark acceptance'
$outer=Get-Content "$ev/outer-exits.json" -Raw|ConvertFrom-Json
Require ($outer.offlineOuterExit -eq 0 -and $outer.benchmarkOuterExit -eq 0 -and $outer.sourceOuterExit -eq 0 -and $outer.sourceAnalyzes -eq 1 -and $outer.metadataGET -eq 2 -and $outer.prepareGET -eq 1) 'Actual outer outcomes/budget'
$exclude=@("$ev/manifest.json","$ev/manifest-sha256.txt")
function Paths{@(@(rg --files -uu $ev labs/tiktok/cobalt|ForEach-Object {$_.Replace('\','/')}|Where-Object {$_ -cnotin $exclude})+$docs+@('docs/TIKTOK_COBALT_CONNECTION_BOUNDARIES_HANDOFF.md')|Sort-Object -Unique)}
if($Capture){
 Require (-not(Test-Path "$ev/manifest.json")) 'No manifest overwrite'
 [ordered]@{utc=[DateTime]::UtcNow.ToString('o');kind='Delegating connection boundaries + one source MP4 technicalPASS/visualpending';predecessorManifest=$audit.predecessorManifest;predecessorManifestSHA=$audit.predecessorManifestSHA;changes=@(foreach($f in $allowed){@{path=$f;beforeSHA=$baseline[$f].sha256;afterSHA=(SHA $f)}})}|ConvertTo-Json -Depth 6|Set-Content "$ev/successor.json" -Encoding utf8
 [ordered]@{utc=[DateTime]::UtcNow.ToString('o');vn=[DateTime]::UtcNow.AddHours(7).ToString('yyyy-MM-dd HH:mm:ss.fff');baseline=$before.Count;preserved=$kept;exactChanges=$changed;offlineExit=0;benchmarkExit=0;sourceAnalyze=1;metadataGET=2;prepareGET=1;sourceOuterExit=0;workerExit=0;parentExit=0;metadata='PASS';file='PASS';sourceSHA=$file.sha256;visual='NEEDS_VISUAL_REVIEW';historicalFailureCause='UNKNOWN_NOT_PROVEN_FIXED';setupSubstages='GROUPED_NOT_SPLIT';acceptedSourceSamples=2;cleanupLeft=0;builds=0;mainApply=$false}|ConvertTo-Json -Depth 6|Set-Content "$ev/completion.json" -Encoding utf8
 @(foreach($f in (Paths)){@{path=$f;bytes=(Get-Item -LiteralPath $f).Length;sha256=(SHA $f)}})|ConvertTo-Json -Depth 5|Set-Content "$ev/manifest.json" -Encoding utf8
 SHA "$ev/manifest.json"|Set-Content "$ev/manifest-sha256.txt" -Encoding ascii
}
$successor=Get-Content "$ev/successor.json" -Raw|ConvertFrom-Json
Require (-not(Compare-Object ($allowed|Sort-Object) (@($successor.changes.path)|Sort-Object))) 'Successor exact scope'
foreach($r in $successor.changes){Require ((SHA $r.path) -ceq $r.afterSHA -and $baseline[$r.path].sha256 -ceq $r.beforeSHA) 'Successor exact SHA'}
$manifest=@(Get-Content "$ev/manifest.json" -Raw|ConvertFrom-Json)
Require ((SHA "$ev/manifest.json") -ceq (Get-Content "$ev/manifest-sha256.txt" -Raw).Trim() -and @($manifest.path|Sort-Object -Unique).Count -eq $manifest.Count -and -not(Compare-Object (Paths) @($manifest.path|Sort-Object))) 'Manifest self/full distinct coverage'
foreach($r in $manifest){Require ((SHA $r.path) -ceq $r.sha256 -and (Get-Item -LiteralPath $r.path).Length -eq $r.bytes) 'Artifact SHA/bytes'}
Write-Output "PASS evidence baseline=$($before.Count); preserved=$kept; scoped=$($changed.Count); artifacts=$($manifest.Count)/$($manifest.Count); raw/golden unchanged; loopback boundaries/stock/identity/reuse/origin PASS; exact offline/long0; source2+1GET/worker-parent0/real MP4-contract-decode-SHA PASS;16events complete; NEEDS_VISUAL_REVIEW/accepted2/3; historicalcauseUNKNOWN; cleanup0"
