param([switch]$CaptureSnapshot)
$ErrorActionPreference='Stop'
$p23Root=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
if((Get-Location).Path -ne $p23Root -or $p23Root -ne 'D:\WED SNAP'){throw 'Wrong workspace'}
function Check($condition,[string]$message){if(-not $condition){throw $message}}
function Hash([string]$path){(Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant()}
function Read-Raw([string]$name,[string]$prefix){@(Get-Content -LiteralPath ('docs/evidence/'+$name)|Where-Object{$_.StartsWith($prefix)}|ForEach-Object{$_.Substring($prefix.Length)|ConvertFrom-Json})}
$before=Read-Raw 'p23-20261003-before-attempt1.log' 'P23_RAW '
$after=Read-Raw 'p23-20261003-after-attempt1.log' 'P23_RAW '
$r9=Read-Raw 'p23-20261003-r9-regression.log' 'P22_RAW '
$bm=@($before|Where-Object stage -eq 'matrix-before-write')[0]
$am=@($after|Where-Object stage -eq 'matrix-before-write')[0]
$rm=@($r9|Where-Object stage -eq 'matrix-before-write')[0]
Check (($bm.matrix|ConvertTo-Json -Compress) -ceq ($am.matrix|ConvertTo-Json -Compress)) 'Matrix/expected/order differ'
Check ($bm.testSha -eq $am.testSha -and $bm.fixtureSha -eq $am.fixtureSha) 'Before/after harness hash differ'
Check ($bm.testSha -eq (Hash 'tests/p23/cleanup.integration.ts')) 'Current test differs from executed test'
Check ($bm.testSha -eq (Hash 'docs/evidence/p23-20261003-before/cleanup.integration.valid-before.ts')) 'Valid before snapshot mismatch'
Check ($rm.testSha -eq (Hash 'tests/p22/metadata.integration.ts')) 'R9 executed test hash differs'
Check ($rm.fixtureSha -eq $am.fixtureSha -and $am.fixtureSha -eq (Hash 'tests/p22/fixture_adapter.py')) 'Fixture changed'
foreach($pair in @(@($before,12,0,12),@($after,12,12,0),@($r9,15,15,0))){
  $rows=$pair[0];$results=@($rows|Where-Object stage -eq 'case-result');$summary=@($rows|Where-Object stage -eq 'summary')
  Check ($results.Count -eq $pair[1] -and @($results.name|Select-Object -Unique).Count -eq $pair[1] -and $summary.Count -eq 1) 'Missing/duplicate case or summary'
  Check ($summary[0].passed -eq $pair[2] -and $summary[0].failed -eq $pair[3]) 'Summary mismatch'
  Check (@($results|Where-Object result -eq 'PASS').Count -eq $pair[2]) 'Case counts mismatch'
  $final=@($rows|Where-Object stage -eq 'finally')[0]
  Check ($final.settingsDeepEqual -and $final.clockRestored -and $final.registrySize -eq 0) 'Finally invariant FAIL'
}
foreach($name in @('selectable-direct-cancel','queued-noasset-cancel','rm-fault-once-retry-and-next-job')){
  $failure=@($before|Where-Object{$_.stage -eq 'case-result' -and $_.name -eq $name})[0]
  Check ($failure.error -like '*folder/preview still present*') 'Baseline not the intended cleanup error'
}
Check (@($after|Where-Object stage -eq 'cleanup-after-FAIL-only').Count -eq 0) 'Final requires manual cleanup'
$clean=@($after|Where-Object stage -eq 'cleanup-observed')
Check ($clean.Count -eq 13 -and @($clean|Where-Object{$_.elapsedMs -ge 8000 -or $_.snapshot.folder -or $_.snapshot.preview -or $_.snapshot.itemCount -ne 0 -or -not $_.snapshot.cleanupCompletedAt -or $_.snapshot.workerToken}).Count -eq 0) 'Cleanup bound/state FAIL'
$fault=@($after|Where-Object stage -eq 'after-rm-fault')[0]
Check ($fault.faultDelta -eq 1 -and $fault.snapshot.folder -and -not $fault.snapshot.cleanupCompletedAt) 'Fault not pending once'
Check (@($after|Where-Object{$_.stage -eq 'rm-before' -and ($_.childAlive -or $_.workerToken -or $_.liveLeases -gt 0)}).Count -eq 0) 'Unsafe rm observed'
$lock=@($after|Where-Object stage -eq 'lock-overlap')[0]
Check ($lock.pendingCancel -eq 1 -and $lock.pendingSweep -eq 1) 'Real lock overlap missing'
Check ((Get-Content tests/p23/cleanup.integration.ts -Raw) -match "pendingSweep===1&&rows\[0\].n>=2") 'DB-lock predicate changed'
Check (@($after|Where-Object stage -eq 'backlog-control')[0].seedCount -eq 501) 'Done backlog control missing'
Check (@($after|Where-Object stage -eq 'retention-purge-control')[0].after.purged) 'Retention control missing'
$paths=@('prisma/schema.prisma','packages/shared/src/core.ts','apps/api/src/services/jobs.service.ts','apps/worker/src/processor.ts','apps/worker/src/lifecycle.ts','apps/worker/src/main.ts','apps/worker/src/adapter.ts','apps/worker/src/process-group.ts','apps/api/src/services/downloads.service.ts','prisma/migrations/202610030002_cleanup_completed/migration.sql','tests/p23/cleanup.integration.ts','tests/p23/tsconfig.json','tests/p22/metadata.integration.ts','tests/p22/fixture_adapter.py','scripts/test-cleanup.ps1','scripts/validate-p23-evidence.ps1','infra/compose.cleanup-lab.yaml','infra/cleanup-lab.env.example')
foreach($p in $am.hashes.PSObject.Properties){
  Check ((Hash $p.Name) -eq $p.Value -and $rm.hashes.($p.Name) -eq $p.Value) ('Executed source mismatch '+$p.Name)
  $old='docs/evidence/p23-20261003-before/'+$p.Name.Replace('/','__')
  Check ((Hash $old) -eq $bm.hashes.($p.Name)) ('Before snapshot mismatch '+$p.Name)
}
foreach($p in @('apps/worker/src/processor.ts','apps/worker/src/main.ts','apps/worker/src/adapter.ts','apps/worker/src/process-group.ts','apps/api/src/services/downloads.service.ts')){
  Check ((Hash $p) -eq (Hash ('docs/evidence/p23-20261003-before/'+$p.Replace('/','__')))) ('Unrelated production changed '+$p)
}
foreach($p in @('scripts/test-cleanup.ps1','scripts/validate-p23-evidence.ps1')){
  $tokens=$null;$errors=$null;[void][Management.Automation.Language.Parser]::ParseFile((Join-Path $p23Root $p),[ref]$tokens,[ref]$errors)
  Check ($errors.Count -eq 0) ('PowerShell parser FAIL '+$p)
}
Check ((Get-Content docs/evidence/p23-20261003-stop-final.log -Raw) -match 'PASS stopped/removed only cleanup lab containers') 'Final guarded Stop missing'
if($CaptureSnapshot){
  $dir='docs/evidence/p23-20261003-after';New-Item -ItemType Directory -Path $dir -Force|Out-Null
  foreach($p in $paths){Copy-Item -LiteralPath $p -Destination ($dir+'/'+$p.Replace('/','__'))}
  @{utc=[DateTime]::UtcNow.ToString('o');vn=[DateTimeOffset]::Now.ToString('o');source=@($paths|ForEach-Object{@{path=$_;sha=Hash $_}});beforeTestSha=$bm.testSha;afterTestSha=$am.testSha;rawBefore='p23-20261003-before-attempt1.log';rawAfter='p23-20261003-after-attempt1.log';rawR9='p23-20261003-r9-regression.log'}|ConvertTo-Json -Depth 6|Set-Content docs/evidence/p23-20261003-after-manifest.json -Encoding UTF8
}
$manifest=Get-Content docs/evidence/p23-20261003-after-manifest.json -Raw|ConvertFrom-Json
foreach($p in $manifest.source){Check ((Hash $p.path) -eq $p.sha -and (Hash ('docs/evidence/p23-20261003-after/'+$p.path.Replace('/','__'))) -eq $p.sha) ('Final manifest/snapshot mismatch '+$p.path)}
Write-Host ('PASS evidence UTC '+[DateTime]::UtcNow.ToString('o')+' VN '+[DateTimeOffset]::Now.ToString('o')+' parsed '+$before.Count+'/'+$after.Count+'/'+$r9.Count+' JSON; same12 matrix/testSHA;0/12 ->12/0;R9 15/0;fault1;guards/Stop/hash/snapshots/parser/settings/bounds/worker-lease safe; no runtime rerun')
