param([switch]$Capture)
$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
$root='D:\WED SNAP';$ev='docs/evidence/tiktok-app-integration-20261009'
function SHA($p){(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLower()}
function Require($ok,$why){if(-not $ok){throw $why}}
$allowed=@('Dockerfile','apps/media/Dockerfile','apps/media/src/media_adapter.py','apps/media/README.md','apps/worker/src/adapter.ts','docs/AUDIT_TIEN_DO.md','docs/PROGRESS.md','docs/ADAPTERS.md','docs/TEST_REPORT.md','docs/STRUCTURE.md','docs/TIKTOK_APP_INTEGRATION_PLAN.md')
$before=@(Get-Content "$ev/before-all.json" -Raw|ConvertFrom-Json);$baseline=@{};$kept=0;$changed=@()
foreach($r in $before){
 $baseline[$r.path]=$r;Require (Test-Path -LiteralPath $r.path) "Missing baseline $($r.path)"
 if((SHA $r.path) -cne $r.sha256){Require ($r.path -cin $allowed) "Unscoped change $($r.path)";$changed+=$r.path}
 else{Require ((Get-Item -LiteralPath $r.path).Length -eq $r.bytes) 'Baseline bytes';$kept++}
}
Require (-not(Compare-Object ($allowed|Sort-Object) ($changed|Sort-Object))) 'Exact app/media/env glue and related docs scope'
$audit=Get-Content "$ev/prior-audit-successor-copy.json" -Raw|ConvertFrom-Json
Require ((SHA "$ev/prior-audit-successor-copy.json") -ceq (SHA 'docs/evidence/tiktok-cobalt-connection-boundaries-audit-20261009/successor.json') -and (SHA $audit.predecessorManifest) -ceq $audit.predecessorManifestSHA) 'Prior audit/golden frozen'
foreach($r in @(Get-Content $audit.predecessorManifest -Raw|ConvertFrom-Json)){
 $b=$baseline[$r.path];Require ($null -ne $b) 'Golden baseline coverage'
 $doc=@($audit.changedDocs|Where-Object {$_.path -ceq $r.path})
 if($doc.Count){Require ($r.sha256 -ceq $doc[0].beforeSHA -and $b.sha256 -ceq $doc[0].afterSHA) 'Docs-only prior audit lineage'}
 else{Require ($r.sha256 -ceq $b.sha256 -and (SHA $r.path) -ceq $r.sha256) 'Lab raw/code/golden unchanged'}
}
$oldY=[IO.File]::ReadAllText("$root/$ev/before/apps--media--src--media_adapter.py")
$newY=[IO.File]::ReadAllText("$root/apps/media/src/media_adapter.py")
Require ($oldY.Substring($oldY.IndexOf('import yt_dlp')) -ceq $newY.Substring($newY.IndexOf('import yt_dlp'))) 'YouTube entire legacy implementation byte text unchanged'
$workerOld=[IO.File]::ReadAllText("$root/$ev/before/apps--worker--src--adapter.ts")
$workerNew=[IO.File]::ReadAllText("$root/apps/worker/src/adapter.ts")
$without=[regex]::Replace($workerNew,'(?m)^          ADAPTER_(ANALYZE|PREPARE)_TIMEOUT:.*\r?\n','')
Require ($without -ceq $workerOld) 'Worker changes only forwarding bounded phase timeouts; processgroup untouched'
$provenance=Get-Content apps/media/src/tiktok/PROVENANCE.json -Raw|ConvertFrom-Json
Require ($provenance.license -ceq 'AGPL-3.0' -and $provenance.commit -ceq 'a636575b09de1fc55d9b8cd98cac88f5f2f16b42' -and $provenance.noRunnerFixtureCopied -and $provenance.YouTubeTailExact) 'License/source provenance'
foreach($f in $provenance.files){
 Require ((SHA $f.from) -ceq $f.fromSHA -and (SHA $f.to) -ceq $f.toSHA) 'Copied core/vendor source SHA'
 if($f.from -like '*vendor/*' -or $f.to -like '*package*json' -or $f.to -like '*LICENSE'){Require (-not $f.modified) 'Vendor/license/locked dependencies unchanged'}
}
$runtime=Get-Content "$ev/verify-runtime/runtime-pins.json" -Raw|ConvertFrom-Json
Require ($runtime.status -ceq 'PASS' -and $runtime.python.'yt-dlp' -ceq '2026.8.19' -and $runtime.python.requests -ceq '2.34.2' -and $runtime.python.urllib3 -ceq '2.8.0' -and $runtime.ffmpeg -ceq '5.1.9' -and $runtime.npm.undici -ceq '6.24.1') 'Actual runtime pins'
foreach($f in $runtime.files){
 if($f.path -notlike 'node_modules/*' -and ($f.path -match '\.(py|mjs|js)$' -or $f.path -in @('package.json','package-lock.json','LICENSE'))){
  Require ((SHA "apps/media/src/tiktok/$($f.path)") -ceq $f.sha256) 'Exact tested executable/package/lock/license host-image match'
 }
}
Require (@(Get-ChildItem apps/media/src/tiktok -Recurse -File|Where-Object {$_.Name -match '^(run|test_|fixture|verify|benchmark|yt_candidate_driver|supervise)'}).Count -eq 0) 'No lab runtime harness/fixture in app core'
Require ([IO.File]::ReadAllText("$root/Dockerfile") -notmatch 'COPY \. \.') 'Product recipe excludes whole lab/test checkout'
$cli=Get-Content "$ev/cli-5/cli-result.json" -Raw|ConvertFrom-Json
Require ($cli.status -ceq 'PASS' -and $cli.sourceCalls -eq 0 -and $cli.results.Count -eq 19) 'Final19 CLI fixture cases'
$two=$cli.results[0]
Require (($two.actualExits -join ',') -ceq '0,0' -and ($two.metadataGET -join ',') -ceq '2,2' -and $two.MP4GET -eq 1 -and $two.distinctChildren -and $two.schemaUnchanged -and $two.output -ceq 'media.mp4') 'Two-child workflow2+2+1/CLI/schema/output'
foreach($name in @('fresh-format-changed','fresh-prepare-bodyID-mismatch','actual-file-dimensions-mismatch-cleanup','lower-output-cap','lower-aggregate-input','job-folder-symlink','shortlink-not-supported-no-request','default-off','preexisting-preserved','total10-reserve-exhausted')){
 Require (@($cli.results|Where-Object {$_.case -ceq $name -and $_.actualExit -ne 0}).Count -eq 1) 'Targeted reject/limits/ownership/defaultoff cases'
}
$api=Get-Content "$ev/api-2/api-result.json" -Raw|ConvertFrom-Json
Require ($api.status -ceq 'PASS' -and $api.sourceCalls -eq 0 -and $api.outcomes.Count -eq 6) 'Real API/worker private fixture cases'
$flow=@($api.outcomes|Where-Object {$_.case -ceq 'two-child-native-full-Range-lease'})[0]
Require ($flow.metadataGET -eq 4 -and $flow.MP4GET -eq 1 -and $flow.distinctChildren -and $flow.leases -eq 2) 'API separate phases/private source-free native transfer leases'
foreach($mode in @('cancel','expired','deadline')){
 Require (@($api.outcomes|Where-Object {$_.case -ceq "$mode-ProcessGroup-child-helper-cleanup" -and $_.groupLive -eq 0}).Count -eq 1) 'Actual group/descendant cleanup on terminal states'
}
$main=Get-Content "$ev/main-off-check.json" -Raw|ConvertFrom-Json
Require ($main.mainImageUnchanged -and -not $main.mainSettingsDBAccessed -and -not $main.mainComposeChanged -and $main.sourceCalls -eq 0) 'Main not enabled/built/data touched'
Require ($newY -match "get\('TIKTOK_ADAPTER_ENABLED'\)!='1'") 'Explicit default-off CLI gate'
foreach($dir in @('cli-4','cli-5','api-2','verify-runtime','typecheck-2')){
 $completion=Get-Content "$ev/$dir/completion.json" -Raw|ConvertFrom-Json
 Require ($completion.actualExit -eq 0 -and $completion.ownResourcesLeft -eq 0 -and $completion.sourceCalls -eq 0 -and $completion.image -ceq $main.integrationImage) 'Actual finalPASS/owncleanup/image'
}
$early=Get-Content "$ev/cli-3/completion.json" -Raw|ConvertFrom-Json
Require ($early.actualExit -eq 0 -and $early.ownResourcesLeft -eq 0 -and $early.sourceCalls -eq 0) 'Earlier image CLI PASS kept as earlier evidence, not final gate'
foreach($f in @(@{dir='cli-1';step='test';exit=1},@{dir='cli-2';step='test';exit=1},@{dir='typecheck-1';step='test';exit=2})){
 $rows=@(Get-Content "$ev/$($f.dir)/native.jsonl"|ForEach-Object {$_|ConvertFrom-Json})
 Require (@($rows|Where-Object {$_.step -ceq $f.step -and $_.actualExit -eq $f.exit}).Count -eq 1 -and @($rows|Where-Object {$_.step -ceq 'remove' -and $_.actualExit -eq 0}).Count -eq 1) 'Retained FAIL and exact own removal'
}
$repair=Get-Content "$ev/api-1/cleanup-repair.json" -Raw|ConvertFrom-Json
Require ($repair.functionalTest -ceq 'PASS' -and $repair.runnerOuterExit -eq 1 -and $repair.ownResourcesLeft -eq 0 -and $repair.noMainTouched) 'API1 stale-ID failure/repaired own cleanup preserved'
$guards=@(Get-ChildItem "$ev/api-2/guard-*.json"|ForEach-Object {Get-Content $_.FullName -Raw|ConvertFrom-Json})
Require ($guards.Count -eq 3 -and ($guards.HostConfig.Memory|Measure-Object -Sum).Sum -eq 960MB) 'PrivateAPI lab total960MiB'
foreach($g in $guards){
 Require ($g.HostConfig.ReadonlyRootfs -and -not $g.HostConfig.Privileged -and -not $g.HostConfig.CapAdd -and $g.HostConfig.CapDrop -contains 'ALL' -and $g.HostConfig.SecurityOpt -contains 'no-new-privileges:true' -and $g.HostConfig.MemorySwap -eq $g.HostConfig.Memory -and $g.HostConfig.IpcMode -ceq 'private' -and -not $g.HostConfig.PidMode -and @($g.HostConfig.PortBindings.PSObject.Properties).Count -eq 0) 'Actual lab isolation'
}
$app=@($guards|Where-Object {$_.Config.Labels.'com.docker.compose.service' -ceq 'app'})[0]
Require ($app.Image -ceq $main.integrationImage -and $app.Config.Env -contains 'DATABASE_URL=postgresql://tiktok_fixture:lab-public-only-password@postgres:5432/tiktok_app_fixture' -and $app.Config.Env -contains 'REDIS_URL=redis://redis:6379/7' -and @($app.Mounts|Where-Object {$_.Type -eq 'volume'}).Count -eq 0) 'No main database/volume'
$rows=@(Get-Content "$ev/api-2/native.jsonl"|ForEach-Object {$_|ConvertFrom-Json})
Require (@($rows|Where-Object {$_.step -ceq 'app-wait' -and $_.stdout.Trim() -ceq '0'}).Count -eq 1 -and @($rows|Where-Object {$_.step -ceq 'remove' -and $_.actualExit -eq 0}).Count -eq 3 -and @($rows|Where-Object {$_.step -ceq 'remove-network' -and $_.actualExit -eq 0}).Count -eq 1) 'Start-only IDs preserved/final app0/own3containers+network removed'
$exclude=@("$ev/manifest.json","$ev/manifest-sha256.txt")
function Paths{@(@(rg --files -uu $ev apps/media/src/tiktok labs/tiktok/app-integration|ForEach-Object {$_.Replace('\','/')}|Where-Object {$_ -cnotin $exclude})+$allowed+@('docs/TIKTOK_APP_INTEGRATION_HANDOFF.md')|Sort-Object -Unique)}
if($Capture){
 Require (-not(Test-Path "$ev/manifest.json")) 'No manifest overwrite'
 [ordered]@{utc=[DateTime]::UtcNow.ToString('o');kind='TikTok core app integration offline-only successor';predecessorManifest=$audit.predecessorManifest;predecessorManifestSHA=$audit.predecessorManifestSHA;changes=@(foreach($f in $allowed){@{path=$f;beforeSHA=$baseline[$f].sha256;afterSHA=(SHA $f)}})}|ConvertTo-Json -Depth 6|Set-Content "$ev/successor.json" -Encoding utf8
 [ordered]@{utc=[DateTime]::UtcNow.ToString('o');vn=[DateTime]::UtcNow.AddHours(7).ToString('yyyy-MM-dd HH:mm:ss.fff');baseline=$before.Count;preserved=$kept;exactChanges=$changed;CLI='PASS19cases';APIWorker='PASS_FIXTURE_ONLY';runtimePins='PASS';typecheck='PASS';workflowGET='2+2+1_MAX';twoIndependentChildren=$true;sourceCalls=0;sourceAPIE2E='NOT_RUN';mainTikTok='OFF';mainImageUnchanged=$true;mainDataTouched=$false;YouTubeLegacyUnchanged=$true;cleanupLeft=0;acceptedSourceSamples=2;sample3Review='NEEDS_VISUAL_REVIEW';deploy=$false}|ConvertTo-Json -Depth 6|Set-Content "$ev/completion.json" -Encoding utf8
 @(foreach($f in (Paths)){@{path=$f;bytes=(Get-Item -LiteralPath $f).Length;sha256=(SHA $f)}})|ConvertTo-Json -Depth 5|Set-Content "$ev/manifest.json" -Encoding utf8
 SHA "$ev/manifest.json"|Set-Content "$ev/manifest-sha256.txt" -Encoding ascii
}
$successor=Get-Content "$ev/successor.json" -Raw|ConvertFrom-Json
Require (-not(Compare-Object ($allowed|Sort-Object) (@($successor.changes.path)|Sort-Object))) 'Exact successor scope'
foreach($r in $successor.changes){Require ((SHA $r.path) -ceq $r.afterSHA -and $baseline[$r.path].sha256 -ceq $r.beforeSHA) 'Successor before/after hashes'}
$manifest=@(Get-Content "$ev/manifest.json" -Raw|ConvertFrom-Json)
Require ((SHA "$ev/manifest.json") -ceq (Get-Content "$ev/manifest-sha256.txt" -Raw).Trim() -and @($manifest.path|Sort-Object -Unique).Count -eq $manifest.Count -and -not(Compare-Object (Paths) @($manifest.path|Sort-Object))) 'Manifest self/full distinct coverage'
foreach($r in $manifest){Require ((SHA $r.path) -ceq $r.sha256 -and (Get-Item -LiteralPath $r.path).Length -eq $r.bytes) 'Artifact SHA/bytes'}
Write-Output "PASS integration offline baseline=$($before.Count); preserved=$kept; scoped=$($changed.Count); artifacts=$($manifest.Count)/$($manifest.Count); CLI19/API-worker-fixture/pins/typecheck PASS; independent2phases/2+2+1GET/media.mp4; YouTube/processgroup/lifecycle/CSRF/schema/rawgolden preserved; mainTikTokOFF/source0/deploy0; cleanup0; sample3reviewpending/accepted2-3"
