param([switch]$Capture)
$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
$root='D:\WED SNAP';$ev='docs/evidence/tiktok-cobalt-read20-20261009'
. "$PSScriptRoot/hash_gate.ps1"
function SHA($p){(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLower()}
function Require($ok,$why){if(-not $ok){throw $why}}
$docs=@('docs/AUDIT_TIEN_DO.md','docs/PROGRESS.md')
$allowed=$docs+@('labs/tiktok/cobalt/run.ps1','labs/tiktok/cobalt/NOTICE.md','labs/tiktok/cobalt/src/yt_candidate.py','labs/tiktok/cobalt/src/test_send_diagnostics.py','labs/tiktok/cobalt/src/test_all.py')
$before=@(Get-Content "$ev/before-all.json" -Raw|ConvertFrom-Json);$baseline=@{};$kept=0;$changed=@()
foreach($r in $before){
 $baseline[$r.path]=$r;Require (Test-Path -LiteralPath $r.path) "Missing baseline $($r.path)"
 if((SHA $r.path) -cne $r.sha256){Require ($r.path -cin $allowed) "Unscoped change $($r.path)";$changed+=$r.path}
 else{Require ((Get-Item -LiteralPath $r.path).Length -eq $r.bytes) 'Baseline bytes';$kept++}
}
Require (-not(Compare-Object ($allowed|Sort-Object) ($changed|Sort-Object))) 'Exact five lab/two docs changes'
$audit=Get-Content "$ev/prior-audit-successor-copy.json" -Raw|ConvertFrom-Json
Require ((SHA "$ev/prior-audit-successor-copy.json") -ceq (SHA 'docs/evidence/tiktok-cobalt-prepare-operations-audit-20261008/successor.json') -and (SHA $audit.predecessorManifest) -ceq $audit.predecessorManifestSHA) 'Predecessor audit/golden frozen'
foreach($r in @(Get-Content $audit.predecessorManifest -Raw|ConvertFrom-Json)){
 $b=$baseline[$r.path];Require ($null -ne $b) 'Predecessor baseline coverage'
 $doc=@($audit.changedDocs|Where-Object {$_.path -ceq $r.path})
 if($doc.Count){Require ($r.sha256 -ceq $doc[0].beforeSHA -and $b.sha256 -ceq $doc[0].afterSHA) 'Docs-only audit lineage'}
 else{Require ($r.sha256 -ceq $b.sha256 -and $r.bytes -eq $b.bytes) 'Golden baseline SHA'}
 if($r.path -cnotin $allowed){Require ((SHA $r.path) -ceq $r.sha256) 'Frozen raw/golden/verifier modified'}
}
$recovery=Get-Content "$ev/before-recovery.json" -Raw|ConvertFrom-Json
Require ($recovery.status -ceq 'PASS' -and $recovery.baselineSHAMatchedOriginal -and $recovery.lateCopiesPreserved -and -not $recovery.rawGoldenModified -and $recovery.recoveries.Count -eq 5) 'Before recovery transparency'
foreach($r in $recovery.recoveries){
 $suffix=$r.path.Substring('labs/tiktok/cobalt/'.Length).Replace('/','--')
 Require ((SHA "$ev/before/$suffix") -ceq $baseline[$r.path].sha256 -and $r.beforeSHA -ceq $baseline[$r.path].sha256 -and (SHA "$ev/captured-after-edit/$suffix") -ceq $r.copiedAfterSHA) 'Exact recovered before bytes and preserved late capture'
}
foreach($p in @(@{sample=1;folder='tiktok-cobalt-candidate-live-audit-20261008'},@{sample=2;folder='tiktok-cobalt-candidate-sample2-audit-20261008'})){
 $sPath="docs/evidence/$($p.folder)/successor.json";$s=Get-Content $sPath -Raw|ConvertFrom-Json
 Require ((SHA $sPath) -ceq (SHA "$ev/sample$($p.sample)-successor-copy.json") -and (SHA $s.humanReview) -ceq $s.humanReviewSHA -and (SHA "$ev/sample$($p.sample)-human-review-copy.json") -ceq $s.humanReviewSHA -and (SHA $s.predecessorManifest) -ceq $s.predecessorManifestSHA) 'Prior accepted records unchanged'
 $h=Get-Content $s.humanReview -Raw|ConvertFrom-Json
 Require ($h.accepted -and $h.fullVideoReviewed -and $h.perceptualAudioReviewed -and $h.watermarkReviewed -and (SHA $h.originalFile) -ceq $h.originalSHA) 'Accepted originals preserved'
}
Require ((SHA "$ev/sample3-target-copy.json") -ceq $s.sample3HistoricalTargetSHA) 'Historical target unchanged'
$image='sha256:5fcc01bb22ca5a264327f4bce4140b07c70d22b0a861ef41ff982d7d0fb3f3a6'
$receipt=Get-Content "$ev/offline-2/receipt.json" -Raw|ConvertFrom-Json
Assert-CobaltHashGate $receipt (CobaltHostHashes) $image
Require ((SHA "$ev/offline-2/native.jsonl") -ceq $receipt.nativeSHA -and (SHA "$ev/offline-2/runtime-inventory.json") -ceq $receipt.runtimeSHA -and (SHA "$ev/benchmark-3/runtime-inventory.json") -ceq $receipt.runtimeSHA) 'Final exact code/long/current receipt hash'
$oldRt=Get-Content 'docs/evidence/tiktok-cobalt-prepare-operations-20261008/offline-1/runtime-inventory.json' -Raw|ConvertFrom-Json
foreach($phase in @(@{dir='offline-1';exit=0},@{dir='benchmark-3';exit=1},@{dir='offline-2';exit=0})){
 $rt=Get-Content "$ev/$($phase.dir)/runtime-inventory.json" -Raw|ConvertFrom-Json
 Require ((ConvertTo-Json -InputObject $rt.dependencies -Depth 5 -Compress) -ceq (ConvertTo-Json -InputObject $oldRt.dependencies -Depth 5 -Compress)) 'Pinned installed dependencies/binaries unchanged'
 $rows=@(Get-Content "$ev/$($phase.dir)/native.jsonl"|ForEach-Object {$_|ConvertFrom-Json});$end=@($rows|Where-Object {$_.step -ceq 'end'})[0]
 Require ($end.actualExit -eq $phase.exit -and $end.ownResourcesLeft -eq 0 -and $end.removedContainers -eq 1 -and $end.removedNetworks -eq 0 -and @($rows|Where-Object {$_.timeout -eq $true -or $_.step -ceq 'single-analyze-conditional-download'}).Count -eq 0) 'Actual0/1/0 ownership cleanup and zero source'
 $guards=@(Get-ChildItem "$ev/$($phase.dir)/guard-*.json"|ForEach-Object {Get-Content $_.FullName -Raw|ConvertFrom-Json})
 Require ($guards.Count -eq 1) 'One offline task only'
 $g=$guards[0]
 Require ($g.Image -ceq $image -and $g.Config.User -ceq '1000:1000' -and $g.HostConfig.Memory -eq 512MB -and $g.HostConfig.MemorySwap -eq 512MB -and $g.HostConfig.NanoCpus -eq 750000000 -and $g.HostConfig.PidsLimit -eq 96 -and $g.HostConfig.NetworkMode -ceq 'none' -and $g.HostConfig.ReadonlyRootfs -and -not $g.HostConfig.Privileged -and -not $g.HostConfig.CapAdd -and $g.HostConfig.CapDrop -contains 'ALL' -and $g.HostConfig.SecurityOpt -contains 'no-new-privileges:true' -and $g.HostConfig.IpcMode -ceq 'private' -and -not $g.HostConfig.PidMode -and @($g.HostConfig.SecurityOpt|Where-Object {$_ -like 'seccomp=*'}).Count -eq 0 -and @($g.HostConfig.PortBindings.PSObject.Properties).Count -eq 0) 'Exact offline security/resource guard'
}
$old1=Get-Content "$ev/offline-1/receipt.json" -Raw|ConvertFrom-Json
Require ((SHA "$ev/offline-1/native.jsonl") -ceq $old1.nativeSHA -and (SHA "$ev/offline-1/runtime-inventory.json") -ceq $old1.runtimeSHA) 'Preserve first receipt without live use'
foreach($f in @('test_read20.py','read20_blocking_worker.py')){
 $rt1=Get-Content "$ev/offline-1/runtime-inventory.json" -Raw|ConvertFrom-Json
 Require ((SHA "$ev/offline1-tested-code/$f") -ceq @($rt1.source|Where-Object {$_.path -ceq $f})[0].sha256) 'Preserved initial startup-only test version'
}
$test=Get-Content "$ev/offline-2/read20-fixtures.json" -Raw|ConvertFrom-Json
Require ($test.status -ceq 'PASS' -and $test.sourceRequests -eq 0 -and $test.connectCeiling -eq 10 -and $test.readCeiling -eq 20 -and $test.realLibraryForwarding -and $test.expiredBeforeSendRejected -and $test.absoluteDeadlineIndependent -and $test.absoluteDeadlineAdapterEntered -and $test.results.Count -eq 7) 'Final read20 forwarding/deadline gate'
foreach($f in @($test.results|Where-Object {$_.case -like 'forward-*'})){
 $t=$f.effectiveTimeout
 Require ($t.connectSeconds -gt 0 -and $t.connectSeconds -le 10 -and $t.readCeilingSeconds -gt 0 -and $t.readCeilingSeconds -le 20 -and $t.connectSeconds -le $t.phaseRemainingSeconds -and $t.readCeilingSeconds -le $t.phaseRemainingSeconds -and $t.totalSeconds -eq $t.phaseRemainingSeconds -and $f.dynamicReadAfterConnect -gt 0 -and $f.dynamicReadAfterConnect -le $t.readCeilingSeconds -and $f.dynamicReadAfterConnect -lt $t.totalSeconds) 'Effective forwarded/clamped and library dynamic read'
}
foreach($phase in @('metadata','prepare')){
 $f=@($test.results|Where-Object {$_.case -ceq "absolute-$phase"})[0]
 $entered=Get-Content "$ev/offline-2/read20-entered-$phase.json" -Raw|ConvertFrom-Json
 Require ($f.adapterEntered -and $entered.adapterEntered -and $entered.phase -ceq $phase -and $f.workerExit -eq -9 -and $f.parentExit -eq 20 -and $f.productionDeadline -eq $(if($phase -ceq 'metadata'){30}else{180})) 'Independent absolute deadline after adapter entered'
}
$fixture=Get-Content "$ev/offline-2/integration-result.json" -Raw|ConvertFrom-Json
Require ($fixture.workerActualExit -eq 0 -and $fixture.parentActualExit -eq 0 -and $fixture.sourceAttempts -eq 0 -and $fixture.status -ceq 'FILE_NEEDS_VISUAL_REVIEW' -and $fixture.preparePacket.result.decode -ceq 'PASS' -and (SHA "$ev/offline-2/video.mp4") -ceq $fixture.preparePacket.result.sha256 -and (SHA "$ev/offline-2/fixture-input.mp4") -ceq $fixture.preparePacket.result.sha256) 'Final short actual pipeline/operations/SHA0'
foreach($req in $fixture.preparePacket.result.requests){$t=$req.effectiveTimeout;Require ($t.connectSeconds -le 10 -and $t.readCeilingSeconds -le 20 -and $t.totalSeconds -eq $t.phaseRemainingSeconds -and $req.url -ceq '[url-redacted]' -and $req.TLSverify -and -not $req.actualImpersonation) 'Integration new timeout/sanitization retained'}
Require (($fixture.preparePacket.result.operations.operation -join ',') -ceq 'DOWNLOADER,OUTPUT_CHECK,FFPROBE,CONTRACT,DECODE,HASH') 'Operations retained'
$b=Get-Content "$ev/benchmark-3/benchmark-result.json" -Raw|ConvertFrom-Json
$long=@($b.results|Where-Object {$_.case -ceq 'long486'})[0]
Require ($b.sourceRequests -eq 0 -and $long.status -ceq 'TIMEOUT' -and $long.exception -ceq 'subprocess.TimeoutExpired' -and $long.bytes -le 200MB -and $long.operations[0].returncode -eq 0 -and $long.operations[1].code -ceq 'OK') 'Long gate actual native decode timeout after contract'
$d=@($long.operations|Where-Object {$_.operation -ceq 'DECODE'})[0]
Require ($d.event -ceq 'ERROR' -and $d.code -ceq 'SUBPROCESS_TIMEOUT' -and $d.timeout -eq 30 -and $d.elapsed -ge 30 -and $d.returncode -eq -9 -and -not(Test-Path "$ev/benchmark-3/long-integration-result.json")) 'No long PASS fabricated'
$priorLong=Get-Content 'docs/evidence/tiktok-cobalt-prepare-operations-20261008/benchmark-3/long-integration-result.json' -Raw|ConvertFrom-Json
Require ($priorLong.preparePacket.result.decode -ceq 'PASS' -and $long.sha256 -ceq $priorLong.preparePacket.result.sha256 -and (SHA "$ev/benchmark-3/fixture-input.mp4") -ceq $long.sha256) 'Identical previously fully decoded known-valid fixture'
$stop=Get-Content "$ev/source-not-run.json" -Raw|ConvertFrom-Json
Require ($stop.status -ceq 'SOURCE_NOT_RUN' -and $stop.sourceAnalyzeAttempts -eq 0 -and $stop.metadataGET -eq 0 -and $stop.prepareGET -eq 0 -and $stop.decodeCap -eq 30 -and $stop.acceptedSourceSamples -eq 2 -and -not(Test-Path "$ev/sample-3")) 'Conditional source correctly blocked, no retry/head/fallback'
$cause=Get-Content "$ev/cause.json" -Raw|ConvertFrom-Json
Require ($cause.operation -ceq 'DECODE' -and $cause.actualNativeReturncode -eq -9 -and $cause.sameKnownValidBytes -and -not $cause.decodePolicyChanged -and $cause.sourceCalls -eq 0 -and $cause.historicalReadTimeoutCause -ceq 'UNKNOWN') 'Honest current cause and historical UNKNOWN'
$exclude=@("$ev/manifest.json","$ev/manifest-sha256.txt")
function Paths{@(@(rg --files -uu $ev labs/tiktok/cobalt|ForEach-Object {$_.Replace('\','/')}|Where-Object {$_ -cnotin $exclude})+$docs+@('docs/TIKTOK_COBALT_READ20_HANDOFF.md')|Sort-Object -Unique)}
if($Capture){
 Require (-not(Test-Path "$ev/manifest.json")) 'No manifest overwrite'
 [ordered]@{utc=[DateTime]::UtcNow.ToString('o');kind='Controlled read20 offline PASS but unchanged decode30 long gate FAIL; source NOT_RUN';predecessorManifest=$audit.predecessorManifest;predecessorManifestSHA=$audit.predecessorManifestSHA;changes=@(foreach($f in $allowed){@{path=$f;beforeSHA=$baseline[$f].sha256;afterSHA=(SHA $f)}})}|ConvertTo-Json -Depth 6|Set-Content "$ev/successor.json" -Encoding utf8
 [ordered]@{utc=[DateTime]::UtcNow.ToString('o');vn=[DateTime]::UtcNow.AddHours(7).ToString('yyyy-MM-dd HH:mm:ss.fff');baseline=$before.Count;preserved=$kept;exactChanges=$changed;offlineExits=@(0,0);longGateExit=1;forwardingAndAbsoluteDeadline='PASS';longDecode='TIMEOUT30_CHILD_MINUS9';decodeCap=30;source='NOT_RUN';sourceCalls=0;sourceRead20CausalOutcome='UNKNOWN';acceptedSourceSamples=2;cleanupLeft=0;builds=0;mainApply=$false}|ConvertTo-Json -Depth 6|Set-Content "$ev/completion.json" -Encoding utf8
 @(foreach($f in (Paths)){@{path=$f;bytes=(Get-Item -LiteralPath $f).Length;sha256=(SHA $f)}})|ConvertTo-Json -Depth 5|Set-Content "$ev/manifest.json" -Encoding utf8
 SHA "$ev/manifest.json"|Set-Content "$ev/manifest-sha256.txt" -Encoding ascii
}
$successor=Get-Content "$ev/successor.json" -Raw|ConvertFrom-Json
Require (-not(Compare-Object ($allowed|Sort-Object) (@($successor.changes.path)|Sort-Object))) 'Successor exact scope'
foreach($r in $successor.changes){Require ((SHA $r.path) -ceq $r.afterSHA -and $baseline[$r.path].sha256 -ceq $r.beforeSHA) 'Successor exact before/after SHA'}
$m=@(Get-Content "$ev/manifest.json" -Raw|ConvertFrom-Json)
Require ((SHA "$ev/manifest.json") -ceq (Get-Content "$ev/manifest-sha256.txt" -Raw).Trim() -and @($m.path|Sort-Object -Unique).Count -eq $m.Count -and -not(Compare-Object (Paths) @($m.path|Sort-Object))) 'Manifest self/full distinct coverage'
foreach($r in $m){Require ((SHA $r.path) -ceq $r.sha256 -and (Get-Item -LiteralPath $r.path).Length -eq $r.bytes) 'Artifact SHA/bytes'}
Write-Output "PASS evidence baseline=$($before.Count); preserved=$kept; scoped=$($changed.Count); artifacts=$($m.Count)/$($m.Count); exact recovered before/golden unchanged; read10-20 forwarding/absolute deadlines PASS; long decode30 timeout child-9/outer1; source0/NOT_RUN; accepted2/3; cleanup0"
