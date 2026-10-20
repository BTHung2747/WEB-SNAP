param([switch]$Capture)
$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
$root='D:\WED SNAP';$ev='docs/evidence/tiktok-cobalt-recheck-20261008';$old='docs/evidence/tiktok-cobalt-20261008'
. "$PSScriptRoot/hash_gate.ps1"
function SHA($f){(Get-FileHash -LiteralPath $f -Algorithm SHA256).Hash.ToLower()}
function Require($ok,$why){if(-not $ok){throw $why}}
$docs=@('docs/AUDIT_TIEN_DO.md','docs/PROGRESS.md','docs/ADAPTERS.md','docs/TEST_REPORT.md')
$glue=@('labs/tiktok/cobalt/run.ps1','labs/tiktok/cobalt/NOTICE.md','labs/tiktok/cobalt/src/transport.mjs',
 'labs/tiktok/cobalt/src/download.py','labs/tiktok/cobalt/src/supervise.py','labs/tiktok/cobalt/src/test.mjs','labs/tiktok/cobalt/src/test_all.py')
$allowed=$docs+$glue
$before=@(Get-Content "$ev/before-all.json" -Raw|ConvertFrom-Json);$kept=0;$changes=@()
foreach($r in $before){
 Require (Test-Path -LiteralPath $r.path) "Missing baseline path $($r.path)"
 if((SHA $r.path) -cne $r.sha256){Require ($r.path -cin $allowed) "Unscoped change $($r.path)";$changes+=$r.path}
 else{Require ((Get-Item -LiteralPath $r.path).Length -eq $r.bytes) 'Baseline size';$kept++}
}
Require (-not(Compare-Object ($allowed|Sort-Object) ($changes|Sort-Object))) 'Expected exact seven glue/four status-doc changes'
Require ((SHA "$old/manifest.json") -ceq '17472fcf1a8534c7abe1506d255a0026aa03a11ce3999a4891e40b0b8a6623d3') 'Old manifest changed'
$oldManifest=@(Get-Content "$old/manifest.json" -Raw|ConvertFrom-Json)
$priorAudit=@($oldManifest|Where-Object {$_.path -ceq 'docs/AUDIT_TIEN_DO.md'})[0]
$auditBefore=@($before|Where-Object {$_.path -ceq 'docs/AUDIT_TIEN_DO.md'})[0]
Require ((SHA "$ev/AUDIT-before.md") -ceq $auditBefore.sha256) 'Before audit snapshot changed'
foreach($r in $oldManifest){
 $b=@($before|Where-Object {$_.path -ceq $r.path})[0]
 Require ($null -ne $b) 'Missing predecessor baseline'
 if($r.path -cne 'docs/AUDIT_TIEN_DO.md'){Require ($b.sha256 -ceq $r.sha256 -and $b.bytes -eq $r.bytes) 'Pre-audit predecessor mismatch'}
 if($r.path -cnotin $allowed){Require ((SHA $r.path) -ceq $r.sha256 -and (Get-Item $r.path).Length -eq $r.bytes) 'Frozen predecessor changed'}
}
$receipt=Get-Content "$ev/offline-2/receipt.json" -Raw|ConvertFrom-Json
Assert-CobaltHashGate $receipt (CobaltHostHashes) 'sha256:5fcc01bb22ca5a264327f4bce4140b07c70d22b0a861ef41ff982d7d0fb3f3a6'
Require ((SHA "$ev/offline-2/native.jsonl") -ceq $receipt.nativeSHA -and (SHA "$ev/offline-2/runtime-inventory.json") -ceq $receipt.runtimeSHA) 'Offline receipt evidence'
Require ((SHA "$ev/sample-1/offline-runtime.json") -ceq $receipt.runtimeSHA -and (SHA "$ev/sample-1/runtime-inventory.json") -ceq $receipt.runtimeSHA) 'Actual live dependency/source mismatch'
$off=@(Get-Content "$ev/offline-2/native.jsonl"|ForEach-Object {$_|ConvertFrom-Json})
$live=@(Get-Content "$ev/sample-1/native.jsonl"|ForEach-Object {$_|ConvertFrom-Json})
Require (@($off|Where-Object {$_.step -eq 'offline-tests' -and $_.actualExit -eq 0 -and $_.stdout -match 'actual 8 MiB response' -and $_.stdout -match 'external 30s watchdog' -and $_.stdout -match '"actualExit": -9'}).Count -eq 1) 'Offline guards not passed'
foreach($logs in @(@{rows=$off;exit=0;containers=1;networks=0},@{rows=$live;exit=20;containers=2;networks=2})){
 $end=@($logs.rows|Where-Object {$_.step -eq 'end'})[-1]
 Require ($end.actualExit -eq $logs.exit -and $end.ownResourcesLeft -eq 0 -and $end.removedContainers -eq $logs.containers -and $end.removedNetworks -eq $logs.networks) 'Actual cleanup/outcome'
}
$attempts=@($live|Where-Object {$_.step -eq 'single-analyze-conditional-download'})
Require ($attempts.Count -eq 1 -and $attempts[0].actualExit -eq 20 -and -not $attempts[0].timeout) 'Exactly one source attempt'
$result=Get-Content "$ev/sample-1/result.json" -Raw|ConvertFrom-Json
Require ($result.runtimeHashGate -ceq 'PASS' -and $result.metadata -ceq 'FAIL' -and $result.file -ceq 'NOT_RUN' -and $result.error -ceq 'Error: COBALT_fetch.fail') 'Do not relabel source failure'
Require ($result.metadataNative.code -eq 20 -and -not $result.metadataNative.timed_out -and $result.metadataNative.seconds -lt 30) 'Metadata native deadline'
Require ($result.requests.Count -eq 1 -and $result.requests[0].status -eq 200 -and $result.totalDecodedBytes -eq 1462 -and -not $result.requests[0].markers.rehydration) 'Observed source limits/markers'
Require (-not(Test-Path "$ev/sample-2") -and -not(Test-Path "$ev/sample-3") -and -not(Test-Path "$ev/sample-1/media.mp4")) 'Stopped after first metadata failure'
# Logs must not contain URL literals; false tokens exist only in code fixtures, not outputs.
foreach($f in @((Get-ChildItem "$ev/offline-2","$ev/sample-1" -Recurse -File)|Where-Object {$_.Extension -in '.json','.jsonl','.yaml','.log'})){
 Require (-not((Get-Content -LiteralPath $f.FullName -Raw) -match '(?i)https?://|FAKEPATH|FAKEQUERY|FAKEPASS|FAKECOOKIE')) "URL/token leaked $($f.Name)"
}
$exclude=@("$ev/manifest.json","$ev/manifest-sha256.txt")
function Paths {@(@(rg --files -uu $ev labs/tiktok/cobalt|ForEach-Object {$_.Replace('\','/')}|Where-Object {$_ -cnotin $exclude})+$docs+@('docs/TIKTOK_COBALT_RECHECK_HANDOFF.md')|Sort-Object -Unique)}
if($Capture){
 Require (-not(Test-Path "$ev/manifest.json")) 'Refuse overwrite successor manifest'
 [ordered]@{oldManifestSHA=(SHA "$old/manifest.json");oldAuditSHA=$priorAudit.sha256;auditedBeforeSHA=$auditBefore.sha256;
  currentAuditSHA=(SHA 'docs/AUDIT_TIEN_DO.md');preAuditScope='Only AUDIT differed from old 87-artifact golden';
  replacements=@(foreach($f in $allowed){@{path=$f;beforeSHA=@($before|Where-Object {$_.path -ceq $f})[0].sha256;afterSHA=(SHA $f)}})}|ConvertTo-Json -Depth 6|Set-Content "$ev/successor.json" -Encoding utf8
 [ordered]@{utc=[DateTime]::UtcNow.ToString('o');vn=[DateTime]::UtcNow.AddHours(7).ToString('yyyy-MM-dd HH:mm:ss.fff');baselineFiles=$before.Count;
  exactPreserved=$kept;exactChanges=$changes;offline='PASS';liveMetadata='FAIL';sourceAttempts=1;nativeExit=20;
  metadataSeconds=$result.metadataNative.seconds;HTTPstatus=200;decodedBytes=1462;downloads=0;file='NOT_RUN';watermark='NOT_RUN';
  samples2and3='NOT_RUN';runtimeHashGate='PASS';cleanupLeft=0;mainApply=$false;builds=0;
  scope='Hash/redaction/caps fixture checks plus one fresh real metadata call; no file/visual acceptance'}|ConvertTo-Json -Depth 6|Set-Content "$ev/completion.json" -Encoding utf8
 @(foreach($f in (Paths)){@{path=$f;bytes=(Get-Item -LiteralPath $f).Length;sha256=(SHA $f)}})|ConvertTo-Json -Depth 5|Set-Content "$ev/manifest.json" -Encoding utf8
 SHA "$ev/manifest.json"|Set-Content "$ev/manifest-sha256.txt" -Encoding ascii
}
$successor=Get-Content "$ev/successor.json" -Raw|ConvertFrom-Json
Require ($successor.oldAuditSHA -ceq $priorAudit.sha256 -and $successor.auditedBeforeSHA -ceq $auditBefore.sha256 -and $successor.currentAuditSHA -ceq (SHA 'docs/AUDIT_TIEN_DO.md')) 'Audit chain'
Require (-not(Compare-Object ($allowed|Sort-Object) (@($successor.replacements.path)|Sort-Object))) 'Successor exact scope'
foreach($r in $successor.replacements){Require ((SHA $r.path) -ceq $r.afterSHA -and @($before|Where-Object {$_.path -ceq $r.path})[0].sha256 -ceq $r.beforeSHA) 'Successor SHA'}
$m=@(Get-Content "$ev/manifest.json" -Raw|ConvertFrom-Json)
Require ((SHA "$ev/manifest.json") -ceq (Get-Content "$ev/manifest-sha256.txt" -Raw).Trim()) 'Manifest self SHA'
Require (@($m.path|Sort-Object -Unique).Count -eq $m.Count -and -not(Compare-Object (Paths) @($m.path|Sort-Object))) 'Full distinct coverage'
foreach($r in $m){Require ((SHA $r.path) -ceq $r.sha256 -and (Get-Item -LiteralPath $r.path).Length -eq $r.bytes) "Artifact changed $($r.path)"}
Write-Output "PASS baseline=$($before.Count); preserved=$kept; exact replacements=$($changes.Count); artifacts=$($m.Count)/$($m.Count); offline caps/hash/redaction/watchdog PASS; real metadata FAIL/exit20/1462bytes; download0; cleanup0; old golden unchanged"
