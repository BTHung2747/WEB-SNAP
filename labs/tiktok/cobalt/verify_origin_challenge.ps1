param([switch]$Capture)
$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
$root='D:\WED SNAP';$ev='docs/evidence/tiktok-cobalt-origin-challenge-20261008';$old='docs/evidence/tiktok-cobalt-stages-20261008'
. "$PSScriptRoot/hash_gate.ps1"
function SHA($p){(Get-FileHash -LiteralPath $p).Hash.ToLower()}
function Require($ok,$why){if(-not $ok){throw $why}}
$docs=@('docs/AUDIT_TIEN_DO.md','docs/PROGRESS.md')
$allowed=$docs+@('labs/tiktok/cobalt/run.ps1','labs/tiktok/cobalt/NOTICE.md','labs/tiktok/cobalt/src/stages.mjs','labs/tiktok/cobalt/src/transport.mjs','labs/tiktok/cobalt/src/test_all.py','labs/tiktok/cobalt/src/test_stages.mjs','labs/tiktok/cobalt/src/runtime_inventory.py')
$before=@(Get-Content "$ev/before-all.json" -Raw|ConvertFrom-Json);$kept=0;$changed=@()
foreach($r in $before){
 Require (Test-Path -LiteralPath $r.path) "Missing baseline $($r.path)"
 if((SHA $r.path) -cne $r.sha256){Require ($r.path -cin $allowed) "Unscoped change $($r.path)";$changed+=$r.path}
 else{Require ((Get-Item -LiteralPath $r.path).Length -eq $r.bytes) 'Baseline bytes';$kept++}
}
Require (-not(Compare-Object ($allowed|Sort-Object) ($changed|Sort-Object))) 'Exact seven lab/two docs'
$accepted=Get-Content "$ev/prior-audit-successor-copy.json" -Raw|ConvertFrom-Json
Require ((SHA "$ev/prior-audit-successor-copy.json") -ceq (SHA 'docs/evidence/tiktok-cobalt-stages-audit-20261008/successor.json') -and (SHA "$old/manifest.json") -ceq $accepted.predecessorManifestSHA) 'Frozen golden/provenance'
$mOld=@(Get-Content "$old/manifest.json" -Raw|ConvertFrom-Json)
foreach($r in $mOld){
 $b=@($before|Where-Object {$_.path -ceq $r.path})[0];$doc=@($accepted.changedDocs|Where-Object {$_.path -ceq $r.path})
 if($doc.Count){Require ($r.sha256 -ceq $doc[0].beforeSHA -and $b.sha256 -ceq $doc[0].afterSHA) 'Exact independent doc successor'}
 else{Require ($r.sha256 -ceq $b.sha256 -and $r.bytes -eq $b.bytes) 'Old baseline mismatch'}
 if($r.path -cnotin $allowed){Require ((SHA $r.path) -ceq $r.sha256) 'Frozen artifact changed'}
}
$receipt=Get-Content "$ev/offline-4/receipt.json" -Raw|ConvertFrom-Json
Assert-CobaltHashGate $receipt (CobaltHostHashes) 'sha256:5fcc01bb22ca5a264327f4bce4140b07c70d22b0a861ef41ff982d7d0fb3f3a6'
Require ((SHA "$ev/offline-4/native.jsonl") -ceq $receipt.nativeSHA -and (SHA "$ev/offline-4/runtime-inventory.json") -ceq $receipt.runtimeSHA) 'Final offline receipt'
$runtime=Get-Content "$ev/offline-4/runtime-inventory.json" -Raw|ConvertFrom-Json
$prior=Get-Content "$old/offline-2/runtime-inventory.json" -Raw|ConvertFrom-Json
foreach($p in $prior.dependencies){
 $current=@($runtime.dependencies|Where-Object {$_.path -ceq $p.path})
 Require ($current.Count -eq 1 -and $current[0].sha256 -ceq $p.sha256 -and $current[0].bytes -eq $p.bytes) 'Old installed dependency changed'
}
foreach($attempt in 1..4){
 $rows=@(Get-Content "$ev/offline-$attempt/native.jsonl"|ForEach-Object {$_|ConvertFrom-Json});$end=@($rows|Where-Object {$_.step -eq 'end'})[0]
 Require ($end.actualExit -eq 0 -and $end.ownResourcesLeft -eq 0 -and $end.removedContainers -eq 1 -and $end.removedNetworks -eq 0) 'Actual cleanup/offline exit'
 Require (@($rows|Where-Object {$_.step -eq 'single-analyze-conditional-download' -or $_.step -eq 'create-lab'}).Count -eq 0) 'No source/egress start'
}
$origins=Get-Content "$ev/offline-4/origin-fixtures.json" -Raw|ConvertFrom-Json
Require ($origins.results.Count -eq 3) 'Three origin cases'
$redirect=$origins.results[0].requests;$reuse=$origins.results[1].requests;$failure=$origins.results[2].requests
Require ($redirect[0].originId -cne $redirect[1].originId -and $redirect[0].connectionId -cne $redirect[1].connectionId -and -not $redirect[1].connectionReused) 'Cross-origin isolation'
Require ($reuse[0].connectionId -ceq $reuse[1].connectionId -and $reuse[1].connectionReused -and $reuse[1].originTLSReady) 'Verified reuse'
Require (-not $failure[1].originTLSReady -and $failure[1].failureStage -ceq 'WAITING_ORIGIN_TLS' -and $null -eq $failure[2].failureStage -and $failure[2].connectionId -ceq $failure[0].connectionId -and $failure[2].connectionReused) 'No inherited TLS/failure'
$candidate=Get-Content "$ev/offline-4/candidate-fixtures.json" -Raw|ConvertFrom-Json
Require ($candidate.sourceAttempts -eq 0 -and $candidate.fileDownloads -eq 0 -and $candidate.results.Count -eq 14) 'Offline candidate only'
$native=$candidate.results[0]
Require ($native.requests -eq 2 -and $native.nativeCookieGenerated -and $native.nativeCookieCleared -and $native.playSelected -and -not $native.cookieFile -and $native.file -ceq 'NOT_RUN') 'Real native extractor fixture'
foreach($name in @('wrong-id','redirect','download-only','request-cap-before-send','actual-eight-MiB-Brotli-cap','actual-sixteen-MiB-aggregate-cap','default-source-disabled','parent-CPU-starvation-deadline','parent-prepare-deadline')){
 Require (@($candidate.results|Where-Object {$_.case -ceq $name}).Count -eq 1) "Missing $name check"
}
$logs=@(Get-Content "$ev/offline-4/native.jsonl"|ForEach-Object {$_|ConvertFrom-Json})
$test=@($logs|Where-Object {$_.step -eq 'offline-tests'})[0]
Require ($test.stdout -match 'external 30s watchdog' -and $test.stdout -match 'wrong-id' -and $test.actualExit -eq 0) 'Final check coverage'
$outcome=Get-Content "$ev/outcome.json" -Raw|ConvertFrom-Json
Require ($outcome.realSourceAttempts -eq 0 -and $outcome.fileDownloads -eq 0 -and $outcome.finalAttempt -eq 4 -and $outcome.runtimeSHA -ceq $receipt.runtimeSHA) 'Do not claim real metadata/file'
Require (-not(Test-Path "$ev/sample-1") -and -not(Test-Path "$ev/sample-2") -and -not(Test-Path "$ev/sample-3")) 'No live source evidence'
foreach($f in @((Get-ChildItem "$ev/offline-4" -Recurse -File)|Where-Object {$_.Extension -in '.json','.jsonl','.yaml','.log'})){
 Require (-not((Get-Content -LiteralPath $f.FullName -Raw) -match '(?i)https?://|FAKEPATH|FAKEQUERY|FAKESESSION|fixture_challenge=')) 'URL/token in execution logs'
}
$exclude=@("$ev/manifest.json","$ev/manifest-sha256.txt")
function Paths{@(@(rg --files -uu $ev labs/tiktok/cobalt|ForEach-Object {$_.Replace('\','/')}|Where-Object {$_ -cnotin $exclude})+$docs+@('docs/TIKTOK_COBALT_ORIGIN_CHALLENGE_HANDOFF.md')|Sort-Object -Unique)}
if($Capture){
 Require (-not(Test-Path "$ev/manifest.json")) 'No manifest overwrite'
 @(foreach($f in $allowed){@{path=$f;beforeSHA=@($before|Where-Object {$_.path -ceq $f})[0].sha256;afterSHA=(SHA $f)}})|ConvertTo-Json -Depth 4|Set-Content "$ev/successor.json" -Encoding utf8
 @{utc=[DateTime]::UtcNow.ToString('o');vn=[DateTime]::UtcNow.AddHours(7).ToString('yyyy-MM-dd HH:mm:ss.fff');baseline=$before.Count;preserved=$kept;exactChanges=$changed;
  finding='F-STAGE-ORIGIN_CLOSED_OFFLINE';candidate='IMPLEMENTED_OFFLINE_HIGH_API';nativeSolverFixture='PASS_NOT_REAL_SOURCE';sourceAttempts=0;downloads=0;metadata='NOT_RUN';file='NOT_RUN';watermark='NOT_RUN';offlineAttempts=4;cleanupLeft=0;builds=0;mainApply=$false;
  sourcePlan='One future analyze <=2 metadata GET + conditional one MP4 GET; no redirect;30/180s;8/16MiB metadata;250/200MiB prepare; source task not authorized now'}|ConvertTo-Json -Depth 5|Set-Content "$ev/completion.json" -Encoding utf8
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
Write-Output "PASS baseline=$($before.Count); preserved=$kept; exact changes=$($changed.Count); artifacts=$($m.Count)/$($m.Count); F-STAGE-ORIGIN offline closed; native yt-dlp high API fixture14PASS; caps/hash/cookie/deadlines; source0/file0; cleanup0; old evidence/golden unchanged"
