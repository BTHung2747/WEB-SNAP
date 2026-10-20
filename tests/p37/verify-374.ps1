# Offline successor only; do not modify predecessor manifests/verifiers.
param([switch]$Capture)
$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
$ev='docs/evidence/p37-4-20261007';$old='docs/evidence/p37-3-20261007'
$docs=@('docs/PROGRESS.md','docs/ADAPTERS.md','docs/TEST_REPORT.md','docs/AUDIT_TIEN_DO.md')
function SHA([string]$f){(Get-FileHash -LiteralPath $f -Algorithm SHA256).Hash.ToLower()}
$before=Get-Content "$ev/before-all-sha.json" -Raw | ConvertFrom-Json
$proof=Get-Content "$ev/predecessor-373-proof.json" -Raw | ConvertFrom-Json
if((SHA "$old/manifest.json") -cne 'f46fcf1a35ee369538935b01b6e97484219b9f35c0d001c5d514fb1be8ded1fe' -or (SHA "$old/manifest.json") -cne (Get-Content "$old/manifest-sha256.txt" -Raw).Trim()){throw 'Predecessor manifest/selfmetadata changed'}
$pred=Get-Content "$old/manifest.json" -Raw | ConvertFrom-Json
if($pred.Count -ne 75 -or $proof.manifestEntries -ne 75 -or $proof.preserved -ne 74 -or $proof.manifestSHA -cne (SHA "$old/manifest.json")){throw 'Predecessor proof invalid'}
foreach($r in $pred){
    $row=@($proof.rows | Where-Object {$_.path -ceq $r.path})
    if($row.Count -ne 1 -or $row[0].oldSHA -cne $r.sha256){throw 'Predecessor proof coverage mismatch'}
    if($r.path -ne 'docs/AUDIT_TIEN_DO.md' -and $row[0].currentSHA -cne $r.sha256){throw 'Pre-update 74/74 proof invalid'}
    if($r.path -notin $docs -and ((SHA $r.path) -cne $r.sha256 -or (Get-Item -LiteralPath $r.path).Length -ne $r.bytes)){throw "Historical raw/source FAIL $($r.path)"}
}
$priorAudit=@($before | Where-Object {$_.file -eq 'docs/AUDIT_TIEN_DO.md'})[0]
if($priorAudit.sha256 -cne $proof.authorizedAuditSHA){throw 'Before374 audit successor mismatch'}
$kept=0;$changed=@()
foreach($r in $before){
    if(-not(Test-Path -LiteralPath $r.file)){throw "Missing before file $($r.file)"}
    if($r.file -in $docs){if((SHA $r.file) -cne $r.sha256){$changed+=$r.file}}
    elseif((SHA $r.file) -cne $r.sha256 -or (Get-Item -LiteralPath $r.file).Length -ne $r.bytes){throw "Preservation FAIL $($r.file)"}
    else{$kept++}
}
if(@(rg --files -uu $ev | Where-Object {$_ -match 'ab-attempt-.*\.json$'}).Count){throw 'Preparation was expected to make zero source attempts'}
$gate=Get-Content "$ev/missing-network-gate.json" -Raw | ConvertFrom-Json
if($gate.actualExit -ne 40 -or $gate.sourceRequests -ne 0 -or $gate.dockerInvoked){throw 'Missing-condition evidence mismatch'}
$log=@(Get-Content "$ev/offline/runner-offline.jsonl" | ForEach-Object {$_ | ConvertFrom-Json})
$fixture=@($log | Where-Object {$_.step -eq 'offline-fixture'})[0]
$end=@($log | Where-Object {$_.step -eq 'end'})[-1]
$clean=@($log | Where-Object {$_.step -eq 'cleanup-verified'})[-1]
if($fixture.exit -ne 0 -or $end.exit -ne 0 -or $clean.ownResourcesLeft -ne 0 -or $clean.ownCreatedCleaned -ne 1){throw 'Offline fixture/cleanup mismatch'}
$cfg=Get-Content "$ev/offline/offline-config-proof.json" -Raw | ConvertFrom-Json
if(-not $cfg.no_request_made -or $cfg.network -ne 'none' -or $cfg.configuration_sha256 -cne '6c2c655ffc39af3c658c6b58c26da013b504092fb4f32f4d39bf4d05a7bc6121'){throw 'Fixed configuration offline proof mismatch'}
$case="$ev/network-case-final"
foreach($r in (Get-Content "$case/source-pin.json" -Raw | ConvertFrom-Json)){if((SHA $r.file) -cne $r.sha256){throw 'Prepared final source changed'}}
$cp=Get-Content "$case/config-pin.json" -Raw | ConvertFrom-Json
if((SHA "$case/fixed-configuration.json") -cne $cp.file_sha256 -or $cp.configuration_sha256 -cne $cfg.configuration_sha256){throw 'Prepared configuration changed'}
$extra=@('tests/p37/probe_374.py','tests/p37/run-374.ps1','tests/p37/guard_374.ps1',
    'tests/p37/test_374_offline.py','tests/p37/verify-374.ps1',
    'tests/p37/network-plan-374.example.json','tests/p37/network-proof-374.example.json',
    'infra/compose.tiktok-lab-374.yaml','docs/TIKTOK_37_4_HANDOFF.md')+$docs
