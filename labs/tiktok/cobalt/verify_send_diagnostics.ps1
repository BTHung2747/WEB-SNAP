param([switch]$Capture)
$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
$root='D:\WED SNAP';$ev='docs/evidence/tiktok-cobalt-sample3-send-diagnostics-20261008'
. "$PSScriptRoot/hash_gate.ps1"
function SHA($p){(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLower()}
function Require($ok,$why){if(-not $ok){throw $why}}
$docs=@('docs/AUDIT_TIEN_DO.md','docs/PROGRESS.md')
$allowed=$docs+@('labs/tiktok/cobalt/run.ps1','labs/tiktok/cobalt/NOTICE.md','labs/tiktok/cobalt/src/yt_candidate.py','labs/tiktok/cobalt/src/test_all.py')
$before=@(Get-Content "$ev/before-all.json" -Raw|ConvertFrom-Json);$baseline=@{};$kept=0;$changed=@()
foreach($r in $before){
 $baseline[$r.path]=$r;Require (Test-Path -LiteralPath $r.path) "Missing baseline $($r.path)"
 if((SHA $r.path) -cne $r.sha256){Require ($r.path -cin $allowed) "Unscoped change $($r.path)";$changed+=$r.path}
 else{Require ((Get-Item -LiteralPath $r.path).Length -eq $r.bytes) 'Baseline bytes';$kept++}
}
Require (-not(Compare-Object ($allowed|Sort-Object) ($changed|Sort-Object))) 'Exact four lab/two docs changes'
$audit=Get-Content "$ev/prior-audit-successor-copy.json" -Raw|ConvertFrom-Json
Require ((SHA "$ev/prior-audit-successor-copy.json") -ceq (SHA 'docs/evidence/tiktok-cobalt-candidate-sample3-audit-20261008/successor.json') -and (SHA $audit.predecessorManifest) -ceq $audit.predecessorManifestSHA) 'Prior audit/golden unchanged'
foreach($r in @(Get-Content $audit.predecessorManifest -Raw|ConvertFrom-Json)){
 $b=$baseline[$r.path];Require ($null -ne $b) 'Golden baseline coverage'
 $doc=@($audit.changedDocs|Where-Object {$_.path -ceq $r.path})
 if($doc.Count){Require ($r.sha256 -ceq $doc[0].beforeSHA -and $b.sha256 -ceq $doc[0].afterSHA) 'Doc-only audit lineage'}
 else{Require ($r.sha256 -ceq $b.sha256 -and $r.bytes -eq $b.bytes) 'Golden predecessor baseline'}
 if($r.path -cnotin $allowed){Require ((SHA $r.path) -ceq $r.sha256) 'Frozen raw/verifier/golden modified'}
}
foreach($p in @(@{sample=1;folder='tiktok-cobalt-candidate-live-audit-20261008'},@{sample=2;folder='tiktok-cobalt-candidate-sample2-audit-20261008'})){
 $sPath="docs/evidence/$($p.folder)/successor.json";$s=Get-Content $sPath -Raw|ConvertFrom-Json
 Require ((SHA $sPath) -ceq (SHA "$ev/sample$($p.sample)-successor-copy.json") -and (SHA $s.predecessorManifest) -ceq $s.predecessorManifestSHA -and (SHA $s.humanReview) -ceq $s.humanReviewSHA -and (SHA "$ev/sample$($p.sample)-human-review-copy.json") -ceq $s.humanReviewSHA) 'Prior review/successor/manifest immutable'
 $h=Get-Content $s.humanReview -Raw|ConvertFrom-Json
 Require ($h.accepted -and $h.fullVideoReviewed -and $h.perceptualAudioReviewed -and $h.watermarkReviewed -and (SHA $h.originalFile) -ceq $h.originalSHA -and $h.originalSHA -ceq $s.sourceFileSHA) 'Prior human acceptance/original unchanged'
}
Require ((SHA "$ev/sample3-target-copy.json") -ceq $s.sample3HistoricalTargetSHA -and (SHA $s.sample3HistoricalTarget) -ceq $s.sample3HistoricalTargetSHA) 'Historical mapping unchanged'
$image='sha256:5fcc01bb22ca5a264327f4bce4140b07c70d22b0a861ef41ff982d7d0fb3f3a6'
$receipt=Get-Content "$ev/offline-1/receipt.json" -Raw|ConvertFrom-Json
Assert-CobaltHashGate $receipt (CobaltHostHashes) $image
Require ((SHA "$ev/offline-1/native.jsonl") -ceq $receipt.nativeSHA -and (SHA "$ev/offline-1/runtime-inventory.json") -ceq $receipt.runtimeSHA -and (SHA "$ev/sample-3/runtime-inventory.json") -ceq $receipt.runtimeSHA -and (SHA "$ev/sample-3/offline-runtime.json") -ceq $receipt.runtimeSHA) 'Exact offline/live source+installed runtime hashes'
$rt=Get-Content "$ev/sample-3/runtime-inventory.json" -Raw|ConvertFrom-Json
$oldRuntime=Get-Content 'docs/evidence/tiktok-cobalt-candidate-sample3-20261008/sample-3/runtime-inventory.json' -Raw|ConvertFrom-Json
Require ((ConvertTo-Json -InputObject $rt.dependencies -Depth 5 -Compress) -ceq (ConvertTo-Json -InputObject $oldRuntime.dependencies -Depth 5 -Compress)) 'Pinned1364dependencies unchanged'
foreach($r in $oldRuntime.source){if($r.path -cnotin @('yt_candidate.py','test_all.py')){Require ((SHA "labs/tiktok/cobalt/src/$($r.path)") -ceq $r.sha256) 'Original resolver/guards/downloader/file contract unchanged'}}
$fixture=Get-Content "$ev/offline-1/send-diagnostics-fixtures.json" -Raw|ConvertFrom-Json
Require ($fixture.status -ceq 'PASS' -and $fixture.sourceRequests -eq 0 -and $fixture.originalExceptionsPreserved -and $fixture.unknownSubStagesPreserved -and $fixture.poisonedPayloadRejected -and $fixture.boundedGraph -and $fixture.results.Count -eq 10) 'Exact library diagnostics offline gates'
$codes=@{ 'connect-timeout'='CONNECT_TIMEOUT';'read-timeout'='READ_TIMEOUT';'proxy-connect-failure'='PROXY_ERROR';'tls-failure'='TLS_ERROR';'new-connection-is-not-timeout'='NEW_CONNECTION_ERROR'}
foreach($f in $fixture.results){
 Require ($f.poolSendCalls -eq 1 -and $f.timeoutConnect -eq 10 -and $f.timeoutRead -eq 10 -and $f.decodedBytes -eq 0 -and $f.libraryMappingReal) 'RealAdapter fakepool timeout/cap/request policy'
 if($codes.ContainsKey($f.case)){Require ($f.diagnostic.code -ceq $codes[$f.case] -and $f.diagnostic.status -ceq 'UNKNOWN') 'Correct timeout/proxy/TLS mapping'}
 else{Require ($f.diagnostic.code -ceq 'HTTP_RESPONSE' -and $f.diagnostic.status -in @(200,302,403,404,500)) 'Actual HTTP fixture statuses'}
 Require ($f.diagnostic.proxyConnect -ceq 'UNKNOWN' -and $f.diagnostic.originTLS -ceq 'UNKNOWN' -and $f.diagnostic.headerWait -ceq 'UNKNOWN' -and $f.diagnostic.seconds -ge 0.002) 'No fictitious stage inference'
}
Require ((ConvertTo-Json -InputObject $fixture -Depth 12 -Compress) -notmatch 'FAKEUSER|FAKEPASS|FAKEPATH|FAKEQUERY|FAKECOOKIE|FAKECLASS|Cookie:|https://fixture') 'No fake payload secrets exported'
$integrated=Get-Content "$ev/offline-1/integration-result.json" -Raw|ConvertFrom-Json
Require ($integrated.parentActualExit -eq 0 -and $integrated.workerActualExit -eq 0 -and $integrated.metadataAccepted -and $integrated.sourceAttempts -eq 0 -and $integrated.metadataPacket.summary.id -ceq '7692288554839313682' -and $integrated.preparePacket.result.decode -ceq 'PASS' -and $integrated.preparePacket.result.container -ceq 'MP4_ISO_BMFF' -and (SHA "$ev/offline-1/video.mp4") -ceq $integrated.preparePacket.result.sha256 -and (SHA "$ev/offline-1/fixture-input.mp4") -ceq $integrated.preparePacket.result.sha256) 'Full exact offline pipeline/SHA/exit0'
foreach($phase in @(@{dir='offline-1';exit=0;c=1;n=0},@{dir='sample-3';exit=20;c=2;n=2})){
 $rows=@(Get-Content "$ev/$($phase.dir)/native.jsonl"|ForEach-Object {$_|ConvertFrom-Json});$end=@($rows|Where-Object {$_.step -ceq 'end'})[0]
 Require ($end.actualExit -eq $phase.exit -and $end.ownResourcesLeft -eq 0 -and $end.removedContainers -eq $phase.c -and $end.removedNetworks -eq $phase.n -and @($rows|Where-Object {$_.timeout -eq $true}).Count -eq 0) 'Native FAIL/PASS and exact ownership cleanup'
}
$outer=Get-Content "$ev/outer-exits.json" -Raw|ConvertFrom-Json
Require ($outer.offlineOuterActualExit -eq 0 -and $outer.liveOuterActualExit -eq 20) 'Offline/source outer outcomes'
$rows=@(Get-Content "$ev/sample-3/native.jsonl"|ForEach-Object {$_|ConvertFrom-Json});$calls=@($rows|Where-Object {$_.step -ceq 'single-analyze-conditional-download'})
Require ($calls.Count -eq 1 -and $calls[0].actualExit -eq 20 -and -not $calls[0].timeout) 'Exactly one source trial'
$states=@($rows|Where-Object {$_.step -ceq 'inspect'}|ForEach-Object {@($_.stdout|ConvertFrom-Json)[0]}|Where-Object {$_.Name -ceq '/wed-snap-cobalt-resolver' -and $_.State.ExitCode -eq 20})
Require ($states.Count -ge 1 -and @($states|Where-Object {$_.State.OOMKilled -or $_.State.Running}).Count -eq 0) 'Actual container20/not OOM'
$guards=@(Get-ChildItem "$ev/sample-3/guard-*.json"|ForEach-Object {Get-Content $_.FullName -Raw|ConvertFrom-Json})
Require ($guards.Count -eq 2 -and ($guards.HostConfig.Memory|Measure-Object -Sum).Sum -eq 608MB) 'Actual608MiB'
foreach($g in $guards){Require ($g.HostConfig.ReadonlyRootfs -and -not $g.HostConfig.Privileged -and -not $g.HostConfig.CapAdd -and $g.HostConfig.CapDrop -contains 'ALL' -and $g.HostConfig.SecurityOpt -contains 'no-new-privileges:true' -and $g.HostConfig.MemorySwap -eq $g.HostConfig.Memory -and $g.HostConfig.IpcMode -ceq 'private' -and -not $g.HostConfig.PidMode -and @($g.HostConfig.SecurityOpt|Where-Object {$_ -like 'seccomp=*'}).Count -eq 0 -and @($g.HostConfig.PortBindings.PSObject.Properties).Count -eq 0) 'Actual security guards'}
$resolver=@($guards|Where-Object {$_.Config.User -ceq '1000:1000'})[0];$proxy=@($guards|Where-Object {$_.Config.User -ceq '65534:65534'})[0]
Require ($resolver.Image -ceq $image -and $resolver.HostConfig.Memory -eq 512MB -and $resolver.Config.Cmd[-1] -ceq '7692288554839313682' -and $resolver.Config.Env -contains 'MEDIA_PROXY=[url-redacted]' -and $proxy.Image -ceq 'sha256:8bc0a567955111ea3cfbab2dd3b14f40a602f2d10ac987e78eb465f9d48d7f10' -and $proxy.HostConfig.Memory -eq 96MB) 'Images/user/expectedID/proxy wiring unchanged'
$r=Get-Content "$ev/sample-3/candidate-result.json" -Raw|ConvertFrom-Json;$meta=$r.metadataPacket.summary;$fail=$r.preparePacket
Require ($r.stage -ceq 'prepare' -and $r.status -ceq 'FAIL' -and $r.file -ceq 'FAIL_DISCARDED' -and -not $r.metadataAccepted -and $r.parentActualExit -eq 20 -and $r.workerActualExit -eq -9 -and $r.workerSignal -eq 9 -and $r.runtimeHashGate -ceq 'PASS') 'No packet-only success'
Require ($r.metadataPacket.status -ceq 'PASS' -and $meta.id -ceq '7692288554839313682' -and $meta.bodyIdAndTypeVerifiedByCobalt -and $meta.duration -gt 0 -and $meta.duration -le 600 -and $meta.requestCount -eq 2 -and $r.metadataSeconds -lt 30 -and $meta.decodedBytes -le 16MB -and @($meta.requests|Where-Object {$_.status -ne 200 -or $_.decodedBytes -gt 8MB}).Count -eq 0) 'Fresh bodyID/bounded provisional metadata'
Require ($fail.status -ceq 'FAIL' -and $fail.exception -ceq 'UNKNOWN' -and $fail.error -ceq 'YTDLP_OR_FILE_FAILURE' -and $fail.requestCount -eq 1 -and $fail.decodedBytes -le 250MB -and $r.prepareSeconds -lt 180) 'Recorded bounded prepareFAIL'
$attempts=@($fail.requests|Where-Object {$_.phase -ceq 'prepare'})
Require ($attempts.Count -eq 1 -and $attempts[0].status -eq 200 -and $attempts[0].decodedBytes -eq 93936477 -and $attempts[0].sendDiagnostic.status -eq 200 -and $attempts[0].sendDiagnostic.code -ceq 'HTTP_RESPONSE') 'New actual HTTP200/body observation; not historical failure rewrite'
$fields=@('boundary','phase','code','classes','status','proxyConnect','originTLS','headerWait','seconds')
foreach($req in $fail.requests){
 $d=$req.sendDiagnostic
 Require ($req.url -ceq '[url-redacted]' -and $req.TLSverify -and -not $req.actualImpersonation -and $req.method -ceq 'GET' -and $d.boundary -ceq 'HTTPAdapter.send' -and $d.phase -ceq $req.phase -and $d.code -ceq 'HTTP_RESPONSE' -and $d.classes.Count -eq 0 -and $d.status -eq 200 -and $d.seconds -ge 0 -and $d.proxyConnect -ceq 'UNKNOWN' -and $d.originTLS -ceq 'UNKNOWN' -and $d.headerWait -ceq 'UNKNOWN' -and -not(Compare-Object ($fields|Sort-Object) @($d.PSObject.Properties.Name|Sort-Object))) 'Whitelisted safe observed diagnostic schema/no invented substages'
}
foreach($n in @('video.mp4','video.mp4.part','video.mp4.ytdl')){Require (-not(Test-Path "$ev/sample-3/$n")) 'No retained real file to review'}
Require ($r.visualAudioWatermark -ceq 'NOT_RUN') 'No false watermark/file acceptance'
$cause=Get-Content "$ev/cause.json" -Raw|ConvertFrom-Json
Require ($cause.overallStatus -ceq 'FAIL' -and -not $cause.fileExists -and $cause.fileSHA -ceq 'NOT_AVAILABLE' -and $cause.sourceReruns -eq 0 -and $cause.sendDiagnostic.status -eq 200 -and $cause.unmeasuredSubStages.postResponseOperation -ceq 'UNKNOWN') 'Cause evidence limits/stop'
Require (-not(Test-Path "$ev/sample-1") -and -not(Test-Path "$ev/sample-2")) 'No old sample rerun'
$exclude=@("$ev/manifest.json","$ev/manifest-sha256.txt")
function Paths{@(@(rg --files -uu $ev labs/tiktok/cobalt|ForEach-Object {$_.Replace('\','/')}|Where-Object {$_ -cnotin $exclude})+$docs+@('docs/TIKTOK_COBALT_SEND_DIAGNOSTICS_HANDOFF.md')|Sort-Object -Unique)}
if($Capture){
 Require (-not(Test-Path "$ev/manifest.json")) 'No manifest overwrite'
 [ordered]@{utc=[DateTime]::UtcNow.ToString('o');kind='Safe send diagnostics + one new source FAIL successor';predecessorManifest=$audit.predecessorManifest;predecessorManifestSHA=$audit.predecessorManifestSHA;changes=@(foreach($f in $allowed){@{path=$f;beforeSHA=$baseline[$f].sha256;afterSHA=(SHA $f)}})}|ConvertTo-Json -Depth 6|Set-Content "$ev/successor.json" -Encoding utf8
 [ordered]@{utc=[DateTime]::UtcNow.ToString('o');vn=[DateTime]::UtcNow.AddHours(7).ToString('yyyy-MM-dd HH:mm:ss.fff');baseline=$before.Count;preserved=$kept;exactChanges=$changed;offlineExit=0;sourceAnalyzes=1;metadataGET=2;prepareGET=1;mp4SendStatus=200;mp4InputBytes=93936477;sourceStatus='FAIL';sourceStage='prepare';workerExit=-9;parentExit=20;sourceOuterExit=20;fileProbeDecode='UNPROVEN_NO_RESULT';fileSHA='NOT_AVAILABLE';visualAudioWatermark='NOT_RUN';acceptedSourceSamples=2;cleanupLeft=0;builds=0;mainApply=$false}|ConvertTo-Json -Depth 6|Set-Content "$ev/completion.json" -Encoding utf8
 @(foreach($f in (Paths)){@{path=$f;bytes=(Get-Item -LiteralPath $f).Length;sha256=(SHA $f)}})|ConvertTo-Json -Depth 5|Set-Content "$ev/manifest.json" -Encoding utf8
 SHA "$ev/manifest.json"|Set-Content "$ev/manifest-sha256.txt" -Encoding ascii
}
$successor=Get-Content "$ev/successor.json" -Raw|ConvertFrom-Json
Require (-not(Compare-Object ($allowed|Sort-Object) (@($successor.changes.path)|Sort-Object))) 'Successor exact scope'
foreach($r in $successor.changes){Require ((SHA $r.path) -ceq $r.afterSHA -and $baseline[$r.path].sha256 -ceq $r.beforeSHA) 'Successor exact hashes'}
$m=@(Get-Content "$ev/manifest.json" -Raw|ConvertFrom-Json)
Require ((SHA "$ev/manifest.json") -ceq (Get-Content "$ev/manifest-sha256.txt" -Raw).Trim() -and @($m.path|Sort-Object -Unique).Count -eq $m.Count -and -not(Compare-Object (Paths) @($m.path|Sort-Object))) 'Manifest self/full distinct coverage'
foreach($r in $m){Require ((SHA $r.path) -ceq $r.sha256 -and (Get-Item -LiteralPath $r.path).Length -eq $r.bytes) 'Artifact hash/bytes'}
Write-Output "PASS evidence baseline=$($before.Count); preserved=$kept; scoped=$($changed.Count); artifacts=$($m.Count)/$($m.Count); pinned libraries/old raw/golden unchanged; diagnostics+full offline0; one source2+1GET HTTP200/input93936477 but prepareFAIL/parent20/worker-9; no accepted file; substagesUNKNOWN; accepted2/3; cleanup0"
