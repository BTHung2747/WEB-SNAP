$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
. (Join-Path $PSScriptRoot 'wiring.ps1')
$ev='docs/evidence/ui-final-fixture-20261016';if(Test-Path "$ev/preflight.json"){throw 'REFUSE_REUSE'}
New-Item -ItemType Directory -Path "$ev/filesystem-control"|Out-Null
$map=@(Get-FinalMountMap (Resolve-Path "$ev/filesystem-control").Path);$commands=Get-FinalCommands;$proof=@(Assert-FinalPlan $map $commands);$cases=@([pscustomobject]@{case='CORRECT_FINAL_WIRING';status='PASS'})
$bad=Get-FinalCommands;$bad.gateway=@('node','/gatewayfix/gateway.cjs');$rejected=$false
try{Assert-FinalPlan $map $bad|Out-Null}catch{if($_.Exception.Message -cne 'FINAL_COMMAND_WIRING'){throw};$rejected=$true};if(!$rejected){throw 'STALE_GATEWAY_ACCEPTED'}
$cases+=[pscustomobject]@{case='REJECT_STALE_GATEWAY';status='PASS'}
$badMap=@($map|Where-Object target -CNE '/newlab/controller.ts');$rejected=$false
try{Assert-FinalPlan $badMap $commands|Out-Null}catch{if($_.Exception.Message -cne 'CONTROLLER_DEEPEST_MOUNT'){throw};$rejected=$true};if(!$rejected){throw 'STALE_CONTROLLER_ACCEPTED'}
$cases+=[pscustomobject]@{case='REJECT_STALE_CONTROLLER';status='PASS'}
$pins=@();foreach($manifest in @('docs/evidence/ui-observation-fix-20261016/manifest.json','docs/evidence/ui-combined-wired-20261016/manifest.json','docs/evidence/ui-gateway-failurefix-20261016/manifest.json','docs/evidence/ui-combined-mountfix-20261016/manifest.json')){$m=Get-Content $manifest -Raw|ConvertFrom-Json;foreach($p in (@($m.implementation)+@($m.reusedImplementation)|Where-Object {$_ -and $_.path})){if((Get-FileHash -LiteralPath $p.path).Hash.ToLowerInvariant() -cne $p.sha256){throw 'REVIEWED_HASH_CHANGED'};$pins+=$p}}
$pins+=@(Get-ChildItem $PSScriptRoot -File|ForEach-Object{@{path=[IO.Path]::GetRelativePath((Get-Location).Path,$_.FullName).Replace('\','/');sha256=(Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant()}})
foreach($file in Get-ChildItem $PSScriptRoot -Filter *.ps1){$t=$null;$e=$null;[Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$t,[ref]$e)|Out-Null;if($e.Count){throw 'POWERSHELL_SYNTAX'}}
$info=[Diagnostics.ProcessStartInfo]::new((Get-Command node).Source);$info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true;foreach($a in @('--max-old-space-size=64','labs/tiktok/ui-final-fixture/test-gate.cjs')){$info.ArgumentList.Add($a)}
$p=[Diagnostics.Process]::new();$p.StartInfo=$info;try{$p.Start()|Out-Null;$o=$p.StandardOutput.ReadToEndAsync();$e=$p.StandardError.ReadToEndAsync();$timeout=!$p.WaitForExit(5000);if($timeout){$p.Kill($true);$p.WaitForExit()};$text=$o.GetAwaiter().GetResult();$err=$e.GetAwaiter().GetResult();@{actualProcessExit=$p.ExitCode;timedOut=$timeout;stdout=$text;stderrBytes=$err.Length}|ConvertTo-Json|Set-Content "$ev/unit-final-gate.json";if($timeout -or $p.ExitCode -ne 0){throw 'FINAL_GATE_UNIT'};}finally{$p.Dispose()}
@{status='PASS_FINAL_WIRING_FILESYSTEM_ONLY';cases=$cases;caseCount=$cases.Count;pins=$pins;commands=$commands;mounts=$map;requiredPaths=$proof;dockerCalls=0;browserCalls=0;sourceCalls=0;utc=[DateTimeOffset]::UtcNow.ToString('o')}|ConvertTo-Json -Depth 8|Set-Content "$ev/preflight.json"
Write-Output 'PASS_FINAL_WIRING_FILESYSTEM_ONLY';exit 0
