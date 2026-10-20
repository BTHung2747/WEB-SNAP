param([switch]$Capture)
$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
$root='D:\WED SNAP';$ev='docs/evidence/tiktok-cobalt-prepare-operations-20261008'
. "$PSScriptRoot/hash_gate.ps1"
function SHA($p){(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLower()}
function Require($ok,$why){if(-not $ok){throw $why}}
$docs=@('docs/AUDIT_TIEN_DO.md','docs/PROGRESS.md')
$allowed=$docs+@('labs/tiktok/cobalt/run.ps1','labs/tiktok/cobalt/NOTICE.md','labs/tiktok/cobalt/src/candidate_file.py','labs/tiktok/cobalt/src/yt_candidate.py','labs/tiktok/cobalt/src/send_diagnostics.py','labs/tiktok/cobalt/src/test_all.py','labs/tiktok/cobalt/src/fixture_pipeline_worker.py')
$before=@(Get-Content "$ev/before-all.json" -Raw|ConvertFrom-Json);$baseline=@{};$kept=0;$changed=@()
foreach($r in $before){
 $baseline[$r.path]=$r;Require (Test-Path -LiteralPath $r.path) "Missing baseline $($r.path)"
 if((SHA $r.path) -cne $r.sha256){Require ($r.path -cin $allowed) "Unscoped change $($r.path)";$changed+=$r.path}
 else{Require ((Get-Item -LiteralPath $r.path).Length -eq $r.bytes) 'Baseline bytes';$kept++}
}
Require (-not(Compare-Object ($allowed|Sort-Object) ($changed|Sort-Object))) 'Exact seven lab/two docs changes'
$audit=Get-Content "$ev/prior-audit-successor-copy.json" -Raw|ConvertFrom-Json
Require ((SHA "$ev/prior-audit-successor-copy.json") -ceq (SHA 'docs/evidence/tiktok-cobalt-send-diagnostics-audit-20261008/successor.json') -and (SHA $audit.predecessorManifest) -ceq $audit.predecessorManifestSHA) 'Predecessor audit/manifest frozen'
foreach($r in @(Get-Content $audit.predecessorManifest -Raw|ConvertFrom-Json)){
 $b=$baseline[$r.path];Require ($null -ne $b) 'Predecessor baseline coverage'
 $doc=@($audit.changedDocs|Where-Object {$_.path -ceq $r.path})
 if($doc.Count){Require ($r.sha256 -ceq $doc[0].beforeSHA -and $b.sha256 -ceq $doc[0].afterSHA) 'Docs-only audit lineage'}
 else{Require ($r.sha256 -ceq $b.sha256 -and $r.bytes -eq $b.bytes) 'Predecessor baseline SHA'}
 if($r.path -cnotin $allowed){Require ((SHA $r.path) -ceq $r.sha256) 'Frozen raw/verifier/golden changed'}
}
foreach($p in @(@{sample=1;folder='tiktok-cobalt-candidate-live-audit-20261008'},@{sample=2;folder='tiktok-cobalt-candidate-sample2-audit-20261008'})){
 $sPath="docs/evidence/$($p.folder)/successor.json";$s=Get-Content $sPath -Raw|ConvertFrom-Json
 Require ((SHA $sPath) -ceq (SHA "$ev/sample$($p.sample)-successor-copy.json") -and (SHA $s.humanReview) -ceq $s.humanReviewSHA -and (SHA "$ev/sample$($p.sample)-human-review-copy.json") -ceq $s.humanReviewSHA -and (SHA $s.predecessorManifest) -ceq $s.predecessorManifestSHA) 'Prior reviews/goldens frozen'
 $h=Get-Content $s.humanReview -Raw|ConvertFrom-Json
 Require ($h.accepted -and $h.fullVideoReviewed -and $h.perceptualAudioReviewed -and $h.watermarkReviewed -and (SHA $h.originalFile) -ceq $h.originalSHA) 'Prior accepted originals unchanged'
}
Require ((SHA "$ev/sample3-target-copy.json") -ceq $s.sample3HistoricalTargetSHA) 'Historical target unchanged'
$image='sha256:5fcc01bb22ca5a264327f4bce4140b07c70d22b0a861ef41ff982d7d0fb3f3a6'
$receipt=Get-Content "$ev/offline-1/receipt.json" -Raw|ConvertFrom-Json
Assert-CobaltHashGate $receipt (CobaltHostHashes) $image
Require ((SHA "$ev/offline-1/native.jsonl") -ceq $receipt.nativeSHA -and (SHA "$ev/offline-1/runtime-inventory.json") -ceq $receipt.runtimeSHA) 'Final offline exact receipt'
foreach($dir in @('benchmark-3','sample-3')){Require ((SHA "$ev/$dir/runtime-inventory.json") -ceq $receipt.runtimeSHA) 'Final long/offline/live runtime identical'}
Require ((SHA "$ev/sample-3/offline-runtime.json") -ceq $receipt.runtimeSHA) 'Entry runtime hash gate'
$oldRt=Get-Content 'docs/evidence/tiktok-cobalt-sample3-send-diagnostics-20261008/sample-3/runtime-inventory.json' -Raw|ConvertFrom-Json
foreach($dir in @('benchmark-1','benchmark-2','benchmark-3','offline-1','sample-3')){
 $rt=Get-Content "$ev/$dir/runtime-inventory.json" -Raw|ConvertFrom-Json
 Require ((ConvertTo-Json -InputObject $rt.dependencies -Depth 5 -Compress) -ceq (ConvertTo-Json -InputObject $oldRt.dependencies -Depth 5 -Compress)) 'Installed dependency fingerprints unchanged'
 $rows=@(Get-Content "$ev/$dir/native.jsonl"|ForEach-Object {$_|ConvertFrom-Json});$end=@($rows|Where-Object {$_.step -ceq 'end'})[0]
 $live=$dir -ceq 'sample-3';$expectedExit=if($live){20}else{0}
 Require ($end.actualExit -eq $expectedExit -and $end.ownResourcesLeft -eq 0 -and $end.removedContainers -eq $(if($live){2}else{1}) -and $end.removedNetworks -eq $(if($live){2}else{0}) -and @($rows|Where-Object {$_.timeout -eq $true}).Count -eq 0) 'All actual exits/own cleanup'
 $guards=@(Get-ChildItem "$ev/$dir/guard-*.json"|ForEach-Object {Get-Content $_.FullName -Raw|ConvertFrom-Json})
 foreach($g in $guards){Require ($g.HostConfig.ReadonlyRootfs -and -not $g.HostConfig.Privileged -and -not $g.HostConfig.CapAdd -and $g.HostConfig.CapDrop -contains 'ALL' -and $g.HostConfig.SecurityOpt -contains 'no-new-privileges:true' -and $g.HostConfig.MemorySwap -eq $g.HostConfig.Memory -and $g.HostConfig.IpcMode -ceq 'private' -and -not $g.HostConfig.PidMode -and @($g.HostConfig.SecurityOpt|Where-Object {$_ -like 'seccomp=*'}).Count -eq 0 -and @($g.HostConfig.PortBindings.PSObject.Properties).Count -eq 0) 'Actual security guards'}
 $resolver=@($guards|Where-Object {$_.Config.User -ceq '1000:1000'})[0]
 Require ($resolver.Image -ceq $image -and $resolver.HostConfig.Memory -eq 512MB -and $resolver.HostConfig.NanoCpus -eq 750000000 -and $resolver.HostConfig.PidsLimit -eq 96) 'Exact512MiB/CPU0.75 for every offline/live resolver'
 if(-not $live){Require ($guards.Count -eq 1 -and $resolver.HostConfig.NetworkMode -ceq 'none') 'Offline network-none'}
 else{Require ($guards.Count -eq 2 -and ($guards.HostConfig.Memory|Measure-Object -Sum).Sum -eq 608MB -and $resolver.Config.Cmd[-1] -ceq '7692288554839313682' -and $resolver.Config.Env -contains 'MEDIA_PROXY=[url-redacted]') 'Live608MiB expectedID/proxy wiring'}
}
foreach($f in @('candidate_file.py','benchmark_prepare.py')){
 $rt=Get-Content "$ev/benchmark-1/runtime-inventory.json" -Raw|ConvertFrom-Json
 Require ((SHA "$ev/measure25-code/src--$f") -ceq @($rt.source|Where-Object {$_.path -ceq $f})[0].sha256) 'Frozen initial measurement code provenance'
}
$ops=@('DOWNLOADER','OUTPUT_CHECK','FFPROBE','CONTRACT','DECODE','HASH');$fields=@('operation','event','code','elapsed','timeout','returncode')
foreach($dir in @('benchmark-1','benchmark-2','benchmark-3','offline-1')){
 foreach($path in @(Get-ChildItem "$ev/$dir/*operations.jsonl")){
  foreach($event in @(Get-Content $path.FullName|ForEach-Object {$_|ConvertFrom-Json})){
   Require ($event.operation -cin $ops -and $event.event -cin @('BEGIN','END','ERROR') -and $event.elapsed -ge 0 -and -not(Compare-Object ($fields|Sort-Object) @($event.PSObject.Properties.Name|Sort-Object))) 'Fixed operations schema/no cmd/output/message'
  }
 }
}
foreach($dir in @('benchmark-1','benchmark-2','benchmark-3')){
 $b=Get-Content "$ev/$dir/benchmark-result.json" -Raw|ConvertFrom-Json
 Require ($b.sourceRequests -eq 0 -and @($b.results|Where-Object {$_.case -in @('short','long486') -and $_.status -ceq 'PASS'}).Count -eq 2) 'Short/486 media actual contract/decodePASS'
 $long=@($b.results|Where-Object {$_.case -ceq 'long486'})[0];$d=@($long.operations|Where-Object {$_.operation -ceq 'DECODE'})[0]
 Require ($d.returncode -eq 0 -and $d.code -ceq 'OK' -and $d.timeout -eq 30 -and $d.elapsed -lt 30 -and $long.inspection.expectedDuration -eq 486 -and $long.inspection.decode -ceq 'PASS' -and (SHA "$ev/$dir/fixture-input.mp4") -ceq $long.sha256) 'Legacy decode30 not rejected these valid486s fixtures'
 if($dir -cne 'benchmark-3'){
  $completion=@($b.results|Where-Object {$_.case -ceq 'long-full-completion'})[0]
  Require ($completion.actualExit -eq 0 -and $completion.operations[0].timeout -eq 120 -and $completion.operations[0].returncode -eq 0) 'Full same-CLI offline completion comparison only'
 }
}
$long=Get-Content "$ev/benchmark-3/long-integration-result.json" -Raw|ConvertFrom-Json
Require ($long.workerActualExit -eq 0 -and $long.parentActualExit -eq 0 -and $long.status -ceq 'FILE_NEEDS_VISUAL_REVIEW' -and $long.sourceAttempts -eq 0 -and $long.metadataPacket.summary.id -ceq '7692288554839313682' -and $long.metadataPacket.summary.duration -eq 486 -and $long.prepareSeconds -lt 180 -and $long.preparePacket.result.decode -ceq 'PASS' -and $long.preparePacket.result.container -ceq 'MP4_ISO_BMFF' -and (SHA "$ev/benchmark-3/video.mp4") -ceq (SHA "$ev/benchmark-3/fixture-input.mp4") -and $long.preparePacket.result.sha256 -ceq (SHA "$ev/benchmark-3/video.mp4")) 'Long exact real pipeline/contract/SHA/native0'
Require (($long.preparePacket.result.operations.operation -join ',') -ceq ($ops -join ',') -and @($long.preparePacket.result.operations|Where-Object {$_.code -cne 'OK'}).Count -eq 0) 'Six real prepare operations completed'
$test=Get-Content "$ev/offline-1/operation-fixtures.json" -Raw|ConvertFrom-Json
Require ($test.status -ceq 'PASS' -and $test.timeoutWhitelisted -and $test.timeoutActualReturncode -eq -9 -and $test.nonzeroActualReturncode -eq 20 -and $test.fixedSchema -and $test.poisonRejected -and $test.remainingDeadlineClamped -and $test.sourceRequests -eq 0) 'TimeoutExpired and real native exit guards offline'
$short=Get-Content "$ev/offline-1/integration-result.json" -Raw|ConvertFrom-Json
Require ($short.workerActualExit -eq 0 -and $short.parentActualExit -eq 0 -and $short.sourceAttempts -eq 0 -and $short.preparePacket.result.decode -ceq 'PASS') 'Short final fullpipeline0'
$rows=@(Get-Content "$ev/sample-3/native.jsonl"|ForEach-Object {$_|ConvertFrom-Json});$calls=@($rows|Where-Object {$_.step -ceq 'single-analyze-conditional-download'})
Require ($calls.Count -eq 1 -and $calls[0].actualExit -eq 20) 'Exactly one source analyzeFAIL'
$r=Get-Content "$ev/sample-3/candidate-result.json" -Raw|ConvertFrom-Json;$m=$r.metadataPacket
Require ($r.stage -ceq 'metadata' -and $r.status -ceq 'FAIL' -and -not $r.metadataAccepted -and $r.parentActualExit -eq 20 -and $r.workerActualExit -eq -9 -and $r.workerSignal -eq 9 -and $r.runtimeHashGate -ceq 'PASS' -and $m.status -ceq 'FAIL' -and $m.exception -ceq 'requests.ReadTimeout' -and $m.requestCount -eq 1 -and $m.decodedBytes -eq 0 -and -not $r.PSObject.Properties['preparePacket']) 'Source metadata timeout, prepare not run'
$d=$m.requests[0].sendDiagnostic
Require ($d.code -ceq 'READ_TIMEOUT' -and $d.status -ceq 'UNKNOWN' -and $d.seconds -ge 10 -and $d.seconds -lt 30 -and $d.phase -ceq 'metadata' -and $d.proxyConnect -ceq 'UNKNOWN' -and $d.originTLS -ceq 'UNKNOWN' -and $d.headerWait -ceq 'UNKNOWN') 'Exact safe observed source error/unmeasured stages'
foreach($n in @('video.mp4','video.mp4.part','video.mp4.ytdl','prepare-operations.jsonl')){Require (-not(Test-Path "$ev/sample-3/$n")) 'No source prepare/file/visual acceptance'}
$outer=Get-Content "$ev/outer-exits.json" -Raw|ConvertFrom-Json
Require (($outer.benchmarkOuterExits -join ',') -ceq '0,0,0' -and $outer.offlineOuterExit -eq 0 -and $outer.sourceOuterExit -eq 20 -and $outer.metadataGETAttempts -eq 1 -and $outer.prepareGETAttempts -eq 0) 'All outer outcomes/budgets'
$cause=Get-Content "$ev/cause.json" -Raw|ConvertFrom-Json
Require ($cause.falseRejectionOffline -ceq 'NOT_DEMONSTRATED' -and -not $cause.decodePolicyChanged -and $cause.decodeCapSeconds -eq 30 -and $cause.sourcePrepareOperations -ceq 'NOT_RUN' -and $cause.sourceRetries -eq 0) 'Honest false-rejection/UNKNOWN conclusion and stop'
Require (-not(Test-Path "$ev/sample-1") -and -not(Test-Path "$ev/sample-2")) 'No previous samples rerun'
$exclude=@("$ev/manifest.json","$ev/manifest-sha256.txt")
function Paths{@(@(rg --files -uu $ev labs/tiktok/cobalt|ForEach-Object {$_.Replace('\','/')}|Where-Object {$_ -cnotin $exclude})+$docs+@('docs/TIKTOK_COBALT_PREPARE_OPERATIONS_HANDOFF.md')|Sort-Object -Unique)}
if($Capture){
 Require (-not(Test-Path "$ev/manifest.json")) 'No manifest overwrite'
 [ordered]@{utc=[DateTime]::UtcNow.ToString('o');kind='Prepare operations/short+486 offline and one source metadataFAIL';predecessorManifest=$audit.predecessorManifest;predecessorManifestSHA=$audit.predecessorManifestSHA;changes=@(foreach($f in $allowed){@{path=$f;beforeSHA=$baseline[$f].sha256;afterSHA=(SHA $f)}})}|ConvertTo-Json -Depth 6|Set-Content "$ev/successor.json" -Encoding utf8
 [ordered]@{utc=[DateTime]::UtcNow.ToString('o');vn=[DateTime]::UtcNow.AddHours(7).ToString('yyyy-MM-dd HH:mm:ss.fff');baseline=$before.Count;preserved=$kept;exactChanges=$changed;benchmarkExits=@(0,0,0);offlineExit=0;sourceAnalyze=1;metadataGET=1;prepareGET=0;sourceStatus='METADATA_READ_TIMEOUT';workerExit=-9;parentExit=20;falseRejection='NOT_DEMONSTRATED';decodeCap=30;sourcePrepare='NOT_RUN';sourceFileVisual='NOT_RUN';acceptedSourceSamples=2;cleanupLeft=0;builds=0;mainApply=$false}|ConvertTo-Json -Depth 6|Set-Content "$ev/completion.json" -Encoding utf8
 @(foreach($f in (Paths)){@{path=$f;bytes=(Get-Item -LiteralPath $f).Length;sha256=(SHA $f)}})|ConvertTo-Json -Depth 5|Set-Content "$ev/manifest.json" -Encoding utf8
 SHA "$ev/manifest.json"|Set-Content "$ev/manifest-sha256.txt" -Encoding ascii
}
$successor=Get-Content "$ev/successor.json" -Raw|ConvertFrom-Json
Require (-not(Compare-Object ($allowed|Sort-Object) (@($successor.changes.path)|Sort-Object))) 'Exact successor scope'
foreach($r in $successor.changes){Require ((SHA $r.path) -ceq $r.afterSHA -and $baseline[$r.path].sha256 -ceq $r.beforeSHA) 'Successor exact hashes'}
$m=@(Get-Content "$ev/manifest.json" -Raw|ConvertFrom-Json)
Require ((SHA "$ev/manifest.json") -ceq (Get-Content "$ev/manifest-sha256.txt" -Raw).Trim() -and @($m.path|Sort-Object -Unique).Count -eq $m.Count -and -not(Compare-Object (Paths) @($m.path|Sort-Object))) 'Manifest self SHA and full coverage'
foreach($r in $m){Require ((SHA $r.path) -ceq $r.sha256 -and (Get-Item -LiteralPath $r.path).Length -eq $r.bytes) 'Artifact SHA/bytes'}
Write-Output "PASS evidence baseline=$($before.Count); preserved=$kept; scoped=$($changed.Count); artifacts=$($m.Count)/$($m.Count); old raw/golden unchanged; exact512MiB/CPU0.75 offline short486+fullpipeline0; decode30 false rejection NOT_DEMONSTRATED; one source metadataReadTimeout/parent20/worker-9, prepare0GET/NOT_RUN; accepted2/3; cleanup0"
