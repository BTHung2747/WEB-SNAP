param([switch]$CaptureSnapshot)
$ErrorActionPreference='Stop'
$root30=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
if((Get-Location).Path -ne $root30 -or $root30 -ne 'D:\WED SNAP'){throw 'Native repository path required'}
$stem30='docs/evidence/p30-20261004'
function Require30($ok,$message){if(-not $ok){throw $message}}
function Hash30($path){(Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant()}
function Records30($path,$prefix){@(Get-Content -LiteralPath $path|Where-Object{$_.StartsWith($prefix)}|ForEach-Object{ $_.Substring($prefix.Length)|ConvertFrom-Json })}
function Json30($path,$value){[IO.File]::WriteAllText((Join-Path $root30 $path),($value|ConvertTo-Json -Depth 100)+"`n",(New-Object Text.UTF8Encoding($false)))}
$protected30=Get-Content "$stem30-protected-before.json" -Raw|ConvertFrom-Json
Require30 ($protected30.protected.Count -eq 915) 'Protected inventory'
Require30 (@($protected30.protected.path|Select-Object -Unique).Count -eq 915) 'Duplicate protected path'
foreach($p30 in $protected30.protected){Require30 ((Hash30 $p30.path) -eq $p30.sha) ('Protected changed '+$p30.path)}
$runs30=@();$allHttp30=0
foreach($r30 in @('cleanup-before','cleanup-typecheck-before','cleanup-ui-contract-before','cleanup-final')){
 $raw30=Records30 "$stem30-$r30.log" 'P30_RAW '
 $http30=@($raw30|Where-Object stage -eq http)
 $cleanup30=@($raw30|Where-Object stage -eq cleanup-pass)
 Require30 ($cleanup30.Count -eq 1 -and $cleanup30[0].requestCount -eq $http30.Count) 'HTTP/cleanup count mismatch'
 Require30 ($cleanup30[0].settingsDeepEqual -and $cleanup30[0].budgetDeepEqual -and $cleanup30[0].chargedUnchanged) 'Restore mismatch'
 Require30 (@($cleanup30[0].counts.PSObject.Properties|Where-Object Value -ne 0).Count -eq 0) 'Fixture rows remain'
 Require30 (@($raw30|Where-Object stage -eq close-pass).Count -eq 1) 'Missing close'
 foreach($h30 in $http30){Require30 ($h30.startOrder -lt $h30.finishOrder -and $h30.noStore -and $h30.nosniff) 'HTTP order/headers'}
 $allHttp30+=$http30.Count
 $runs30+=@{run=$r30;http=$http30.Count;browserObservations=@($raw30|Where-Object stage -eq browser).Count;cleanup=$cleanup30[0]}
}
Require30 ($allHttp30 -eq 170) 'Bounded HTTP total'
$baseline30=Records30 "$stem30-cleanup-before.log" 'P30_RAW '
$baselineMatrix30=@($baseline30|Where-Object stage -eq matrix-summary)[0]
Require30 ($baselineMatrix30.cases -eq 2 -and $baselineMatrix30.fail -eq 2) 'Baseline missing feature not preserved'
$final30=Records30 "$stem30-cleanup-final.log" 'P30_RAW '
$matrix30=@($final30|Where-Object stage -eq matrix-summary)[0]
Require30 ($matrix30.cases -eq 22 -and $matrix30.pass -eq 22 -and $matrix30.fail -eq 0) 'Final matrix'
$browser30=@($final30|Where-Object stage -eq browser)
$names30=@('browser-live-window','browser-invalid','browser-empty','browser-narrow-focus','active-tab-preserve','race-new-window','race-logout','race-unmount','server-invalid-window','default-button','expired-admin-statistics')
Require30 ($browser30.Count -eq 13 -and @($browser30.name|Select-Object -Unique).Count -eq 11) 'Browser observations/unique'
foreach($n30 in $names30){Require30 (@($browser30|Where-Object{$_.name -eq $n30 -and $_.result -eq 'PASS'}).Count -ge 1) ('Missing final browser '+$n30)}
Require30 (@($browser30|Where-Object result -ne PASS).Count -eq 0) 'Final browser FAIL'
$oldBrowser30=Records30 "$stem30-cleanup-ui-contract-before.log" 'P30_RAW '
Require30 (@($oldBrowser30|Where-Object{$_.stage -eq 'browser' -and $_.name -eq 'active-tab-preserve' -and $_.result -eq 'FAIL'}).Count -eq 1) 'Missing UI baseline FAIL'
$supplement30=@(Records30 "$stem30-supplement.log" 'P30_SUPPLEMENT ')[0]
Require30 ($supplement30.cases -eq 7 -and $supplement30.pass -eq 7 -and $supplement30.fail -eq 0) 'Supplement'
$contractBefore30=@(Records30 "$stem30-contracts.log" 'P30_CONTRACT ')[0]
Require30 ($contractBefore30.pass -eq 4 -and $contractBefore30.fail -eq 1) 'Missing contract FAIL'
$contract30=@(Records30 "$stem30-checks-final.log" 'P30_CONTRACT ')[0]
Require30 ($contract30.pass -eq 5 -and $contract30.fail -eq 0 -and $contract30.docSHA -eq (Hash30 'docs/openapi.json')) 'Contract/current generated SHA'
Require30 ((Hash30 'tests/p30/expected.json') -eq 'f7b1a370b26a9b34458be551102b873f7722c5f67411c981455cbb6bab9c5ee7') 'Original expected changed'
foreach($phase30 in @(@('checks-final','FinalizeChecks'),@('cleanup-final','Cleanup'),@('stop-final','Stop'))){Require30 ((Get-Content "$stem30-$($phase30[0]).log" -Raw).Contains('P30_COMMAND_EXIT 0 '+$phase30[1]+' UTC')) 'Missing exit0'}
$environment30=@($final30|Where-Object stage -eq environment)[0]
Require30 ($environment30.sourceSHA -eq 'e5f86036ee5f76f801b0ac91a35d7f42f68a01c0d76228aabc6609d37734effe') 'Final runtime fingerprint'
foreach($h30 in $environment30.hashes.PSObject.Properties){Require30 ((Hash30 $h30.Name) -eq $h30.Value) ('Current runtime source changed '+$h30.Name)}
foreach($s30 in @('scripts/test-ad-statistics.ps1','scripts/verify-ad-statistics-evidence.ps1')){$tokens30=$null;$errors30=$null;[void][Management.Automation.Language.Parser]::ParseFile((Join-Path $root30 $s30),[ref]$tokens30,[ref]$errors30);Require30 ($errors30.Count -eq 0) ('PowerShell parser '+$s30)}
$manifestPath30="$stem30-manifest-final.json"
if($CaptureSnapshot){
 Require30 (-not (Test-Path -LiteralPath $manifestPath30)) 'Never overwrite frozen evidence manifest'
 foreach($p30 in $protected30.allowed){$dest30=Join-Path "$stem30-source-final" $p30;New-Item -ItemType Directory -Force -Path (Split-Path $dest30)|Out-Null;Copy-Item -LiteralPath $p30 -Destination $dest30}
 $summary30=@{utc=[DateTime]::UtcNow.ToString('o');vn=[DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(7)).ToString('o');scope='Offline evidence/hash parser; no runtime/HTTP/browser rerun';protected=915;matrix=@{baseline=@{cases=2;fail=2};final=@{cases=22;pass=22}};supplement=@{cases=7;pass=7};contracts=@{cases=5;pass=5};browser=@{unique=11;observations=13;pass=13;names=$names30};runs=$runs30;businessHttpAllRuns=170;finalBusinessHttp=63;finalSourceSHA=$environment30.sourceSHA;snapshotSHA=$contract30.docSHA}
 Json30 "$stem30-summary-final.json" $summary30
 $files30=@(Get-ChildItem docs/evidence -Recurse -File|Where-Object{$_.FullName.Contains('p30-20261004') -and $_.Name -notmatch '(manifest-final|verification|offline-verify)'})+@(Get-ChildItem tests/p30 -Recurse -File)+@(Get-Item scripts/test-ad-statistics.ps1,scripts/verify-ad-statistics-evidence.ps1,infra/compose.ad-statistics-lab.yaml,infra/ad-statistics-lab.env.example)
 $artifacts30=@($files30|Sort-Object FullName -Unique|ForEach-Object{@{path=$_.FullName.Substring($root30.Length+1).Replace('\','/');sha=Hash30 $_.FullName}})
 $code30=@($environment30.hashes.PSObject.Properties|ForEach-Object{@{path=$_.Name;sha=$_.Value}})+@(@{path='docs/openapi.json';sha=Hash30 'docs/openapi.json'})
 Json30 $manifestPath30 @{utc=[DateTime]::UtcNow.ToString('o');historicalScopes='19-29 frozen/protected, no reruns; live handoff prose stored as copies';sourceSHA=$environment30.sourceSHA;currentCode=$code30;artifacts=$artifacts30}
}
Require30 (Test-Path -LiteralPath $manifestPath30) 'Capture own final manifest once after handoff documents'
$manifest30=Get-Content $manifestPath30 -Raw|ConvertFrom-Json
foreach($h30 in @($manifest30.currentCode)+@($manifest30.artifacts)){Require30 ((Hash30 $h30.path) -eq $h30.sha) ('Evidence/source mismatch '+$h30.path)}
Write-Host ('PASS offline30 protected915 artifacts'+$manifest30.artifacts.Count+' matrix22 supplemental7 contract5 browser11unique/13PASSobservations HTTP63final/170all ownCleanup/Stop/typecheck; no runtime rerun UTC '+[DateTime]::UtcNow.ToString('o'))
