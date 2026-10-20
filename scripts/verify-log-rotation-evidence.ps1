param([switch]$CaptureSnapshot)
$ErrorActionPreference='Stop'
$root33=(Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
if((Get-Location).Path -ne $root33 -or $root33 -ne 'D:\WED SNAP'){throw 'Native repository required'}
$stem33='docs/evidence/p33-20261004'
function Need33($ok,$why){if(-not $ok){throw $why}}
function Hash33($path){(Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant()}
function Json33($path,$value){Need33 (-not(Test-Path -LiteralPath $path)) ('Never overwrite '+$path);[IO.File]::WriteAllText((Join-Path $root33 $path),($value|ConvertTo-Json -Depth 100)+"`n",(New-Object Text.UTF8Encoding($false)))}
function Records33($path){@(Get-Content -LiteralPath $path|Where-Object{$_.StartsWith('P33_RAW ')}|ForEach-Object{$_.Substring(8)|ConvertFrom-Json})}
function Canon33($v){
 if($null -eq $v){return 'null'}
 if($v -is [System.Collections.IDictionary]){return '{'+((@($v.Keys|Sort-Object)|ForEach-Object{(ConvertTo-Json -InputObject ([string]$_) -Compress)+':'+(Canon33 $v[$_])})-join ',')+'}'}
 if($v -is [pscustomobject]){return '{'+((@($v.PSObject.Properties.Name|Sort-Object)|ForEach-Object{(ConvertTo-Json -InputObject ([string]$_) -Compress)+':'+(Canon33 $v.$_)})-join ',')+'}'}
 if($v -is [System.Collections.IList]){return '['+((@($v)|ForEach-Object{Canon33 $_})-join ',')+']'}
 return (ConvertTo-Json -InputObject $v -Compress -Depth 100)
}
$before33=Get-Content "$stem33-before.json" -Raw|ConvertFrom-Json
$allowed33=@('compose.yaml','README.md','docs/RUNBOOK.md','docs/PROGRESS.md','docs/TEST_REPORT.md','docs/AUDIT_TIEN_DO.md','docs/API.md')
Need33 (($before33.allowed -join '|') -eq ($allowed33 -join '|') -and $before33.inventory.Count -eq 1094 -and @($before33.inventory.path|Select-Object -Unique).Count -eq 1094) 'Successor scope/inventory'
$unchanged33=0
foreach($p33 in $before33.inventory){if($allowed33 -notcontains $p33.path){Need33 ((Hash33 $p33.path) -eq $p33.sha) ('Successor protected changed '+$p33.path);$unchanged33++}}
Need33 ($unchanged33 -eq 1087) 'Successor distinct unchanged count'
# No exclusion applies to frozen copies/raw/manifest/test/expected/runtime paths.
$protected31=Get-Content docs/evidence/p31-20261004-protected-before.json -Raw|ConvertFrom-Json
$checked31=0;$excluded31=@()
foreach($p33 in $protected31.protected){if($allowed33 -contains $p33.path){$excluded31+=$p33.path}else{Need33 ((Hash33 $p33.path) -eq $p33.sha) ('Historical protected31 '+$p33.path);$checked31++}}
Need33 ($protected31.protected.Count -eq 1027 -and $checked31 -eq 1025 -and (($excluded31|Sort-Object)-join '|') -eq 'compose.yaml|docs/RUNBOOK.md') 'Exact historical31 current-path exemptions'
$inventory32=Get-Content docs/evidence/p32-20261004-before.json -Raw|ConvertFrom-Json
$checked32=0
foreach($p33 in $inventory32.inventory){if($allowed33 -notcontains $p33.path){Need33 ((Hash33 $p33.path) -eq $p33.sha) ('Historical inventory32 '+$p33.path);$checked32++}}
Need33 ($checked32 -eq 1066) 'Inventory32 comparison excluding seven current paths; do not sum overlapping inventories'
$manifest31=Get-Content docs/evidence/p31-20261004-manifest-final.json -Raw|ConvertFrom-Json
$manifest32=Get-Content docs/evidence/p32-20261004-manifest.json -Raw|ConvertFrom-Json
Need33 ($manifest31.artifacts.Count -eq 36 -and $manifest31.currentCode.Count -eq 16 -and $manifest32.artifacts.Count -eq 20) 'Frozen/current inventory sizes'
foreach($p33 in @($manifest31.artifacts)+@($manifest31.currentCode)+@($manifest32.artifacts)){Need33 ((Hash33 $p33.path) -eq $p33.sha) ('Frozen artifact/runtime changed '+$p33.path)}
Need33 ((Hash33 'docs/evidence/p31-20261004-manifest-final.json') -eq $manifest32.retainedManifest31SHA) 'Historical manifest31 unchanged'
$expected33=Get-Content tests/p33/expected.json -Raw|ConvertFrom-Json
Need33 ((Hash33 'tests/p33/expected.json') -eq 'c4bfbf6bd9f330eb842a5dbb91514fa20a25a6bad0d3f0a96adf86ced0126bd7' -and (Hash33 'tests/p33/probe.cjs') -eq 'e29dfd36184272c6c31495832d6f192a5f0ae5274064f472d6f072c478ca51a6') 'Original expected/writer'
$resolvedBefore33=Get-Content "$stem33-resolved-before.json" -Raw|ConvertFrom-Json
$resolvedAfter33=Get-Content "$stem33-resolved-final.json" -Raw|ConvertFrom-Json
Need33 (@($resolvedBefore33.services.PSObject.Properties).Count -eq 6 -and @($resolvedAfter33.services.PSObject.Properties).Count -eq 6) 'Six services'
foreach($s33 in $expected33.sourceServices){
 Need33 (-not $resolvedBefore33.services.$s33.logging) 'Baseline only unspecified source'
 Need33 ((Canon33 $resolvedAfter33.services.$s33.logging) -ceq (Canon33 $expected33.sourcePolicy)) ('Final policy '+$s33)
 Need33 ($resolvedAfter33.services.$s33.logging.options.'max-file' -is [string] -and $resolvedAfter33.services.$s33.logging.options.'max-size' -is [string]) 'String log options'
 $resolvedBefore33.services.$s33.PSObject.Properties.Remove('logging');$resolvedAfter33.services.$s33.PSObject.Properties.Remove('logging')
}
$resolvedAfter33.PSObject.Properties.Remove('x-logging');$resolvedAfter33.'x-app'.PSObject.Properties.Remove('logging')
Need33 ((Canon33 $resolvedBefore33) -ceq (Canon33 $resolvedAfter33)) 'Canonical nonlogging preservation'
$sourceBefore33=[IO.File]::ReadAllText((Join-Path $root33 "$stem33-source-before/compose.yaml")).Replace("`r`n","`n")
$sourceNow33=[IO.File]::ReadAllText((Join-Path $root33 'compose.yaml')).Replace("`r`n","`n")
$reversed33=$sourceNow33.Replace("x-logging: &logging`n  driver: json-file`n  options:`n    max-size: '10m'`n    max-file: '3'`n",'')
$reversed33=[regex]::Replace($reversed33,'(?m)^\s+logging: \*logging\n','')
Need33 ($reversed33 -ceq $sourceBefore33) 'Compose textual diff outside logging'
$raw33=Records33 "$stem33-probe.log"
$actual33=@($raw33|Where-Object stage -eq 'actual-guard')
$pre33=@($raw33|Where-Object stage -eq 'pre-emit')
Need33 ($pre33.Count -eq 1 -and $pre33[0].actualGuardComplete -and $pre33[0].sourceThreshold -eq '10m' -and $pre33[0].probeThreshold -eq '64k') 'Threshold distinction/guard before emit'
Need33 (@($actual33|Where-Object state -eq running).Count -ge 1 -and @($actual33|Where-Object{$_.state -eq 'exited' -and $_.exitCode -eq 0}).Count -ge 1) 'Actual running/exited0'
foreach($a33 in $actual33){Need33 ($a33.project -eq $expected33.project -and $a33.image -eq $expected33.imagePin -and $a33.networkMode -eq 'none' -and $a33.privatePID -and $a33.rootfsRO -and $a33.sourceRO -and $a33.memory -eq 100663296 -and $a33.nanoCpus -eq 250000000 -and $a33.pids -eq 32 -and $a33.ports -eq 0 -and $a33.dataVolumes -eq 0) 'Actual isolation/resources';Need33 ($a33.logging.Type -eq 'json-file' -and $a33.logging.Config.'max-file' -eq '3' -and $a33.logging.Config.'max-size' -eq '64k') 'Actual probe LogConfig'}
$result33=Get-Content "$stem33-probe-result.json" -Raw|ConvertFrom-Json
$lines33=@(Get-Content "$stem33-retained.log")
Need33 ((Get-Item "$stem33-retained.log").Length -le 1048576 -and $result33.emittedBytes -eq 524468 -and $result33.writerActualExit -eq 0 -and $result33.completeAfterDrain) 'Bounded emit/exit/drain'
$seq33=@($lines33|Where-Object{$_ -match '^P33_SEQ (\d{6}) x+$'}|ForEach-Object{Need33 ($_.Length+1 -eq 1024) 'Retained record width';[int]($_.Substring(8,6))})
$done33=@($lines33|Where-Object{$_.StartsWith('P33_DONE ')}|ForEach-Object{$_.Substring(9)|ConvertFrom-Json})
Need33 ($seq33.Count -eq 158 -and $seq33[0] -eq 355 -and $seq33[-1] -eq 512 -and ($seq33-join ',') -eq ((355..512)-join ',') -and $seq33 -notcontains 1 -and $done33.Count -eq 1 -and $done33[0].records -eq 512 -and $done33[0].sequenceBytes -eq 524288) 'Historical retained suffix/marker'
$commands33=Get-Content "$stem33-probe-commands.json" -Raw|ConvertFrom-Json
Need33 ($commands33.phaseSuccess -and @($commands33.commands|Where-Object{ $_.label -eq 'retained-all' -and $_.command.EndsWith('logs --no-color --no-log-prefix --tail all probe') -and $_.exitCode -eq 0 }).Count -eq 1) 'Actual all-log read completion'
Need33 (@($commands33.commands|Where-Object exitCode -ne 0).Count -eq 0) 'Successful probe native commands'
$cleanup33=Get-Content "$stem33-cleanup.json" -Raw|ConvertFrom-Json
Need33 ($cleanup33.ownContainerRemoved -and $cleanup33.rawKept -and -not $cleanup33.mainTouched -and $cleanup33.dataVolumes -eq 0) 'Own cleanup'
foreach($p33 in @(@('baseline','Baseline'),@('source','Source'),@('probe','Probe'),@('cleanup-after-fail','Cleanup'))){Need33 ((Get-Content "$stem33-$($p33[0]).log" -Raw).Contains('P33_COMMAND_EXIT 0 '+$p33[1]+' UTC')) 'Actual command completion marker'}
foreach($p33 in @('probe-guard-fail','probe-tmpfs-guard-fail','probe-native-progress-fail','cleanup-emptyobject-guard-fail')){Need33 (@(Records33 "$stem33-$p33.log"|Where-Object stage -eq failure).Count -eq 1) 'Preserved harness FAIL';Need33 (@(Records33 "$stem33-$p33.log"|Where-Object stage -eq 'pre-emit').Count -eq 0) 'No emission before failed harness guard'}
foreach($s33 in @('scripts/test-log-rotation.ps1','scripts/verify-log-rotation-evidence.ps1')){$t33=$null;$e33=$null;[void][Management.Automation.Language.Parser]::ParseFile((Join-Path $root33 $s33),[ref]$t33,[ref]$e33);Need33 ($e33.Count -eq 0) 'PowerShell syntax'}
$manifestPath33="$stem33-manifest-final.json"
if($CaptureSnapshot){
 Need33 (-not(Test-Path -LiteralPath $manifestPath33)) 'Never overwrite manifest33'
 foreach($p33 in $allowed33){$dest33=Join-Path "$stem33-source-final" $p33;New-Item -ItemType Directory -Force (Split-Path $dest33)|Out-Null;Copy-Item -LiteralPath $p33 -Destination $dest33}
 Json33 "$stem33-summary-final.json" @{utc=[DateTime]::UtcNow.ToString('o');scope='Successor33 offline preservation and proof parsing; no old verifier/runtime rerun';distinctBaseline=1094;unchanged=1087;allowedCurrentPaths=$allowed33;historical31=@{baselineProtected=1027;checked=1025;exemptedCurrent=$excluded31;runtimeHashes=16;frozenArtifacts=36};historical32=@{inventory=1073;checked=1066;excludedCurrent=7;frozenArtifacts=20};countsOverlap='Do not add overlapping inventories';source='six services10m/3 strings, canonical/text only logging';probe=$result33;cleanup=$cleanup33;finding32='Audit32 accepted/F31.1 closed; history kept'}
 $files33=@(Get-ChildItem docs/evidence -Recurse -File|Where-Object{$_.FullName.Contains('p33-20261004') -and $_.Name -notmatch '(manifest-final|offline-verify)'})+@(Get-ChildItem tests/p33 -Recurse -File)+@(Get-Item scripts/test-log-rotation.ps1,scripts/verify-log-rotation-evidence.ps1,infra/compose.log-rotation-lab.yaml,infra/log-rotation-lab.env.example)
 $artifacts33=@($files33|Sort-Object FullName -Unique|ForEach-Object{@{path=$_.FullName.Substring($root33.Length+1).Replace('\','/');sha=Hash33 $_.FullName}})
 Json33 $manifestPath33 @{utc=[DateTime]::UtcNow.ToString('o');artifacts=$artifacts33;currentPolicySHA=Hash33 'compose.yaml';allowedCurrentPaths=$allowed33;runtimeHashes=$manifest31.currentCode;status='Implementation33 pending independent audit, no main apply'}
}
Need33 (Test-Path -LiteralPath $manifestPath33) 'Capture manifest33 once after handoff docs'
$m33=Get-Content $manifestPath33 -Raw|ConvertFrom-Json
Need33 ((Hash33 'compose.yaml') -eq $m33.currentPolicySHA) 'Current source policy hash'
foreach($p33 in @($m33.artifacts)+@($m33.runtimeHashes)){Need33 ((Hash33 $p33.path) -eq $p33.sha) ('Manifest33/current runtime '+$p33.path)}
Write-Host ('PASS successor33 distinct1094/unchanged1087 exact7current exemptions; old31 protected1025of1027 runtime16/artifacts36, old32 inventory1066of1073/artifacts20 (overlapping, not summed); source6policies canonical/textPASS, probe355-512/158retained exit0/cleanup, ownArtifacts'+$m33.artifacts.Count+' UTC '+[DateTime]::UtcNow.ToString('o'))
