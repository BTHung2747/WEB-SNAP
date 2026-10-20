param([switch]$Capture)
$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
$ev='docs/evidence/p37-renderer-launch-20261007';$old='docs/evidence/p37-renderer-20261007'
$allowed=@('tests/p37/renderer_capability.js','tests/p37/run_renderer_capability.ps1',
    'docs/PROGRESS.md','docs/ADAPTERS.md','docs/TEST_REPORT.md','docs/AUDIT_TIEN_DO.md')
function SHA([string]$p){(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLower()}
$oldSHA='8e902b964cb65e6d967bf575ff39725a2091db3471885adfbef243df255659c3'
if((SHA "$old/manifest.json") -cne $oldSHA -or (Get-Content "$old/manifest-sha256.txt" -Raw).Trim() -cne $oldSHA){throw 'Old manifest/selfmetadata changed'}
$pred=@(Get-Content "$old/manifest.json" -Raw | ConvertFrom-Json)
$proof=Get-Content "$ev/predecessor.json" -Raw | ConvertFrom-Json
if($pred.Count -ne 149 -or $proof.beforePreserved -ne 148 -or $proof.manifestSHA -cne $oldSHA){throw 'Predecessor mismatch'}
foreach($r in $pred){
    $p=@($proof.rows | Where-Object {$_.path -ceq $r.path})
    if($p.Count -ne 1 -or $p[0].oldSHA -cne $r.sha256){throw 'Predecessor coverage mismatch'}
    if($r.path -ne 'docs/AUDIT_TIEN_DO.md' -and $p[0].beforeSHA -cne $r.sha256){throw 'Before148/148 mismatch'}
    if($r.path -notin $allowed -and ((SHA $r.path) -cne $r.sha256 -or (Get-Item -LiteralPath $r.path).Length -ne $r.bytes)){throw "Old source/raw changed $($r.path)"}
    if($r.path -in @('tests/p37/renderer_capability.js','tests/p37/run_renderer_capability.ps1')){if((SHA "$ev/before/$([IO.Path]::GetFileName($r.path))") -cne $r.sha256){throw 'Original tool copy mismatch'}}
}
$before=@(Get-Content "$ev/before-all-sha.json" -Raw | ConvertFrom-Json);$kept=0;$changed=@()
if(@($before | Where-Object {$_.file -eq 'docs/AUDIT_TIEN_DO.md'})[0].sha256 -cne $proof.currentAuditSHA){throw 'Inherited audit mismatch'}
foreach($r in $before){
    if(-not(Test-Path -LiteralPath $r.file)){throw "Missing before path $($r.file)"}
    if($r.file -in $allowed){if((SHA $r.file) -cne $r.sha256){$changed+=$r.file}}
    elseif((SHA $r.file) -cne $r.sha256 -or (Get-Item -LiteralPath $r.file).Length -ne $r.bytes){throw "Unscoped change $($r.file)"}
    else{$kept++}
}
$cap=Get-Content "$ev/attempt-1/capability.json" -Raw | ConvertFrom-Json
$logs=@(Get-Content "$ev/attempt-1/native.jsonl" | ForEach-Object {$_ | ConvertFrom-Json})
$end=@($logs | Where-Object {$_.step -eq 'end'})[-1]
$launch=@($logs | Where-Object {$_.step -eq 'offline-launch'})
if($launch.Count -ne 1 -or $launch[0].actualExit -ne 30 -or $end.actualExit -ne 30 -or $end.ownResourcesLeft -ne 0){throw 'Native/cleanup outcome mismatch'}
if($cap.sourceNavigations -ne 0 -or $cap.capabilityStatus -cne 'FAIL' -or $cap.observed.contextCreated -or $cap.observed.CDP){throw 'Pipeline stage mismatch'}
if(@($cap.chromiumProcesses).Count -ne 1 -or -not $cap.chromiumProcesses[0].exitObserved -or $cap.chromiumProcesses[0].signal -cne 'SIGTRAP' -or $null -ne $cap.chromiumProcesses[0].exitCode){throw 'Actual Chromium exit/signal mismatch'}
$stderr=$cap.chromiumProcesses[0].stderr
if($stderr.truncated -or $stderr.bytesReceived -ne 181 -or $cap.launchError.truncated -or $stderr.text -notmatch 'sys_chroot' -or $stderr.text -notmatch 'zygote'){throw 'Full cause/log missing'}
if($cap.diagnosticFixture.status -cne 'PASS' -or $cap.diagnosticFixture.cases -ne 3){throw 'Log fixture mismatch'}
$guard=Get-Content "$ev/attempt-1/actual-guard.json" -Raw | ConvertFrom-Json
if($guard.Image -cne 'sha256:e3e776372b598eb8eaf57dea5ce293f79a1c834e6e92dce9e6b9bb9a2bf2baf9' -or $guard.Config.User -cne '1000:1000' -or $guard.HostConfig.Memory -ne 928MB -or $guard.HostConfig.NetworkMode -cne 'none'){throw 'Actual guard mismatch'}
if((SHA 'infra/renderer-seccomp-1.63.json') -cne 'cc3e61cabda6bbc1e53e54d27ba4d55a9d3be829b6dd1a596f4a7b31b1cc7849'){throw 'Pinned protection changed'}
$proposal=Get-Content "$ev/proposal-not-applied.json" -Raw | ConvertFrom-Json
if($proposal.applied){throw 'Proposal must not be applied'}
if(Test-Path "$ev/attempt-2"){throw 'Expected stop after first real launch'}
$final=@(Get-Content "$ev/final-docker-read.json" -Raw | ConvertFrom-Json)
if(@($final | Where-Object {$_.actualExit -ne 0}).Count -or $final[1].output.Trim() -or $final[2].output.Trim()){throw 'Final cleanup/pins proof unavailable'}
$extra=@('tests/p37/renderer_capability.js','tests/p37/run_renderer_capability.ps1','tests/p37/renderer_diagnostics.js',
    'tests/p37/verify_renderer_launch.ps1','docs/TIKTOK_RENDERER_LAUNCH_HANDOFF.md',
    'docs/PROGRESS.md','docs/ADAPTERS.md','docs/TEST_REPORT.md','docs/AUDIT_TIEN_DO.md')
$excluded=@("$ev/manifest.json","$ev/manifest-sha256.txt")
function ActualPaths{@(@(rg --files -uu $ev | ForEach-Object {$_.Replace('\','/')} | Where-Object {$_ -notin $excluded})+$extra | Sort-Object -Unique)}
if($Capture){
    if(Test-Path "$ev/manifest.json"){throw 'Refuse frozen successor overwrite'}
    New-Item -ItemType Directory -Path "$ev/executed-source" | Out-Null
    foreach($f in @('tests/p37/renderer_capability.js','tests/p37/run_renderer_capability.ps1','tests/p37/renderer_diagnostics.js')){Copy-Item -LiteralPath $f -Destination "$ev/executed-source/$([IO.Path]::GetFileName($f))"}
    @(foreach($f in $allowed){@{file=$f;beforeSHA=@($before | Where-Object {$_.file -ceq $f})[0].sha256;acceptedAfterSHA=(SHA $f)}}) | ConvertTo-Json | Set-Content "$ev/accepted-successor.json" -Encoding utf8
    @{utc=[DateTime]::UtcNow.ToString('o');vn=[DateTime]::UtcNow.AddHours(7).ToString('yyyy-MM-dd HH:mm:ss.fff');status='LOG_FIELDS_FIXED_PENDING_AUDIT_BOOT_BLOCKED_POLICY_DECISION';
      beforeFiles=$before.Count;exactPreserved=$kept;authorizedChanges=$changed;predecessorBefore148=148;oldManifestEntries=149;oldCurrentlyUnchangedNonAuthorized=143;
      realOfflineLaunches=1;secondLaunch='NOT_RUN';logFixturesPASS=3;chromiumSignal='SIGTRAP';chromiumExitCode=$null;runnerExit=30;
      fullStderrBytes=181;stderrTruncated=$false;launchErrorBytes=$cap.launchError.bytesReceived;contextObserved=$false;TLSObserved='NOT_RUN';
      byteGuard='NOT_RUN';metadata='NOT_RUN';sourceNavigations=0;downloads=0;visual='NOT_RUN';
      proposalApplied=$false;imageRebuilt=$false;hostChanged=$false;ownContainerCleaned=1;ownResourcesLeft=0;
      cgroupPeakBytes=$cap.cgroupAfter.'memory.peak'.value;cause='Sandbox chroot bootstrap failure + pinned chroot/CAP_SYS_CHROOT versus CapDropALL policy conflict';
      scope='one offline launch; not source/CDN outcome; file/log/hash verifier only'} | ConvertTo-Json -Depth 10 | Set-Content "$ev/completion.json" -Encoding utf8
    @(foreach($f in (ActualPaths)){@{path=$f;bytes=(Get-Item -LiteralPath $f).Length;sha256=(SHA $f)}}) | ConvertTo-Json -Depth 5 | Set-Content "$ev/manifest.json" -Encoding utf8
    SHA "$ev/manifest.json" | Set-Content "$ev/manifest-sha256.txt" -Encoding ascii
}
$accepted=@(Get-Content "$ev/accepted-successor.json" -Raw | ConvertFrom-Json)
if($accepted.Count -ne 6 -or (Compare-Object $allowed @($accepted.file))){throw 'Exact successor set mismatch'}
foreach($r in $accepted){if((SHA $r.file) -cne $r.acceptedAfterSHA -or @($before | Where-Object {$_.file -ceq $r.file})[0].sha256 -cne $r.beforeSHA){throw "Exact successor mismatch $($r.file)"}}
$m=@(Get-Content "$ev/manifest.json" -Raw | ConvertFrom-Json)
if(@($m.path | Sort-Object -Unique).Count -ne $m.Count -or (Compare-Object (ActualPaths) @($m.path | Sort-Object -Unique))){throw 'Full distinct coverage mismatch'}
foreach($r in $m){if((SHA $r.path) -cne $r.sha256 -or (Get-Item -LiteralPath $r.path).Length -ne $r.bytes){throw "Artifact mismatch $($r.path)"}}
if((SHA "$ev/manifest.json") -cne (Get-Content "$ev/manifest-sha256.txt" -Raw).Trim()){throw 'Selfmetadata mismatch'}
Write-Output "PASS preserved=$kept; exactSuccessor6; predecessor148/148 before-change/frozen149; artifacts=$($m.Count)/$($m.Count) SHA/bytes/distinct/fullcoverage; launch1/2FAIL_SIGTRAP; stderr181full; logfixture3PASS; source0/download0/NOT_RUN; proposalNotApplied; cleanup0left"
