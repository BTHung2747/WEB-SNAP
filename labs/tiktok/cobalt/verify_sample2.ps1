param([switch]$Capture)
$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
$root='D:\WED SNAP';$ev='docs/evidence/tiktok-cobalt-candidate-sample2-20261008'
. "$PSScriptRoot/hash_gate.ps1"
function SHA($p){(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLower()}
function Require($ok,$why){if(-not $ok){throw $why}}
$docs=@('docs/AUDIT_TIEN_DO.md','docs/PROGRESS.md')
$allowed=$docs+@('labs/tiktok/cobalt/run.ps1','labs/tiktok/cobalt/compose.yaml','labs/tiktok/cobalt/NOTICE.md','labs/tiktok/cobalt/src/test_pipeline.py','labs/tiktok/cobalt/src/fixture_pipeline_worker.py')
$before=@(Get-Content "$ev/before-all.json" -Raw|ConvertFrom-Json);$kept=0;$changed=@();$baseline=@{}
foreach($r in $before){
 $baseline[$r.path]=$r
 Require (Test-Path -LiteralPath $r.path) "Missing baseline $($r.path)"
 if((SHA $r.path) -cne $r.sha256){Require ($r.path -cin $allowed) "Unscoped change $($r.path)";$changed+=$r.path}
 else{Require ((Get-Item -LiteralPath $r.path).Length -eq $r.bytes) 'Baseline bytes';$kept++}
}
Require (-not(Compare-Object ($allowed|Sort-Object) ($changed|Sort-Object))) 'Exact five lab/two docs successor'
$accepted=Get-Content "$ev/sample1-audit-successor-copy.json" -Raw|ConvertFrom-Json
Require ((SHA "$ev/sample1-audit-successor-copy.json") -ceq (SHA 'docs/evidence/tiktok-cobalt-candidate-live-audit-20261008/successor.json')) 'Sample1 audit successor unchanged'
Require ((SHA $accepted.predecessorManifest) -ceq $accepted.predecessorManifestSHA) 'Sample1 golden manifest unchanged'
Require ((SHA $accepted.humanReview) -ceq $accepted.humanReviewSHA -and (SHA "$ev/sample1-human-review-copy.json") -ceq $accepted.humanReviewSHA) 'Sample1 human review unchanged'
$human=Get-Content $accepted.humanReview -Raw|ConvertFrom-Json
Require ($human.accepted -and $human.fullVideoReviewed -and $human.perceptualAudioReviewed -and $human.watermarkReviewed -and $accepted.acceptedSourceSamples -eq 1 -and $human.originalSHA -ceq $accepted.sourceFileSHA -and (SHA $human.originalFile) -ceq $human.originalSHA) 'Explicit sample1 owner acceptance/file SHA'
$old=@(Get-Content $accepted.predecessorManifest -Raw|ConvertFrom-Json)
foreach($r in $old){
 $b=$baseline[$r.path];Require ($null -ne $b) 'Predecessor baseline coverage'
 $doc=@($accepted.changedDocs|Where-Object {$_.path -ceq $r.path})
 if($doc.Count){Require ($r.sha256 -ceq $doc[0].beforeSHA -and $b.sha256 -ceq $doc[0].afterSHA) 'Sample1 independent doc lineage'}
 else{Require ($r.sha256 -ceq $b.sha256 -and $r.bytes -eq $b.bytes) 'Sample1 predecessor baseline SHA'}
 if($r.path -cnotin $allowed){Require ((SHA $r.path) -ceq $r.sha256) 'Sample1 raw/golden/video/verifier modified'}
}
$image='sha256:5fcc01bb22ca5a264327f4bce4140b07c70d22b0a861ef41ff982d7d0fb3f3a6'
$receipt=Get-Content "$ev/offline-2/receipt.json" -Raw|ConvertFrom-Json
Assert-CobaltHashGate $receipt (CobaltHostHashes) $image
Require ((SHA "$ev/offline-2/native.jsonl") -ceq $receipt.nativeSHA -and (SHA "$ev/offline-2/runtime-inventory.json") -ceq $receipt.runtimeSHA) 'Offline exact code/receipt evidence'
Require ((SHA "$ev/sample-2/runtime-inventory.json") -ceq $receipt.runtimeSHA -and (SHA "$ev/sample-2/offline-runtime.json") -ceq $receipt.runtimeSHA) 'Exact installed live runtime'
$rt=Get-Content "$ev/sample-2/runtime-inventory.json" -Raw|ConvertFrom-Json
$prior=Get-Content 'docs/evidence/tiktok-cobalt-candidate-live-20261008/sample-1/runtime-inventory.json' -Raw|ConvertFrom-Json
Require ((ConvertTo-Json -InputObject $rt.dependencies -Depth 5 -Compress) -ceq (ConvertTo-Json -InputObject $prior.dependencies -Depth 5 -Compress)) 'Pinned installed dependencies unchanged'
foreach($r in $rt.source){
 Require ($r.sha256 -ceq (SHA "labs/tiktok/cobalt/src/$($r.path)")) 'Actual mounted source SHA'
 if($r.path -cnotin @('test_pipeline.py','fixture_pipeline_worker.py')){
  Require ($r.sha256 -ceq @($prior.source|Where-Object {$_.path -ceq $r.path})[0].sha256) 'Candidate/resolver/guard source unchanged'
 }
}
$denied=@(Get-Content "$ev/offline-1/native.jsonl"|ForEach-Object {$_|ConvertFrom-Json})
Require (@($denied|Where-Object {$_.step -eq 'preexisting' -and $_.actualExit -eq 1 -and $_.stderr -match 'permission denied'}).Count -eq 1 -and @($denied|Where-Object {$_.step -like 'create*'}).Count -eq 0 -and -not(Test-Path "$ev/offline-1/receipt.json")) 'Preflight Docker pipe failure retained, no false receipt/source'
$outer=@(Get-Content "$ev/outer-exits.json" -Raw|ConvertFrom-Json)
Require (($outer.outerActualExit -join ',') -ceq '1,0,0') 'Outer native exits retained'
foreach($phase in @(@{dir='offline-2';c=1;n=0},@{dir='sample-2';c=2;n=2})){
 $rows=@(Get-Content "$ev/$($phase.dir)/native.jsonl"|ForEach-Object {$_|ConvertFrom-Json});$end=@($rows|Where-Object {$_.step -eq 'end'})[0]
 Require ($end.actualExit -eq 0 -and $end.ownResourcesLeft -eq 0 -and $end.removedContainers -eq $phase.c -and $end.removedNetworks -eq $phase.n) 'Actual exit0 and ownership cleanup'
 Require (@($rows|Where-Object {$_.timeout -eq $true -or ($_.actualExit -and $_.actualExit -ne 0)}).Count -eq 0) 'No concealed native failure in successful phases'
}
$integration=Get-Content "$ev/offline-2/integration-result.json" -Raw|ConvertFrom-Json
Require ($integration.workerActualExit -eq 0 -and $integration.parentActualExit -eq 0 -and $integration.metadataAccepted -and $integration.status -ceq 'FILE_NEEDS_VISUAL_REVIEW' -and $integration.sourceAttempts -eq 0 -and $integration.metadataPacket.summary.id -ceq '7611475556395191573') 'Full offline pipeline sample2 ID/exit0'
Require ($integration.metadataPacket.summary.requestCount -eq 2 -and $integration.preparePacket.result.requestCount -eq 1 -and $integration.preparePacket.result.decode -ceq 'PASS' -and $integration.preparePacket.result.container -ceq 'MP4_ISO_BMFF') 'Full fixture downloader/file contract'
Require ((SHA "$ev/offline-2/video.mp4") -ceq $integration.preparePacket.result.sha256 -and (SHA "$ev/offline-2/fixture-input.mp4") -ceq $integration.preparePacket.result.sha256) 'Fixture native output unchanged'
$rows=@(Get-Content "$ev/sample-2/native.jsonl"|ForEach-Object {$_|ConvertFrom-Json});$calls=@($rows|Where-Object {$_.step -eq 'single-analyze-conditional-download'})
Require ($calls.Count -eq 1 -and $calls[0].actualExit -eq 0 -and -not $calls[0].timeout) 'Exactly one source analyze'
$reserved=Get-Content "$ev/sample-2/attempt-reserved.json" -Raw|ConvertFrom-Json
Require ($reserved.expectedId -ceq '7611475556395191573' -and $reserved.maxMetadataGET -eq 2 -and $reserved.maxPrepareGET -eq 1) 'Assigned source ID/request reservation'
$guards=@(Get-ChildItem "$ev/sample-2/guard-*.json"|ForEach-Object {Get-Content $_.FullName -Raw|ConvertFrom-Json})
Require ($guards.Count -eq 2 -and ($guards.HostConfig.Memory|Measure-Object -Sum).Sum -eq 608MB) 'Actual608MiB runtime'
foreach($g in $guards){Require ($g.HostConfig.ReadonlyRootfs -and -not $g.HostConfig.Privileged -and -not $g.HostConfig.CapAdd -and $g.HostConfig.CapDrop -contains 'ALL' -and $g.HostConfig.SecurityOpt -contains 'no-new-privileges:true' -and $g.HostConfig.MemorySwap -eq $g.HostConfig.Memory -and $g.HostConfig.IpcMode -ceq 'private' -and -not $g.HostConfig.PidMode -and @($g.HostConfig.SecurityOpt|Where-Object {$_ -like 'seccomp=*'}).Count -eq 0 -and @($g.HostConfig.PortBindings.PSObject.Properties).Count -eq 0) 'Actual guards unchanged'}
$resolver=@($guards|Where-Object {$_.Config.User -ceq '1000:1000'})[0];$proxy=@($guards|Where-Object {$_.Config.User -ceq '65534:65534'})[0]
# Runner checks the actual proxy before start; persisted guard JSON deliberately redacts all URLs.
Require ($resolver.Image -ceq $image -and $resolver.HostConfig.Memory -eq 512MB -and $resolver.Config.Cmd[-1] -ceq '7611475556395191573' -and $resolver.Config.Cmd[-2] -ceq '[url-redacted]' -and $resolver.Config.Env -contains 'MEDIA_PROXY=[url-redacted]' -and $proxy.Image -ceq 'sha256:8bc0a567955111ea3cfbab2dd3b14f40a602f2d10ac987e78eb465f9d48d7f10' -and $proxy.HostConfig.Memory -eq 96MB) 'Actual image/user/expectedID/redacted proxy wiring'
$r=Get-Content "$ev/sample-2/candidate-result.json" -Raw|ConvertFrom-Json;$meta=$r.metadataPacket.summary;$file=$r.preparePacket.result
Require ($r.workerActualExit -eq 0 -and $r.parentActualExit -eq 0 -and $r.metadataAccepted -and $r.runtimeHashGate -ceq 'PASS' -and $r.status -ceq 'FILE_NEEDS_VISUAL_REVIEW') 'PASS requires native worker exit0'
Require ($meta.metadata -ceq 'PASS' -and $meta.id -ceq '7611475556395191573' -and $meta.bodyIdAndTypeVerifiedByCobalt -and $meta.duration -gt 0 -and $meta.duration -le 600 -and $meta.requestCount -eq 2 -and $r.metadataSeconds -lt 30 -and $meta.decodedBytes -le 16MB) 'Actual source body ID/time/request/aggregate cap'
Require (@($meta.requests|Where-Object {$_.status -ne 200 -or $_.decodedBytes -gt 8MB -or $_.method -cne 'GET' -or $_.url -cne '[url-redacted]' -or -not $_.TLSverify}).Count -eq 0) 'Streaming response caps/verified TLS/redacted URLs'
Require ($file.requestCount -eq 1 -and $r.prepareSeconds -lt 180 -and $file.inputBytes -le 250MB -and $file.bytes -le 200MB -and $file.container -ceq 'MP4_ISO_BMFF' -and $file.decode -ceq 'PASS') 'Actual bounded MP4/decode'
Require (@($file.requests|Where-Object {$_.phase -eq 'prepare' -and $_.status -eq 200 -and $_.url -ceq '[url-redacted]'}).Count -eq 1 -and $file.ffprobe.format.tags.major_brand -ceq 'isom' -and @($file.ffprobe.streams|Where-Object {$_.codec_name -eq 'h264'}).Count -eq 1 -and @($file.ffprobe.streams|Where-Object {$_.codec_type -eq 'audio'}).Count -eq 1 -and [Math]::Abs($file.containerDuration-$meta.duration) -le $file.durationToleranceSeconds -and $file.durationToleranceSeconds -le 0.75) 'Real MP4/duration/H264/audio'
Require ((SHA "$ev/sample-2/video.mp4") -ceq $file.sha256 -and (Get-Item "$ev/sample-2/video.mp4").Length -eq $file.bytes) 'Original file SHA/bytes'
$visual=Get-Content "$ev/visual-assessment.json" -Raw|ConvertFrom-Json
Require ($visual.status -ceq 'NEEDS_VISUAL_REVIEW' -and -not $visual.accepted -and -not $visual.fullVideoReviewed -and -not $visual.perceptualAudioReviewed -and -not $visual.watermarkReviewed -and $visual.sha256 -ceq $file.sha256 -and $visual.acceptedSourceSamples -eq 1) 'No inferred visual/watermark acceptance'
Require (-not(Test-Path "$ev/sample-1") -and -not(Test-Path "$ev/sample-3")) 'No sample1 overwrite/sample3'
$exclude=@("$ev/manifest.json","$ev/manifest-sha256.txt")
function Paths{@(@(rg --files -uu $ev labs/tiktok/cobalt|ForEach-Object {$_.Replace('\','/')}|Where-Object {$_ -cnotin $exclude})+$docs+@('docs/TIKTOK_COBALT_SAMPLE2_HANDOFF.md')|Sort-Object -Unique)}
if($Capture){
 Require (-not(Test-Path "$ev/manifest.json")) 'No manifest overwrite'
 [ordered]@{utc=[DateTime]::UtcNow.ToString('o');kind='Sample2 narrow wiring and one source successor';predecessorManifest=$accepted.predecessorManifest;predecessorManifestSHA=$accepted.predecessorManifestSHA;sample1HumanReviewSHA=$accepted.humanReviewSHA;changes=@(foreach($f in $allowed){@{path=$f;beforeSHA=$baseline[$f].sha256;afterSHA=(SHA $f)}})}|ConvertTo-Json -Depth 6|Set-Content "$ev/successor.json" -Encoding utf8
 [ordered]@{utc=[DateTime]::UtcNow.ToString('o');vn=[DateTime]::UtcNow.AddHours(7).ToString('yyyy-MM-dd HH:mm:ss.fff');baseline=$before.Count;preserved=$kept;exactChanges=$changed;sourceAnalyzes=1;metadataGET=$meta.requestCount;prepareGET=$file.requestCount;workerExit=0;parentExit=0;sourceOuterExit=0;metadata='PASS';fileContract='PASS';visualAudioWatermark='NEEDS_VISUAL_REVIEW';sourceFileSHA=$file.sha256;offlineOuterExits=@(1,0);cleanupLeft=0;builds=0;acceptedSourceSamples=1;sample3='NOT_RUN';mainApply=$false}|ConvertTo-Json -Depth 6|Set-Content "$ev/completion.json" -Encoding utf8
 @(foreach($f in (Paths)){@{path=$f;bytes=(Get-Item -LiteralPath $f).Length;sha256=(SHA $f)}})|ConvertTo-Json -Depth 5|Set-Content "$ev/manifest.json" -Encoding utf8
 SHA "$ev/manifest.json"|Set-Content "$ev/manifest-sha256.txt" -Encoding ascii
}
$successor=Get-Content "$ev/successor.json" -Raw|ConvertFrom-Json
Require (-not(Compare-Object ($allowed|Sort-Object) (@($successor.changes.path)|Sort-Object))) 'Exact successor changes'
foreach($r in $successor.changes){Require ((SHA $r.path) -ceq $r.afterSHA -and $baseline[$r.path].sha256 -ceq $r.beforeSHA) 'Successor SHA'}
$m=@(Get-Content "$ev/manifest.json" -Raw|ConvertFrom-Json)
Require ((SHA "$ev/manifest.json") -ceq (Get-Content "$ev/manifest-sha256.txt" -Raw).Trim() -and @($m.path|Sort-Object -Unique).Count -eq $m.Count -and -not(Compare-Object (Paths) @($m.path|Sort-Object))) 'Manifest SHA/full distinct coverage'
foreach($r in $m){Require ((SHA $r.path) -ceq $r.sha256 -and (Get-Item -LiteralPath $r.path).Length -eq $r.bytes) 'Artifact hash/size'}
Write-Output "PASS baseline=$($before.Count); preserved=$kept; scoped=$($changed.Count); artifacts=$($m.Count)/$($m.Count); sample1 human/raw/golden unchanged; offline pipe FAIL1->PASS0 full sample2 fixture; one source2+1GET; worker/parent0; bodyID/MP4/decode/duration/SHA PASS; NEEDS_VISUAL_REVIEW; accepted1/3; cleanup0; no sample3/build/main"
