param([switch]$CaptureSnapshot)
$ErrorActionPreference='Stop'
if((Get-Location).Path -ne 'D:\WED SNAP'){throw 'Native repository required'}
$stem34='docs/evidence/p34-20261004'
function Hash34([string]$path34){(Get-FileHash -LiteralPath $path34).Hash.ToLowerInvariant()}
function Need34($value34,[string]$message34){if(-not $value34){throw $message34}}
function Write34([string]$path34,$value34){Need34 (-not(Test-Path -LiteralPath $path34)) ('Never overwrite '+$path34);$value34|ConvertTo-Json -Depth 35|Set-Content -Encoding utf8 -LiteralPath $path34}
function ReadRaw34([string]$path34){@(Get-Content -LiteralPath $path34|Where-Object{$_.StartsWith('P34_RAW ')}|ForEach-Object{$_.Substring(8)|ConvertFrom-Json})}
$before34=Get-Content "$stem34-before.json" -Raw|ConvertFrom-Json
$allowed34=@('apps/worker/src/lifecycle.ts','prisma/schema.prisma','README.md','docs/RUNBOOK.md','docs/PROGRESS.md','docs/TEST_REPORT.md','docs/AUDIT_TIEN_DO.md','docs/API.md')
Need34 (($allowed34 -join '|') -eq ($before34.allowed -join '|')) 'Exact successor34 exemptions'
Need34 (@($before34.inventory.path|Select-Object -Unique).Count -eq $before34.inventory.Count) 'Distinct current inventory'
$checked34=0
foreach($f34 in $before34.inventory){if($allowed34 -notcontains $f34.path){Need34 ((Hash34 $f34.path) -eq $f34.sha) ('Current protected '+$f34.path);$checked34++}}
$acceptedCompose34='fe92fa79a4db42f47c0a81f3ac380a283a7bb695cc4ed3add5788fa4900e5829'
Need34 ((Hash34 'compose.yaml') -eq $acceptedCompose34) 'Compose accepted33 unchanged; no34 Compose exemption'
function Historical34($entries34,[string]$label34){$count34=0;$superseded33=0;$exempt34=@();foreach($f34 in $entries34){if($allowed34 -contains $f34.path){$exempt34+=$f34.path;continue};if($f34.path -eq 'compose.yaml' -and $f34.sha -ne $acceptedCompose34){Need34 ((Hash34 $f34.path) -eq $acceptedCompose34) 'Accepted33 Compose successor pinned';$superseded33++}else{Need34 ((Hash34 $f34.path) -eq $f34.sha) ('Historical '+$label34+' '+$f34.path)};$count34++};@{label=$label34;baseline=$entries34.Count;checked=$count34;exactAllowedCurrentExemptions=$exempt34;accepted33ComposeSuccessorChecks=$superseded33}}
$old31=Get-Content docs/evidence/p31-20261004-protected-before.json -Raw|ConvertFrom-Json
$old32=Get-Content docs/evidence/p32-20261004-before.json -Raw|ConvertFrom-Json
$old33=Get-Content docs/evidence/p33-20261004-before.json -Raw|ConvertFrom-Json
$history34=@((Historical34 $old31.protected '31protected'),(Historical34 $old32.inventory '32inventory'),(Historical34 $old33.inventory '33inventory'))
$m31=Get-Content docs/evidence/p31-20261004-manifest-final.json -Raw|ConvertFrom-Json
$m32=Get-Content docs/evidence/p32-20261004-manifest.json -Raw|ConvertFrom-Json
$m33=Get-Content docs/evidence/p33-20261004-manifest-final.json -Raw|ConvertFrom-Json
Need34 ($m31.artifacts.Count -eq 36 -and $m32.artifacts.Count -eq 20 -and $m33.artifacts.Count -eq 50) 'Frozen inventory counts'
foreach($f34 in @($m31.artifacts)+@($m32.artifacts)+@($m33.artifacts)){Need34 ((Hash34 $f34.path) -eq $f34.sha) ('Frozen artifact, no exemption '+$f34.path)}
foreach($f34 in $m33.runtimeHashes){if($f34.path -notin @('apps/worker/src/lifecycle.ts','prisma/schema.prisma')){Need34 ((Hash34 $f34.path) -eq $f34.sha) ('Current runtime outside scope '+$f34.path)}}
Need34 ((Hash34 'docs/evidence/p31-20261004-manifest-final.json') -eq $m32.retainedManifest31SHA) 'Frozen manifest31'
$pre34=Get-Content "$stem34-matrix-before.json" -Raw|ConvertFrom-Json
Need34 ((Hash34 'tests/p34/expected.json') -eq $pre34.expectedSHA -and (Hash34 'tests/p34/retention.ts') -eq $pre34.testSHA) 'Same expected/test before-after'
$normalize34={param($s)$s.Replace("`r`n","`n").TrimEnd()}
$lc34=Get-Content apps/worker/src/lifecycle.ts -Raw
$reversed34=$lc34.Replace("import { purgeWorkerMetrics } from './worker-metrics-retention';`n",'').Replace("  await purgeWorkerMetrics(now);`n",'')
Need34 ((&$normalize34 $reversed34) -eq (&$normalize34 (Get-Content "$stem34-source-before/apps/worker/src/lifecycle.ts" -Raw))) 'Only import and one metrics helper call in lifecycle'
Need34 (@([regex]::Matches($lc34,'await purgeWorkerMetrics\(now\);')).Count -eq 1) 'One batch per sweep'
$schema34=(Get-Content prisma/schema.prisma -Raw).Replace("  @@index([actor, action, createdAt, id])`n",'')
Need34 ((&$normalize34 $schema34) -eq (&$normalize34 (Get-Content "$stem34-source-before/prisma/schema.prisma" -Raw))) 'Schema only composite index'
$sql34=(Get-Content prisma/migrations/202610040001_worker_metrics_retention_index/migration.sql -Raw).Trim()
Need34 ($sql34 -ceq 'CREATE INDEX "AuditLog_actor_action_createdAt_id_idx" ON "AuditLog"("actor", "action", "createdAt", "id");') 'Exactly one CREATE INDEX, no data change'
$baseline34=ReadRaw34 "$stem34-baseline.log";$final34=ReadRaw34 "$stem34-final.log"
$b34=@($baseline34|Where-Object stage -eq summary);$f34=@($final34|Where-Object stage -eq summary)
Need34 ($b34.Count -eq 1 -and $b34[0].cases -eq 13 -and $b34[0].pass -eq 2 -and $b34[0].fail -eq 8 -and $b34[0].skip -eq 3) 'Baseline expected-negative faithfully retained'
Need34 ($f34.Count -eq 1 -and $f34[0].cases -eq 13 -and $f34[0].pass -eq 13 -and $f34[0].fail -eq 0 -and $f34[0].skip -eq 0) 'Final13 PASS'
Need34 (@($final34|Where-Object stage -eq 'row-lock-barrier').Count -eq 3 -and @($final34|Where-Object stage -eq 'race-readback').Count -eq 3) 'Three real PG DELETE lock barriers and readbacks'
foreach($run34 in @($baseline34,$final34)){Need34 (@($run34|Where-Object stage -eq 'harness-failure').Count -eq 0) 'No harness failure counted runtime';$cleanup34=@($run34|Where-Object stage -eq cleanup);$close34=@($run34|Where-Object stage -eq close);Need34 ($cleanup34.Count -eq 1 -and $cleanup34[0].modelsEmpty -and $cleanup34[0].keysEmpty -and $cleanup34[0].mediaResolvedEmptyNonrecursiveRmdir -and $cleanup34[0].chargedPreservedUntilOwnFixtureCleanup -eq 37) 'Own fixture cleanup and charged preservation';Need34 ($close34.Count -eq 1 -and $close34[0].hooksRestored -and $close34[0].clientsClosed -and $close34[0].counters.deniedDials -eq 0 -and $close34[0].counters.deniedListens -eq 0) 'Clients/hooks no foreign socket/listener'}
foreach($entry34 in @(@('start-baseline','Start'),@('stop-baseline','Stop'),@('start-final','Start'),@('final','Matrix'),@('typecheck','Typecheck'),@('stop-final','Stop'))){Need34 ((Get-Content "$stem34-$($entry34[0]).log" -Raw).Contains('P34_COMMAND_EXIT 0 '+$entry34[1]+' UTC')) 'Actual runner completion exit0'}
Need34 ((Get-Content "$stem34-baseline.log" -Raw).Contains('P34_NATIVE_COMPLETION exit=1')) 'Actual baseline exit1'
$report34=@{utc=[DateTime]::UtcNow.ToString('o');vn=[DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(7)).ToString('o');distinctBefore=$before34.inventory.Count;unchangedOutsideAllowed=$checked34;exactCurrentExemptions=$allowed34;history=$history34;countsOverlap='Do not sum inventories';frozen31=36;frozen32=20;frozen33=50;currentRuntimeOutsideScope=14;composeAccepted33SHA=$acceptedCompose34;baseline=@{pass=2;fail=8;skip=3;exit=1};final=@{uniqueCases=13;pass=13;exit=0;http=0};typecheck='worker/shared/tests34 only, one tsc';mainApplied=$false;schedulerTested=$false;status='34 pending independent audit;33 accepted scoped'}
if($CaptureSnapshot){
 Write34 "$stem34-summary-verified.json" $report34
 foreach($p34 in $allowed34+@('apps/worker/src/worker-metrics-retention.ts','prisma/migrations/202610040001_worker_metrics_retention_index/migration.sql')){$dest34=Join-Path "$stem34-source-verified" $p34;Need34 (-not(Test-Path $dest34)) 'Never overwrite verified copy';New-Item -ItemType Directory -Force (Split-Path $dest34)|Out-Null;Copy-Item -LiteralPath $p34 -Destination $dest34}
 $files34=@(Get-ChildItem docs/evidence -Recurse -File|Where-Object{$_.FullName.Contains('p34-20261004') -and $_.Name -notin @('p34-20261004-manifest-verified.json','p34-20261004-offline-verify-capture-v2.log','p34-20261004-offline-verify-final.log')})+@(Get-ChildItem tests/p34 -File)+@(Get-Item scripts/test-worker-metrics-retention.ps1,scripts/verify-worker-metrics-retention-evidence.ps1,infra/compose.worker-metrics-retention-lab.yaml,infra/worker-metrics-retention-lab.env.example)
 $artifacts34=@($files34|ForEach-Object{$rel34=$_.FullName.Substring((Get-Location).Path.Length+1).Replace('\','/');[pscustomobject]@{path=$rel34;sha=Hash34 $rel34}}|Sort-Object path -Unique)
 Need34 ($artifacts34.Count -eq @($files34.FullName|Sort-Object -Unique).Count -and $artifacts34.Count -gt 50) 'Every distinct new artifact captured, no hashtable coalescing'
 Write34 "$stem34-manifest-verified.json" @{utc=[DateTime]::UtcNow.ToString('o');artifacts=$artifacts34;allowedCurrentPaths=$allowed34;currentCode=@('apps/worker/src/lifecycle.ts','apps/worker/src/worker-metrics-retention.ts','prisma/schema.prisma','prisma/migrations/202610040001_worker_metrics_retention_index/migration.sql')|ForEach-Object{@{path=$_;sha=Hash34 $_}};status='34 pending independent audit; migration ownlab only';supersedes='manifest-final.json incomplete1artifact, original kept/F34.H1 harness only'}
}
$manifest34=Get-Content "$stem34-manifest-verified.json" -Raw|ConvertFrom-Json
Need34 ($manifest34.artifacts.Count -gt 50 -and $manifest34.artifacts.Count -eq @($manifest34.artifacts.path|Sort-Object -Unique).Count) 'Complete distinct artifact coverage'
foreach($f34 in @($manifest34.artifacts)+@($manifest34.currentCode)){Need34 ((Hash34 $f34.path) -eq $f34.sha) ('Manifest34 '+$f34.path)}
Write-Host ($report34|ConvertTo-Json -Depth 8 -Compress)
Write-Host ('P34_OFFLINE_EXIT 0 UTC '+[DateTime]::UtcNow.ToString('o')+' ownArtifacts '+$manifest34.artifacts.Count+'; offline only, no runtime rerun')
