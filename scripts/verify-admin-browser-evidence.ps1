param([switch]$CaptureSnapshot)
$ErrorActionPreference='Stop'
$root=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
if((Get-Location).Path -ne $root -or $root -ne 'D:\WED SNAP'){throw 'Wrong repository'}
$proof=Get-Content docs/evidence/p29-20261004-protected-before.json -Raw|ConvertFrom-Json
foreach($f in $proof.protected){if((Get-FileHash -LiteralPath $f.path).Hash.ToLowerInvariant() -ne $f.sha){throw ('Protected mismatch '+$f.path)}}
$raw=@(Get-Content docs/evidence/p29-20261004-cleanup-final.log | Where-Object {$_ -match '^P29_RAW '} | ForEach-Object {$_.Substring(8)|ConvertFrom-Json})
$expected=Get-Content tests/p29/expected.json -Raw|ConvertFrom-Json
$matrixBefore=Get-Content docs/evidence/p29-20261004-matrix-before.json -Raw|ConvertFrom-Json
$expectedHash=@($matrixBefore|Where-Object path -eq 'tests/p29/expected.json')[0].sha
if((Get-FileHash tests/p29/expected.json).Hash.ToLowerInvariant() -ne $expectedHash){throw 'Original independent expected changed'}
$caseRecords=@($raw|Where-Object{$_.stage -eq 'browser' -and $_.kind -eq 'case'})
foreach($e in $expected.cases){$last=@($caseRecords|Where-Object name -eq $e[0])[-1];if(-not $last -or $last.result -ne 'PASS' -or $last.expected -ne $e[1]){throw ('Independent case expected mismatch '+$e[0])}}
$responsive=@($raw|Where-Object{$_.stage -eq 'browser' -and $_.kind -eq 'responsive-case'})
if($responsive.Count -ne 2 -or $responsive[0].result -ne 'FAIL' -or $responsive[0].viewport.scrollWidth -ne 470 -or $responsive[1].result -ne 'PASS' -or $responsive[1].viewport.scrollWidth -ne 345 -or $responsive[0].expected -ne $responsive[1].expected){throw 'CSS harness missing-import baseline/final evidence mismatch'}
$http=@($raw|Where-Object stage -eq 'http')
if($http.Count -ne 95 -or @($http|Select-Object -ExpandProperty num -Unique).Count -ne 95 -or @($http|Where-Object{-not $_.noStore -or -not $_.nosniff}).Count){throw 'Real HTTP inventory/headers mismatch'}
if(@($http|Where-Object{$_.path -match 'jobs|downloads|health|ad-events'}).Count){throw 'Forbidden HTTP path'}
$clean=@($raw|Where-Object stage -eq 'cleanup-pass')[-1];$close=@($raw|Where-Object stage -eq 'close-pass')[-1]
if(-not $clean.settingsDeepEqual -or -not $clean.budgetDeepEqual -or -not $clean.chargedUnchanged -or $clean.ownedKeysRemoved -ne 2 -or @($clean.counts.PSObject.Properties|Where-Object Value -ne 0).Count -or $clean.counters.deniedDials -ne 0 -or $clean.counters.deniedListens -ne 0 -or -not $close.hooksRestored -or -not $close.serverClosed -or -not $close.datastoreClientsClosed){throw 'Cleanup/restore/close evidence mismatch'}
$type=Get-Content docs/evidence/p29-20261004-typecheck-attempt2.log -Raw
$stop=Get-Content docs/evidence/p29-20261004-stop-final.log -Raw
if($type -notmatch 'PASS API/shared/web/p29 checks sequential' -or $stop -notmatch 'P29_COMMAND_EXIT 0 Stop'){throw 'Typecheck/Stop completion absent'}
if($CaptureSnapshot){
 $snap='docs/evidence/p29-20261004-handoff';if(Test-Path -LiteralPath $snap){throw 'Refuse overwrite handoff snapshot'};New-Item -ItemType Directory -Path $snap|Out-Null
 foreach($p in @('docs/PROGRESS.md','docs/TEST_REPORT.md','docs/AUDIT_TIEN_DO.md','README.md')){Copy-Item -LiteralPath $p -Destination (Join-Path $snap ($p.Replace('/','__')))}
 $all=@((rg --files tests/p29 scripts -g '*admin-browser*' -g 'tests/p29/**')+(rg --files infra -g '*admin-browser*')+@(Get-ChildItem docs/evidence -Recurse -File|Where-Object{$_.FullName -match '[\\/]p29-'}|ForEach-Object{$_.FullName.Substring($root.Length+1)}))|Sort-Object -Unique
 $all=@($all|Where-Object{$_ -notmatch 'manifest-final\.json$'})
 $artifacts=@($all|ForEach-Object{@{path=$_;sha=(Get-FileHash -LiteralPath $_).Hash.ToLowerInvariant()}})
 @{utc=[DateTime]::UtcNow.ToString('o');vn=[DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(7)).ToString('o');scope='Implementation29 pending independent audit;13 business+1 responsive final PASS;2 harness failures retained; no production source change';businessRequests=95;mainCases=13;additionalResponsive=1;mainObservations=$caseRecords.Count;runtimeVerdictFixes=0;protectedCount=$proof.protected.Count;artifacts=$artifacts}|ConvertTo-Json -Depth 7|Set-Content -Encoding utf8 docs/evidence/p29-20261004-manifest-final.json
}
if(Test-Path docs/evidence/p29-20261004-manifest-final.json){$m=Get-Content docs/evidence/p29-20261004-manifest-final.json -Raw|ConvertFrom-Json;foreach($a in $m.artifacts){if((Get-FileHash -LiteralPath $a.path).Hash.ToLowerInvariant() -ne $a.sha){throw ('Frozen29 artifact mismatch '+$a.path)}};Write-Host ('PASS '+$m.artifacts.Count+' frozen29 hashes; handoff copies independent of later live docs')}
Write-Host ('PASS offline29:13 independent cases + responsive,95 real HTTP,cleanup/typecheck/Stop; '+$proof.protected.Count+' protected hashes unchanged. Not a browser/backend rerun.')