$excluded=@("$ev/manifest.json","$ev/manifest-sha256.txt")
function ActualPaths{@(@(rg --files -uu $ev | ForEach-Object {$_.Replace('\','/')} | Where-Object {$_ -notin $excluded})+$extra | Sort-Object -Unique)}
if($Capture){
    if(Test-Path "$ev/manifest.json"){throw 'Refuse frozen successor manifest overwrite'}
    @(foreach($f in $docs){@{file=$f;beforeSHA=(@($before | Where-Object {$_.file -eq $f})[0].sha256);acceptedAfterSHA=(SHA $f)}}) | ConvertTo-Json | Set-Content "$ev/authorized-doc-successor.json" -Encoding utf8
    @{utc=[DateTime]::UtcNow.ToString('o');vn=[DateTime]::UtcNow.AddHours(7).ToString('yyyy-MM-dd HH:mm:ss.fff');
        status='PREPARED_NOT_RUN_MISSING_OWNER_NETWORK';sourceAttempts=0;sourceActualExit=$null;
        metadata='NOT_RUN';target='NOT_RUN';markers='NOT_RUN';bytes='NOT_RUN';
        predecessorBefore374=74;predecessorManifestEntries=75;predecessorCurrentlyUnchangedNonDocs=71;
        beforeFiles=$before.Count;exactPreserved=$kept;authorizedDocChanges=$changed;
        actualMissingConditionExit=$gate.actualExit;actualOfflineNativeExit=$fixture.exit;actualOfflineRunnerExit=$end.exit;
        ownCreatedCleaned=1;ownResourcesLeft=0;runtimeScope='network-none fixture; not live metadata';
        configurationSHA=$cfg.configuration_sha256;offlineEnd=$end.end;
        missing=@('owner-provided alternate network and access permission','approved verification method/private proof of actual own-egress outbound change');
        noProductionChange=$true;noRebuild=$true;noNetworkChange=$true} | ConvertTo-Json -Depth 8 | Set-Content "$ev/completion.json" -Encoding utf8
    @(foreach($f in (ActualPaths)){@{path=$f;bytes=(Get-Item -LiteralPath $f).Length;sha256=(SHA $f)}}) | ConvertTo-Json -Depth 5 | Set-Content "$ev/manifest.json" -Encoding utf8
    SHA "$ev/manifest.json" | Set-Content "$ev/manifest-sha256.txt" -Encoding ascii
}
$accepted=Get-Content "$ev/authorized-doc-successor.json" -Raw | ConvertFrom-Json
if(@($accepted).Count -ne 4 -or (Compare-Object $docs @($accepted.file))){throw 'Exact successor doc set mismatch'}
foreach($r in $accepted){
    if((SHA $r.file) -cne $r.acceptedAfterSHA -or @($before | Where-Object {$_.file -eq $r.file})[0].sha256 -cne $r.beforeSHA){throw "Authorized exact doc successor FAIL $($r.file)"}
}
$m=@(Get-Content "$ev/manifest.json" -Raw | ConvertFrom-Json)
if(@($m.path | Sort-Object -Unique).Count -ne $m.Count -or (Compare-Object (ActualPaths) @($m.path | Sort-Object -Unique))){throw 'Full distinct artifact coverage FAIL'}
foreach($r in $m){if((SHA $r.path) -cne $r.sha256 -or (Get-Item -LiteralPath $r.path).Length -ne $r.bytes){throw "Manifest SHA/bytes FAIL $($r.path)"}}
if((SHA "$ev/manifest.json") -cne (Get-Content "$ev/manifest-sha256.txt" -Raw).Trim()){throw 'Manifest selfmetadata mismatch'}
Write-Output "PASS exactPreserved=$kept; docs=$($changed.Count) exact successor; predecessor=74/74 before374 + frozen manifest; artifacts=$($m.Count)/$($m.Count) SHA/bytes/distinct/fullcoverage; source=0/2 NOT_RUN; offlineexit0/gate40/cleanup0left"
