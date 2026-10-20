param([switch]$Capture)
$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
$root='D:\WED SNAP';$ev='docs/evidence/tiktok-cobalt-decode-budget-20261009'
. "$PSScriptRoot/hash_gate.ps1"
function SHA($p){(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLower()}
function Require($ok,$why){if(-not $ok){throw $why}}
$docs=@('docs/AUDIT_TIEN_DO.md','docs/PROGRESS.md')
$allowed=$docs+@('labs/tiktok/cobalt/run.ps1','labs/tiktok/cobalt/NOTICE.md','labs/tiktok/cobalt/src/candidate_file.py','labs/tiktok/cobalt/src/prepare_operations.py','labs/tiktok/cobalt/src/test_all.py')
$before=@(Get-Content "$ev/before-all.json" -Raw|ConvertFrom-Json);$baseline=@{};$kept=0;$changed=@()
foreach($r in $before){
 $baseline[$r.path]=$r;Require (Test-Path -LiteralPath $r.path) "Missing baseline $($r.path)"
 if((SHA $r.path) -cne $r.sha256){Require ($r.path -cin $allowed) "Unscoped change $($r.path)";$changed+=$r.path}
 else{Require ((Get-Item -LiteralPath $r.path).Length -eq $r.bytes) 'Baseline bytes';$kept++}
}
Require (-not(Compare-Object ($allowed|Sort-Object) ($changed|Sort-Object))) 'Exact five lab/two docs changes'
$audit=Get-Content "$ev/prior-audit-successor-copy.json" -Raw|ConvertFrom-Json
Require ((SHA "$ev/prior-audit-successor-copy.json") -ceq (SHA 'docs/evidence/tiktok-cobalt-read20-audit-20261009/successor.json') -and (SHA $audit.predecessorManifest) -ceq $audit.predecessorManifestSHA) 'Frozen predecessor audit/golden'
foreach($r in @(Get-Content $audit.predecessorManifest -Raw|ConvertFrom-Json)){
 $b=$baseline[$r.path];Require ($null -ne $b) 'Predecessor baseline coverage'
 $doc=@($audit.changedDocs|Where-Object {$_.path -ceq $r.path})
 if($doc.Count){Require ($r.sha256 -ceq $doc[0].beforeSHA -and $b.sha256 -ceq $doc[0].afterSHA) 'Docs-only audit lineage'}
 else{Require ($r.sha256 -ceq $b.sha256 -and $r.bytes -eq $b.bytes) 'Golden before baseline'}
 if($r.path -cnotin $allowed){Require ((SHA $r.path) -ceq $r.sha256) 'Frozen raw/golden/verifier modified'}
}
foreach($path in @($allowed|Where-Object {$_ -like 'labs/*'})){
 $suffix=$path.Substring('labs/tiktok/cobalt/'.Length).Replace('/','--')
 Require ((SHA "$ev/before/$suffix") -ceq $baseline[$path].sha256) 'Exact before snapshot taken before edit'
}
foreach($p in @(@{sample=1;folder='tiktok-cobalt-candidate-live-audit-20261008'},@{sample=2;folder='tiktok-cobalt-candidate-sample2-audit-20261008'})){
 $sPath="docs/evidence/$($p.folder)/successor.json";$s=Get-Content $sPath -Raw|ConvertFrom-Json
 Require ((SHA $sPath) -ceq (SHA "$ev/sample$($p.sample)-successor-copy.json") -and (SHA $s.humanReview) -ceq $s.humanReviewSHA -and (SHA "$ev/sample$($p.sample)-human-review-copy.json") -ceq $s.humanReviewSHA -and (SHA $s.predecessorManifest) -ceq $s.predecessorManifestSHA) 'Accepted predecessor records frozen'
 $h=Get-Content $s.humanReview -Raw|ConvertFrom-Json
 Require ($h.accepted -and $h.fullVideoReviewed -and $h.perceptualAudioReviewed -and $h.watermarkReviewed -and (SHA $h.originalFile) -ceq $h.originalSHA) 'Accepted source originals unchanged'
}
Require ((SHA "$ev/sample3-target-copy.json") -ceq $s.sample3HistoricalTargetSHA) 'Historical target unchanged'
$image='sha256:5fcc01bb22ca5a264327f4bce4140b07c70d22b0a861ef41ff982d7d0fb3f3a6'
$receipt=Get-Content "$ev/offline-1/receipt.json" -Raw|ConvertFrom-Json
Assert-CobaltHashGate $receipt (CobaltHostHashes) $image
Require ((SHA "$ev/offline-1/native.jsonl") -ceq $receipt.nativeSHA -and (SHA "$ev/offline-1/runtime-inventory.json") -ceq $receipt.runtimeSHA) 'Exact fresh offline receipt'
foreach($dir in @('benchmark-3','sample-3')){Require ((SHA "$ev/$dir/runtime-inventory.json") -ceq $receipt.runtimeSHA) 'Known-valid/offline/live exact runtime'}
Require ((SHA "$ev/sample-3/offline-runtime.json") -ceq $receipt.runtimeSHA) 'Entry installed hash gate'
$oldRt=Get-Content 'docs/evidence/tiktok-cobalt-read20-20261009/offline-2/runtime-inventory.json' -Raw|ConvertFrom-Json
foreach($phase in @(@{dir='benchmark-3';exit=0;c=1;n=0},@{dir='offline-1';exit=0;c=1;n=0},@{dir='sample-3';exit=20;c=2;n=2})){
 $rt=Get-Content "$ev/$($phase.dir)/runtime-inventory.json" -Raw|ConvertFrom-Json
 Require ((ConvertTo-Json -InputObject $rt.dependencies -Depth 5 -Compress) -ceq (ConvertTo-Json -InputObject $oldRt.dependencies -Depth 5 -Compress)) 'Pinned installed dependencies unchanged'
 $rows=@(Get-Content "$ev/$($phase.dir)/native.jsonl"|ForEach-Object {$_|ConvertFrom-Json});$end=@($rows|Where-Object {$_.step -ceq 'end'})[0]
 Require ($end.actualExit -eq $phase.exit -and $end.ownResourcesLeft -eq 0 -and $end.removedContainers -eq $phase.c -and $end.removedNetworks -eq $phase.n -and @($rows|Where-Object {$_.timeout -eq $true}).Count -eq 0) 'Actual0/0/20 and owned cleanup'
 $guards=@(Get-ChildItem "$ev/$($phase.dir)/guard-*.json"|ForEach-Object {Get-Content $_.FullName -Raw|ConvertFrom-Json})
 Require ($guards.Count -eq $phase.c) 'Actual task count'
 foreach($g in $guards){Require ($g.HostConfig.ReadonlyRootfs -and -not $g.HostConfig.Privileged -and -not $g.HostConfig.CapAdd -and $g.HostConfig.CapDrop -contains 'ALL' -and $g.HostConfig.SecurityOpt -contains 'no-new-privileges:true' -and $g.HostConfig.MemorySwap -eq $g.HostConfig.Memory -and $g.HostConfig.IpcMode -ceq 'private' -and -not $g.HostConfig.PidMode -and @($g.HostConfig.SecurityOpt|Where-Object {$_ -like 'seccomp=*'}).Count -eq 0 -and @($g.HostConfig.PortBindings.PSObject.Properties).Count -eq 0) 'Actual security guards'}
 $resolver=@($guards|Where-Object {$_.Config.User -ceq '1000:1000'})[0]
 Require ($resolver.Image -ceq $image -and $resolver.HostConfig.Memory -eq 512MB -and $resolver.HostConfig.NanoCpus -eq 750000000 -and $resolver.HostConfig.PidsLimit -eq 96) 'Exact512MiB/CPU0.75'
 if($phase.dir -cne 'sample-3'){Require ($resolver.HostConfig.NetworkMode -ceq 'none') 'Offline network-none'}
 else{
  $egress=@($guards|Where-Object {$_.Config.User -ceq '65534:65534'})[0]
  Require (($guards.HostConfig.Memory|Measure-Object -Sum).Sum -eq 608MB -and $egress.HostConfig.Memory -eq 96MB -and $egress.Image -ceq 'sha256:8bc0a567955111ea3cfbab2dd3b14f40a602f2d10ac987e78eb465f9d48d7f10' -and $resolver.Config.Cmd[-1] -ceq '7692288554839313682' -and $resolver.Config.Env -contains 'MEDIA_PROXY=[url-redacted]') 'Live pinned608MiB/sourceID/proxy'
 }
}
$expected='f587381808e3f189ee0125e31a040d17d9f2c4100dde9738e169c93f7c3592bb'
$copy=Get-Content "$ev/known-valid-copy.json" -Raw|ConvertFrom-Json
Require ($copy.sha256 -ceq $expected -and -not $copy.historicalSourceModified -and (SHA $copy.from) -ceq $expected -and (SHA $copy.to) -ceq $expected) 'Exact known-valid bytes copied, original unchanged'
$known=Get-Content "$ev/benchmark-3/known-valid-result.json" -Raw|ConvertFrom-Json
$kd=@($known.operations|Where-Object {$_.operation -ceq 'DECODE'})[0]
Require ($known.status -ceq 'PASS' -and $known.sha256 -ceq $expected -and $known.inspection.decode -ceq 'PASS' -and $kd.code -ceq 'OK' -and $kd.returncode -eq 0 -and $kd.elapsed -gt 30 -and $kd.timeout -le 170 -and $kd.timeout -gt 30) 'Full valid decode beyond30 within remaining-minus10'
$long=Get-Content "$ev/benchmark-3/long-integration-result.json" -Raw|ConvertFrom-Json
$ld=@($long.preparePacket.result.operations|Where-Object {$_.operation -ceq 'DECODE'})[0]
Require ($long.workerActualExit -eq 0 -and $long.parentActualExit -eq 0 -and $long.sourceAttempts -eq 0 -and $long.status -ceq 'FILE_NEEDS_VISUAL_REVIEW' -and $long.metadataPacket.summary.duration -eq 486 -and $long.prepareSeconds -lt 180 -and $long.preparePacket.result.decode -ceq 'PASS' -and $long.preparePacket.result.container -ceq 'MP4_ISO_BMFF' -and $long.preparePacket.result.sha256 -ceq $expected -and (SHA "$ev/benchmark-3/video.mp4") -ceq $expected -and $ld.returncode -eq 0 -and $ld.elapsed -gt 30 -and $ld.timeout -le 170) 'Full exact486pipeline/worker0/contract/SHA/reserve'
$budget=Get-Content "$ev/offline-1/decode-budget-fixtures.json" -Raw|ConvertFrom-Json
Require ($budget.status -ceq 'PASS' -and $budget.sourceRequests -eq 0 -and $budget.reserveSeconds -eq 10 -and $budget.exhaustedBeforeSpawn -and $budget.nativeErrorsAndReap -and $budget.results.Count -eq 8) 'Decode reserve and native gate tests'
foreach($f in @($budget.results|Where-Object {$_.case -like 'exhausted-*'})){Require ($f.spawnCalls -eq 0 -and $f.operation.code -ceq 'PREPARE_DEADLINE' -and $null -eq $f.operation.returncode -and $f.operation.timeout -eq 0) 'Exhausted reserve rejected before spawn'}
$native=@{success=0;exit20=20;selfkill=-9;timeout=-9}
foreach($f in @($budget.results|Where-Object {$_.case -in @('success','exit20','selfkill','timeout')})){Require ($f.operation.returncode -eq $native[$f.case] -and $f.reapedActualReturncode -eq $native[$f.case]) 'Actual child error/signal/timeout reaped'}
$findings=Get-Content "$ev/offline-1/finding-fixtures.json" -Raw|ConvertFrom-Json
Require (@($findings.results|Where-Object {$_.finding -ceq 'F-CANDIDATE-EXIT' -and $_.newOutputsCleaned -and $_.preexistingPreserved -and $_.parentActualExit -eq 20}).Count -eq 4) 'Metadata/prepare failed child cleanup exact owned outputs'
$short=Get-Content "$ev/offline-1/integration-result.json" -Raw|ConvertFrom-Json
Require ($short.workerActualExit -eq 0 -and $short.parentActualExit -eq 0 -and $short.sourceAttempts -eq 0 -and $short.preparePacket.result.decode -ceq 'PASS') 'Short exact final fullpipeline0'
$read=Get-Content "$ev/offline-1/read20-fixtures.json" -Raw|ConvertFrom-Json
Require ($read.status -ceq 'PASS' -and $read.absoluteDeadlineAdapterEntered -and $read.absoluteDeadlineIndependent -and $read.connectCeiling -eq 10 -and $read.readCeiling -eq 20) 'Read20+absolute deadlines retained'
$rows=@(Get-Content "$ev/sample-3/native.jsonl"|ForEach-Object {$_|ConvertFrom-Json});$calls=@($rows|Where-Object {$_.step -ceq 'single-analyze-conditional-download'})
Require ($calls.Count -eq 1 -and $calls[0].actualExit -eq 20) 'Exactly one assigned source trial'
$r=Get-Content "$ev/sample-3/candidate-result.json" -Raw|ConvertFrom-Json;$m=$r.metadataPacket.summary;$fail=$r.preparePacket
Require ($r.status -ceq 'FAIL' -and $r.stage -ceq 'prepare' -and $r.file -ceq 'FAIL_DISCARDED' -and -not $r.metadataAccepted -and $r.parentActualExit -eq 20 -and $r.workerActualExit -eq -9 -and $r.workerSignal -eq 9 -and $r.runtimeHashGate -ceq 'PASS') 'No packet-only success'
Require ($r.metadataPacket.status -ceq 'PASS' -and $m.id -ceq '7692288554839313682' -and $m.bodyIdAndTypeVerifiedByCobalt -and $m.duration -le 600 -and $m.requestCount -eq 2 -and $m.decodedBytes -le 16MB -and $r.metadataSeconds -lt 30 -and @($m.requests|Where-Object {$_.status -ne 200 -or $_.decodedBytes -gt 8MB}).Count -eq 0) 'Fresh real bounded provisional metadata'
$req=@($fail.requests|Where-Object {$_.phase -ceq 'prepare'})
Require ($fail.status -ceq 'FAIL' -and $fail.exception -ceq 'UnavailableVideoError' -and $fail.requestCount -eq 1 -and $fail.decodedBytes -eq 0 -and $r.prepareSeconds -lt 180 -and $req.Count -eq 1 -and -not $req[0].PSObject.Properties['status']) 'One MP4 send failed before response/body'
$d=$req[0].sendDiagnostic
Require ($d.code -ceq 'READ_TIMEOUT' -and $d.status -ceq 'UNKNOWN' -and $d.phase -ceq 'prepare' -and $d.seconds -ge 10 -and $d.seconds -lt 20 -and $d.proxyConnect -ceq 'UNKNOWN' -and $d.originTLS -ceq 'UNKNOWN' -and $d.headerWait -ceq 'UNKNOWN') 'Measured safe lower HTTP failure/unobserved substages'
foreach($q in $fail.requests){$t=$q.effectiveTimeout;Require ($q.url -ceq '[url-redacted]' -and $q.TLSverify -and -not $q.actualImpersonation -and $t.connectSeconds -le 10 -and $t.readCeilingSeconds -le 20 -and $t.totalSeconds -eq $t.phaseRemainingSeconds) 'Unchanged read20/verified TLS/redaction'}
Require ($fail.operations.Count -eq 1 -and $fail.operations[0].operation -ceq 'DOWNLOADER' -and $fail.operations[0].event -ceq 'ERROR') 'Failed actual operation, no decode attribution'
$events=@(Get-Content "$ev/sample-3/prepare-operations.jsonl"|ForEach-Object {$_|ConvertFrom-Json})
Require ($events.Count -eq 2 -and $events[0].event -ceq 'BEGIN' -and $events[1].event -ceq 'ERROR' -and @($events|Where-Object {$_.operation -cne 'DOWNLOADER'}).Count -eq 0) 'Complete source operations BEGIN/ERROR, downstream not run'
foreach($name in @('video.mp4','video.mp4.part','video.mp4.ytdl')){Require (-not(Test-Path "$ev/sample-3/$name")) 'No real file/visual acceptance'}
Require ($r.visualAudioWatermark -ceq 'NOT_RUN') 'No watermark claim'
$cause=Get-Content "$ev/cause.json" -Raw|ConvertFrom-Json
Require ($cause.operation -ceq 'DOWNLOADER' -and $cause.adapter.code -ceq 'READ_TIMEOUT' -and $cause.decodeBudgetFinding -ceq 'FIXED_OFFLINE' -and -not $cause.currentFailureIsDecodeBudget -and $cause.sourceRetries -eq 0) 'Cause accurately separates fixed finding from source error'
$outer=Get-Content "$ev/outer-exits.json" -Raw|ConvertFrom-Json
Require ($outer.benchmarkOuterExit -eq 0 -and $outer.offlineOuterExit -eq 0 -and $outer.sourceOuterExit -eq 20 -and $outer.sourceAnalyzes -eq 1 -and $outer.metadataGET -eq 2 -and $outer.prepareGET -eq 1) 'Native actual outcomes and source budget'
$exclude=@("$ev/manifest.json","$ev/manifest-sha256.txt")
function Paths{@(@(rg --files -uu $ev labs/tiktok/cobalt|ForEach-Object {$_.Replace('\','/')}|Where-Object {$_ -cnotin $exclude})+$docs+@('docs/TIKTOK_COBALT_DECODE_BUDGET_HANDOFF.md')|Sort-Object -Unique)}
if($Capture){
 Require (-not(Test-Path "$ev/manifest.json")) 'No manifest overwrite'
 [ordered]@{utc=[DateTime]::UtcNow.ToString('o');kind='F-DECODE-BUDGET fix offlinePASS and one source downloaderFAIL';predecessorManifest=$audit.predecessorManifest;predecessorManifestSHA=$audit.predecessorManifestSHA;changes=@(foreach($f in $allowed){@{path=$f;beforeSHA=$baseline[$f].sha256;afterSHA=(SHA $f)}})}|ConvertTo-Json -Depth 6|Set-Content "$ev/successor.json" -Encoding utf8
 [ordered]@{utc=[DateTime]::UtcNow.ToString('o');vn=[DateTime]::UtcNow.AddHours(7).ToString('yyyy-MM-dd HH:mm:ss.fff');baseline=$before.Count;preserved=$kept;exactChanges=$changed;finding='F-DECODE-BUDGET_FIXED_OFFLINE';reserveSeconds=10;prepareTotal=180;offlineExit=0;benchmarkExit=0;sourceAnalyze=1;metadataGET=2;prepareGET=1;source='DOWNLOADER_READ_TIMEOUT';sourceOuterExit=20;workerExit=-9;parentExit=20;sourceFileVisual='NOT_RUN';acceptedSourceSamples=2;cleanupLeft=0;builds=0;mainApply=$false}|ConvertTo-Json -Depth 6|Set-Content "$ev/completion.json" -Encoding utf8
 @(foreach($f in (Paths)){@{path=$f;bytes=(Get-Item -LiteralPath $f).Length;sha256=(SHA $f)}})|ConvertTo-Json -Depth 5|Set-Content "$ev/manifest.json" -Encoding utf8
 SHA "$ev/manifest.json"|Set-Content "$ev/manifest-sha256.txt" -Encoding ascii
}
$successor=Get-Content "$ev/successor.json" -Raw|ConvertFrom-Json
Require (-not(Compare-Object ($allowed|Sort-Object) (@($successor.changes.path)|Sort-Object))) 'Successor exact scope'
foreach($r in $successor.changes){Require ((SHA $r.path) -ceq $r.afterSHA -and $baseline[$r.path].sha256 -ceq $r.beforeSHA) 'Successor exact SHA'}
$manifest=@(Get-Content "$ev/manifest.json" -Raw|ConvertFrom-Json)
Require ((SHA "$ev/manifest.json") -ceq (Get-Content "$ev/manifest-sha256.txt" -Raw).Trim() -and @($manifest.path|Sort-Object -Unique).Count -eq $manifest.Count -and -not(Compare-Object (Paths) @($manifest.path|Sort-Object))) 'Manifest self/full distinct coverage'
foreach($r in $manifest){Require ((SHA $r.path) -ceq $r.sha256 -and (Get-Item -LiteralPath $r.path).Length -eq $r.bytes) 'Artifact SHA/bytes'}
Write-Output "PASS evidence baseline=$($before.Count); preserved=$kept; scoped=$($changed.Count); artifacts=$($manifest.Count)/$($manifest.Count); golden/raw unchanged; F-DECODE-BUDGET fixed offline/exhausted no spawn/known486 full decode32-33s/pipeline0; source2+1GET DOWNLOADER_READ_TIMEOUT/parent20/worker-9; no source file; accepted2/3; cleanup0"
