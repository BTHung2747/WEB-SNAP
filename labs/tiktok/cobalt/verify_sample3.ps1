param([switch]$Capture)
$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
$root='D:\WED SNAP';$ev='docs/evidence/tiktok-cobalt-candidate-sample3-20261008'
. "$PSScriptRoot/hash_gate.ps1"
function SHA($p){(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLower()}
function Require($ok,$why){if(-not $ok){throw $why}}
$docs=@('docs/AUDIT_TIEN_DO.md','docs/PROGRESS.md')
$allowed=$docs+@('labs/tiktok/cobalt/run.ps1','labs/tiktok/cobalt/NOTICE.md','labs/tiktok/cobalt/src/test_pipeline.py','labs/tiktok/cobalt/src/fixture_pipeline_worker.py')
$before=@(Get-Content "$ev/before-all.json" -Raw|ConvertFrom-Json);$baseline=@{};$kept=0;$changed=@()
foreach($r in $before){
 $baseline[$r.path]=$r;Require (Test-Path -LiteralPath $r.path) "Missing baseline $($r.path)"
 if((SHA $r.path) -cne $r.sha256){Require ($r.path -cin $allowed) "Unscoped change $($r.path)";$changed+=$r.path}
 else{Require ((Get-Item -LiteralPath $r.path).Length -eq $r.bytes) 'Baseline bytes';$kept++}
}
Require (-not(Compare-Object ($allowed|Sort-Object) ($changed|Sort-Object))) 'Exact four lab/two docs successor'
foreach($prior in @(@{sample=1;folder='tiktok-cobalt-candidate-live-audit-20261008';id='7692808825228807442'},@{sample=2;folder='tiktok-cobalt-candidate-sample2-audit-20261008';id='7611475556395191573'})){
 $sPath="docs/evidence/$($prior.folder)/successor.json";$accepted=Get-Content $sPath -Raw|ConvertFrom-Json
 Require ((SHA $sPath) -ceq (SHA "$ev/sample$($prior.sample)-successor-copy.json") -and (SHA $accepted.predecessorManifest) -ceq $accepted.predecessorManifestSHA) 'Frozen prior successor/manifest'
 Require ((SHA $accepted.humanReview) -ceq $accepted.humanReviewSHA -and (SHA "$ev/sample$($prior.sample)-human-review-copy.json") -ceq $accepted.humanReviewSHA) 'Frozen human review'
 $human=Get-Content $accepted.humanReview -Raw|ConvertFrom-Json
 Require ($human.sourceVideoId -ceq $prior.id -and $human.accepted -and $human.fullVideoReviewed -and $human.perceptualAudioReviewed -and $human.watermarkReviewed -and $human.originalSHA -ceq $accepted.sourceFileSHA -and (SHA $human.originalFile) -ceq $human.originalSHA -and $accepted.acceptedSourceSamples -eq $prior.sample) 'Both explicit human acceptances/originals'
}
Require ((SHA $accepted.sample1AcceptanceSuccessor) -ceq $accepted.sample1AcceptanceSuccessorSHA -and (SHA $accepted.sample3HistoricalTarget) -ceq $accepted.sample3HistoricalTargetSHA -and (SHA "$ev/sample3-target-copy.json") -ceq $accepted.sample3HistoricalTargetSHA) 'Acceptance/mapping lineage'
$target=Get-Content "$ev/sample3-target-copy.json" -Raw|ConvertFrom-Json
Require ($target.canonicalVideoId -ceq '7692288554839313682' -and $target.canonicalAuthor -ceq 'nguye003' -and $target.historicalMetadata -ceq 'FAIL' -and -not $target.canonicalMappingRecheckedThisAudit) 'Mapping is historical only'
$old=@(Get-Content $accepted.predecessorManifest -Raw|ConvertFrom-Json)
foreach($r in $old){
 $b=$baseline[$r.path];Require ($null -ne $b) 'Predecessor baseline coverage'
 $doc=@($accepted.changedDocs|Where-Object {$_.path -ceq $r.path})
 if($doc.Count){Require ($r.sha256 -ceq $doc[0].beforeSHA -and $b.sha256 -ceq $doc[0].afterSHA) 'Sample2 doc-only successor lineage'}
 else{Require ($r.sha256 -ceq $b.sha256 -and $r.bytes -eq $b.bytes) 'Sample2 golden baseline SHA'}
 if($r.path -cnotin $allowed){Require ((SHA $r.path) -ceq $r.sha256) 'Prior raw/golden/verifier/video changed'}
}
$image='sha256:5fcc01bb22ca5a264327f4bce4140b07c70d22b0a861ef41ff982d7d0fb3f3a6'
$receipt=Get-Content "$ev/offline-1/receipt.json" -Raw|ConvertFrom-Json
Assert-CobaltHashGate $receipt (CobaltHostHashes) $image
Require ((SHA "$ev/offline-1/native.jsonl") -ceq $receipt.nativeSHA -and (SHA "$ev/offline-1/runtime-inventory.json") -ceq $receipt.runtimeSHA -and (SHA "$ev/sample-3/runtime-inventory.json") -ceq $receipt.runtimeSHA -and (SHA "$ev/sample-3/offline-runtime.json") -ceq $receipt.runtimeSHA) 'Exact offline/live hash gate'
$rt=Get-Content "$ev/sample-3/runtime-inventory.json" -Raw|ConvertFrom-Json
$priorRuntime=Get-Content 'docs/evidence/tiktok-cobalt-candidate-sample2-20261008/sample-2/runtime-inventory.json' -Raw|ConvertFrom-Json
Require ((ConvertTo-Json -InputObject $rt.dependencies -Depth 5 -Compress) -ceq (ConvertTo-Json -InputObject $priorRuntime.dependencies -Depth 5 -Compress)) 'Installed dependencies unchanged'
foreach($r in $rt.source){
 Require ($r.sha256 -ceq (SHA "labs/tiktok/cobalt/src/$($r.path)")) 'Actual mounted source'
 if($r.path -cnotin @('test_pipeline.py','fixture_pipeline_worker.py')){Require ($r.sha256 -ceq @($priorRuntime.source|Where-Object {$_.path -ceq $r.path})[0].sha256) 'Candidate/resolver/guards unchanged'}
}
$integration=Get-Content "$ev/offline-1/integration-result.json" -Raw|ConvertFrom-Json
Require ($integration.sourceAttempts -eq 0 -and $integration.parentActualExit -eq 0 -and $integration.workerActualExit -eq 0 -and $integration.metadataAccepted -and $integration.status -ceq 'FILE_NEEDS_VISUAL_REVIEW' -and $integration.metadataPacket.summary.id -ceq '7692288554839313682') 'Exact sample3 full offline pipeline/exit0'
Require ($integration.metadataPacket.summary.requestCount -eq 2 -and $integration.preparePacket.result.requestCount -eq 1 -and $integration.preparePacket.result.container -ceq 'MP4_ISO_BMFF' -and $integration.preparePacket.result.decode -ceq 'PASS' -and (SHA "$ev/offline-1/video.mp4") -ceq $integration.preparePacket.result.sha256 -and (SHA "$ev/offline-1/fixture-input.mp4") -ceq $integration.preparePacket.result.sha256) 'Actual fixture downloader/file/SHA'
foreach($phase in @(@{dir='offline-1';exit=0;c=1;n=0},@{dir='sample-3';exit=20;c=2;n=2})){
 $rows=@(Get-Content "$ev/$($phase.dir)/native.jsonl"|ForEach-Object {$_|ConvertFrom-Json});$end=@($rows|Where-Object {$_.step -eq 'end'})[0]
 Require ($end.actualExit -eq $phase.exit -and $end.ownResourcesLeft -eq 0 -and $end.removedContainers -eq $phase.c -and $end.removedNetworks -eq $phase.n) 'Actual exits and ownership cleanup'
 Require (@($rows|Where-Object {$_.timeout -eq $true}).Count -eq 0) 'No native supervisory timeout'
 Require (@($rows|Where-Object {$null -ne $_.actualExit -and $_.actualExit -ne 0 -and $_.step -cnotin @('single-analyze-conditional-download','end')}).Count -eq 0) 'No concealed unrelated native failures'
}
$outer=Get-Content "$ev/outer-exits.json" -Raw|ConvertFrom-Json
Require ($outer.offlineOuterActualExit -eq 0 -and $outer.liveOuterActualExit -eq 20) 'Outer exits distinguish offline/source'
$rows=@(Get-Content "$ev/sample-3/native.jsonl"|ForEach-Object {$_|ConvertFrom-Json});$calls=@($rows|Where-Object {$_.step -eq 'single-analyze-conditional-download'})
Require ($calls.Count -eq 1 -and $calls[0].actualExit -eq 20 -and -not $calls[0].timeout) 'Exactly one failed source trial'
$states=@($rows|Where-Object {$_.step -eq 'inspect'}|ForEach-Object {@($_.stdout|ConvertFrom-Json)[0]}|Where-Object {$_.Name -ceq '/wed-snap-cobalt-resolver' -and $_.State.ExitCode -eq 20})
Require ($states.Count -ge 1 -and @($states|Where-Object {$_.State.OOMKilled -or $_.State.Running}).Count -eq 0) 'Actual container20/no OOM'
$guards=@(Get-ChildItem "$ev/sample-3/guard-*.json"|ForEach-Object {Get-Content $_.FullName -Raw|ConvertFrom-Json})
Require ($guards.Count -eq 2 -and ($guards.HostConfig.Memory|Measure-Object -Sum).Sum -eq 608MB) 'Actual608MiB runtime'
foreach($g in $guards){Require ($g.HostConfig.ReadonlyRootfs -and -not $g.HostConfig.Privileged -and -not $g.HostConfig.CapAdd -and $g.HostConfig.CapDrop -contains 'ALL' -and $g.HostConfig.SecurityOpt -contains 'no-new-privileges:true' -and $g.HostConfig.MemorySwap -eq $g.HostConfig.Memory -and $g.HostConfig.IpcMode -ceq 'private' -and -not $g.HostConfig.PidMode -and @($g.HostConfig.SecurityOpt|Where-Object {$_ -like 'seccomp=*'}).Count -eq 0 -and @($g.HostConfig.PortBindings.PSObject.Properties).Count -eq 0) 'Actual unchanged protection'}
$resolver=@($guards|Where-Object {$_.Config.User -ceq '1000:1000'})[0];$proxy=@($guards|Where-Object {$_.Config.User -ceq '65534:65534'})[0]
Require ($resolver.Image -ceq $image -and $resolver.HostConfig.Memory -eq 512MB -and $resolver.Config.Cmd[-1] -ceq '7692288554839313682' -and $resolver.Config.Cmd[-2] -ceq '[url-redacted]' -and $resolver.Config.Env -contains 'MEDIA_PROXY=[url-redacted]' -and $proxy.Image -ceq 'sha256:8bc0a567955111ea3cfbab2dd3b14f40a602f2d10ac987e78eb465f9d48d7f10' -and $proxy.HostConfig.Memory -eq 96MB) 'Actual IDs/images/proxy wiring sanitized; runner checked real proxy'
$reserved=Get-Content "$ev/sample-3/attempt-reserved.json" -Raw|ConvertFrom-Json
Require ($reserved.expectedId -ceq '7692288554839313682' -and $reserved.maxMetadataGET -eq 2 -and $reserved.maxPrepareGET -eq 1) 'Exclusive reservation/budgets'
$r=Get-Content "$ev/sample-3/candidate-result.json" -Raw|ConvertFrom-Json;$meta=$r.metadataPacket.summary;$fail=$r.preparePacket
Require ($r.stage -ceq 'prepare' -and $r.status -ceq 'FAIL' -and $r.file -ceq 'FAIL_DISCARDED' -and -not $r.metadataAccepted -and $r.parentActualExit -eq 20 -and $r.workerActualExit -eq -9 -and $r.workerSignal -eq 9 -and $r.runtimeHashGate -ceq 'PASS') 'FAIL packet and native worker outcome cannot pass'
Require ($r.metadataPacket.status -ceq 'PASS' -and $meta.id -ceq '7692288554839313682' -and $meta.bodyIdAndTypeVerifiedByCobalt -and $meta.duration -gt 0 -and $meta.duration -le 600 -and $meta.requestCount -eq 2 -and $r.metadataSeconds -lt 30 -and $meta.decodedBytes -le 16MB) 'Fresh metadata body ID and bounds, provisional only'
Require (@($meta.requests|Where-Object {$_.status -ne 200 -or $_.decodedBytes -gt 8MB -or $_.method -cne 'GET' -or $_.url -cne '[url-redacted]' -or -not $_.TLSverify}).Count -eq 0) 'Metadata decoded cap/redaction/TLS'
Require ($fail.status -ceq 'FAIL' -and $fail.error -ceq 'YTDLP_OR_FILE_FAILURE' -and $fail.exception -ceq 'UnavailableVideoError' -and $fail.requestCount -eq 1 -and $fail.decodedBytes -eq 0 -and $r.prepareSeconds -lt 180) 'Recorded prepare failure and budget'
$attempts=@($fail.requests|Where-Object {$_.phase -ceq 'prepare'})
Require ($attempts.Count -eq 1 -and $attempts[0].method -ceq 'GET' -and $attempts[0].url -ceq '[url-redacted]' -and -not $attempts[0].PSObject.Properties['status'] -and $attempts[0].decodedBytes -eq 0 -and $attempts[0].TLSverify) 'One prepare attempt, no observed HTTP status/body'
foreach($name in @('video.mp4','video.mp4.part','video.mp4.ytdl')){Require (-not(Test-Path "$ev/sample-3/$name")) 'No real media/output to review'}
Require ($r.ownedOutputRemoved.Count -eq 0 -and $r.preexistingOutputsPreserved.Count -eq 0 -and $r.visualAudioWatermark -ceq 'NOT_RUN') 'No fake file/visual acceptance'
$cause=Get-Content "$ev/cause.json" -Raw|ConvertFrom-Json
Require ($cause.stage -ceq 'prepare' -and -not $cause.httpStatusObserved -and -not $cause.fileExists -and $cause.probe -ceq 'NOT_RUN' -and $cause.decode -ceq 'NOT_RUN' -and $cause.fileSHA -ceq 'NOT_RUN' -and $cause.sourceReruns -eq 0) 'Cause limits and stop respected'
Require (-not(Test-Path "$ev/sample-1") -and -not(Test-Path "$ev/sample-2")) 'No previous sample rerun/overwrite'
$exclude=@("$ev/manifest.json","$ev/manifest-sha256.txt")
function Paths{@(@(rg --files -uu $ev labs/tiktok/cobalt|ForEach-Object {$_.Replace('\','/')}|Where-Object {$_ -cnotin $exclude})+$docs+@('docs/TIKTOK_COBALT_SAMPLE3_HANDOFF.md')|Sort-Object -Unique)}
if($Capture){
 Require (-not(Test-Path "$ev/manifest.json")) 'No manifest overwrite'
 [ordered]@{utc=[DateTime]::UtcNow.ToString('o');kind='Sample3 narrow wiring and one failed longURL source successor';predecessorManifest=$accepted.predecessorManifest;predecessorManifestSHA=$accepted.predecessorManifestSHA;sample1SuccessorSHA=$accepted.sample1AcceptanceSuccessorSHA;sample2HumanReviewSHA=$accepted.humanReviewSHA;historicalTargetSHA=$accepted.sample3HistoricalTargetSHA;changes=@(foreach($f in $allowed){@{path=$f;beforeSHA=$baseline[$f].sha256;afterSHA=(SHA $f)}})}|ConvertTo-Json -Depth 6|Set-Content "$ev/successor.json" -Encoding utf8
 [ordered]@{utc=[DateTime]::UtcNow.ToString('o');vn=[DateTime]::UtcNow.AddHours(7).ToString('yyyy-MM-dd HH:mm:ss.fff');baseline=$before.Count;preserved=$kept;exactChanges=$changed;offlineExit=0;sourceAnalyzes=1;metadataGET=2;prepareClientAttempts=1;metadataPacket='PASS';overallMetadataAccepted=$false;sourceStage='prepare';sourceStatus='FAIL';workerExit=-9;workerSignal=9;parentExit=20;containerExit=20;sourceOuterExit=20;sourceFile='NOT_RUN';fileProbeDecodeSHA='NOT_RUN';visualAudioWatermark='NOT_RUN';acceptedSourceSamples=2;cleanupLeft=0;builds=0;shortlinkRequests=0;shortlinkAPIE2E='NOT_RUN';mainApply=$false}|ConvertTo-Json -Depth 6|Set-Content "$ev/completion.json" -Encoding utf8
 @(foreach($f in (Paths)){@{path=$f;bytes=(Get-Item -LiteralPath $f).Length;sha256=(SHA $f)}})|ConvertTo-Json -Depth 5|Set-Content "$ev/manifest.json" -Encoding utf8
 SHA "$ev/manifest.json"|Set-Content "$ev/manifest-sha256.txt" -Encoding ascii
}
$successor=Get-Content "$ev/successor.json" -Raw|ConvertFrom-Json
Require (-not(Compare-Object ($allowed|Sort-Object) (@($successor.changes.path)|Sort-Object))) 'Exact successor scope'
foreach($r in $successor.changes){Require ((SHA $r.path) -ceq $r.afterSHA -and $baseline[$r.path].sha256 -ceq $r.beforeSHA) 'Successor exact SHA'}
$m=@(Get-Content "$ev/manifest.json" -Raw|ConvertFrom-Json)
Require ((SHA "$ev/manifest.json") -ceq (Get-Content "$ev/manifest-sha256.txt" -Raw).Trim() -and @($m.path|Sort-Object -Unique).Count -eq $m.Count -and -not(Compare-Object (Paths) @($m.path|Sort-Object))) 'Manifest self SHA and full distinct coverage'
foreach($r in $m){Require ((SHA $r.path) -ceq $r.sha256 -and (Get-Item -LiteralPath $r.path).Length -eq $r.bytes) 'Artifact hash/size'}
Write-Output "PASS evidence verification baseline=$($before.Count); preserved=$kept; scoped=$($changed.Count); artifacts=$($m.Count)/$($m.Count); prior reviews/raw/golden unchanged; exact offline0; one source metadata packetPASS/bodyID, prepareFAIL/worker-9/parent20; no real file; accepted2/3; cleanup0; no shortlink/retry/build/main"
