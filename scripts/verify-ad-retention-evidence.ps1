param([switch]$CaptureSnapshot)
$ErrorActionPreference = 'Stop'
$root31 = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
if ((Get-Location).Path -ne $root31 -or $root31 -ne 'D:\WED SNAP') { throw 'Native repository path required' }
$stem31 = 'docs/evidence/p31-20261004'
function Require31($ok, $message) { if (-not $ok) { throw $message } }
function Hash31($path) { (Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant() }
function Records31($path) { @(Get-Content -LiteralPath $path | Where-Object { $_.StartsWith('P31_RAW ') } | ForEach-Object { $_.Substring(8) | ConvertFrom-Json }) }
function Json31($path, $value) { [IO.File]::WriteAllText((Join-Path $root31 $path), ($value | ConvertTo-Json -Depth 100) + "`n", (New-Object Text.UTF8Encoding($false))) }
$protected31 = Get-Content "$stem31-protected-before.json" -Raw | ConvertFrom-Json
Require31 ($protected31.protected.Count -eq 1027 -and @($protected31.protected.path | Select-Object -Unique).Count -eq 1027) 'Protected inventory'
foreach ($p31 in $protected31.protected) { Require31 ((Hash31 $p31.path) -eq $p31.sha) ('Protected changed ' + $p31.path) }
$expected31 = Get-Content tests/p31/expected.json -Raw | ConvertFrom-Json
$expectedSHA31 = 'c9d624620baadf8c737a827de1bf95a1d84a4b7e85973ee133a611796feaa4eb'
$testSHA31 = '30e8f6f961f6e34e31f56cd868373f766c8353d65c6f0b49f1e33311a3127089'
Require31 ((Hash31 'tests/p31/expected.json') -eq $expectedSHA31 -and (Hash31 'tests/p31/retention.ts') -eq $testSHA31) 'Original expected/test changed'
Require31 ((Hash31 "$stem31-tests-before.ts") -eq $testSHA31) 'Baseline test snapshot changed'
$matrix31 = Get-Content "$stem31-matrix-before.json" -Raw | ConvertFrom-Json
Require31 ($matrix31.expectedSHA -eq $expectedSHA31) 'Pre-run expected mismatch'
$runs31 = @()
foreach ($mode31 in @('baseline', 'final')) {
    $raw31 = Records31 "$stem31-$mode31.log"
    $summary31 = @($raw31 | Where-Object stage -eq summary)
    Require31 ($summary31.Count -eq 1 -and $summary31[0].cases -eq 12 -and $summary31[0].httpCount -eq 3) 'Matrix inventory'
    $wantFail31 = if ($mode31 -eq 'baseline') { 4 } else { 0 }
    Require31 ($summary31[0].fail -eq $wantFail31 -and $summary31[0].pass -eq (12 - $wantFail31)) 'Baseline/final outcome'
    $cases31 = @($raw31 | Where-Object stage -eq case)
    Require31 ($cases31.Count -eq 12 -and @($cases31.name | Select-Object -Unique).Count -eq 12) 'Case uniqueness'
    foreach ($n31 in $expected31.cases) { Require31 (@($cases31 | Where-Object name -eq $n31).Count -eq 1) ('Missing expected ' + $n31) }
    Require31 (@($raw31 | Where-Object stage -eq 'harness-failure').Count -eq 0) 'Harness failure is not runtime evidence'
    $env31 = @($raw31 | Where-Object stage -eq environment)[0]
    Require31 ($env31.expectedSHA -eq $expectedSHA31 -and $env31.testSHA -eq $testSHA31) 'Runtime expected/test SHA'
    $obs31 = @($raw31 | Where-Object stage -eq 'retention-observation')
    Require31 ($obs31.Count -eq 8) 'Retention observation inventory'
    foreach ($o31 in $obs31) {
        Require31 ($o31.beforeCount - $o31.afterCount -eq $o31.deletedCount -and @($o31.deletedIds).Count -eq $o31.deletedCount) 'DB delta/deleted IDs'
        Require31 (@($o31.deletedIds | Select-Object -Unique).Count -eq $o31.deletedCount) 'Duplicate deleted ID'
        if ($mode31 -eq 'final') { Require31 ($o31.deletedCount -le 500) 'Batch limit' }
    }
    Require31 (@($obs31 | Where-Object name -eq boundary)[0].deletedCount -eq 3 -and @($obs31 | Where-Object name -eq 'boundary-repeat')[0].deletedCount -eq 0) 'Existing strict TTL boundary'
    foreach ($prefix31 in @('batch', 'actual-sweep')) {
        $first31 = @($obs31 | Where-Object name -eq "$prefix31-first")[0]
        $second31 = @($obs31 | Where-Object name -eq "$prefix31-second")[0]
        $third31 = @($obs31 | Where-Object name -eq "$prefix31-third")[0]
        $wantFirst31 = if ($mode31 -eq 'baseline') { 501 } else { 500 }
        $wantSecond31 = if ($mode31 -eq 'baseline') { 0 } else { 1 }
        Require31 ($first31.beforeCount -eq 506 -and $first31.deletedCount -eq $wantFirst31 -and $second31.deletedCount -eq $wantSecond31 -and $third31.deletedCount -eq 0 -and $third31.afterCount -eq 5) '501 seed multi-call result'
        if ($mode31 -eq 'final') {
            $wantedIds31 = @('ffffffff-ffff-4fff-8fff-ffffffffffff') + @(1..499 | ForEach-Object { '00000000-0000-4000-8000-' + $_.ToString('D12') })
            Require31 (($first31.deletedIds -join ',') -eq ($wantedIds31 -join ',') -and $second31.deletedIds[0] -eq '00000000-0000-4000-8000-000000000500') 'Stable older-first/tie IDs'
            Require31 ($first31.afterCount -eq 6 -and $second31.afterCount -eq 5) 'Residual readback'
        }
    }
    $lock31 = @($raw31 | Where-Object stage -eq 'row-lock-barrier')[0]
    Require31 ($lock31.observedDeleteWait -and @($lock31.waiters | Where-Object { $_.wait_event_type -eq 'Lock' -and $_.blockers -contains $lock31.ownBlockerPid }).Count -ge 1) 'Native PG lock barrier'
    $recheck31 = @($cases31 | Where-Object name -eq 'same-cutoff-row-lock-recheck')[0]
    Require31 ($recheck31.result -eq 'PASS' -and $recheck31.evidence.deleteReturned.count -eq 0 -and $recheck31.evidence.lockWaitObserved) 'Rechecked fresh row retained'
    $actual31 = @($raw31 | Where-Object stage -eq 'actual-pre-state')[0]
    Require31 ($actual31.realClock -and $actual31.marginDays -ge 1 -and $actual31.eligible -eq 501 -and $actual31.kept -eq 5 -and $actual31.jobLeaseTicketOutboxEmpty -and $actual31.mediaEmpty -and -not $actual31.workerMain -and -not $actual31.scheduler) 'Actual sweep scope/preconditions'
    $http31 = @($raw31 | Where-Object stage -eq http)
    Require31 ($http31.Count -eq 3 -and ($http31.status -join ',') -eq '403,200,200' -and $http31[0].response.error.code -eq 'ADMIN_REQUIRED') 'HTTP guard/control inventory'
    foreach ($h31 in $http31) { Require31 ($h31.method -eq 'GET' -and $h31.noStore -and $h31.nosniff -and -not $h31.setCookie -and -not $h31.guestCookie -and -not $h31.csrfHeader) 'HTTP headers/GET auth scope' }
    foreach ($pair31 in @(@(1,167,167,100), @(2,0,0,$null))) {
        $body31 = $http31[$pair31[0]].response
        $a31 = @($body31.rows | Where-Object title -eq 'p31-A')[0]
        $z31 = @($body31.rows | Where-Object title -eq 'p31-zero')[0]
        Require31 ($body31.rows.Count -eq 2 -and $a31.impressions -eq $pair31[1] -and $a31.clicks -eq $pair31[2] -and $a31.ctrPercent -eq $pair31[3] -and $z31.impressions -eq 0 -and $z31.clicks -eq 0 -and $null -eq $z31.ctrPercent) 'Stats counts/CTR/zero campaign'
        Require31 ($body31.window.timezone -eq 'UTC' -and [DateTimeOffset]$body31.window.from -eq [DateTimeOffset]'2026-09-01T12:00:00Z' -and [DateTimeOffset]$body31.window.to -eq [DateTimeOffset]'2026-10-06T12:00:00Z') 'Actual window'
    }
    $cleanup31 = @($raw31 | Where-Object stage -eq cleanup)[0]
    $media31 = @($raw31 | Where-Object stage -eq 'media-cleanup')[0]
    $close31 = @($raw31 | Where-Object stage -eq close)[0]
    Require31 ($cleanup31.fixtureRowsAfter -eq 0 -and $cleanup31.chargedWrites -eq 0 -and $cleanup31.ownedKeysRemoved -eq 2 -and $cleanup31.requestCount -eq 3 -and $cleanup31.keptMain) 'Own fixture cleanup'
    Require31 (@($cleanup31.settingsBefore).Count -eq 0 -and @($cleanup31.settingsAfter).Count -eq 0 -and @($cleanup31.budgetBefore).Count -eq 0 -and @($cleanup31.budgetAfter).Count -eq 0) 'Empty settings/budget unchanged'
    Require31 ($media31.verifiedResolvedOwnPath -and $media31.emptyBeforeRmdir -and -not $media31.recursive) 'Own media empty non-recursive cleanup'
    Require31 ($close31.httpClosed -and $close31.datastoreClientsClosed -and $close31.hooksRestored -and $close31.counters.httpDials -eq 3 -and $close31.counters.listens -eq 1 -and $close31.counters.deniedDials -eq 0 -and $close31.counters.deniedListens -eq 0) 'Clients/server/hooks closed/socket counters'
    $runs31 += @{ mode=$mode31; summary=$summary31[0]; http=$http31.Count; environment=$env31; cleanup=$cleanup31; close=$close31 }
}
$final31 = $runs31[1].environment
Require31 ($final31.sourceSHA -eq '783f27a3850900ba1136fc0a2cb99e4d36504950f2ff1697d116b04b237780af') 'Final runtime fingerprint'
foreach ($h31 in $final31.hashes.PSObject.Properties) { Require31 ((Hash31 $h31.Name) -eq $h31.Value) ('Current runtime source changed ' + $h31.Name) }
$beforeLifecycle31 = [IO.File]::ReadAllText((Join-Path $root31 "$stem31-source-before/apps/worker/src/lifecycle.ts")).Replace("`r`n", "`n")
$nowLifecycle31 = [IO.File]::ReadAllText((Join-Path $root31 'apps/worker/src/lifecycle.ts')).Replace("`r`n", "`n")
$reversed31 = $nowLifecycle31.Replace("import { purgeAdEvents } from './ad-event-retention';`n", '').Replace('await purgeAdEvents();', 'await db.adEvent.deleteMany({ where: { createdAt: { lt: after(-30 * 86400) } } });')
Require31 ($beforeLifecycle31 -ceq $reversed31) 'Lifecycle changed beyond retention import/call'
foreach ($phase31 in @(@('start-before','Start'),@('stop-before','Stop'),@('start-final','Start'),@('final','Matrix'),@('typecheck','Typecheck'),@('containers-final','Logs'),@('stop-final','Stop'))) { Require31 ((Get-Content "$stem31-$($phase31[0]).log" -Raw).Contains('P31_COMMAND_EXIT 0 ' + $phase31[1] + ' UTC')) 'Missing command completion exit0' }
Require31 ((Get-Content "$stem31-stop-final.log" -Raw).Contains('PASS own3 removed, volumes/network/raw retained')) 'Missing own Stop proof'
$commands31 = Get-Content "$stem31-commands.json" -Raw | ConvertFrom-Json
Require31 (@($commands31.commands | Where-Object { $_.phase -eq 'Baseline' -and $_.exitCode -eq 1 -and $_.completionEvidence -eq 'exec/write_stdin session15491 returned process exit code1' }).Count -eq 1) 'Baseline completion ledger'
foreach ($script31 in @('scripts/test-ad-retention.ps1','scripts/verify-ad-retention-evidence.ps1')) { $tokens31=$null; $errors31=$null; [void][Management.Automation.Language.Parser]::ParseFile((Join-Path $root31 $script31),[ref]$tokens31,[ref]$errors31); Require31 ($errors31.Count -eq 0) ('PowerShell parser ' + $script31) }
$manifestPath31 = "$stem31-manifest-final.json"
if ($CaptureSnapshot) {
    Require31 (-not (Test-Path -LiteralPath $manifestPath31)) 'Never overwrite frozen31 manifest'
    foreach ($p31 in $protected31.allowed) { $dest31=Join-Path "$stem31-source-final" $p31; New-Item -ItemType Directory -Force -Path (Split-Path $dest31) | Out-Null; Copy-Item -LiteralPath $p31 -Destination $dest31 }
    Json31 "$stem31-summary-final.json" @{ utc=[DateTime]::UtcNow.ToString('o'); vn=[DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(7)).ToString('o'); scope='Offline evidence/hash parser; no runtime/HTTP rerun; implementation31 pending independent audit'; protected=1027; runs=$runs31; actualHttpAllRuns=6; caveats='Controlled clock vs manual actual real-clock sweep; empty outside models; admin cookie/Redis fixture; no scheduler/live lease/nonzero charged/load/Internet/main/public certification' }
    $files31 = @(Get-ChildItem docs/evidence -Recurse -File | Where-Object { $_.FullName.Contains('p31-20261004') -and $_.Name -notmatch '(manifest-final|verification|offline-verify)' }) + @(Get-ChildItem tests/p31 -Recurse -File) + @(Get-Item scripts/test-ad-retention.ps1,scripts/verify-ad-retention-evidence.ps1,infra/compose.ad-retention-lab.yaml,infra/ad-retention-lab.env.example)
    $artifacts31 = @($files31 | Sort-Object FullName -Unique | ForEach-Object { @{path=$_.FullName.Substring($root31.Length+1).Replace('\','/');sha=Hash31 $_.FullName} })
    $code31 = @($final31.hashes.PSObject.Properties | ForEach-Object { @{path=$_.Name;sha=$_.Value} })
    Json31 $manifestPath31 @{ utc=[DateTime]::UtcNow.ToString('o'); historicalScopes='19-30 frozen/protected, no reruns; handoff prose31 stored as copies, old validators/manifests unchanged'; sourceSHA=$final31.sourceSHA; currentCode=$code31; artifacts=$artifacts31 }
}
Require31 (Test-Path -LiteralPath $manifestPath31) 'Capture own final manifest once after handoff documents'
$manifest31 = Get-Content $manifestPath31 -Raw | ConvertFrom-Json
foreach ($h31 in @($manifest31.currentCode)+@($manifest31.artifacts)) { Require31 ((Hash31 $h31.path) -eq $h31.sha) ('Evidence/source mismatch ' + $h31.path) }
Write-Host ('PASS offline31 protected1027 artifacts' + $manifest31.artifacts.Count + ' baseline8PASS/4FAIL final12PASS HTTP3each/6total bounded500-1-0 lock-recheck cleanup/Stop/typecheck; no runtime rerun UTC ' + [DateTime]::UtcNow.ToString('o'))
