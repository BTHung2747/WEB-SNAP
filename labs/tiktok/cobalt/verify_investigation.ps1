param([switch]$Capture)
$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
$root='D:\WED SNAP';$ev='docs/evidence/tiktok-cobalt-investigation-20261008';$prev='docs/evidence/tiktok-cobalt-recheck-20261008'
. "$PSScriptRoot/hash_gate.ps1"
function SHA($p){(Get-FileHash -LiteralPath $p).Hash.ToLower()}
function Require($ok,$why){if(-not $ok){throw $why}}
$docs=@('docs/PROGRESS.md','docs/AUDIT_TIEN_DO.md','docs/ADAPTERS.md','docs/TEST_REPORT.md')
$allowed=$docs+@('labs/tiktok/cobalt/run.ps1','labs/tiktok/cobalt/NOTICE.md','labs/tiktok/cobalt/src/transport.mjs','labs/tiktok/cobalt/src/test.mjs')
$before=@(Get-Content "$ev/before-all.json" -Raw|ConvertFrom-Json);$kept=0;$changed=@()
foreach($r in $before){
 Require (Test-Path -LiteralPath $r.path) "Missing preserved file $($r.path)"
 if((SHA $r.path) -cne $r.sha256){Require ($r.path -cin $allowed) "Unscoped change $($r.path)";$changed+=$r.path}
 else{Require ((Get-Item -LiteralPath $r.path).Length -eq $r.bytes) 'Preserved size';$kept++}
}
Require (-not(Compare-Object ($allowed|Sort-Object) ($changed|Sort-Object))) 'Exact four lab/four doc changes'
$audit=Get-Content "$ev/read-only-audit.json" -Raw|ConvertFrom-Json
Require ($audit.actualExit -eq 0 -and $audit.matchedArtifacts -eq 73 -and (SHA "$prev/manifest.json") -ceq $audit.previousManifestSHA) 'Read-only predecessor audit'
$pm=@(Get-Content "$prev/manifest.json" -Raw|ConvertFrom-Json)
$inherited=Get-Content "$ev/progress-predecessor-observation.json" -Raw|ConvertFrom-Json
Require ($inherited.actualExit -eq 1 -and $inherited.path -ceq 'docs/PROGRESS.md' -and
 $inherited.goldenSHA -ceq '18da0f606977fc2bf54525c2e69e0bba6097500314c3cef60f4c456c266b8c71' -and
 $inherited.baselineSHA -ceq '673067e6f608bc14b7842552e224510d6efa25070f6f37eace4252404d69518a') 'Exact inherited PROGRESS observation'
