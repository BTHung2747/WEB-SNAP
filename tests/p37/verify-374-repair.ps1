# Offline successor for exactly runner374 + four authorized docs. No historical verifier mutation.
param([switch]$Capture)
$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
$ev='docs/evidence/p37-4-r-20261007';$old='docs/evidence/p37-4-20261007'
$allowed=@('tests/p37/run-374.ps1','docs/PROGRESS.md','docs/ADAPTERS.md','docs/TEST_REPORT.md','docs/AUDIT_TIEN_DO.md')
function SHA([string]$f){(Get-FileHash -LiteralPath $f -Algorithm SHA256).Hash.ToLower()}
$before=Get-Content "$ev/before-all-sha.json" -Raw | ConvertFrom-Json
$pred=Get-Content "$old/manifest.json" -Raw | ConvertFrom-Json
$proof=Get-Content "$ev/predecessor-374.json" -Raw | ConvertFrom-Json
$oldSHA='c76ca5e89b2c9f9559a8cf96f1c0855de5be5ee32e007c63f7dd3633f22f7a3e'
if((SHA "$old/manifest.json") -cne $oldSHA -or (Get-Content "$old/manifest-sha256.txt" -Raw).Trim() -cne $oldSHA){throw 'Frozen374 manifest/selfmetadata changed'}
if($pred.Count -ne 40 -or $proof.beforeRepairPreserved -ne 39 -or $proof.manifestSHA -cne $oldSHA){throw 'Predecessor proof mismatch'}
foreach($r in $pred){
    $p=@($proof.rows | Where-Object {$_.path -ceq $r.path})
    if($p.Count -ne 1 -or $p[0].oldSHA -cne $r.sha256){throw 'Predecessor coverage mismatch'}
    if($r.path -ne 'docs/AUDIT_TIEN_DO.md' -and $p[0].currentSHA -cne $r.sha256){throw 'Pre-repair39/39 preservation failed'}
    if($r.path -notin $allowed -and ((SHA $r.path) -cne $r.sha256 -or (Get-Item -LiteralPath $r.path).Length -ne $r.bytes)){throw "Old374 source/raw FAIL $($r.path)"}
}
$oldRunner=@($pred | Where-Object {$_.path -eq 'tests/p37/run-374.ps1'})[0]
if((SHA "$ev/before/run-374.ps1") -cne $oldRunner.sha256){throw 'Original executable runner snapshot mismatch'}
$priorAudit=@($before | Where-Object {$_.file -eq 'docs/AUDIT_TIEN_DO.md'})[0]
if($priorAudit.sha256 -cne $proof.currentAuditSHA){throw 'Inherited current audit SHA mismatch'}
$kept=0;$changed=@()
foreach($r in $before){
    if(-not(Test-Path -LiteralPath $r.file)){throw "Before file missing $($r.file)"}
    if($r.file -in $allowed){if((SHA $r.file) -cne $r.sha256){$changed+=$r.file}}
    elseif((SHA $r.file) -cne $r.sha256 -or (Get-Item -LiteralPath $r.file).Length -ne $r.bytes){throw "Unscoped change $($r.file)"}
    else{$kept++}
}
$case="$ev/case-current-final"
$pins=@(Get-Content "$case/source-pin.json" -Raw | ConvertFrom-Json)
if($pins.Count -ne 5){throw 'Final case requires exactly five source pins'}
foreach($p in $pins){if((SHA $p.file) -cne $p.sha256){throw "Default case stale pin $($p.file)"}}
$cp=Get-Content "$case/config-pin.json" -Raw | ConvertFrom-Json
if((SHA "$case/fixed-configuration.json") -cne $cp.file_sha256 -or $cp.configuration_sha256 -cne '6c2c655ffc39af3c658c6b58c26da013b504092fb4f32f4d39bf4d05a7bc6121'){throw 'Configuration changed'}
foreach($root in @('docs/evidence/p37-3-20261007','docs/evidence/p37-4-20261007')){
    # Every prior evidence path is also in before-set; manifest/selfSHA included, no blanket historical exemption.
    if(-not(Test-Path "$root/manifest.json")){throw 'Predecessor evidence missing'}
}
foreach($caseRoot in @("$ev/case-current","$case")){
    if(@(rg --files -uu $caseRoot | Where-Object {$_ -match 'ab-attempt|network-observation'}).Count){throw 'Repair case contains unexpected source report/receipt'}
}
$b=Get-Content "$ev/fixtures-before-2/result.json" -Raw | ConvertFrom-Json
$a=Get-Content "$ev/fixtures-after-2/result.json" -Raw | ConvertFrom-Json
if($b.actualExit -ne 1 -or $b.failed -ne 8 -or $b.passed -ne 4 -or $a.actualExit -ne 0 -or $a.failed -ne 0 -or $a.passed -ne 12){throw 'Final fixture outcomes mismatch'}
foreach($r in @($b,$a)){if($r.sourceRequests -ne 0 -or $r.dockerInvoked){throw 'Offline scope mismatch'}}
$natives=@(Get-Content "$ev/fixtures-after-2/native.jsonl" | ForEach-Object {$_ | ConvertFrom-Json})
$gate=@($natives | Where-Object {$_.args -contains 'analyze'})
if($gate.Count -ne 1 -or $gate[0].actualExit -ne 40){throw 'Missing-input must remain exit40 before runtime'}
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path (Get-Location) 'tests/p37/run-374.ps1'),[ref]$tokens,[ref]$errors)
if($errors.Count){throw 'Runner parser errors'}
$default=@($ast.ParamBlock.Parameters | Where-Object {$_.Name.VariablePath.UserPath -eq 'CaseDir'})[0].DefaultValue.Value
if($default -cne $case){throw 'Default does not use verified successor case'}
$extra=@('tests/p37/run-374.ps1','tests/p37/test_374_repair.ps1','tests/p37/verify-374-repair.ps1',
    'docs/TIKTOK_37_4_R_HANDOFF.md','docs/PROGRESS.md','docs/ADAPTERS.md','docs/TEST_REPORT.md','docs/AUDIT_TIEN_DO.md')
