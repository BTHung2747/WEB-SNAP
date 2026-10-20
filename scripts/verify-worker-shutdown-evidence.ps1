param([switch]$CaptureSnapshot)
$ErrorActionPreference='Stop'
if((Get-Location).Path -ne 'D:\WED SNAP'){throw 'Native repository required'}
$stem36='docs/evidence/p36-20261004'
function Hash36([string]$p36){(Get-FileHash -LiteralPath $p36).Hash.ToLowerInvariant()}
function Need36($v36,[string]$message36){if(-not $v36){throw $message36}}
function Raw36([string]$p36){@(Get-Content -LiteralPath $p36|Where-Object{$_.StartsWith('P36_RAW ')}|ForEach-Object{$_.Substring(8)|ConvertFrom-Json})}
function NewJson36([string]$p36,$v36){Need36 (-not(Test-Path -LiteralPath $p36)) ('Never overwrite '+$p36);$v36|ConvertTo-Json -Depth 30|Set-Content -Encoding utf8 -LiteralPath $p36}
$allowed36=@('README.md','docs/RUNBOOK.md','docs/PROGRESS.md','docs/TEST_REPORT.md','docs/AUDIT_TIEN_DO.md','docs/API.md')
$before36=Get-Content "$stem36-before.json" -Raw|ConvertFrom-Json
Need36 (($allowed36 -join '|') -eq ($before36.allowedDocs -join '|')) 'Exact6 docs only'
Need36 (@($before36.inventory.path|Sort-Object -Unique).Count -eq $before36.inventory.Count) 'Distinct before inventory'
$fix36=Get-Content "$stem36-fix.json" -Raw|ConvertFrom-Json
$initialMain36=@($before36.inventory|Where-Object path -eq 'apps/worker/src/main.ts')[0]
Need36 ($fix36.baselineProductionFailure -and $fix36.beforeSHA -eq $initialMain36.sha -and $fix36.beforeSHA -eq (Hash36 "$stem36-source-before/apps/worker/src/main.ts") -and $fix36.afterSHA -eq (Hash36 'apps/worker/src/main.ts') -and $fix36.baselineRawSHA -eq (Hash36 "$stem36-baseline.log")) 'Only conditional exact main successor backed by baseline raw'
$protected36=0
foreach($p36 in $before36.inventory){if($allowed36 -contains $p36.path -or $p36.path -eq 'apps/worker/src/main.ts'){continue};Need36 ((Hash36 $p36.path) -eq $p36.sha) ('Protected source/history '+$p36.path);$protected36++}
$m34=Get-Content docs/evidence/p34-20261004-manifest-verified.json -Raw|ConvertFrom-Json
$m35=Get-Content docs/evidence/p35-20261004-manifest-final.json -Raw|ConvertFrom-Json
$s35=Get-Content docs/evidence/p35-20261004-completion-supplement.json -Raw|ConvertFrom-Json
Need36 ($m34.artifacts.Count -eq 64 -and $m34.currentCode.Count -eq 4 -and $m35.artifacts.Count -eq 61 -and $s35.artifacts.Count -eq 65) 'Accepted scoped histories34/35 counts'
foreach($p36 in @($m34.artifacts)+@($m34.currentCode)+@($m35.artifacts)+@($s35.artifacts)){Need36 ((Hash36 $p36.path) -eq $p36.sha) ('Frozen accepted34/35 '+$p36.path)}
Need36 ((Hash36 'compose.yaml') -eq 'fe92fa79a4db42f47c0a81f3ac380a283a7bb695cc4ed3add5788fa4900e5829') 'Accepted33 Compose unchanged'
$preOriginal36=Get-Content "$stem36-matrix-before.json" -Raw|ConvertFrom-Json
$preV236=Get-Content "$stem36-matrix-pool-v2-before.json" -Raw|ConvertFrom-Json
$pre36=Get-Content "$stem36-matrix-v4-before.json" -Raw|ConvertFrom-Json
Need36 ($preV236.expectedSHA -eq $preOriginal36.expectedSHA -and (Hash36 "$stem36-observer-v2-test.ts") -eq $preV236.testSHA) 'V2 observer-only trial preserved'
Need36 ($pre36.expectedSHA -eq $preOriginal36.expectedSHA -and (Hash36 "$stem36-tests-before/tests/p36/shutdown.ts") -eq $preOriginal36.testSHA -and (Hash36 "$stem36-pool-v1-source/tests/p36/shutdown.ts") -eq $preOriginal36.testSHA) 'V1 frozen/test copies preserved; expected unchanged after observer-only correction'
Need36 ((Hash36 'tests/p36/expected.json') -eq $pre36.expectedSHA -and (Hash36 'tests/p36/shutdown.ts') -eq $pre36.testSHA) 'Expected/test same before baseline-final'
$expected36=Get-Content tests/p36/expected.json -Raw|ConvertFrom-Json
$baseRaw36=Raw36 "$stem36-baseline-v4.log";$baseSum36=@($baseRaw36|Where-Object stage -eq summary)[0]
Need36 ($baseSum36.uniqueControls -eq 11 -and $baseSum36.pass -eq 9 -and $baseSum36.fail -eq 2 -and $baseSum36.notRun -eq 0) 'Real baseline9PASS2FAIL retained'
$baseTail36=@($baseRaw36|Where-Object stage -eq tail-latch-result)[0]
Need36 (-not $baseTail36.tailObserved -and $baseTail36.childExit.code -eq 0 -and $baseTail36.sessions.Count -eq 2 -and $baseTail36.eligibleIds.Count -eq 1) 'Baseline early exit skipped tail witness, not isolation failure'
Need36 ((Get-Content "$stem36-baseline-v4.log" -Raw).Contains('P36_NATIVE_COMPLETION exit=1')) 'Actual corrected baseline native exit1'
$v1Raw36=Raw36 "$stem36-final.log";$v1Sum36=@($v1Raw36|Where-Object stage -eq summary)[0]
Need36 ($v1Sum36.pass -eq 8 -and $v1Sum36.fail -eq 3 -and @($v1Raw36|Where-Object stage -eq 'tail-witness-before-exit').Count -eq 1) 'V1 post-fix observer FAIL retained, tail runtime passed'
$raw36=Raw36 "$stem36-final-v4.log";$summary36=@($raw36|Where-Object stage -eq summary)[0]
Need36 ($summary36.uniqueControls -eq 11 -and $summary36.pass -eq 11 -and $summary36.fail -eq 0 -and $summary36.notRun -eq 0 -and $summary36.parentSweepCalls -eq 0 -and $summary36.http -eq 0) 'Actual11PASS no parent sweep/HTTP'
Need36 (($summary36.results.name -join '|') -eq ($expected36.cases -join '|')) 'Independent expected case names/order'
foreach($r36 in @($baseRaw36,$raw36)){
 $p36=@($r36|Where-Object stage -eq preflight)[0]
 Need36 ($p36.expectedSHA -eq $pre36.expectedSHA -and $p36.testSHA -eq $pre36.testSHA -and $p36.effectiveSeconds -eq 2 -and $p36.sourceDefaultSeconds -eq 30 -and $p36.redisDb -eq 9) 'Same actual paths/fixture effective2/default30/Redis9'
}
$finalPre36=@($raw36|Where-Object stage -eq preflight)[0]
Need36 ($finalPre36.hashes.'apps/worker/src/main.ts' -eq $fix36.afterSHA) 'Exact fixed main executed in ownlab'
$signal36=@($raw36|Where-Object{$_.stage -eq 'signal' -and $_.childLabel -eq 'inflight'})[0]
$release36=@($raw36|Where-Object stage -eq all-latches-released)[0]
$hold36=@($raw36|Where-Object stage -eq sigterm-held-sample)
Need36 ($signal36.signal -eq 'SIGTERM' -and $signal36.guarded -and $hold36.Count -ge 2 -and $release36.elapsedSinceSignalMs -le 1000 -and $release36.elapsedSinceSignalMs -ge 250) 'Actual TERM before locks released bounded'
foreach($sample36 in $hold36){Need36 (-not $sample36.childExited -and @($sample36.pg|Where-Object{$_.query -match 'DELETE.*AuditLog' -and $_.blockers -contains $sample36.blocker}).Count -eq 1) 'Child live/own blocked query after TERM'}
$heldResult36=@($raw36|Where-Object{$_.stage -eq 'case' -and $_.name -eq $expected36.cases[3]})[0]
Need36 ($heldResult36.evidence.heldMs -ge 250) 'Actual held observation >=250'
$phases36=@($raw36|Where-Object stage -eq db-phase)
Need36 ($phases36.Count -eq 2 -and $phases36[0].deletedIds.Count -eq 500 -and $phases36[0].eligibleIds.Count -eq 501 -and -not $phases36[0].workerReady -and $phases36[1].deletedIds.Count -eq 500 -and $phases36[1].eligibleIds.Count -eq 1 -and $phases36[1].workerReady -and -not $phases36[1].childAlreadyExited) 'Startup precondition/current periodic500 before exit'
foreach($p36 in $phases36){Need36 (($p36.deletedIds -join '|') -eq ($p36.wantedDeletedIds -join '|')) 'Actual deterministic deleted IDs'}
$tail36=@($raw36|Where-Object stage -eq tail-witness-before-exit)[0]
$exits36=@($raw36|Where-Object stage -eq child-exit)
$inflightExit36=@($exits36|Where-Object childLabel -eq inflight)[0]
Need36 ($tail36.snapshot.Count -eq 1 -and $tail36.snapshot[0].id -eq $tail36.freshId -and -not $tail36.childExit -and $tail36.actualLiveIdentity.pid -eq $signal36.identity.pid -and $tail36.actualLiveIdentity.startTicks -eq $signal36.identity.startTicks -and $tail36.actualLiveIdentity.state -in @('R','S','D') -and $tail36.monoMs -lt $inflightExit36.at) 'Tail commit readback actual OS child alive before exit'
Need36 ($exits36.Count -eq 2 -and @($exits36|Where-Object{$_.code -ne 0 -or $null -ne $_.signal}).Count -eq 0 -and $inflightExit36.at -ge $release36.allReleasedAt -and ($inflightExit36.at-$release36.allReleasedAt) -le 5000) 'Two actual child exits0, bounded inflight release-to-exit'
$closed36=@($raw36|Where-Object stage -eq closed-readback)
Need36 ($closed36.Count -eq 2 -and @($closed36|Where-Object{$_.pgChildConnections -ne 0 -or $_.workerConsumers -ne 0}).Count -eq 0) 'Both child connections closed'
$post36=@($raw36|Where-Object stage -eq postexit-nochange)[0]
Need36 ($post36.observedMs -ge 4000 -and $post36.eligibleIds.Count -eq 1 -and $post36.eligibleIds[0] -eq '00000000-0000-4000-8000-000000001000') 'No new timer deletion >=2fixtureintervals, ID1000 retained'
$clean36=@($raw36|Where-Object stage -eq cleanup)[0]
Need36 ($clean36.modelsEmpty -and $clean36.keysEmpty -and $clean36.childExited -and $clean36.locksReleased -and $clean36.chargedPreservedUntilCleanup -eq 37 -and $clean36.mediaResolvedEmptyNonrecursiveRmdir) 'Own cleanup before guarded Stop'
foreach($pair36 in @(@('start-baseline','Start'),@('stop-baseline','Stop'),@('start-final','Start'),@('stop-pool-v1','Stop'),@('start-baseline-v2','Start'),@('stop-baseline-v2','Stop'),@('start-baseline-v3','Start'),@('stop-baseline-v3','Stop'),@('start-final-v3','Start'),@('stop-final-v3','Stop'),@('start-baseline-v4','Start'),@('stop-baseline-v4','Stop'),@('start-final-v4','Start'),@('final-v4','Matrix'),@('typecheck','Typecheck'),@('stop-final','Stop'))){Need36 ((Get-Content "$stem36-$($pair36[0]).log" -Raw).Contains('P36_COMMAND_EXIT 0 '+$pair36[1]+' UTC')) 'Actual command completion exit0'}
$report36=[pscustomobject]@{utc=[DateTime]::UtcNow.ToString('o');vn=[DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(7)).ToString('o');beforeDistinct=$before36.inventory.Count;protectedOutside6DocsAndExactMain=$protected36;exactMainSHA=$fix36.afterSHA;baseline=@{pass=9;fail=2;notRun=0;exit=1};final=@{pass=11;fail=0;notRun=0;exit=0;http=0;parentSweepCalls=0};fixtureSeconds=2;defaultSeconds=30;heldMs=$heldResult36.evidence.heldMs;releaseAllMs=$release36.elapsedSinceSignalMs;shutdownAfterReleaseMs=$inflightExit36.at-$release36.allReleasedAt;postExitMs=$post36.observedMs;frozen35Snapshot=61;frozen35Supplement=65;frozen34=64;mainApplied=$false;liveJobsTested=$false;status='35 accepted scoped/F35.H1closed;36 pending independent audit';countsOverlap='Do not sum'}
if($CaptureSnapshot){
 NewJson36 "$stem36-summary-final.json" $report36
 foreach($p36 in $allowed36+@('apps/worker/src/main.ts','apps/worker/src/lifecycle.ts','apps/worker/src/worker-metrics-retention.ts','apps/worker/src/ad-event-retention.ts','packages/shared/src/core.ts','prisma/schema.prisma','compose.yaml')){$target36=Join-Path "$stem36-source-final" $p36;Need36 (-not(Test-Path -LiteralPath $target36)) 'No source snapshot overwrite';New-Item -ItemType Directory -Force (Split-Path $target36)|Out-Null;Copy-Item -LiteralPath $p36 -Destination $target36}
 $files36=@(Get-ChildItem docs/evidence -Recurse -File|Where-Object{$_.FullName.Contains('p36-20261004') -and $_.Name -notin @('p36-20261004-manifest-final.json','p36-20261004-offline-verify-capture.log','p36-20261004-offline-verify-final.log')})+@(Get-ChildItem tests/p36 -File)+@(Get-Item scripts/test-worker-shutdown.ps1,scripts/verify-worker-shutdown-evidence.ps1,infra/compose.worker-shutdown-lab.yaml,infra/worker-shutdown-lab.env.example)
 $artifacts36=@($files36|ForEach-Object{[pscustomobject]@{path=$_.FullName.Substring((Get-Location).Path.Length+1).Replace('\','/');sha=Hash36 $_.FullName}}|Sort-Object path -Unique)
 Need36 ($artifacts36.Count -eq @($files36.FullName|Sort-Object -Unique).Count -and $artifacts36.Count -gt 50) 'Full distinct actual file coverage'
 NewJson36 "$stem36-manifest-final.json" ([pscustomobject]@{utc=[DateTime]::UtcNow.ToString('o');artifacts=$artifacts36;allowedCurrentDocs=$allowed36;protectedExactMainSHA=$fix36.afterSHA;baselineRawSHA=$fix36.baselineRawSHA;status='36 pending independent audit;only main fix proven by baseline'})
}
$manifest36=Get-Content "$stem36-manifest-final.json" -Raw|ConvertFrom-Json
Need36 ($manifest36.artifacts.Count -gt 50 -and $manifest36.artifacts.Count -eq @($manifest36.artifacts.path|Sort-Object -Unique).Count -and (Hash36 'apps/worker/src/main.ts') -eq $manifest36.protectedExactMainSHA) 'Distinct manifest/exactmain'
foreach($p36 in $manifest36.artifacts){Need36 ((Hash36 $p36.path) -eq $p36.sha) ('Frozen36 '+$p36.path)}
Write-Host ($report36|ConvertTo-Json -Depth 8 -Compress)
Write-Host ('P36_OFFLINE_EXIT 0 UTC '+[DateTime]::UtcNow.ToString('o')+' artifacts '+$manifest36.artifacts.Count+'; offline only/no historical runtime rerun')
