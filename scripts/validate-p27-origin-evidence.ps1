param([switch]$CaptureSnapshot)
$ErrorActionPreference='Stop'
$p27Root=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
if((Get-Location).Path -ne $p27Root -or $p27Root -ne 'D:\WED SNAP'){throw 'Wrong workspace'}
function Check($value,[string]$message){if(-not $value){throw $message}}
function Hash([string]$path){(Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant()}
function ReadRaw([string]$log,[string]$prefix){@(Get-Content -LiteralPath $log|Where-Object{$_ -like ($prefix+' *')}|ForEach-Object{$_.Substring($prefix.Length+1)|ConvertFrom-Json})}
function Stage($rows,[string]$name){$match=@($rows|Where-Object stage -eq $name);Check ($match.Count -eq 1) ('Stage '+$name);$match[0]}
Write-Output 'COMMAND powershell -NoProfile -File scripts/validate-p27-origin-evidence.ps1 (offline read/hash/parser; no Docker/app/HTTP)'
$p27Base=ReadRaw 'docs/evidence/p27-20261003-matrix-identity-repair.log' 'P27_RAW'
$p27BaseSummary=Stage $p27Base 'summary'
Check ($p27BaseSummary.passed -eq 36 -and $p27BaseSummary.failed -eq 0 -and $p27BaseSummary.requests -eq 79 -and $p27BaseSummary.successCount -eq 11) 'Original36/79/11'
$p27Old=Get-Content docs/evidence/p27-20261003-after-manifest.json -Raw|ConvertFrom-Json
Check ($p27Old.files.Count -eq 9 -and $p27Old.commands.Count -eq 6) 'Original9/6'
foreach($file in $p27Old.files){Check ((Hash $file.snapshot) -eq $file.sha) ('Original frozen copy '+$file.snapshot);if($file.path -ne 'docs/API.md'){Check ((Hash $file.path) -eq $file.sha) ('Original harness changed '+$file.path)}}
foreach($command in $p27Old.commands){Check ((Hash $command.log) -eq $command.sha) ('Original raw changed '+$command.log)}
$p27EarlyHandoff=Get-Content docs/evidence/p27-20261003-handoff-manifest.json -Raw|ConvertFrom-Json
foreach($run in $p27EarlyHandoff.commands){Check ((Hash $run.log) -eq $run.sha) ('Early offline raw changed '+$run.log)}
$p27Protected=Get-Content docs/evidence/p27-20261003-protected-before.json -Raw|ConvertFrom-Json
Check ($p27Protected.protected.Count -eq 261) 'Protected261'
foreach($file in $p27Protected.protected){Check ((Hash $file.path) -eq $file.sha) ('Protected runtime/frozen24-26 '+$file.path)}
Write-Output 'PASS original36/79/11; original9file copies/6commands; early5offline logs;261protected unchanged, API prose supplement allowed'
$p27Rows=ReadRaw 'docs/evidence/p27-20261003-origin-matrix.log' 'P27_ORIGIN_RAW'
$p27Before=Stage $p27Rows 'matrix-before-write';$p27Summary=Stage $p27Rows 'summary';$p27Cleanup=Stage $p27Rows 'cleanup';$p27Finally=Stage $p27Rows 'finally';$p27Identity=Stage $p27Rows 'datastore-identity'
Check ($p27Summary.passed -eq 4 -and $p27Summary.failed -eq 0 -and $p27Summary.requests -eq 8 -and $p27Summary.successCount -eq 4 -and $p27Summary.cleanupOk) 'Origin4/8 scoped'
Check (@($p27Rows|Where-Object{$_.stage -in @('HARNESS_FAIL','CLEANUP_FAIL')}).Count -eq 0) 'Origin harness/cleanup failure'
Check ($p27Identity.database -eq 'wed_snap_admin_http_test' -and $p27Identity.redisDatabase -eq 15 -and $p27Identity.clusterMatchesContainer -and $p27Identity.serverAddressMatchesContainer -and $p27Identity.redisRunMatchesContainer -and $p27Identity.keysBefore -eq 0) 'Origin actual datastore identity'
Check ($p27Before.testSha -eq (Hash tests/p27/origin.ts) -and $p27Before.expectedSha -eq (Hash tests/p27/origin-expectations.ts)) 'Origin executedSHA'
foreach($name in @('origin.ts','origin-expectations.ts')){Check ((Hash ('tests/p27/'+$name)) -eq (Hash ('docs/evidence/p27-20261003-origin-before/'+$name))) 'Origin before source'}
Check ((Hash scripts/test-admin-http-origin.ps1) -eq (Hash docs/evidence/p27-20261003-origin-before/test-admin-http-origin-final.ps1)) 'Runner pre-HTTP copy'
foreach($property in $p27Before.hashes.PSObject.Properties){Check ((Hash $property.Name) -eq $property.Value) ('Origin production hash '+$property.Name)}
$p27Cases=@($p27Rows|Where-Object stage -eq case-result);Check ($p27Cases.Count -eq 4) 'Origin4cases'
for($i=0;$i -lt 4;$i++){Check ($p27Cases[$i].name -ceq $p27Before.expected[$i].name -and $p27Cases[$i].expected -ceq $p27Before.expected[$i].expected -and $p27Cases[$i].result -eq 'PASS') 'Origin independent expected/order'}
$p27Starts=@($p27Rows|Where-Object stage -eq request-start);$p27Finishes=@($p27Rows|Where-Object stage -eq request-finish)
Check ($p27Starts.Count -eq 8 -and $p27Finishes.Count -eq 8) 'Origin8HTTP'
for($i=0;$i -lt 8;$i++){
  $a=$p27Starts[$i];$b=$p27Finishes[$i]
  Check ($a.request -eq $i+1 -and $a.startOrder -eq 2*$i+1 -and $b.finishOrder -eq 2*$i+2 -and $a.method -ceq $b.method -and $a.path -ceq $b.path -and $b.status -eq $a.expectedStatus) 'Origin HTTP order/status'
  Check ($b.elapsedMs -lt 5000 -and $b.bodyBytes -le 65536 -and $b.headers.cacheControl -eq 'no-store' -and $b.headers.nosniff -eq 'nosniff') 'Origin HTTP bounds/headers'
  if($a.expectedCode){Check ($b.body.error.code -ceq $a.expectedCode) 'Origin error'}
}
Check ($p27Starts[3].method -eq 'DELETE' -and $p27Starts[3].origin -eq 'missing' -and $p27Starts[3].csrfHeader -eq 'correct') 'DELETE missingOrigin topology'
Check ($p27Starts[4].method -eq 'DELETE' -and $p27Starts[4].origin -eq 'wrong' -and $p27Starts[4].csrfHeader -eq 'correct') 'DELETE wrongOrigin topology'
Check ($p27Starts[5].path -eq '/api/v1/admin/logout' -and $p27Starts[5].origin -eq 'wrong' -and $p27Starts[5].csrfHeader -eq 'missing' -and $p27Starts[5].bodyKeys -contains 'csrf') 'Logout wrongOrigin fallback topology'
foreach($i in @(3,4,5)){Check ($p27Finishes[$i].status -eq 403 -and $p27Finishes[$i].body.error.code -eq 'CSRF_INVALID') '403 concrete Origin controls'}
Check (@($p27Rows|Where-Object stage -eq db-rejection).Count -eq 2) 'Origin DB rejection readbacks'
Check ($p27Cleanup.fixtureRowsRestored -and $p27Cleanup.settingsBudgetDeepEqual -and $p27Cleanup.redisKeysAfter -eq 0 -and $p27Cleanup.keysRemoved -eq 3 -and $p27Cleanup.ownAdmin -eq 1 -and $p27Cleanup.ownSessions -eq 1 -and $p27Cleanup.ownCampaigns -eq 1 -and $p27Cleanup.ownAudits -eq 2 -and $p27Cleanup.ownJobs -eq 0 -and $p27Cleanup.ownAssets -eq 0 -and $p27Cleanup.ownLeases -eq 0 -and $p27Cleanup.noReset -and $p27Cleanup.noMediaCreated) 'Origin own fixtures restoration'
foreach($property in $p27Cleanup.rows.PSObject.Properties){Check ($property.Value -eq $p27Before.beforeCounts.($property.Name)) 'Origin rows restored'}
Check ($p27Finally.hooksRestored -and $p27Finally.serverClosed -and $p27Finally.socketsRemaining -eq 0 -and $p27Finally.peersRemaining -eq 0 -and $p27Finally.cleanupOk -and $p27Finally.counters.httpDials -eq 8 -and $p27Finally.counters.redisDials -eq 2 -and $p27Finally.counters.allowedListens -eq 1 -and $p27Finally.counters.deniedDials -eq 0) 'Origin closed/isolation'
Check ((Get-Content docs/evidence/p27-20261003-origin-stop.log -Raw).Contains('PASS stopped/removed only admin HTTP lab containers')) 'Origin own Stop'
Check ((Get-Content docs/evidence/p27-20261003-origin-start-authorized.log -Raw).Contains('relation "adminuser" does not exist')) 'Keep native argv guardFAIL, no runtime claim'
Check ((Get-Content docs/evidence/p27-20261003-origin-start-stdin.log -Raw).Contains('PASS pre-migrate readonly empty application tables=13')) 'Stdin empty guard passed without reset'
Check ((Get-Content docs/evidence/p27-20261003-origin-start-stdin.log -Raw).Contains('No pending migrations to apply.')) 'Retained schema not reset'
Write-Output 'PASS supplement4cases8HTTP specific DELETE/logout Origin403/DB/token controls;restore/close/Stop;total40cases87HTTP, no original36 rerun'
$p27Document=Get-Content docs/openapi.json -Raw|ConvertFrom-Json
Check ((Hash docs/openapi.json) -eq 'f4b6cd7bbf6631f89265def504fed869e6f1aa6853303c47e5f3c7c39540b16a') 'Snapshot unchanged'
Check (@($p27Document.paths.PSObject.Properties).Count -eq 19 -and @($p27Document.components.schemas.PSObject.Properties).Count -eq 20) 'Snapshot inventory'
$p27Readme=Get-Content README.md -Raw;$p27Section=(($p27Readme -split '## 6\.17\.')[1] -split '## 7\.')[0]
$p27Blocks=[regex]::Matches($p27Section,'(?s)```powershell\s*(.*?)```');Check ($p27Blocks.Count -eq 2) 'README2blocks'
foreach($block in $p27Blocks){$tokens=$null;$errors=$null;[Management.Automation.Language.Parser]::ParseInput($block.Groups[1].Value,[ref]$tokens,[ref]$errors)|Out-Null;Check ($errors.Count -eq 0 -and $block.Groups[1].Value.TrimStart().StartsWith('cd "D:\WED SNAP"')) 'README syntax/cd'}
$p27Files=@('README.md','docs/API.md','docs/PROGRESS.md','docs/TEST_REPORT.md','docs/AUDIT_TIEN_DO.md','tests/p27/origin.ts','tests/p27/origin-expectations.ts','scripts/test-admin-http-origin.ps1','scripts/validate-p27-origin-evidence.ps1')
$p27Commands=@(@('Start','start',1),@('Start','start-authorized',1),@('Stop','stop-guard-attempt',0),@('Start','start-stdin',0),@('Matrix','matrix',0),@('Typecheck','typecheck',0),@('Logs','containers',0),@('Stop','stop',0))
if($CaptureSnapshot){
  $dir='docs/evidence/p27-20261003-origin-after';$path='docs/evidence/p27-20261003-final-manifest.json';Check (-not (Test-Path $dir) -and -not (Test-Path $path)) 'Refuse overwrite final history';New-Item -ItemType Directory -Path $dir|Out-Null
  $files=@();foreach($file in $p27Files){$copy=$dir+'/'+$file.Replace('/','_');Copy-Item -LiteralPath $file -Destination $copy;$files+=@{path=$file;snapshot=$copy;sha=Hash $file}}
  $runs=@();foreach($row in $p27Commands){$log='docs/evidence/p27-20261003-origin-'+$row[1]+'.log';$runs+=@{command=('powershell -NoProfile -File scripts/test-admin-http-origin.ps1 -Phase '+$row[0]+' 2>&1 | Tee-Object -FilePath '+$log+'; exit $LASTEXITCODE');log=$log;sha=Hash $log;exitCode=$row[2];scope='supplement only; failed Start attempts before HTTP/write fixture, no production FAIL'}}
  @{utc=[DateTime]::UtcNow.ToString('o');vn=[DateTimeOffset]::Now.ToString('o');files=$files;commands=$runs;originalManifest='docs/evidence/p27-20261003-after-manifest.json';earlyOfflineManifest='docs/evidence/p27-20261003-handoff-manifest.json';protectedCount=261;scope='36original+4supplement=40cases;79+8=87HTTP,11targetsuccess;runtime unchanged/main not applied;pending independent audit'}|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $path -Encoding utf8
}
$p27Final=Get-Content docs/evidence/p27-20261003-final-manifest.json -Raw|ConvertFrom-Json
foreach($file in $p27Final.files){Check ((Hash $file.path) -eq $file.sha -and (Hash $file.snapshot) -eq $file.sha) ('Final source snapshot '+$file.path)}
foreach($run in $p27Final.commands){Check ((Hash $run.log) -eq $run.sha) ('Final raw '+$run.log)}
Write-Output ('PASS P27 final evidence UTC '+[DateTime]::UtcNow.ToString('o')+' VN '+[DateTimeOffset]::Now.ToString('o')+'40cases87HTTP/11targetsuccess/typecheck/261protected/original frozen/new9files8commands/README;offline only')