$excluded=@("$ev/manifest.json","$ev/manifest-sha256.txt")
function ActualPaths{@(@(rg --files -uu $ev | ForEach-Object {$_.Replace('\','/')} | Where-Object {$_ -notin $excluded})+$extra | Sort-Object -Unique)}
if($Capture){
    if(Test-Path "$ev/manifest.json"){throw 'Refuse frozen repair manifest overwrite'}
    New-Item -ItemType Directory -Path "$ev/after-source" | Out-Null
    foreach($f in @('tests/p37/run-374.ps1','tests/p37/test_374_repair.ps1')){Copy-Item -LiteralPath $f -Destination "$ev/after-source/$([IO.Path]::GetFileName($f))"}
    @(foreach($f in $allowed){@{file=$f;beforeSHA=@($before | Where-Object {$_.file -ceq $f})[0].sha256;acceptedAfterSHA=(SHA $f)}}) | ConvertTo-Json | Set-Content "$ev/accepted-successor.json" -Encoding utf8
    @{utc=[DateTime]::UtcNow.ToString('o');vn=[DateTime]::UtcNow.AddHours(7).ToString('yyyy-MM-dd HH:mm:ss.fff');
        status='TWO_FINDINGS_FIXED_PENDING_AUDIT';beforeFiles=$before.Count;exactPreserved=$kept;authorizedChangedPaths=$changed;
        predecessorBeforeRepair=39;predecessorManifestEntries=40;predecessorCurrentlyUnchangedPaths=35;
        fixtureBaseline=@{passed=4;failed=8;actualExit=1};fixtureFinal=@{passed=12;failed=0;actualExit=0};
        missingInputActualExit=40;defaultCase=$case;sourcePins=5;sourceRequests=0;dockerInvoked=$false;
        sourceMetadata='NOT_RUN';sourceActualExit=$null;network='owner only has current network; two-network comparison NOT_RUN';
        priorEvidenceRetained=$true;probeGuardProductionUnchanged=$true;noContainerNetworkCreated=$true;
        fixtureScope='synthetic files + actual summary branch, not extraction/live network'} | ConvertTo-Json -Depth 10 | Set-Content "$ev/completion.json" -Encoding utf8
    @(foreach($f in (ActualPaths)){@{path=$f;bytes=(Get-Item -LiteralPath $f).Length;sha256=(SHA $f)}}) | ConvertTo-Json -Depth 5 | Set-Content "$ev/manifest.json" -Encoding utf8
    SHA "$ev/manifest.json" | Set-Content "$ev/manifest-sha256.txt" -Encoding ascii
}
$accepted=@(Get-Content "$ev/accepted-successor.json" -Raw | ConvertFrom-Json)
if($accepted.Count -ne 5 -or (Compare-Object $allowed @($accepted.file))){throw 'Successor set is not exact'}
foreach($r in $accepted){if((SHA $r.file) -cne $r.acceptedAfterSHA -or @($before | Where-Object {$_.file -ceq $r.file})[0].sha256 -cne $r.beforeSHA){throw "Exact successor SHA failed $($r.file)"}}
$m=@(Get-Content "$ev/manifest.json" -Raw | ConvertFrom-Json)
if(@($m.path | Sort-Object -Unique).Count -ne $m.Count -or (Compare-Object (ActualPaths) @($m.path | Sort-Object -Unique))){throw 'Distinct/full artifact coverage failed'}
foreach($r in $m){if((SHA $r.path) -cne $r.sha256 -or (Get-Item -LiteralPath $r.path).Length -ne $r.bytes){throw "Artifact SHA/bytes failed $($r.path)"}}
if((SHA "$ev/manifest.json") -cne (Get-Content "$ev/manifest-sha256.txt" -Raw).Trim()){throw 'Repair manifest selfmetadata mismatch'}
Write-Output "PASS exactPreserved=$kept; authorizedSuccessor5; predecessor39/39 before-repair/frozen manifests; artifacts=$($m.Count)/$($m.Count) SHA/bytes/distinct/fullcoverage; fixtures4PASS8FAIL->12PASS0FAIL; default5/5pins; source0/Docker0/NOT_RUN"
