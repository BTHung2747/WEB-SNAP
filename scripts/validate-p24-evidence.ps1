param([switch]$CaptureSnapshot)
$ErrorActionPreference='Stop'
$p24Root=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
if((Get-Location).Path -ne $p24Root -or $p24Root -ne 'D:\WED SNAP'){throw 'Wrong workspace'}
function Check($condition,[string]$message){if(-not $condition){throw $message}}
function Hash([string]$path){(Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant()}
function Raw([string]$name){@(Get-Content -LiteralPath ('docs/evidence/'+$name)|Where-Object{$_.StartsWith('P24_RAW ')}|ForEach-Object{$_.Substring(8)|ConvertFrom-Json})}
$before=Raw 'p24-20261003-before.log';$after=Raw 'p24-20261003-after-final.log';$generate=Raw 'p24-20261003-generate-final-id.log'
$bm=@($before|Where-Object stage -eq 'matrix-before-checks')[0];$am=@($after|Where-Object stage -eq 'matrix-before-checks')[0]
$be=@($before|Where-Object stage -eq 'environment')[0];$ae=@($after|Where-Object stage -eq 'environment')[0];$ge=@($generate|Where-Object stage -eq 'environment')[0]
Check (($bm.expected|ConvertTo-Json -Depth 8 -Compress) -ceq ($am.expected|ConvertTo-Json -Depth 8 -Compress)) 'Matrix/order/expected changed'
foreach($property in @('testSha','bootstrapSha')){Check ($be.$property -eq $ae.$property) 'Harness hash changed'}
Check ($bm.expectedSha -eq $am.expectedSha -and $am.expectedSha -eq (Hash 'tests/p24/expectations.ts')) 'Independent expected source changed'
Check ($ae.testSha -eq (Hash 'tests/p24/contracts.ts') -and $ae.bootstrapSha -eq (Hash 'tests/p24/bootstrap.ts')) 'Executed test/bootstrap mismatch'
foreach($pair in @(@($before,3,16),@($after,19,0))){
  $rows=$pair[0];$results=@($rows|Where-Object stage -eq 'case-result');$summary=@($rows|Where-Object stage -eq 'summary')
  Check ($results.Count -eq 19 -and @($results.name|Select-Object -Unique).Count -eq 19 -and $summary.Count -eq 1) 'Missing/duplicate case or summary'
  Check ($summary[0].passed -eq $pair[1] -and $summary[0].failed -eq $pair[2] -and @($results|Where-Object result -eq 'PASS').Count -eq $pair[1]) 'Results disagree'
  $final=@($rows|Where-Object stage -eq 'finally')[0]
  Check ($final.hooksRestored -and $final.noListen -and $final.noDatastore -and $final.noDial) 'Offline finally FAIL'
  Check (@($rows|Where-Object stage -eq 'HARNESS_FAIL').Count -eq 0) 'Harness error is not a contract failure'
}
foreach($rows in @($before,$after,$generate)){
  foreach($event in $rows|Where-Object{$_.counts}){Check ($event.counts.datastoreCalls -eq 0 -and $event.counts.listens -eq 0 -and $event.counts.dials -eq 0) 'Forbidden side effect'}
}
foreach($p in $be.hashes.PSObject.Properties){
  $beforePath=if($p.Name -match '/controllers/'){$p.Name}else{'docs/evidence/p24-20261003-before/'+$p.Name.Replace('/','__')}
  Check ((Hash $beforePath) -eq $p.Value) ('Before docs snapshot mismatch '+$p.Name)
}
foreach($p in $ae.hashes.PSObject.Properties){Check ((Hash $p.Name) -eq $p.Value -and $ge.hashes.($p.Name) -eq $p.Value) ('Executed/factory/current mismatch '+$p.Name)}
$protected=Get-Content docs/evidence/p24-20261003-protected-before.json -Raw|ConvertFrom-Json
foreach($p in $protected.protected){Check ((Hash $p.path) -eq $p.sha) ('Protected source changed '+$p.path)}
Check ($protected.protected.Count -eq 71) 'Protected inventory mismatch'
Check ($ae.snapshotSha -eq (Hash 'docs/openapi.json')) 'Snapshot differs from final tested file'
Check ($be.snapshotSha -eq (Hash 'tests/p24/backlog.baseline.json') -and $be.snapshotSha -eq (Hash 'docs/evidence/p24-20261003-before/docs__openapi.json')) 'Before snapshot not preserved'
$doc=Get-Content docs/openapi.json -Raw|ConvertFrom-Json
$operations=0;foreach($p in $doc.paths.PSObject.Properties){foreach($m in @('get','head','post','put','delete')){if($p.Value.$m){$operations++}}}
Check (@($doc.paths.PSObject.Properties).Count -eq 19 -and $operations -eq 23) 'Inventory mismatch'
Check (@($doc.components.schemas.PSObject.Properties).Count -eq 12) 'Schema inventory mismatch'
Check (@($generate|Where-Object stage -eq 'generated')[0].noManualSnapshot) 'Generator provenance missing'
Check ((Get-Content docs/evidence/p24-20261003-stop-final.log -Raw) -match 'PASS stopped/removed only offline OpenAPI lab') 'Guarded final Stop missing'
foreach($file in @('scripts/test-openapi.ps1','scripts/validate-p24-evidence.ps1')){$tokens=$null;$errors=$null;[void][Management.Automation.Language.Parser]::ParseFile((Resolve-Path $file),[ref]$tokens,[ref]$errors);Check ($errors.Count -eq 0) ('Parser FAIL '+$file)}
$paths=@('apps/api/src/openapi.ts','apps/api/src/main.ts','docs/openapi.json','tests/p24/contracts.ts','tests/p24/expectations.ts','tests/p24/bootstrap.ts','tests/p24/generate.ts','tests/p24/tsconfig.json','tests/p24/backlog.baseline.json','scripts/test-openapi.ps1','scripts/validate-p24-evidence.ps1','infra/compose.openapi-lab.yaml','infra/openapi-lab.env.example')
if($CaptureSnapshot){
  $dir='docs/evidence/p24-20261003-after';New-Item -ItemType Directory -Path $dir -Force|Out-Null
  foreach($p in $paths){Copy-Item -LiteralPath $p -Destination ($dir+'/'+$p.Replace('/','__'))}
  @{utc=[DateTime]::UtcNow.ToString('o');vn=[DateTimeOffset]::Now.ToString('o');source=@($paths|ForEach-Object{@{path=$_;sha=Hash $_}});protected=@($protected.protected);counts=@{paths=19;operations=23;targetPaths=11;targetOperations=12;schemas=12;tests=19};baseline='3PASS/16FAIL';final='19PASS/0FAIL';scope='offline public OpenAPI only; admin/ads/behavior protected; no lifecycle/main runtime'}|ConvertTo-Json -Depth 7|Set-Content docs/evidence/p24-20261003-after-manifest.json -Encoding UTF8
}
$manifest=Get-Content docs/evidence/p24-20261003-after-manifest.json -Raw|ConvertFrom-Json
foreach($p in $manifest.source){Check ((Hash $p.path) -eq $p.sha -and (Hash ('docs/evidence/p24-20261003-after/'+$p.path.Replace('/','__'))) -eq $p.sha) ('After manifest mismatch '+$p.path)}
Write-Host ('PASS evidence UTC '+[DateTime]::UtcNow.ToString('o')+' VN '+[DateTimeOffset]::Now.ToString('o')+' JSON '+$before.Count+'/'+$after.Count+'/'+$generate.Count+' same19matrix/test/bootstrap/expectedSHA;3/16->19/0;19paths23ops12schemas;protected71/source/snapshots/parser/Stop;datastoreCalls/listens/dials0;offline validation only')
