param([switch]$Capture)
$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
$root='D:\WED SNAP';$ev='docs/evidence/tiktok-cobalt-stages-20261008';$old='docs/evidence/tiktok-cobalt-investigation-20261008'
. "$PSScriptRoot/hash_gate.ps1"
function SHA($p){(Get-FileHash -LiteralPath $p).Hash.ToLower()}
function Require($ok,$why){if(-not $ok){throw $why}}
$docs=@('docs/AUDIT_TIEN_DO.md','docs/PROGRESS.md')
$allowed=$docs+@('labs/tiktok/cobalt/run.ps1','labs/tiktok/cobalt/NOTICE.md','labs/tiktok/cobalt/src/transport.mjs','labs/tiktok/cobalt/src/main.mjs','labs/tiktok/cobalt/src/test_all.py')
$before=@(Get-Content "$ev/before-all.json" -Raw|ConvertFrom-Json);$kept=0;$changed=@()
foreach($r in $before){
 Require (Test-Path -LiteralPath $r.path) "Missing baseline $($r.path)"
 if((SHA $r.path) -cne $r.sha256){Require ($r.path -cin $allowed) "Unscoped change $($r.path)";$changed+=$r.path}
 else{Require ((Get-Item -LiteralPath $r.path).Length -eq $r.bytes) 'Baseline bytes';$kept++}
}
Require (-not(Compare-Object ($allowed|Sort-Object) ($changed|Sort-Object))) 'Exact five lab/two doc changes'
$accepted=Get-Content "$ev/accepted-audit-successor-copy.json" -Raw|ConvertFrom-Json
Require ((SHA "$ev/accepted-audit-successor-copy.json") -ceq (SHA 'docs/evidence/tiktok-cobalt-acceptance-audit-20261008/successor.json')) 'Accepted audit provenance'
Require ((SHA "$old/manifest.json") -ceq $accepted.predecessorManifestSHA -and $accepted.changedPath -ceq 'docs/AUDIT_TIEN_DO.md') 'Old golden'
$mOld=@(Get-Content "$old/manifest.json" -Raw|ConvertFrom-Json)
foreach($r in $mOld){
 $b=@($before|Where-Object {$_.path -ceq $r.path})[0]
 if($r.path -ceq $accepted.changedPath){Require ($r.sha256 -ceq $accepted.beforeSHA -and $b.sha256 -ceq $accepted.afterSHA) 'Exact old AUDIT accepted successor'}
 else{Require ($r.sha256 -ceq $b.sha256 -and $r.bytes -eq $b.bytes) 'Old artifact baseline mismatch'}
 if($r.path -cnotin $allowed){Require ((SHA $r.path) -ceq $r.sha256) 'Frozen predecessor changed'}
}
$receipt=Get-Content "$ev/offline-2/receipt.json" -Raw|ConvertFrom-Json
Assert-CobaltHashGate $receipt (CobaltHostHashes) 'sha256:5fcc01bb22ca5a264327f4bce4140b07c70d22b0a861ef41ff982d7d0fb3f3a6'
Require ((SHA "$ev/offline-2/native.jsonl") -ceq $receipt.nativeSHA -and (SHA "$ev/offline-2/runtime-inventory.json") -ceq $receipt.runtimeSHA) 'Tested receipt'
Require ((SHA "$ev/sample-1/runtime-inventory.json") -ceq $receipt.runtimeSHA -and (SHA "$ev/sample-1/offline-runtime.json") -ceq $receipt.runtimeSHA) 'Exact tested/live runtime'
$rt=Get-Content "$ev/sample-1/runtime-inventory.json" -Raw|ConvertFrom-Json
$prior=Get-Content "$old/sample-1/runtime-inventory.json" -Raw|ConvertFrom-Json
Require ((ConvertTo-Json -InputObject $rt.dependencies -Depth 5 -Compress) -ceq (ConvertTo-Json -InputObject $prior.dependencies -Depth 5 -Compress)) 'Installed deps unchanged'
foreach($phase in @(@{dir='offline-1';exit=0;c=1;n=0},@{dir='offline-2';exit=0;c=1;n=0},@{dir='sample-1';exit=20;c=2;n=2})){
 $rows=@(Get-Content "$ev/$($phase.dir)/native.jsonl"|ForEach-Object {$_|ConvertFrom-Json});$end=@($rows|Where-Object {$_.step -eq 'end'})[0]
 Require ($end.actualExit -eq $phase.exit -and $end.ownResourcesLeft -eq 0 -and $end.removedContainers -eq $phase.c -and $end.removedNetworks -eq $phase.n) 'Actual exit/own cleanup'
 if($phase.dir -like 'offline-*'){
  $test=@($rows|Where-Object {$_.step -eq 'offline-tests'})[0]
  Require ($test.actualExit -eq 0 -and $test.stdout -match 'observer cap128' -and $test.stdout -match 'external 30s watchdog') 'Offline observer/guards'
 }
}
$fixture=Get-Content "$ev/offline-2/stage-fixtures.json" -Raw|ConvertFrom-Json
Require ($fixture.results.Count -eq 5 -and (@($fixture.results.measuredStage)-join '|') -ceq 'WAITING_PROXY_CONNECT_RESPONSE|WAITING_ORIGIN_TLS|WAITING_RESPONSE_HEADERS|READING_BODY|COMPLETE') 'Five discriminating fake cases'
$live=@(Get-Content "$ev/sample-1/native.jsonl"|ForEach-Object {$_|ConvertFrom-Json})
$calls=@($live|Where-Object {$_.step -eq 'single-analyze-conditional-download'})
Require ($calls.Count -eq 1 -and $calls[0].actualExit -eq 20 -and -not $calls[0].timeout) 'One actual source attempt'
$r=Get-Content "$ev/sample-1/result.json" -Raw|ConvertFrom-Json
Require ($r.runtimeHashGate -ceq 'PASS' -and $r.metadata -ceq 'FAIL' -and $r.file -ceq 'NOT_RUN' -and $r.error -ceq 'Error: COBALT_fetch.fail') 'Real source failure'
Require ($r.metadataNative.code -eq 20 -and $r.metadataNative.seconds -lt 30 -and -not $r.metadataNative.timed_out -and $r.requests.Count -eq 1 -and $r.requests[0].status -eq 200 -and $r.totalDecodedBytes -eq 1462) 'Actual source deadline/bytes/status'
$trace=$r.transportStages
Require ($trace.awaitedStage -ceq 'COMPLETE' -and $trace.proxyTCPReady -and $trace.tunnelStatus -eq 200 -and $trace.originTLSReady -and $trace.originSent -and $trace.originHeaders -and $trace.bodyReaderStarted -and $trace.bodyComplete -and -not $trace.observerFault -and $trace.dropped -eq 0 -and $trace.events.Count -le 128) 'Observed transport stage'
Require ((ConvertTo-Json -InputObject $trace -Depth 7 -Compress) -ceq (ConvertTo-Json -InputObject (Get-Content "$ev/sample-1/transport-progress.json" -Raw|ConvertFrom-Json) -Depth 7 -Compress)) 'Persisted sanitized trace matches final'
$classification=$r.requests[0].classification
Require ($classification.csElement -and $classification.wciElement -and $classification.challengeDataJSON -and $classification.challengeDigestFields -and $classification.pleaseWaitText -and -not $classification.rehydrationElement -and -not $r.requests[0].markers.rehydration) 'Measured new challenge shape only'
foreach($e in $trace.events){Require (@($e.PSObject.Properties.Name|Where-Object {$_ -cnotin @('event','ms','role','status','encrypted','authorized','code','bytes')}).Count -eq 0) 'Diagnostic whitelist'}
Require (-not(Test-Path "$ev/sample-2") -and -not(Test-Path "$ev/sample-3") -and -not(Test-Path "$ev/sample-1/media.mp4")) 'Stop without download/other samples'
foreach($f in @((Get-ChildItem "$ev/offline-1","$ev/offline-2","$ev/sample-1" -Recurse -File)|Where-Object {$_.Extension -in '.json','.jsonl','.yaml','.log'})){
 Require (-not((Get-Content -LiteralPath $f.FullName -Raw) -match '(?i)https?://|FAKEPATH|FAKEQUERY|FAKECOOKIE|FAKEAUTH|FAKEBODY')) 'Source URL/token leak'
}
$exclude=@("$ev/manifest.json","$ev/manifest-sha256.txt")
function Paths{@(@(rg --files -uu $ev labs/tiktok/cobalt|ForEach-Object {$_.Replace('\','/')}|Where-Object {$_ -cnotin $exclude})+$docs+@('docs/TIKTOK_COBALT_STAGES_HANDOFF.md')|Sort-Object -Unique)}
if($Capture){
 Require (-not(Test-Path "$ev/manifest.json")) 'No manifest overwrite'
 @(foreach($f in $allowed){@{path=$f;beforeSHA=@($before|Where-Object {$_.path -ceq $f})[0].sha256;afterSHA=(SHA $f)}})|ConvertTo-Json -Depth 4|Set-Content "$ev/successor.json" -Encoding utf8
 @{utc=[DateTime]::UtcNow.ToString('o');vn=[DateTime]::UtcNow.AddHours(7).ToString('yyyy-MM-dd HH:mm:ss.fff');baseline=$before.Count;preserved=$kept;exactChanges=$changed;
  offline1=0;offline2=0;sourceAttempts=1;metadata='FAIL';actualExit=20;HTTPstatus=200;decodedBytes=1462;transport='COMPLETE';newResponse='JS_CHALLENGE_SHAPE';
  old28sStage='UNKNOWN_NOT_REPRODUCED';old1462BodyIdentity='UNPROVEN';downloads=0;watermark='NOT_RUN';cleanupLeft=0;builds=0;mainApply=$false;
  scope='Official diagnostic API plus discriminating offline delays and one observed real metadata failure; no TikTok acceptance'}|ConvertTo-Json -Depth 5|Set-Content "$ev/completion.json" -Encoding utf8
 @(foreach($f in (Paths)){@{path=$f;bytes=(Get-Item -LiteralPath $f).Length;sha256=(SHA $f)}})|ConvertTo-Json -Depth 5|Set-Content "$ev/manifest.json" -Encoding utf8
 SHA "$ev/manifest.json"|Set-Content "$ev/manifest-sha256.txt" -Encoding ascii
}
$successor=@(Get-Content "$ev/successor.json" -Raw|ConvertFrom-Json)
Require (-not(Compare-Object ($allowed|Sort-Object) (@($successor.path)|Sort-Object))) 'Exact successor scope'
foreach($r in $successor){Require ((SHA $r.path) -ceq $r.afterSHA -and @($before|Where-Object {$_.path -ceq $r.path})[0].sha256 -ceq $r.beforeSHA) 'Successor exact SHA'}
$m=@(Get-Content "$ev/manifest.json" -Raw|ConvertFrom-Json)
Require ((SHA "$ev/manifest.json") -ceq (Get-Content "$ev/manifest-sha256.txt" -Raw).Trim()) 'Manifest self SHA'
Require (@($m.path|Sort-Object -Unique).Count -eq $m.Count -and -not(Compare-Object (Paths) @($m.path|Sort-Object))) 'Full distinct coverage'
foreach($r in $m){Require ((SHA $r.path) -ceq $r.sha256 -and (Get-Item -LiteralPath $r.path).Length -eq $r.bytes) 'Artifact SHA/bytes'}
Write-Output "PASS baseline=$($before.Count); preserved=$kept; exact changes=$($changed.Count); artifacts=$($m.Count)/$($m.Count); offline stages/caps/hash PASS; one source transport COMPLETE/metadata FAIL/JS challenge/exit20; old timeout unknown; downloads0; cleanup0; prior raw/golden untouched"