foreach($r in $pm){
 $b=@($before|Where-Object {$_.path -ceq $r.path})[0]
 if($r.path -ceq $inherited.path){
  Require ($b.sha256 -ceq $inherited.baselineSHA -and $b.bytes -eq $inherited.baselineBytes -and $r.sha256 -ceq $inherited.goldenSHA -and $r.bytes -eq $inherited.goldenBytes) 'Inherited PROGRESS exact chain'
 }else{Require ($b.sha256 -ceq $r.sha256 -and $b.bytes -eq $r.bytes) 'Predecessor snapshot mismatch'}
 if($r.path -cnotin $allowed){Require ((SHA $r.path) -ceq $r.sha256) 'Frozen predecessor altered'}
}
$receipt=Get-Content "$ev/offline-1/receipt.json" -Raw|ConvertFrom-Json
Assert-CobaltHashGate $receipt (CobaltHostHashes) 'sha256:5fcc01bb22ca5a264327f4bce4140b07c70d22b0a861ef41ff982d7d0fb3f3a6'
Require ((SHA "$ev/offline-1/native.jsonl") -ceq $receipt.nativeSHA -and (SHA "$ev/offline-1/runtime-inventory.json") -ceq $receipt.runtimeSHA) 'Offline evidence receipt'
Require ((SHA "$ev/sample-1/runtime-inventory.json") -ceq $receipt.runtimeSHA -and (SHA "$ev/sample-1/offline-runtime.json") -ceq $receipt.runtimeSHA) 'Live matches tested runtime'
$rt=Get-Content "$ev/sample-1/runtime-inventory.json" -Raw|ConvertFrom-Json
$prt=Get-Content "$prev/sample-1/runtime-inventory.json" -Raw|ConvertFrom-Json
Require ((ConvertTo-Json -InputObject $rt.dependencies -Depth 5 -Compress) -ceq (ConvertTo-Json -InputObject $prt.dependencies -Depth 5 -Compress)) 'Installed dependencies changed'
$off=@(Get-Content "$ev/offline-1/native.jsonl"|ForEach-Object {$_|ConvertFrom-Json})
$live=@(Get-Content "$ev/sample-1/native.jsonl"|ForEach-Object {$_|ConvertFrom-Json})
$tests=@($off|Where-Object {$_.step -eq 'offline-tests'})[0]
Require ($tests.actualExit -eq 0 -and $tests.stdout -match '"fixtures":9' -and $tests.stdout -match 'Brotli library decode preserves' -and $tests.stdout -match 'external 30s watchdog') 'Offline diagnostic/cap/watchdog checks'
foreach($phase in @(@{rows=$off;exit=0;c=1;n=0},@{rows=$live;exit=20;c=2;n=2})){
 $end=@($phase.rows|Where-Object {$_.step -eq 'end'})[0]
 Require ($end.actualExit -eq $phase.exit -and $end.ownResourcesLeft -eq 0 -and $end.removedContainers -eq $phase.c -and $end.removedNetworks -eq $phase.n) 'Actual exits/own cleanup'
}
$attempt=@($live|Where-Object {$_.step -eq 'single-analyze-conditional-download'})
Require ($attempt.Count -eq 1 -and $attempt[0].actualExit -eq 20 -and -not $attempt[0].timeout) 'One source attempt'
$r=Get-Content "$ev/sample-1/result.json" -Raw|ConvertFrom-Json
Require ($r.metadata -ceq 'FAIL' -and $r.runtimeHashGate -ceq 'PASS' -and $r.error -ceq 'Error: METADATA_DEADLINE' -and $r.file -ceq 'NOT_RUN') 'Correct source outcome'
Require ($r.metadataNative.code -eq 20 -and -not $r.metadataNative.timed_out -and $r.metadataNative.seconds -lt 30) 'Worker deadline'
Require ($r.requests.Count -eq 1 -and $r.requests[0].error -ceq 'METADATA_DEADLINE' -and $null -eq $r.requests[0].status -and $null -eq $r.requests[0].classification -and $r.totalDecodedBytes -eq 0) 'No manufactured headers/classification'
Require (-not(Test-Path "$ev/sample-2") -and -not(Test-Path "$ev/sample-3") -and -not(Test-Path "$ev/sample-1/media.mp4")) 'Stop after failure'
foreach($f in @((Get-ChildItem "$ev/offline-1","$ev/sample-1" -Recurse -File)|Where-Object {$_.Extension -in '.json','.jsonl','.yaml','.log'})){
 Require (-not((Get-Content -LiteralPath $f.FullName -Raw) -match '(?i)https?://|FAKEPATH|FAKEQUERY|FAKECOOKIE|FAKEHASH|FAKEDIGEST')) 'Sensitive URL/token in logs'
}
$exclude=@("$ev/manifest.json","$ev/manifest-sha256.txt")
function Paths{@(@(rg --files -uu $ev labs/tiktok/cobalt|ForEach-Object {$_.Replace('\','/')}|Where-Object {$_ -cnotin $exclude})+$docs+@('docs/TIKTOK_COBALT_INVESTIGATION_HANDOFF.md')|Sort-Object -Unique)}
if($Capture){
 Require (-not(Test-Path "$ev/manifest.json")) 'No manifest overwrite'
 @(foreach($f in $allowed){@{path=$f;beforeSHA=@($before|Where-Object {$_.path -ceq $f})[0].sha256;afterSHA=(SHA $f)}})|ConvertTo-Json -Depth 4|Set-Content "$ev/successor.json" -Encoding utf8
 @{utc=[DateTime]::UtcNow.ToString('o');vn=[DateTime]::UtcNow.AddHours(7).ToString('yyyy-MM-dd HH:mm:ss.fff');baseline=$before.Count;preserved=$kept;changes=$changed;
   offline='PASS';sourceAttempts=1;metadata='FAIL';actualExit=20;error='METADATA_DEADLINE';metadataSeconds=$r.metadataNative.seconds;
   observedDecodedBytes=0;HTTPstatus='NOT_OBSERVED';challengeClassification='NOT_RUN';original1462Cause='UNRESOLVED';
   downloads=0;watermark='NOT_RUN';cleanupLeft=0;mainApply=$false;builds=0;inheritedProgressDifference='Exact golden->baseline->current recorded separately; origin unknown';scope='Read-only audit, narrow diagnostic glue, offline fixtures, one failed source attempt'}|ConvertTo-Json -Depth 5|Set-Content "$ev/completion.json" -Encoding utf8
 @(foreach($f in (Paths)){@{path=$f;bytes=(Get-Item -LiteralPath $f).Length;sha256=(SHA $f)}})|ConvertTo-Json -Depth 5|Set-Content "$ev/manifest.json" -Encoding utf8
 SHA "$ev/manifest.json"|Set-Content "$ev/manifest-sha256.txt" -Encoding ascii
}
$successor=@(Get-Content "$ev/successor.json" -Raw|ConvertFrom-Json)
Require (-not(Compare-Object ($allowed|Sort-Object) (@($successor.path)|Sort-Object))) 'Successor scope'
foreach($r in $successor){Require ((SHA $r.path) -ceq $r.afterSHA -and @($before|Where-Object {$_.path -ceq $r.path})[0].sha256 -ceq $r.beforeSHA) 'Successor exact SHA'}
$m=@(Get-Content "$ev/manifest.json" -Raw|ConvertFrom-Json)
Require ((SHA "$ev/manifest.json") -ceq (Get-Content "$ev/manifest-sha256.txt" -Raw).Trim()) 'Manifest self SHA'
Require (@($m.path|Sort-Object -Unique).Count -eq $m.Count -and -not(Compare-Object (Paths) @($m.path|Sort-Object))) 'Full distinct coverage'
foreach($r in $m){Require ((SHA $r.path) -ceq $r.sha256 -and (Get-Item -LiteralPath $r.path).Length -eq $r.bytes) 'Artifact SHA/size'}
Write-Output "PASS baseline=$($before.Count); preserved=$kept; scoped changes=$($changed.Count); artifacts=$($m.Count)/$($m.Count); inherited PROGRESS exact successor1; exact offline/live hashes; deps unchanged; offline9+guards PASS; one source metadataFAIL/deadline/exit20; no response/classification/download; cleanup0; old evidence/golden unchanged"
