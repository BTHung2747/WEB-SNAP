param([switch]$Capture)
$ErrorActionPreference='Stop'
Set-Location 'D:\WED SNAP'
$ev='docs/evidence/p37-3-20261007'
$allowed=@('docs/PROGRESS.md','docs/ADAPTERS.md','docs/TEST_REPORT.md','docs/AUDIT_TIEN_DO.md')
$before=Get-Content "$ev/before-all-sha.json" -Raw | ConvertFrom-Json
$changed=@(); $kept=0
foreach($r in $before){
    if(-not(Test-Path -LiteralPath $r.file)){throw "Missing old file $($r.file)"}
    $same=(Get-FileHash -LiteralPath $r.file -Algorithm SHA256).Hash.ToLower() -ceq $r.sha
    if($r.file -in $allowed){if(-not $same){$changed+=$r.file}}
    elseif(-not $same){throw "Preservation FAIL $($r.file)"}
    else{$kept++}
}
$review=Get-Content docs/evidence/p37-2-review-20261005/manifest.json -Raw | ConvertFrom-Json
if($review.Count -ne 24){throw 'Review manifest count changed'}
foreach($r in $review){if((Get-FileHash -LiteralPath $r.path -Algorithm SHA256).Hash.ToLower() -cne $r.sha256 -or (Get-Item -LiteralPath $r.path).Length -ne $r.bytes){throw "Review37.2 FAIL $($r.path)"}}
$a=Get-Content "$ev/ab/ab-attempt-A.json" -Raw | ConvertFrom-Json
$b=Get-Content "$ev/ab/ab-attempt-B.json" -Raw | ConvertFrom-Json
$attempts=@(rg --files -uu $ev | Where-Object {$_ -match 'ab-attempt-[AB]\.json$'})
if($attempts.Count -ne 2 -or $a.metadata_status -ne 'FAIL' -or $b.metadata_status -ne 'FAIL' -or $a.seconds -gt 30 -or $b.seconds -gt 30){throw 'Analyze allowance/outcome mismatch'}
$runtime=@{}
foreach($dir in @('offline-A','offline-B','ab','diag-before','diag-after')){
    $log=@(Get-Content "$ev/$dir/runner-$(if($dir -eq 'ab'){'ab'}else{'offline'}).jsonl" | ForEach-Object {$_ | ConvertFrom-Json})
    $end=@($log | Where-Object {$_.step -eq 'end'})[-1]
    $cleanup=@($log | Where-Object {$_.step -eq 'cleanup-verified'})[-1]
    if($cleanup.ownResourcesLeft -ne 0){throw 'Runtime cleanup not verified'}
    $expected=if($dir -eq 'ab'){20}elseif($dir -eq 'diag-before'){30}else{0}
    if($end.exit -ne $expected){throw "Runner exit mismatch $dir"}
    $runtime[$dir]=@{runner_exit=$end.exit;end=$end.end;ownResourcesLeft=$cleanup.ownResourcesLeft}
}
$extra=@('tests/p37/build-373.ps1','tests/p37/run-373.ps1','tests/p37/probe_373.py',
    'tests/p37/test_373_offline.py','tests/p37/cap_373.py','tests/p37/verify-373.ps1',
    'infra/compose.tiktok-lab-373.yaml','infra/media-curlcffi-373.Dockerfile',
    'infra/requirements-media-curlcffi-373.lock','docs/TIKTOK_37_3_HANDOFF.md') + $allowed
$excluded=@("$ev/manifest.json","$ev/manifest-sha256.txt")
function Actual-Paths {
    @(@(rg --files -uu $ev | ForEach-Object {$_.Replace('\','/')} | Where-Object {$_ -notin $excluded}) + $extra | Sort-Object -Unique)
}
if($Capture){
    if(Test-Path "$ev/manifest.json"){throw 'Refuse manifest overwrite'}
    $report=@{utc=[DateTime]::UtcNow.ToString('o');vn=[DateTime]::UtcNow.AddHours(7).ToString('yyyy-MM-dd HH:mm:ss.fff');
        beforeFiles=$before.Count;preservedExactSHA=$kept;authorizedChangedDocs=$changed;
        review372=24;review372Passed=24;analyzeAttempts=$attempts.Count;
        A_metadata=$a.metadata_status;B_metadata=$b.metadata_status;runtime=$runtime;
        abCreatedCleanedContainers=3;abCreatedCleanedNetworks=2;
        rawBPerResponseMarkersUsable=$false;bodyNotStored=$true;sourceNotRerunAfterDiagnosticFix=$true;
        verification='offline file/log/hash check; not a runtime rerun'}
    $report | ConvertTo-Json -Depth 12 | Set-Content "$ev/completion.json" -Encoding utf8
    $current=@(foreach($f in $extra){[pscustomobject]@{file=$f;bytes=(Get-Item -LiteralPath $f).Length;sha256=(Get-FileHash -LiteralPath $f -Algorithm SHA256).Hash.ToLower()}})
    $current | ConvertTo-Json -Depth 5 | Set-Content "$ev/after-current-sha.json" -Encoding utf8
    $rows=@(foreach($f in (Actual-Paths)){[pscustomobject]@{path=$f;bytes=(Get-Item -LiteralPath $f).Length;sha256=(Get-FileHash -LiteralPath $f -Algorithm SHA256).Hash.ToLower()}})
    $rows | ConvertTo-Json -Depth 5 | Set-Content "$ev/manifest.json" -Encoding utf8
    (Get-FileHash "$ev/manifest.json" -Algorithm SHA256).Hash.ToLower() | Set-Content "$ev/manifest-sha256.txt" -Encoding ascii
}
$manifest=@(Get-Content "$ev/manifest.json" -Raw | ConvertFrom-Json)
$actual=Actual-Paths
if(@($manifest.path | Sort-Object -Unique).Count -ne $manifest.Count -or (Compare-Object $actual @($manifest.path | Sort-Object -Unique))){throw 'Manifest distinct/full actual coverage FAIL'}
foreach($r in $manifest){if((Get-FileHash -LiteralPath $r.path -Algorithm SHA256).Hash.ToLower() -cne $r.sha256 -or (Get-Item -LiteralPath $r.path).Length -ne $r.bytes){throw "Manifest SHA/bytes FAIL $($r.path)"}}
if((Get-FileHash "$ev/manifest.json" -Algorithm SHA256).Hash.ToLower() -cne (Get-Content "$ev/manifest-sha256.txt" -Raw).Trim()){throw 'Manifest selfmetadata SHA mismatch'}
Write-Output "PASS preserved=$kept; changedDocs=$($changed.Count); review372=24/24; attempts=2; metadata=A_FAIL/B_FAIL; manifest=$($manifest.Count)/$($manifest.Count) SHA/bytes/distinct/fullcoverage; cleanup=0left"
