$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'plan.ps1')
$root=(Get-Location).Path
$ev='docs/evidence/ui-source-readiness-20261016/backend'
if (Test-Path -LiteralPath $ev) { throw 'REFUSE_REUSE_BACKEND_EVIDENCE' }
$plan=Get-SourceReadinessPlan
Assert-SourceReadinessPlan $plan
$source=@(Get-Content 'labs/tiktok/photo-source-fixed/source-pins.json' -Raw|ConvertFrom-Json)
$ui=@(Get-Content 'docs/evidence/ui-final-fixture-20261016/runtime/expected-source.json' -Raw|ConvertFrom-Json)
$tools=@(Get-Content 'labs/tiktok/photo-source-fixed/tool-dependencies.json' -Raw|ConvertFrom-Json)
$uiImplementation=@((Get-Content 'docs/evidence/ui-final-fixture-20261016/manifest.json' -Raw|ConvertFrom-Json).implementation)
if ($source.Count -ne 128 -or $ui.Count -ne 199 -or $tools.Count -ne 36 -or $uiImplementation.Count -ne 6) { throw 'AUTHORITY_COVERAGE' }
foreach ($p in @($ui+$tools+$uiImplementation)) {
    if ((Get-FileHash -LiteralPath $p.path).Hash.ToLowerInvariant() -cne $p.sha256) { throw 'ACCEPTED_CURRENT_PIN_MISMATCH' }
}
$drift=@(foreach ($p in $source) {
    $actual=(Get-FileHash -LiteralPath $p.path).Hash.ToLowerInvariant()
    if ($actual -cne $p.sha256) { [pscustomobject]@{path=$p.path;historical=$p.sha256;current=$actual} }
})
$expectedDrift=@('apps/web/src/App.tsx','apps/web/src/components/Footer.tsx','apps/web/src/components/Header.tsx','apps/web/src/pages/Home.tsx','apps/web/src/style.css','apps/web/src/styles/home.css','apps/web/src/styles/layout.css','apps/web/src/styles/responsive.css')
if (($drift.path -join '|') -cne ($expectedDrift -join '|')) { throw 'UNEXPLAINED_SOURCE_RECIPE_DRIFT' }
foreach ($f in Get-ChildItem -LiteralPath $PSScriptRoot -Filter '*.ps1' -File) {
    $t=$null;$e=$null
    [Management.Automation.Language.Parser]::ParseFile($f.FullName,[ref]$t,[ref]$e)|Out-Null
    if ($e.Count) { throw 'POWERSHELL_SYNTAX' }
}
$cases=@([pscustomobject]@{case='STATIC_MAP_AND_IMPORT_TARGETS';status='PASS';runtimeImport='NOT_RUN'})
foreach ($kind in @('AUTHORITY','FIXTURE_MOUNT')) {
    $bad=Get-SourceReadinessPlan
    if ($kind -ceq 'AUTHORITY') { $bad.sourceGate=$true;$expected='READINESS_AUTHORITY_FORBIDDEN' }
    else { $bad.mounts[0].source='labs/tiktok/photo-app-source-executor/common/driver.ts';$expected='FIXTURE_OR_AUTOMATION_FORBIDDEN' }
    $caught=$false
    try { Assert-SourceReadinessPlan $bad } catch { if ($_.Exception.Message -cne $expected) { throw };$caught=$true }
    if (!$caught) { throw 'NEGATIVE_PLAN_ACCEPTED' }
    $cases += [pscustomobject]@{case="REJECT_$kind";status='PASS'}
}
$checks=@(
    @{name='DEFAULT_DENY';args=@();exit=78},
    @{name='EXECUTE_DENY';args=@('-ExecuteSource');exit=78},
    @{name='DESCRIBE_CANNOT_OVERRIDE_DENY';args=@('-ExecuteSource','-Describe');exit=78},
    @{name='DESCRIBE_ONLY';args=@('-Describe');exit=0}
)
foreach ($c in $checks) {
    $begin=[DateTimeOffset]::UtcNow;$sw=[Diagnostics.Stopwatch]::StartNew()
    $info=[Diagnostics.ProcessStartInfo]::new((Get-Command pwsh).Source)
    $info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.WorkingDirectory=$root
    $info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
    foreach ($a in @('-NoLogo','-NoProfile','-NonInteractive','-File',"$PSScriptRoot/run.ps1")+$c.args) { $info.ArgumentList.Add($a) }
    $proc=[Diagnostics.Process]::new();$proc.StartInfo=$info
    try {
        if (!$proc.Start()) { throw 'PREFLIGHT_CHILD_START' }
        $stdout=$proc.StandardOutput.ReadToEndAsync();$stderr=$proc.StandardError.ReadToEndAsync()
        $timedOut=!$proc.WaitForExit(5000)
        if ($timedOut) { $proc.Kill($true);$proc.WaitForExit();throw 'PREFLIGHT_CHILD_TIMEOUT' }
        $text=$stdout.GetAwaiter().GetResult();$err=$stderr.GetAwaiter().GetResult();$sw.Stop()
        if ($proc.ExitCode -ne $c.exit -or $err.Length -ne 0) { throw 'PREFLIGHT_CHILD_RESULT' }
        if ($c.exit -eq 78 -and $text.Trim() -cne 'SOURCE_DISABLED_READINESS_ONLY') { throw 'DENIAL_OUTPUT' }
        if ($c.exit -eq 0) { $parsed=$text|ConvertFrom-Json;if ($parsed.sourceGate -ne $false -or $parsed.launchImplemented -ne $false) { throw 'DESCRIBE_OPENED_GATE' } }
        $cases += [pscustomobject]@{case=$c.name;status='PASS';actualExit=$proc.ExitCode;timedOut=$false;waitLimitMs=5000;elapsedMs=$sw.ElapsedMilliseconds;utcStart=$begin.ToString('o');utcEnd=[DateTimeOffset]::UtcNow.ToString('o');stdoutBytes=[Text.Encoding]::UTF8.GetByteCount($text);stderrBytes=0;argv=$c.args}
    } finally { $proc.Dispose() }
}
$paths=@($source.path)+@($ui.path)+@($tools.path)+@($uiImplementation.path)+@($plan.mounts.source)+@('labs/tiktok/photo-source-fixed/source-pins.json','labs/tiktok/photo-source-fixed/tool-dependencies.json','docs/evidence/ui-final-fixture-20261016/runtime/expected-source.json','docs/evidence/ui-final-fixture-20261016/manifest.json','docs/tasks/UI_SOURCE_NEXT_20261016.md')
$paths+=@(Get-ChildItem -LiteralPath $PSScriptRoot -File|ForEach-Object{[IO.Path]::GetRelativePath($root,$_.FullName).Replace('\','/')})
$pins=@(foreach ($path in $paths|Sort-Object -Unique) { [pscustomobject]@{path=$path;sha256=(Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant();bytes=(Get-Item -LiteralPath $path).Length} })
New-Item -ItemType Directory -Path $ev|Out-Null
$plan|ConvertTo-Json -Depth 8|Set-Content "$ev/plan.json" -Encoding utf8
$pins|ConvertTo-Json -Depth 4|Set-Content "$ev/pins.json" -Encoding utf8
@{sourceHistoricalPins=128;sourceMatch=120;sourceDrift=$drift;currentUIAcceptedPins=199;uiMatch=199;sourceToolPins=36;toolMatch=36;uiImplementationMatch=6;goldenModified=$false}|ConvertTo-Json -Depth 5|Set-Content "$ev/comparison.json" -Encoding utf8
@{status='PASS_READINESS_STATIC_ONLY_NOT_LAUNCH_READY';cases=$cases;caseCount=$cases.Count;pins=$pins.Count;mounts=$plan.mounts.Count;sourceGate=$false;resourcesCreated=0;claimsCreated=0;sourceCalls=0;dockerCalls=0;browserCalls=0;runtimeImports='NOT_RUN';imageCacheAvailability='NOT_INSPECTED';powershell=$PSVersionTable.PSVersion.ToString();utc=[DateTimeOffset]::UtcNow.ToString('o');vn=[DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(7)).ToString('o')}|ConvertTo-Json -Depth 6|Set-Content "$ev/preflight.json" -Encoding utf8
Write-Output 'PASS_READINESS_STATIC_ONLY_NOT_LAUNCH_READY'
exit 0
