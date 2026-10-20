param([switch]$CaptureSnapshot)
$ErrorActionPreference='Stop'
$p25Root=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
if((Get-Location).Path -ne $p25Root -or $p25Root -ne 'D:\WED SNAP'){throw 'Wrong workspace'}
function Check($value,[string]$message){if(-not $value){throw $message}}
function Hash([string]$path){(Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant()}
function Read-Raw([string]$name){@(Get-Content -LiteralPath ('docs/evidence/'+$name)|Where-Object{$_ -like 'P25_RAW *'}|ForEach-Object{$_.Substring(8)|ConvertFrom-Json})}
$p25Before=Read-Raw 'p25-20261003-before-final.log';$p25After=Read-Raw 'p25-20261003-after-final.log';$p25Regression=Read-Raw 'p25-20261003-regression-final.log';$p25Generate=Read-Raw 'p25-20261003-generate-final.log'
function Stage($rows,[string]$stage){@($rows|Where-Object stage -eq $stage)[0]}
$p25BE=Stage $p25Before 'environment';$p25AE=Stage $p25After 'environment';$p25BM=Stage $p25Before 'matrix-before-checks';$p25AM=Stage $p25After 'matrix-before-checks'
foreach($key in @('testSha','bootstrapSha','expectedSha')){Check ($p25BE.$key -eq $p25AE.$key) ('Before/after harness hash mismatch '+$key)}
Check ($p25AE.testSha -eq (Hash 'tests/p25/matrix.ts') -and $p25AE.bootstrapSha -eq (Hash 'tests/p25/bootstrap.ts') -and $p25AE.expectedSha -eq (Hash 'tests/p25/expectations.ts')) 'Current matrix/harness/expected mismatch'
Check (($p25BM.expected|ConvertTo-Json -Depth 10 -Compress) -ceq ($p25AM.expected|ConvertTo-Json -Depth 10 -Compress)) 'Frozen46 matrix/order changed'
foreach($pair in @(@($p25Before,24,22,46),@($p25After,46,0,46),@($p25Regression,20,0,20))){
  $rows=$pair[0];$summary=Stage $rows 'summary';$final=Stage $rows 'finally';$cases=@($rows|Where-Object stage -eq case-result)
  Check ($cases.Count -eq $pair[3] -and @($cases.name|Select-Object -Unique).Count -eq $pair[3]) 'Missing/duplicate cases'
  Check ($summary.passed -eq $pair[1] -and $summary.failed -eq $pair[2] -and @($cases|Where-Object result -eq PASS).Count -eq $pair[1]) 'Summary mismatch'
  Check (@($rows|Where-Object stage -eq HARNESS_FAIL).Count -eq 0) 'Harness failure cannot be runtime PASS'
  Check ($final.hooksRestored -and $final.serverClosed -and $final.clientsRemaining -eq 0 -and $final.peersRemaining -eq 0 -and $final.noDatastore -and $final.counts.datastoreCalls -eq 0) 'I/O cleanup failed'
}
$p25BR=@($p25Before|Where-Object stage -eq request-finish);$p25AR=@($p25After|Where-Object stage -eq request-finish)
Check ($p25BR.Count -eq 32 -and $p25AR.Count -eq 32) 'HTTP32 requests missing'
for($i=0;$i -lt 32;$i++){
  $b=$p25BR[$i];$a=$p25AR[$i]
  foreach($k in @('name','method','path','kind','status','body','bodyBytes','startOrder','finishOrder')){Check ($b.$k -ceq $a.$k) ('Observed HTTP changed '+$k+' '+$a.name)}
  Check ($a.startOrder -eq 2*$i+1 -and $a.finishOrder -eq 2*$i+2 -and $a.elapsedMs -lt 4000) 'HTTP order/timeout mismatch'
  Check ($a.headers.'cache-control' -eq 'no-store' -and $a.headers.'x-content-type-options' -eq 'nosniff') 'Production headers mismatch'
  if($a.kind -in @('malformed-json','malformed-uri')){Check ($a.status -eq 400) 'Measured parser status changed'}
  if($a.method -eq 'HEAD'){Check ($a.bodyBytes -eq 0 -and $a.body -eq '') 'HEAD has wire body'}
  elseif($a.kind -in @('malformed-json','malformed-uri')){Check ($a.body -ceq '{"error":{"code":"INTERNAL_ERROR"}}' -and $a.bodyBytes -eq 35) 'Unsafe/error envelope mismatch'}
  Check ($a.counts.datastoreCalls -eq 0) 'Datastore called'
}
$p25Summary=Stage $p25After 'summary'
Check ($p25Summary.counts.allowedListens -eq 1 -and $p25Summary.counts.allowedDials -eq 32 -and $p25Summary.counts.deniedDials -eq 2 -and $p25Summary.counts.deniedListens -eq 1) 'Loopback isolation counts mismatch'
$p25RM=Stage $p25Regression 'matrix-before-checks';Check ($p25RM.expectedSha -eq (Hash 'tests/p25/regression-expectations.ts')) 'Regression expected mismatch'
Check ((Hash 'tests/p25/regression.ts') -eq (Hash 'docs/evidence/p25-20261003-before-final/regression-with-delta.ts')) 'Regression source changed after pre-run snapshot'
$p25Protected=Get-Content docs/evidence/p25-20261003-protected-before.json -Raw|ConvertFrom-Json
foreach($file in $p25Protected.protected){Check ((Hash $file.path) -eq $file.sha) ('Protected/frozen P24 changed '+$file.path)}
Check ($p25AE.snapshotSha -eq (Hash 'docs/openapi.json')) 'Generated/tested snapshot mismatch'
Check ($p25AE.hashes.'apps/api/src/openapi.ts' -eq (Hash 'apps/api/src/openapi.ts')) 'Tested builder changed'
$p25G=Stage $p25Generate 'generated';Check ($p25G.paths -eq 19 -and $p25G.operations -eq 23) 'Generator count mismatch'
Check ((Get-Content docs/evidence/p25-20261003-stop-final.log -Raw).Contains('PASS stopped/removed only offline OpenAPI lab')) 'Stop proof missing'
$p25Paths=@('apps/api/src/openapi.ts','docs/openapi.json','docs/API.md','infra/compose.parser-lab.yaml','infra/parser-lab.env.example','scripts/test-framework.ps1','scripts/validate-p25-evidence.ps1')+@(rg --files tests/p25)
if($CaptureSnapshot){
  $p25Directory=Join-Path $p25Root 'docs/evidence/p25-20261003-after'
  if(Test-Path -LiteralPath $p25Directory){throw 'After snapshot exists; do not overwrite history'}
  New-Item -ItemType Directory -Path $p25Directory | Out-Null
  $p25Files=@();foreach($path in $p25Paths){$target=Join-Path $p25Directory $path.Replace('/','_').Replace('\','_');Copy-Item -LiteralPath $path -Destination $target;$p25Files+=@{path=$path.Replace('\','/');sha=Hash $path;snapshot=$target.Substring($p25Root.Length+1).Replace('\','/')}}
  @{utc=[DateTime]::UtcNow.ToString('o');files=$p25Files;protectedCount=$p25Protected.protected.Count;scope='filter unit/HTTP loopback parser/contract only; frozen P24/main unchanged'}|ConvertTo-Json -Depth 6|Set-Content docs/evidence/p25-20261003-after-manifest.json -Encoding utf8
}
$p25Manifest=Get-Content docs/evidence/p25-20261003-after-manifest.json -Raw|ConvertFrom-Json
foreach($file in $p25Manifest.files){Check ((Hash $file.path) -eq $file.sha -and (Hash $file.snapshot) -eq $file.sha) ('After snapshot mismatch '+$file.path)}
$p25Tokens=$null;$p25Errors=$null
foreach($path in @('scripts/test-framework.ps1','scripts/validate-p25-evidence.ps1')){[Management.Automation.Language.Parser]::ParseFile((Join-Path $p25Root $path),[ref]$p25Tokens,[ref]$p25Errors)|Out-Null;Check ($p25Errors.Count -eq 0) ('Parser errors '+$path)}
Write-Output ('PASS P25 evidence UTC '+[DateTime]::UtcNow.ToString('o')+' VN '+[DateTimeOffset]::Now.ToString('o')+' 24/22->46/0 same46matrix/expected/test/bootstrap;32HTTP identical400/403/404+HEAD0;20regression;19paths23ops;protected/frozen126;snapshots/parser/Stop;only-loopback/zeroDatastore;offline validation only')
