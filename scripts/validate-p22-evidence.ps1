param(
    [switch]$CaptureSnapshot,
    [string]$AfterLog='docs/evidence/p22-20261003-after-final-guards.log',
    [string]$SnapshotPrefix='docs/evidence/p22-20261003-after-final',
    [string]$StopLog='docs/evidence/p22-20261003-stop-final-guards.log'
)
$ErrorActionPreference='Stop'
if((Get-Location).Path -ne 'D:\WED SNAP'){throw 'Wrong workspace'}
function Require([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
function Read-Raw([string]$Path){
    @(Get-Content -LiteralPath $Path | Where-Object { $_.StartsWith('P22_RAW ') } | ForEach-Object { $_.Substring(8) | ConvertFrom-Json })
}
$before=Read-Raw 'docs/evidence/p22-20261003-before-final.log'
$after=Read-Raw $AfterLog
$beforeCases=@($before|Where-Object stage -eq 'case-result')
$afterCases=@($after|Where-Object stage -eq 'case-result')
$bm=@($before|Where-Object stage -eq 'matrix-before-write')[0]
$am=@($after|Where-Object stage -eq 'matrix-before-write')[0]
Require ($beforeCases.Count -eq 15 -and $afterCases.Count -eq 15) 'Require15 unique cases before/after'
Require (@($afterCases.name|Select-Object -Unique).Count -eq 15) 'Duplicate case'
Require ((($bm.matrix|ConvertTo-Json -Depth 10 -Compress) -ceq ($am.matrix|ConvertTo-Json -Depth 10 -Compress))) 'Changed expected matrix'
for($i=0;$i -lt 15;$i++){
    Require ($beforeCases[$i].name -ceq $afterCases[$i].name -and $beforeCases[$i].expected -ceq $afterCases[$i].expected) 'Changed case order/expected'
    Require ($afterCases[$i].result -eq 'PASS' -and -not $afterCases[$i].error -and $afterCases[$i].registrySize -eq 0) 'Final FAIL/leak'
}
$bs=@($before|Where-Object stage -eq 'summary')[0]
$as=@($after|Where-Object stage -eq 'summary')[0]
Require ($bs.passed -eq 3 -and $bs.failed -eq 12 -and $as.passed -eq 15 -and $as.failed -eq 0) 'Unexpected summary'
$oldStatus=@($before|Where-Object stage -eq 'baseline-stale-status')[0]
$oldPrepare=@($before|Where-Object stage -eq 'baseline-stale-prepare')[0]
Require ($oldStatus.response.status -eq 200 -and $oldStatus.snapshot.state -eq 'selectable' -and $oldStatus.snapshot.itemCount -eq 1) 'Missing stale-status production FAIL'
Require ($oldPrepare.status -eq 202 -and $oldPrepare.snapshot.state -eq 'queued' -and $oldPrepare.snapshot.queuePrepare -eq 'waiting') 'Missing stale-prepare production FAIL'
foreach($s in @($after|Where-Object stage -eq 'race-before-unlock')){
    Require ($s.pendingHTTP -ge 2 -and $s.waitingDatabaseLocks -ge 2) 'No real overlapping transactions'
}
$races=@($after|Where-Object stage -eq 'race-results')
Require ($races.Count -eq 2) 'Missing race results'
foreach($s in $races){$wanted=if($s.cross){410}else{202};Require (@($s.statuses|Where-Object {$_ -ne $wanted}).Count -eq 0) 'Wrong race outcomes'}
$clean=@($after|Where-Object stage -eq 'fixture-lifecycle-cleanup')
Require ($clean.Count -eq 17) 'Missing fixture cleanup'
foreach($s in $clean){Require ($s.elapsedMs -lt 8000 -and -not $s.snapshot.folder -and -not $s.snapshot.workerToken -and $s.registrySize -eq 0) 'Cleanup bound/token/folder FAIL'}
$sweep=@($after|Where-Object stage -eq 'sweep-bound')[0]
Require ($sweep.iterations -eq 3 -and $sweep.elapsedMs -lt 8000 -and -not $sweep.snapshot.folder) 'Missing subsequent sweeps'
$transfer=@($after|Where-Object stage -eq 'ready-transfer-control')[0]
Require ($transfer.bytes -eq 8192 -and $transfer.sha256 -ceq '2849b082b033f51af9d7f9a8b324635ad0981bf09de270c91b0b5ae8d1aecc35') 'Byte/hash control FAIL'
$fin=@($after|Where-Object stage -eq 'finally')[0]
Require ($fin.settingsDeepEqual -and $fin.clockRestored -and $fin.registrySize -eq 0 -and @($fin.fixtureFoldersRemaining|Where-Object exists).Count -eq 0) 'Finally restore/leak FAIL'
Require ([decimal]$fin.chargedAfter[0].charged - [decimal]$fin.chargedBefore[0].charged -eq 8192) 'Charged not retained/control8192 mismatch'
$paths=@($am.hashes.PSObject.Properties.Name)
foreach($p in $paths){
    Require ((Get-FileHash -LiteralPath $p).Hash.ToLowerInvariant() -ceq $am.hashes.$p) ('Current/raw SHA mismatch:'+ $p)
    $snapshot='docs/evidence/p22-20261003-before/'+$p.Replace('/','__')
    Require ((Get-FileHash -LiteralPath $snapshot).Hash.ToLowerInvariant() -ceq $bm.hashes.$p) ('Before/raw SHA mismatch:'+ $p)
}
Require ((Get-FileHash tests/p22/metadata.integration.ts).Hash.ToLowerInvariant() -ceq $am.testSha -and $am.testSha -ceq $bm.testSha) 'Before/after harness not identical'
Require ((Get-FileHash docs/evidence/p22-20261003-before/metadata.integration.valid.ts).Hash.ToLowerInvariant() -ceq $bm.testSha) 'Final baseline harness snapshot mismatch'
Require ((Get-FileHash tests/p22/fixture_adapter.py).Hash.ToLowerInvariant() -ceq $am.fixtureSha -and $am.fixtureSha -ceq $bm.fixtureSha) 'Fixture changed'
$manifestBefore=Get-Content docs/evidence/p22-20261003-before-manifest.json -Raw|ConvertFrom-Json
foreach($p in @('apps/worker/src/adapter.ts','apps/worker/src/process-group.ts','apps/api/src/services/downloads.service.ts')){
    $old=@($manifestBefore.source|Where-Object path -eq $p)[0]
    Require ((Get-FileHash $p).Hash.ToLowerInvariant() -ceq $old.sha) ('Out-of-scope source changed:'+ $p)
}
$extra=@('prisma/migrations/202610030001_metadata_deadline/migration.sql','tests/p22/metadata.integration.ts','tests/p22/fixture_adapter.py','tests/p22/tsconfig.json','scripts/test-metadata.ps1','scripts/validate-p22-evidence.ps1','infra/compose.metadata-lab.yaml','infra/metadata-lab.env.example','infra/media_adapter.py','apps/worker/src/adapter.ts','apps/worker/src/process-group.ts','apps/api/src/services/downloads.service.ts','apps/api/src/services/ads.service.ts','apps/web/src/pages/Home.tsx','apps/web/src/components/Advertising.tsx')
$sources=@($paths+$extra|Select-Object -Unique|ForEach-Object { @{path=$_;sha=(Get-FileHash -LiteralPath $_).Hash.ToLowerInvariant()} })
if($CaptureSnapshot){
    Require ($SnapshotPrefix -match '^docs/evidence/p22-20261003-after(?:-final)?$') 'Wrong evidence target'
    $dest=$SnapshotPrefix
    Require (-not (Test-Path -LiteralPath $dest) -and -not (Test-Path -LiteralPath ($SnapshotPrefix+'-manifest.json'))) 'Snapshot exists; preserve it'
    New-Item -ItemType Directory -Path $dest | Out-Null
    foreach($source in $sources){Copy-Item -LiteralPath $source.path -Destination (Join-Path $dest $source.path.Replace('/','__'))}
    @{utc=[DateTime]::UtcNow.ToString('o');vn=[DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(7)).ToString('o');cwd=(Get-Location).Path;source=$sources;beforeLog='p22-20261003-before-final.log';afterLog=$AfterLog;matrix=$am.matrix;scope='Evidence parse/hash only; no application rerun/Docker/data mutation'} | ConvertTo-Json -Depth 12 | Set-Content -Encoding UTF8 ($SnapshotPrefix+'-manifest.json')
}
foreach($p in @('scripts/test-metadata.ps1','scripts/validate-p22-evidence.ps1')){
    $parseTokens=$null;$parseErrors=$null
    [Management.Automation.Language.Parser]::ParseFile((Resolve-Path $p),[ref]$parseTokens,[ref]$parseErrors)|Out-Null
    Require ($parseErrors.Count -eq 0) ('Parser FAIL:'+ $p)
}
$stop=Get-Content -LiteralPath $StopLog -Raw
Require ($stop -match 'PASS stopped/removed only metadata lab containers') 'Missing guarded lab stop'
Write-Output ('P22 evidence validation UTC '+[DateTime]::UtcNow.ToString('o')+' VN '+[DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(7)).ToString('o'))
Write-Output 'PASS raw parse/same15expected/order/harness SHA; baseline3PASS12FAIL, after15PASS0FAIL'
Write-Output ('PASS real overlap2/2locks/202-before and410-at; 8192bytes/hash;17cleanup<=8s,3sweeps;settingsDeepEqual/charged retained'+$fin.chargedBefore[0].charged+'->'+$fin.chargedAfter[0].charged)
Write-Output 'PASS before/current/source snapshots SHA; adapter/process-group/download unchanged;PS parser0;isolated stop raw'
Write-Output 'Evidence inspection only; no new runtime PASS, no Docker/data action'
