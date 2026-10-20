param([switch]$Capture)
$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
$ev='docs/evidence/tiktok-app-core-fixes-20261009'
function SHA($p){(Get-FileHash -LiteralPath $p -Algorithm SHA256).Hash.ToLower()}
function Require($ok,$why){if(-not $ok){throw $why}}
$allowed=@('apps/media/src/tiktok/core.py','apps/media/src/tiktok/adapter.py','apps/media/src/tiktok/candidate_file.py','apps/media/src/tiktok/NOTICE.md','apps/media/src/tiktok/PROVENANCE.json','docs/AUDIT_TIEN_DO.md','docs/PROGRESS.md')
$baseline=@{};foreach($r in @(Get-Content "$ev/baseline.json" -Raw|ConvertFrom-Json)){$baseline[$r.path]=$r}
$preserved=0;$changed=@()
foreach($p in $baseline.Keys){
 Require (Test-Path -LiteralPath $p -PathType Leaf) "Missing baseline file $p"
 $now=SHA $p
 if($now -cne $baseline[$p].sha256){Require ($allowed -ccontains $p) "Out of scope modification $p";$changed+=$p}
 else{$preserved++}
}
Require ($changed.Count -eq 7) 'Exactly seven scoped existing-file changes'
$all=@(rg --files --hidden -g '!.git/**' -g '!node_modules/**' -g '!**/node_modules/**' -g '!**/__pycache__/**' -g '!.codex/**' -g '!.agents/**')|ForEach-Object {$_.Replace('\','/')}
foreach($p in $all){if(-not $baseline.ContainsKey($p)){Require ($p.StartsWith("$ev/") -or $p.StartsWith('labs/tiktok/app-core-fixes/') -or $p -ceq 'docs/TIKTOK_APP_CORE_FIXES_HANDOFF.md') "Out of scope new file $p"}}
$s=Get-Content "$ev/successor.json" -Raw|ConvertFrom-Json
$a=Get-Content $s.auditSuccessor -Raw|ConvertFrom-Json
Require ((SHA $s.auditSuccessor) -ceq $s.auditSuccessorSHA -and (SHA $a.predecessorManifest) -ceq $a.predecessorManifestSHA) 'Immutable audit and old golden'
foreach($r in @(Get-Content $a.predecessorManifest -Raw|ConvertFrom-Json)){
 $b=$baseline[$r.path];Require ($null -ne $b) 'Prior manifest baseline coverage'
 $d=@($a.changedDocs|Where-Object {$_.path -ceq $r.path})
 if($d.Count){Require ($r.sha256 -ceq $d[0].beforeSHA -and $b.sha256 -ceq $d[0].afterSHA) 'Prior audit docs bridge'}
 else{Require ($r.sha256 -ceq $b.sha256) 'Prior manifest unchanged before new scope'}
}
foreach($d in $s.changedDocs){
 Require ((SHA $d.beforeCopy) -ceq $d.beforeSHA -and (SHA $d.path) -ceq $d.afterSHA) 'New docs bridge hashes'
 $before=[IO.File]::ReadAllText((Resolve-Path $d.beforeCopy));$after=[IO.File]::ReadAllText((Resolve-Path $d.path))
 $insert=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($d.insertedTextBase64))
 Require ($after.Replace($insert,'') -ceq $before) 'Only documented insertion; all historical doc text preserved'
}
foreach($f in $s.changedCore){Require ($baseline[$f.path].sha256 -ceq $f.beforeSHA -and (SHA $f.path) -ceq $f.afterSHA) 'Executable successor'}
$prov=Get-Content apps/media/src/tiktok/PROVENANCE.json -Raw|ConvertFrom-Json
Require ($prov.commit -ceq 'a636575b09de1fc55d9b8cd98cac88f5f2f16b42' -and $prov.license -ceq 'AGPL-3.0') 'License provenance'
foreach($f in $prov.files){Require ((SHA $f.from) -ceq $f.fromSHA -and (SHA $f.to) -ceq $f.toSHA) 'Provenance exact hashes'}
$build=Get-Content "$ev/build-2/receipt.json" -Raw|ConvertFrom-Json
Require ($build.actualExit -eq 0 -and $build.parentBefore -ceq $build.parentAfter -and $build.parentAfter -ceq 'sha256:d4558b29dd379b16d4906fb9e618dfc4d045e3008a70e031ea3474b7b2218e4e' -and $build.dependencyInstalls -eq 0 -and -not $build.productionBuild) 'Cached COPY-only build'
foreach($dir in @('fixes-2','regression-1','runtime-1')){
 $c=Get-Content "$ev/$dir/completion.json" -Raw|ConvertFrom-Json;$g=Get-Content "$ev/$dir/guard.json" -Raw|ConvertFrom-Json;$state=Get-Content "$ev/$dir/state.json" -Raw|ConvertFrom-Json
 Require ($c.actualExit -eq 0 -and $c.ownResourcesLeft -eq 0 -and $c.sourceCalls -eq 0 -and $c.image -ceq $build.image -and $state.ExitCode -eq 0 -and -not $state.Running -and -not $state.OOMKilled) 'Native exits/state/cleanup'
 Require ($g.Image -ceq $build.image -and $g.Config.User -ceq '1000:1000' -and $g.HostConfig.ReadonlyRootfs -and $g.HostConfig.NetworkMode -ceq 'none' -and $g.HostConfig.Memory -eq 512MB -and $g.HostConfig.MemorySwap -eq 512MB -and $g.HostConfig.NanoCpus -eq 750000000 -and $g.HostConfig.PidsLimit -eq 96 -and $g.HostConfig.IpcMode -ceq 'private' -and $g.HostConfig.CapDrop -contains 'ALL' -and $g.HostConfig.SecurityOpt -contains 'no-new-privileges:true') 'Observed guards'
 $n=@(Get-Content "$ev/$dir/native.jsonl"|ForEach-Object {$_|ConvertFrom-Json})
 Require (@($n|Where-Object {$_.step -ceq 'test' -and $_.actualExit -eq 0}).Count -eq 1 -and @($n|Where-Object {$_.step -ceq 'remove' -and $_.actualExit -eq 0}).Count -eq 1) 'Recorded native exits'
}
$f=Get-Content "$ev/fixes-2/fixes-result.json" -Raw|ConvertFrom-Json
$c=Get-Content "$ev/regression-1/cli-result.json" -Raw|ConvertFrom-Json
Require ($f.status -ceq 'PASS' -and $f.results.Count -eq 29 -and $f.sourceCalls -eq 0 -and $c.status -ceq 'PASS' -and $c.results.Count -eq 19 -and $c.sourceCalls -eq 0) 'Fresh fixtures29+19'
foreach($case in @('CLI-duration-above','CLI-body-direct-meta','CLI-body-wrapped-meta','CLI-body-direct-mp4','CLI-body-wrapped-mp4')){
 $r=@($f.results|Where-Object {$_.case -ceq $case})[0]
 Require ($r.ownedCleanup -and ($r.actualExit -eq 1 -or ($r.actualExits -join ',') -ceq '0,1')) 'Fail cleanup and actual child exit'
 Require ($r.error -ceq $(if($case -eq 'CLI-duration-above'){'LIMIT_EXCEEDED'}else{'SOURCE_TIMEOUT'})) 'Correct public error'
}
Require (($c.results[0].actualExits -join ',') -ceq '0,0' -and ($c.results[0].metadataGET -join ',') -ceq '2,2' -and $c.results[0].MP4GET -eq 1 -and $c.results[0].distinctChildren -and $c.results[0].schemaUnchanged) 'Workflow separate children/schema/request budget'
$runtime=Get-Content "$ev/runtime-1/runtime-pins.json" -Raw|ConvertFrom-Json
Require ($runtime.status -ceq 'PASS' -and $runtime.python.requests -ceq '2.34.2' -and $runtime.python.urllib3 -ceq '2.8.0' -and $runtime.python.'yt-dlp' -ceq '2026.8.19' -and $runtime.ffmpeg -ceq '5.1.9') 'Runtime pinned libraries'
$coreFiles=@($runtime.files|Where-Object {$_.path -notlike 'node_modules/*'})
foreach($r in $coreFiles){Require ((SHA "apps/media/src/tiktok/$($r.path)") -ceq $r.sha256) 'Exact host-image tested core gate'}
$api=Get-Content "$ev/runtime-1/library-api-check.json" -Raw|ConvertFrom-Json;Require ($api.status -ceq 'PASS' -and $api.sourceCalls -eq 0) 'Pinned official API source check'
$main=Get-Content "$ev/main-off-check.json" -Raw|ConvertFrom-Json
Require ($main.mainImage -ceq 'sha256:e7f9357708ac06fab1efbc247ad7a11c8b84d9f549d705ec30e7ce53a6d0184b' -and $main.ownContainers -eq 0 -and $main.sourceCalls -eq 0 -and $main.TikTokMain -ceq 'OFF' -and -not $main.mainSettingsDBAccessed) 'Main unchanged/off/source0/cleanup0'
Require ($s.sample3Review -ceq 'NEEDS_VISUAL_REVIEW' -and $s.acceptedSourceSamples -eq 2) 'Acceptance not expanded'
$fail=Get-Content "$ev/early-runner-failures.json" -Raw|ConvertFrom-Json;Require ($fail.build1RunnerExit -eq 1 -and $fail.fixes1RunnerExit -eq 1 -and $fail.ownResourcesCreated -eq 0) 'Failed attempts retained'
Require ((Get-Content apps/media/src/media_adapter.py -Raw) -match "get\('TIKTOK_ADAPTER_ENABLED'\)!='1'") 'Default-off runtime'
$coverage=@($all|Where-Object {($_.StartsWith("$ev/") -and $_ -notmatch '/(manifest\.json|manifest\.sha256|verification[^/]*\.(json|log))$') -or $_.StartsWith('labs/tiktok/app-core-fixes/') -or $_.StartsWith('apps/media/src/tiktok/') -or $_ -in @('docs/AUDIT_TIEN_DO.md','docs/PROGRESS.md','docs/TIKTOK_APP_CORE_FIXES_HANDOFF.md')}|Sort-Object -Unique)
if($Capture){
 Require (-not (Test-Path "$ev/manifest.json")) 'No recapture of frozen manifest'
 $records=@(foreach($p in $coverage){@{path=$p;bytes=(Get-Item -LiteralPath $p).Length;sha256=SHA $p}})
 $records|ConvertTo-Json -Depth 5|Set-Content "$ev/manifest.json"
 SHA "$ev/manifest.json"|Set-Content "$ev/manifest.sha256"
}else{
 Require ((SHA "$ev/manifest.json") -ceq (Get-Content "$ev/manifest.sha256").Trim()) 'New golden manifest hash'
 $records=@(Get-Content "$ev/manifest.json" -Raw|ConvertFrom-Json)
 Require ($records.Count -eq $coverage.Count -and -not (Compare-Object @($records.path|Sort-Object) $coverage)) 'Full evidence/code coverage'
 foreach($r in $records){Require ((SHA $r.path) -ceq $r.sha256 -and (Get-Item -LiteralPath $r.path).Length -eq $r.bytes) 'Frozen artifact hash/bytes'}
}
@{status='PASS';artifactCount=$records.Count;baselineCount=$baseline.Count;baselinePreserved=$preserved;scopedChanges=@($changed|Sort-Object);testedCoreFiles=$coreFiles.Count;targetedCases=29;regressionCases=19;sourceCalls=0;ownResourcesLeft=0;utc=[DateTime]::UtcNow.ToString('o');vn=[DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(7)).ToString('o');capture=[bool]$Capture}|ConvertTo-Json -Depth 5|Set-Content "$ev/verification-result.json"
Write-Output "PASS $($records.Count) artifacts; baseline$($baseline.Count)/preserved$preserved/scoped$($changed.Count); offline29+19; source0/mainOFF/cleanup0"
