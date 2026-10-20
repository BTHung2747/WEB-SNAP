param()
$ErrorActionPreference = 'Stop'
function Require([bool] $Condition, [string] $Message) { if (-not $Condition) { throw $Message } }
function Raw([string] $Path) { @(Get-Content -LiteralPath $Path | Where-Object { $_ -match 'P28_RAW ' } | ForEach-Object { ($_ -split 'P28_RAW ',2)[1] | ConvertFrom-Json }) }
$protected = Get-Content -Raw docs/evidence/p28-20261003-protected-before.json | ConvertFrom-Json
foreach ($entry in $protected.protected) { Require ((Get-FileHash -LiteralPath $entry.path).Hash.ToLowerInvariant() -eq $entry.sha) ('Protected changed: ' + $entry.path) }
$before = Raw 'docs/evidence/p28-20261004-baseline.log'
$after = Raw 'docs/evidence/p28-20261004-final.log'
$baselineCases = @($before | Where-Object kind -eq case)
$cases = @($after | Where-Object kind -eq case)
Require ($baselineCases.Count -eq 30 -and @($baselineCases | Where-Object result -eq FAIL).Count -eq 13) 'Baseline30/13FAIL missing'
Require ($cases.Count -eq 60 -and @($cases | Where-Object result -ne PASS).Count -eq 0) 'Final60PASS missing'
$summaries = @($after | Where-Object kind -eq 'matrix-final')
Require ($summaries.Count -eq 2 -and ($summaries.viewport -join ',') -eq '1280,360') 'Viewport inventory'
foreach ($summary in $summaries) { Require ($summary.pass -eq 30 -and $summary.fail -eq 0 -and $summary.requests -eq 157 -and $summary.cleanup) 'Final matrix counts/cleanup' }
foreach ($case in $cases) {
  Require ($case.cleanup.rootUnmounted -and $case.cleanup.fetchRestored -and $case.cleanup.hooksRestored -and $case.cleanup.pending -eq 0 -and @($case.consoleErrors).Count -eq 0) ('Cleanup/console ' + $case.name)
  Require (@($case.requests | Where-Object phase -eq start).Count -le 30 -and $case.durationMs -lt 1800) ('Bounds ' + $case.name)
}
$beforeStart = @($before | Where-Object kind -eq 'matrix-start')[0]
$afterStarts = @($after | Where-Object kind -eq 'matrix-start')
Require (($beforeStart.expected | ConvertTo-Json -Depth 5 -Compress) -eq ($afterStarts[0].expected | ConvertTo-Json -Depth 5 -Compress)) 'Expected changed to force PASS'
$inputManifest = Get-Content -Raw docs/evidence/p28-20261004-baseline-inputs.json | ConvertFrom-Json
$expectedSha = ($inputManifest.inputs | Where-Object path -eq 'tests/p28/expectations.ts').sha
Require ((Get-FileHash tests/p28/expectations.ts).Hash.ToLowerInvariant() -eq $expectedSha) 'Original expected edited'
foreach ($start in $afterStarts) { foreach ($entry in $start.environment.hashes.PSObject.Properties) { Require ((Get-FileHash -LiteralPath ('apps/web/src/' + $entry.Name)).Hash.ToLowerInvariant() -eq $entry.Value) ('Final production hash ' + $entry.Name) } }
$oldAdmin = 'docs/evidence/p28-20261003-before/apps_web_src_pages_Admin.tsx'
Require ((Get-FileHash -LiteralPath $oldAdmin).Hash.ToLowerInvariant() -eq $beforeStart.environment.hashes.'pages/Admin.tsx') 'Baseline source not tied to raw'
$focusBefore = @(Raw 'docs/evidence/p28-20261004-focus-baseline-and-smoke.log' | Where-Object kind -eq 'focus-regression')
$focusAfter = @($after | Where-Object kind -eq 'focus-regression')
Require ($focusBefore.Count -eq 1 -and $focusBefore[0].result -eq 'FAIL' -and $focusAfter.Count -eq 2 -and @($focusAfter | Where-Object result -ne PASS).Count -eq 0) 'Focus baseline/final'
Require ($focusBefore[0].expected -eq $focusAfter[0].expected) 'Focus expected changed'
foreach ($race in @($cases | Where-Object name -eq 'refresh-late-after-logout')) {
  $logout = @($race.requests | Where-Object { $_.path -eq 'admin/logout' -and $_.phase -eq 'finish' })[0]
  $late = @($race.requests | Where-Object { $_.method -eq 'GET' -and $_.phase -eq 'finish' } | Select-Object -Last 3)
  Require (@($late | Where-Object { $_.order -le $logout.order }).Count -eq 0) 'Late refresh not after logout'
}
$keyboard = Get-Content -Raw docs/evidence/p28-20261004-keyboard-final.json | ConvertFrom-Json
Require (@($keyboard.console).Count -eq 0) 'Browser console error'
foreach ($width in @(1280,360)) { $save = @($keyboard.observations | Where-Object { $_.step -eq ('final' + $width + ' save Enter retains focus') })[0]; Require ($save.focusText -eq 'Lưu cấu hình' -and $save.pageWidth -le $width) 'Native save focus/overflow' }
$scroll = @($keyboard.observations | Where-Object step -eq '360 table keyboard scroll')[0]
Require ($scroll.after.scrollLeft -gt $scroll.before.scrollLeft) 'Native table scroll'
Require ((Get-Content -Raw docs/evidence/p28-20261004-typecheck-final.log).Contains('PASS web + React UI lab TypeScript checks sequential')) 'Typecheck completion missing'
Require ((Get-Content -Raw docs/evidence/p28-20261004-stop-final.log).Contains('PASS UI lab stopped/removed/network removed; no volumes removed; other stacks untouched')) 'Stop completion missing'
Require (-not (Get-Content -Raw docs/evidence/p28-20261004-final.log).Contains('P28_SERVER_API_REFUSED')) 'Fixture fence escaped'
Write-Host ('PASS evidence28: protected=' + $protected.protected.Count + '; baseline17PASS13FAIL; final30+focus1 x1280/360 PASS; original expected unchanged; late-order/cleanup/native-focus/scroll/typecheck/Stop. Evidence check only, no runtime rerun.')
