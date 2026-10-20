param([switch]$CaptureSnapshot)
$ErrorActionPreference='Stop'
$p26Root=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
if((Get-Location).Path -ne $p26Root -or $p26Root -ne 'D:\WED SNAP'){throw 'Wrong workspace'}
function Check($value,[string]$message){if(-not $value){throw $message}}
function Hash([string]$path){(Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant()}
function Raw([string]$name){@(Get-Content -LiteralPath ('docs/evidence/'+$name)|Where-Object{$_ -like 'P26_RAW *'}|ForEach-Object{$_.Substring(8)|ConvertFrom-Json})}
function Stage($rows,[string]$name){$matches=@($rows|Where-Object stage -eq $name);Check ($matches.Count -eq 1) ('Expected one raw stage '+$name);$matches[0]}
$p26Before=Raw 'p26-20261003-before.log';$p26After=Raw 'p26-20261003-after-final.log';$p26Generated=Raw 'p26-20261003-generate-final.log'
$p26BE=Stage $p26Before 'environment';$p26AE=Stage $p26After 'environment'
foreach($key in @('testSha','bootstrapSha','expectedSha','prismaSchemaSha','frameworkSourceSha')){Check ($p26BE.$key -eq $p26AE.$key) ('Before/after hash mismatch '+$key)}
foreach($pair in @(@('testSha','tests/p26/matrix.ts'),@('bootstrapSha','tests/p26/bootstrap.ts'),@('expectedSha','tests/p26/expectations.ts'))){Check ($p26AE.($pair[0]) -eq (Hash $pair[1])) ('Current harness mismatch '+$pair[1])}
$p26BM=Stage $p26Before 'matrix-before-checks';$p26AM=Stage $p26After 'matrix-before-checks'
Check (($p26BM.expected|ConvertTo-Json -Depth 12 -Compress) -ceq ($p26AM.expected|ConvertTo-Json -Depth 12 -Compress)) 'Frozen23 matrix/order changed'
foreach($pair in @(@($p26Before,3,20),@($p26After,23,0))){
  $rows=$pair[0];$summary=Stage $rows 'summary';$final=Stage $rows 'finally';$cases=@($rows|Where-Object stage -eq case-result)
  Check ($cases.Count -eq 23 -and @($cases.name|Select-Object -Unique).Count -eq 23) 'Missing/duplicate cases'
  Check ($summary.passed -eq $pair[1] -and $summary.failed -eq $pair[2] -and @($cases|Where-Object result -eq PASS).Count -eq $pair[1]) 'Summary mismatch'
  Check (@($rows|Where-Object stage -eq HARNESS_FAIL).Count -eq 0) 'Harness failure is not a contract verdict'
  Check ($final.hooksRestored -and $final.noDatastore -and $final.noDial -and $final.noListen) 'Hooks/I/O cleanup failed'
  foreach($record in @($rows|Where-Object{$_.counts})){foreach($name in @('datastoreCalls','dials','listens')){Check ($record.counts.$name -eq 0) ('I/O called '+$name)}}
  Check ($summary.counts.prismaConstructors -eq 1 -and $summary.counts.redisConstructors -eq 1 -and $summary.counts.queueConstructors -eq 1) 'Constructor deny counts mismatch'
}
$p26BX=@($p26Before|Where-Object stage -eq production-expression);$p26AX=@($p26After|Where-Object stage -eq production-expression)
Check ($p26BX.Count -eq 3 -and $p26AX.Count -eq 3) 'Production AST evidence missing'
for($i=0;$i -lt 3;$i++){foreach($key in @('path','method','sourceSha','expression','expressionSha')){Check ($p26BX[$i].$key -ceq $p26AX[$i].$key) ('Production expression changed '+$key)}}
Check ($p26AE.snapshotSha -eq (Hash 'docs/openapi.json') -and $p26AE.hashes.'apps/api/src/openapi.ts' -eq (Hash 'apps/api/src/openapi.ts')) 'Generated/tested source mismatch'
$p26G=Stage $p26Generated 'generated';Check ($p26G.paths -eq 19 -and $p26G.operations -eq 23 -and $p26G.noManualSnapshot) 'Generator inventory mismatch'
$p26Protected=Get-Content docs/evidence/p26-20261003-protected-before.json -Raw|ConvertFrom-Json
Check ($p26Protected.protected.Count -eq 193) 'Protected inventory changed'
foreach($file in $p26Protected.protected){Check ((Hash $file.path) -eq $file.sha) ('Protected/frozen history changed '+$file.path)}
Check ((Get-Content docs/evidence/p26-20261003-stop-final.log -Raw).Contains('PASS stopped/removed only offline OpenAPI lab')) 'Stop proof missing'
$p26Commands=@(
  @('Start','start-before-authorized',0),@('Typecheck','typecheck-before',0),@('Matrix','before',1),@('Stop','stop-before-fix',0),
  @('Start','start-after',0),@('Typecheck','typecheck-final',0),@('Generate','generate-final',0),@('Matrix','after-final',0),@('Logs','containers-final',0),@('Stop','stop-final',0)
)
$p26Paths=@('apps/api/src/openapi.ts','docs/openapi.json','docs/API.md','infra/compose.admin-contract-lab.yaml','infra/admin-contract-lab.env.example','scripts/test-admin-contract.ps1','scripts/validate-p26-evidence.ps1')+@(rg --files tests/p26)
if($CaptureSnapshot){
  $p26Directory=Join-Path $p26Root 'docs/evidence/p26-20261003-after'
  if((Test-Path -LiteralPath $p26Directory) -or (Test-Path docs/evidence/p26-20261003-after-manifest.json)){throw 'After snapshot exists; do not overwrite history'}
  New-Item -ItemType Directory -Path $p26Directory|Out-Null
  $p26Files=@();foreach($path in $p26Paths){$target=Join-Path $p26Directory $path.Replace('/','_').Replace('\','_');Copy-Item -LiteralPath $path -Destination $target;$p26Files+=@{path=$path.Replace('\','/');sha=Hash $path;snapshot=$target.Substring($p26Root.Length+1).Replace('\','/')}}
  $p26Runs=@();foreach($row in $p26Commands){$log='docs/evidence/p26-20261003-'+$row[1]+'.log';Check (Test-Path $log) ('Raw missing '+$log);$p26Runs+=@{phase=$row[0];command=('powershell -NoProfile -File scripts/test-admin-contract.ps1 -Phase '+$row[0]+' 2>&1 | Tee-Object -FilePath '+$log+'; exit $LASTEXITCODE');log=$log;sha=Hash $log;exitCode=$row[2];exitEvidence='actual exec tool completion in this session; baseline1 is expected contract FAIL'}}
  @{utc=[DateTime]::UtcNow.ToString('o');vn=[DateTimeOffset]::Now.ToString('o');files=$p26Files;commands=$p26Runs;protectedCount=193;scope='contract metadata/pure validators/AST expression only; no HTTP/business/datastore; public12/old12schemas/security preserved; frozen24/25 unchanged'}|ConvertTo-Json -Depth 8|Set-Content docs/evidence/p26-20261003-after-manifest.json -Encoding utf8
}
$p26Manifest=Get-Content docs/evidence/p26-20261003-after-manifest.json -Raw|ConvertFrom-Json
foreach($file in $p26Manifest.files){Check ((Hash $file.path) -eq $file.sha -and (Hash $file.snapshot) -eq $file.sha) ('After snapshot mismatch '+$file.path)}
foreach($run in $p26Manifest.commands){Check ((Hash $run.log) -eq $run.sha) ('Raw modified '+$run.log)}
$p26Tokens=$null;$p26Errors=$null
foreach($path in @('scripts/test-admin-contract.ps1','scripts/validate-p26-evidence.ps1')){[Management.Automation.Language.Parser]::ParseFile((Join-Path $p26Root $path),[ref]$p26Tokens,[ref]$p26Errors)|Out-Null;Check ($p26Errors.Count -eq 0) ('Parser errors '+$path)}
Write-Output ('PASS P26 evidence UTC '+[DateTime]::UtcNow.ToString('o')+' VN '+[DateTimeOffset]::Now.ToString('o')+' 3/20->23/0 same23matrix/test/bootstrap/expected;3productionAST;19paths23ops;public12/old12schema/security preservation case;protected193/frozen24+25;zeroDatastore/dial/listen;hooks/snapshots/commands/parser/Stop;offline validation only')
