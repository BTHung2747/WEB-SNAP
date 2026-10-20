param([switch]$CaptureSnapshot)
$ErrorActionPreference='Stop'
if((Get-Location).Path -ne 'D:\WED SNAP'){throw 'Native repository required'}
$stem35='docs/evidence/p35-20261004'
function Hash35([string]$p35){(Get-FileHash -LiteralPath $p35).Hash.ToLowerInvariant()}
function Need35($v35,[string]$m35){if(-not $v35){throw $m35}}
function Write35([string]$p35,$v35){Need35 (-not(Test-Path -LiteralPath $p35)) ('Never overwrite '+$p35);$v35|ConvertTo-Json -Depth 35|Set-Content -Encoding utf8 -LiteralPath $p35}
function Raw35([string]$p35){@(Get-Content -LiteralPath $p35|Where-Object{$_.StartsWith('P35_RAW ')}|ForEach-Object{$_.Substring(8)|ConvertFrom-Json})}
$allowed35=@('README.md','docs/RUNBOOK.md','docs/PROGRESS.md','docs/TEST_REPORT.md','docs/AUDIT_TIEN_DO.md','docs/API.md')
$before35=Get-Content "$stem35-before.json" -Raw|ConvertFrom-Json
Need35 (($allowed35 -join '|') -eq ($before35.allowed -join '|')) 'Exactly6 current docs exemptions, no production exemption'
Need35 (@($before35.inventory.path|Sort-Object -Unique).Count -eq $before35.inventory.Count) 'Distinct before inventory'
$checked35=0;foreach($f35 in $before35.inventory){if($allowed35 -notcontains $f35.path){Need35 ((Hash35 $f35.path) -eq $f35.sha) ('Protected35 '+$f35.path);$checked35++}}
$m34=Get-Content docs/evidence/p34-20261004-manifest-verified.json -Raw|ConvertFrom-Json
Need35 ($m34.artifacts.Count -eq 64 -and @($m34.artifacts.path|Sort-Object -Unique).Count -eq 64 -and $m34.currentCode.Count -eq 4) 'Accepted34 inventories'
foreach($f35 in @($m34.artifacts)+@($m34.currentCode)){Need35 ((Hash35 $f35.path) -eq $f35.sha) ('Accepted34 artifact/current source '+$f35.path)}
$m31=Get-Content docs/evidence/p31-20261004-manifest-final.json -Raw|ConvertFrom-Json
$m32=Get-Content docs/evidence/p32-20261004-manifest.json -Raw|ConvertFrom-Json
$m33=Get-Content docs/evidence/p33-20261004-manifest-final.json -Raw|ConvertFrom-Json
foreach($f35 in @($m31.artifacts)+@($m32.artifacts)+@($m33.artifacts)){Need35 ((Hash35 $f35.path) -eq $f35.sha) ('Frozen historical artifact '+$f35.path)}
Need35 ((Hash35 'compose.yaml') -eq 'fe92fa79a4db42f47c0a81f3ac380a283a7bb695cc4ed3add5788fa4900e5829') 'Accepted33 Compose unchanged'
foreach($f35 in $m33.runtimeHashes){$successor35=@($m34.currentCode|Where-Object path -eq $f35.path);$accepted35=if($successor35.Count){$successor35[0].sha}else{$f35.sha};Need35 ((Hash35 $f35.path) -eq $accepted35) ('Current source incl accepted34 successor, no35 exemption '+$f35.path)}
foreach($f35 in @('docs/evidence/p34-20261004-completion-supplement.json','docs/evidence/p34-20261004-final-static.json','docs/evidence/p34-20261004-offline-verify-final.log','docs/evidence/p34-20261004-offline-verify-capture-v2.log')){$old35=@($before35.inventory|Where-Object path -eq $f35);Need35 ($old35.Count -eq 1 -and (Hash35 $f35) -eq $old35[0].sha) 'Post-snapshot34 files unchanged'}
$pre35=Get-Content "$stem35-matrix-before.json" -Raw|ConvertFrom-Json
Need35 ((Hash35 'tests/p35/expected.json') -eq $pre35.expectedSHA -and (Hash35 'tests/p35/scheduler.ts') -eq $pre35.testSHA) 'Same expected/test before-final'
$expected35=Get-Content tests/p35/expected.json -Raw|ConvertFrom-Json
$raw35=Raw35 "$stem35-final.log";$sum35=@($raw35|Where-Object stage -eq summary)
Need35 ($sum35.Count -eq 1 -and $sum35[0].uniqueControls -eq 11 -and $sum35[0].pass -eq 11 -and $sum35[0].fail -eq 0 -and $sum35[0].notRun -eq 0 -and $sum35[0].parentSweepCalls -eq 0 -and $sum35[0].http -eq 0) 'Actual entrypoint11PASS/0parentSweep/0HTTP'
Need35 (($sum35[0].results.name -join '|') -eq ($expected35.cases -join '|')) 'Independent names/order'
$preflight35=@($raw35|Where-Object stage -eq preflight);Need35 ($preflight35.Count -eq 1 -and $preflight35[0].effectiveSeconds -eq 2 -and $preflight35[0].sourceDefaultSeconds -eq 30) 'Effective production limits2/default30'
$phases35=@($raw35|Where-Object stage -eq 'db-phase');Need35 ($phases35.Count -eq 3) 'Three actual PG readback phases'
for($i35=0;$i35 -lt 3;$i35++){Need35 ($phases35[$i35].deletedIds.Count -eq $expected35.batchDeletes[$i35] -and $phases35[$i35].eligibleIds.Count -eq $expected35.remaining[$i35] -and ($phases35[$i35].deletedIds -join '|') -eq ($phases35[$i35].wantedDeletedIds -join '|')) 'Batch/order/retained expected exact';Need35 ($phases35[$i35].workerReady -eq ($i35 -ne 0)) 'Startup before ready/timers after ready'}
$startup35=@($raw35|Where-Object stage -eq 'startup-latch-observed');$periodic35=@($raw35|Where-Object stage -eq 'periodic-latch-observed');$window35=@($raw35|Where-Object stage -eq 'periodic-window-result');$samples35=@($raw35|Where-Object stage -eq 'periodic-window-sample')
Need35 ($startup35.Count -eq 1 -and -not $startup35[0].workerReady -and $startup35[0].waiters.Count -ge 1 -and $periodic35.Count -eq 1 -and $periodic35[0].outsideStartupBatch) 'Real PG startup latch versus periodic row latch'
Need35 ($window35.Count -eq 1 -and $window35[0].heldMs -ge $expected35.minBlockedWindowMs -and $window35[0].maxConcurrentDeletes -eq 1 -and $samples35.Count -eq $window35[0].samples -and $samples35.Count -ge 2) 'Bounded >=2interval sampled nonoverlap'
foreach($s35 in $samples35){Need35 ($s35.retentionDeletes -eq 1 -and @($s35.pg|Where-Object{$_.query -match 'DELETE.*AuditLog' -and $_.blockers -contains $s35.blocker}).Count -eq 1) 'Every sampled DELETE tied to own blocker'}
$exit35=@($raw35|Where-Object stage -eq 'child-exit');$signal35=@($raw35|Where-Object stage -eq signal);$closed35=@($raw35|Where-Object stage -eq 'closed-readback');$cleanup35=@($raw35|Where-Object stage -eq cleanup)
Need35 ($exit35.Count -eq 1 -and $exit35[0].code -eq 0 -and $null -eq $exit35[0].signal -and $signal35.Count -eq 1 -and $signal35[0].signal -eq 'SIGTERM' -and $signal35[0].label -eq 'idle-runtime-test' -and $signal35[0].guarded) 'Actual guarded SIGTERM idle exit0'
Need35 ($closed35.Count -eq 1 -and $closed35[0].pgChildConnections -eq 0 -and $closed35[0].workerConsumers -eq 0 -and $closed35[0].noChangesWindowMs -ge 4000) 'Child connections/timer closed bounded proof'
Need35 ($cleanup35.Count -eq 1 -and $cleanup35[0].modelsEmpty -and $cleanup35[0].keysEmpty -and $cleanup35[0].ownChildExited -and $cleanup35[0].mediaResolvedEmptyNonrecursiveRmdir -and $cleanup35[0].chargedPreservedUntilOwnFixtureCleanup -eq 37) 'Own fixture-only cleanup'
$fail35=Raw35 "$stem35-matrix.log";$failSum35=@($fail35|Where-Object stage -eq summary);$panic35=@($fail35|Where-Object{ $_.stage -eq 'child-output' -and $_.chunk.Contains("OS can't spawn worker thread")})
Need35 ($failSum35.Count -eq 1 -and $failSum35[0].pass -eq 2 -and $failSum35[0].fail -eq 1 -and $failSum35[0].notRun -eq 8 -and $panic35.Count -eq 1) 'First pids64 FAIL retained, not fabricated baseline'
foreach($pair35 in @(@('start','Start'),@('pids-diagnostics-file','Diagnostics'),@('stop-pids64','Stop'),@('start-pids192','Start'),@('final','Matrix'),@('typecheck','Typecheck'),@('stop-final','Stop'))){Need35 ((Get-Content "$stem35-$($pair35[0]).log" -Raw).Contains('P35_COMMAND_EXIT 0 '+$pair35[1]+' UTC')) 'Actual native/runner exits0'}
Need35 ((Get-Content "$stem35-matrix.log" -Raw).Contains('P35_NATIVE_COMPLETION exit=1') -and (Get-Content "$stem35-pids-diagnostics.log" -Raw).Contains('P35_NATIVE_COMPLETION exit=1')) 'Retained runtime fixture and diagnostic quoting FAIL exits1'
$report35=@{utc=[DateTime]::UtcNow.ToString('o');vn=[DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(7)).ToString('o');distinctBefore=$before35.inventory.Count;unchangedOutside6Docs=$checked35;exactAllowedCurrentDocs=$allowed35;productionExemptions=0;accepted34Current4Checked=4;frozen34Artifacts=64;frozen31=36;frozen32=20;frozen33=50;countsOverlap='Do not sum';uniqueControls=11;pass=11;firstAttempt=@{pass=2;fail=1;notRun=8;cause='Own PIDs64 fixture/native thread limit, raw kept/cleanup';notProductionSchedulerBug=$true};window=$window35[0];startupTimerDeleted=@(500,500,1);eligible=@(1001,501,1,0);fixtureSeconds=2;sourceDefaultSeconds=30;shutdown='Actual SIGTERM idle exit0/connectionsclosed';mainApplied=$false;liveJobsTested=$false;default30SlaTested=$false;status='35 awaiting independent audit;34 accepted scoped/F34.H1closed'}
if($CaptureSnapshot){
 Write35 "$stem35-summary-final.json" $report35
 foreach($p35 in $allowed35+@('apps/worker/src/main.ts','apps/worker/src/lifecycle.ts','apps/worker/src/worker-metrics-retention.ts','apps/worker/src/ad-event-retention.ts','prisma/schema.prisma','packages/shared/src/core.ts','compose.yaml')){$d35=Join-Path "$stem35-source-final" $p35;Need35 (-not(Test-Path $d35)) 'No source snapshot overwrite';New-Item -ItemType Directory -Force (Split-Path $d35)|Out-Null;Copy-Item -LiteralPath $p35 -Destination $d35}
 $files35=@(Get-ChildItem docs/evidence -Recurse -File|Where-Object{$_.FullName.Contains('p35-20261004') -and $_.Name -notin @('p35-20261004-manifest-final.json','p35-20261004-offline-verify-capture.log','p35-20261004-offline-verify-final.log')})+@(Get-ChildItem tests/p35 -File)+@(Get-Item scripts/test-worker-scheduler.ps1,scripts/verify-worker-scheduler-evidence.ps1,infra/compose.worker-scheduler-lab.yaml,infra/worker-scheduler-lab.env.example)
 $artifacts35=@($files35|ForEach-Object{$rel35=$_.FullName.Substring((Get-Location).Path.Length+1).Replace('\','/');[pscustomobject]@{path=$rel35;sha=Hash35 $rel35}}|Sort-Object path -Unique)
 Need35 ($artifacts35.Count -eq @($files35.FullName|Sort-Object -Unique).Count -and $artifacts35.Count -gt 50) 'Full distinct actual file coverage/no Hashtable coalescing'
 Write35 "$stem35-manifest-final.json" @{utc=[DateTime]::UtcNow.ToString('o');artifacts=$artifacts35;allowedCurrentDocs=$allowed35;protectedAccepted34CurrentCode=$m34.currentCode;status='35 pending independent audit, production unchanged'}
}
$manifest35=Get-Content "$stem35-manifest-final.json" -Raw|ConvertFrom-Json
Need35 ($manifest35.artifacts.Count -gt 50 -and $manifest35.artifacts.Count -eq @($manifest35.artifacts.path|Sort-Object -Unique).Count) 'Manifest distinct coverage guard'
foreach($f35 in @($manifest35.artifacts)+@($manifest35.protectedAccepted34CurrentCode)){Need35 ((Hash35 $f35.path) -eq $f35.sha) ('Manifest35 '+$f35.path)}
Write-Host ($report35|ConvertTo-Json -Depth 9 -Compress)
Write-Host ('P35_OFFLINE_EXIT 0 UTC '+[DateTime]::UtcNow.ToString('o')+' artifacts '+$manifest35.artifacts.Count+'; offline only, no historical runtime rerun')
