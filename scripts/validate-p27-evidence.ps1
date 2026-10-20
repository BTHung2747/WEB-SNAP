param([switch]$CaptureSnapshot)
$ErrorActionPreference='Stop'
$p27Root=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
if((Get-Location).Path -ne $p27Root -or $p27Root -ne 'D:\WED SNAP'){throw 'Wrong workspace'}
function Check($value,[string]$message){if(-not $value){throw $message}}
function Hash([string]$path){(Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant()}
function Raw([string]$name){@(Get-Content -LiteralPath ('docs/evidence/'+$name)|Where-Object{$_ -like 'P27_RAW *'}|ForEach-Object{$_.Substring(8)|ConvertFrom-Json})}
function Stage($rows,[string]$name){$items=@($rows|Where-Object stage -eq $name);Check ($items.Count -eq 1) ('Expected one stage '+$name);$items[0]}
$p27Rows=Raw 'p27-20261003-matrix-identity-repair.log'
$p27Before=Stage $p27Rows 'matrix-before-write';$p27Summary=Stage $p27Rows 'summary';$p27Finally=Stage $p27Rows 'finally';$p27Cleanup=Stage $p27Rows 'cleanup';$p27Identity=Stage $p27Rows 'datastore-identity';$p27Comparison=Stage $p27Rows 'datastore-identity-comparison'
Check ($p27Summary.passed -eq 36 -and $p27Summary.failed -eq 0 -and $p27Summary.successCount -eq 11 -and $p27Summary.requests -eq 79 -and $p27Summary.result -eq 'PASS') 'Scoped36/79/11 summary'
Check (@($p27Rows|Where-Object{$_.stage -in @('HARNESS_FAIL','CLEANUP_FAIL')}).Count -eq 0) 'Harness/cleanup failure is not runtime PASS'
$p27Cases=@($p27Rows|Where-Object stage -eq case-result)
Check ($p27Cases.Count -eq 36 -and @($p27Cases.name|Select-Object -Unique).Count -eq 36 -and @($p27Cases|Where-Object result -ne PASS).Count -eq 0) 'Case inventory'
for($i=0;$i -lt 36;$i++){Check ($p27Cases[$i].name -ceq $p27Before.expected[$i].name -and $p27Cases[$i].expected -ceq $p27Before.expected[$i].expected) 'Independent matrix/order changed'}
Check ($p27Before.testSha -eq (Hash 'tests/p27/matrix.ts') -and $p27Before.expectedSha -eq (Hash 'tests/p27/expectations.ts') -and $p27Before.schemaHelperSha -eq (Hash 'tests/p27/schema.ts')) 'Executed harness changed'
Check ((Hash 'tests/p27/matrix.ts') -eq (Hash 'docs/evidence/p27-20261003-before-identity-repair/matrix.ts') -and (Hash 'tests/p27/expectations.ts') -eq (Hash 'docs/evidence/p27-20261003-before/tests_p27_expectations.ts')) 'Pre-run copies mismatch'
Check ($p27Identity.database -eq 'wed_snap_admin_http_test' -and $p27Identity.redisDatabase -eq 15 -and $p27Identity.serverAddressMatchesContainer -and $p27Identity.clusterMatchesContainer -and $p27Identity.redisRunMatchesContainer -and $p27Identity.keysBefore -eq 0) 'Datastore identity'
Check ($p27Comparison.addressText -eq ($p27Comparison.numericHost+'/32') -and $p27Comparison.numericHost -eq $p27Comparison.expectedContainerIP -and $p27Comparison.clusterMatches) 'Inet32 harness cause evidence'
$p27Starts=@($p27Rows|Where-Object stage -eq request-start);$p27Finishes=@($p27Rows|Where-Object stage -eq request-finish)
Check ($p27Starts.Count -eq 79 -and $p27Finishes.Count -eq 79) 'HTTP79 records'
for($i=0;$i -lt 79;$i++){
  $a=$p27Starts[$i];$b=$p27Finishes[$i]
  foreach($key in @('name','request','startOrder','method','path')){Check ($a.$key -ceq $b.$key) ('HTTP match '+$key)}
  Check ($a.request -eq $i+1 -and $a.startOrder -eq 2*$i+1 -and $b.finishOrder -eq 2*$i+2 -and $b.status -eq $a.expectedStatus) 'HTTP ordered bounded status'
  Check ($b.elapsedMs -lt 5000 -and $b.bodyBytes -le 65536 -and $b.headers.cacheControl -eq 'no-store' -and $b.headers.nosniff -eq 'nosniff') 'Wire deadline/bytes/header'
  if($a.expectedCode){Check ($b.body.error.code -ceq $a.expectedCode -and @($b.body.PSObject.Properties).Count -eq 1 -and @($b.body.error.PSObject.Properties).Count -eq 1) 'Safe exact error'}
  if($a.path -eq '/api/v1/session'){Check ($b.body.csrf -ceq '[REDACTED]') 'CSRF leaked'}
  Check (@($b.headers.PSObject.Properties.Name|Where-Object{$_ -in @('cookie','set-cookie','authorization','x-csrf-token')}).Count -eq 0) 'Sensitive raw header'
}
foreach($operation in $p27Before.operationSuccess){Check (@($p27Finishes|Where-Object{$_.method -eq $operation[0] -and ($_.path -replace '/admin/campaigns/[^/?]+$','/admin/campaigns/{id}') -eq $operation[1] -and $_.status -eq $operation[2]}).Count -gt 0) '11 actual operation successes'}
Check ($p27Finally.hooksRestored -and $p27Finally.serverClosed -and $p27Finally.socketsRemaining -eq 0 -and $p27Finally.peersRemaining -eq 0 -and $p27Finally.cleanupOk -and $p27Finally.counters.allowedListens -eq 1 -and $p27Finally.counters.httpDials -eq 79 -and $p27Finally.counters.redisDials -eq 2 -and $p27Finally.counters.deniedDials -eq 0 -and $p27Finally.counters.deniedListens -eq 0) 'Close/isolation counts'
Check ($p27Cleanup.settingsBudgetDeepEqual -and $p27Cleanup.fixtureRowsRestored -and $p27Cleanup.redisKeysAfter -eq 0 -and $p27Cleanup.noReset -and $p27Cleanup.noMediaCreated) 'Fixture restore'
foreach($property in $p27Cleanup.rows.PSObject.Properties){Check ($property.Value -eq $p27Before.beforeCounts.($property.Name)) 'Row restoration'}
Check (($p27Cleanup.queueBefore|ConvertTo-Json -Compress) -ceq ($p27Cleanup.queueAfter|ConvertTo-Json -Compress)) 'Queue restored'
Check ($p27Cleanup.ownAdmin -eq 1 -and $p27Cleanup.ownSessions -eq 1 -and $p27Cleanup.ownCampaigns -eq 2 -and $p27Cleanup.ownEvents -eq 2 -and $p27Cleanup.ownJobs -eq 3 -and $p27Cleanup.ownAssets -eq 1 -and $p27Cleanup.ownLeases -eq 2 -and $p27Cleanup.ownAudits -eq 6) 'Fixture inventory'
$p27Protected=Get-Content docs/evidence/p27-20261003-protected-before.json -Raw|ConvertFrom-Json
Check ($p27Protected.protected.Count -eq 261) 'Protected261'
foreach($file in $p27Protected.protected){Check ((Hash $file.path) -eq $file.sha) ('Runtime/frozen24-26 changed '+$file.path)}
foreach($property in $p27Before.hashes.PSObject.Properties){Check ((Hash $property.Name) -eq $property.Value) ('Executed production source changed '+$property.Name)}
$p27Attempt=Raw 'p27-20261003-matrix-first.log';Check (@($p27Attempt|Where-Object stage -eq request-finish).Count -eq 0 -and @($p27Attempt|Where-Object stage -eq HARNESS_FAIL).Count -eq 1) 'Preserve first0HTTP harness attempt'
Check ((Get-Content docs/evidence/p27-20261003-stop.log -Raw).Contains('PASS stopped/removed only admin HTTP lab containers; DB/Redis volumes/logs retained')) 'Stop own lab proof'
$p27Paths=@('scripts/test-admin-http.ps1','scripts/validate-p27-evidence.ps1','infra/compose.admin-http-lab.yaml','infra/admin-http-lab.env.example','docs/API.md')+@(rg --files tests/p27)
$p27Commands=@(@('Start','start',0),@('Matrix','matrix-first',1),@('Matrix','matrix-identity-repair',0),@('Typecheck','typecheck',0),@('Logs','containers',0),@('Stop','stop',0))
if($CaptureSnapshot){
  $p27Directory=Join-Path $p27Root 'docs/evidence/p27-20261003-after';if((Test-Path $p27Directory) -or (Test-Path docs/evidence/p27-20261003-after-manifest.json)){throw 'Refuse overwrite history'}
  New-Item -ItemType Directory -Path $p27Directory|Out-Null
  $p27Files=@();foreach($path in $p27Paths){$target=Join-Path $p27Directory $path.Replace('/','_').Replace('\','_');Copy-Item -LiteralPath $path -Destination $target;$p27Files+=@{path=$path.Replace('\','/');sha=Hash $path;snapshot=$target.Substring($p27Root.Length+1).Replace('\','/')}}
  $p27Runs=@();foreach($row in $p27Commands){$log='docs/evidence/p27-20261003-'+$row[1]+'.log';$p27Runs+=@{phase=$row[0];command=('powershell -NoProfile -File scripts/test-admin-http.ps1 -Phase '+$row[0]+' 2>&1 | Tee-Object -FilePath '+$log+'; exit $LASTEXITCODE');log=$log;sha=Hash $log;exitCode=$row[2];exitEvidence='actual exec completion; first Matrix1 is preflight harness0HTTP, not business FAIL'}}
  @{utc=[DateTime]::UtcNow.ToString('o');vn=[DateTimeOffset]::Now.ToString('o');files=$p27Files;commands=$p27Runs;protectedCount=261;scope='36cases79realHTTP/11success; nativeDBRedis lab, runtime/frozen24-26 unchanged; dashboard directDB fixtures not lifecycle'}|ConvertTo-Json -Depth 8|Set-Content docs/evidence/p27-20261003-after-manifest.json -Encoding utf8
}
$p27Manifest=Get-Content docs/evidence/p27-20261003-after-manifest.json -Raw|ConvertFrom-Json
foreach($file in $p27Manifest.files){Check ((Hash $file.path) -eq $file.sha -and (Hash $file.snapshot) -eq $file.sha) ('After file mismatch '+$file.path)}
foreach($run in $p27Manifest.commands){Check ((Hash $run.log) -eq $run.sha) ('Raw changed '+$run.log)}
$p27Tokens=$null;$p27Errors=$null
foreach($path in @('scripts/test-admin-http.ps1','scripts/validate-p27-evidence.ps1')){[Management.Automation.Language.Parser]::ParseFile((Join-Path $p27Root $path),[ref]$p27Tokens,[ref]$p27Errors)|Out-Null;Check ($p27Errors.Count -eq 0) ('PowerShell syntax '+$path)}
Write-Output ('PASS P27 evidence UTC '+[DateTime]::UtcNow.ToString('o')+' VN '+[DateTimeOffset]::Now.ToString('o')+' 36cases79HTTP11success/status/header/schema/DBeffects;expected/pre-run/SHA/261protected/frozen24-26;identity-inet32-harness-attempt0HTTP;restore/close/Stop;commands/snapshots/parser;offline only, no HTTP rerun')
