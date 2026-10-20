$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
$ev='docs/evidence/ui-observation-fix-20261016/browser';if(Test-Path -LiteralPath $ev){throw 'REFUSE_PROBE_REUSE'}
$listeners=@(Get-NetTCPConnection -State Listen -LocalPort 5217 -ErrorAction SilentlyContinue);if($listeners.Count){throw 'SEPARATE_PORT_BUSY'}
$offline=Get-Content docs/evidence/ui-observation-fix-20261016/offline-successor/result.json -Raw|ConvertFrom-Json;if($offline.status -cne 'PASS_DELTA_OFFLINE_ONLY' -or $offline.count -ne 19){throw 'OFFLINE_GATE'}
New-Item -ItemType Directory -Path $ev|Out-Null;$run=[Guid]::NewGuid().ToString('N')
$source=@(Get-ChildItem labs/tiktok/ui-observation-fix -File|ForEach-Object{@{path=[IO.Path]::GetRelativePath((Get-Location).Path,$_.FullName).Replace('\','/');sha256=(Get-FileHash -LiteralPath $_.FullName).Hash.ToLowerInvariant()}})
@{runID=$run;pins=$source;port=5217;preexistingListeners=0;serverDeadlineMs=28000;ownerWaitMs=29000;outerLimitMs=60000;browserProviderCancellationGuarantee=$false;sourceCalls=0}|ConvertTo-Json -Depth 5|Set-Content "$ev/preflight.json"
$info=[Diagnostics.ProcessStartInfo]::new((Get-Command pwsh).Source);$info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
foreach($a in @('-NoProfile','-File','labs/tiktok/ui-observation-fix/browser-owner.ps1','-RunID',$run,'-NodePath',(Get-Command node).Source)){$info.ArgumentList.Add($a)}
$p=[Diagnostics.Process]::new();$p.StartInfo=$info;$p.Start()|Out-Null;@{ownerPID=$p.Id;runID=$run;hidden=$true;utc=[DateTimeOffset]::UtcNow.ToString('o')}|ConvertTo-Json|Set-Content "$ev/launcher.json";$p.Dispose()
$until=[DateTimeOffset]::UtcNow.AddSeconds(2);while(!(Test-Path "$ev/ready.json") -and !(Test-Path "$ev/owner-error.json") -and [DateTimeOffset]::UtcNow -lt $until){Start-Sleep -Milliseconds 20};if(!(Test-Path "$ev/ready.json")){throw 'PROBE_NOT_READY'}
Get-Content "$ev/ready.json"
