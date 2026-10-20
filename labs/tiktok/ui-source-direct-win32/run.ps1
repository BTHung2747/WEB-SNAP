param([switch]$ExecuteOffline,[string]$Evidence)
$ErrorActionPreference='Stop'
if(!$ExecuteOffline -or [string]::IsNullOrWhiteSpace($Evidence)){Write-Output 'OFFLINE_POC_EXPLICIT_ONLY';exit 78}
$root=[IO.Path]::GetFullPath($Evidence);$allowed=[IO.Path]::GetFullPath((Join-Path (Get-Location).Path 'docs/evidence'))+[IO.Path]::DirectorySeparatorChar
if(!$root.StartsWith($allowed) -or (Test-Path -LiteralPath $root)){throw 'FRESH_OFFLINE_EVIDENCE_REQUIRED'}
$walk=[IO.Path]::GetDirectoryName($root);while($walk.StartsWith($allowed)){if((Test-Path $walk) -and ((Get-Item -LiteralPath $walk -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)){throw 'REPARSE_EVIDENCE'};$walk=[IO.Path]::GetDirectoryName($walk)}
New-Item -ItemType Directory -Path $root|Out-Null
$exe=(Get-Process -Id $PID).Path;$si=[Diagnostics.ProcessStartInfo]::new($exe);$si.UseShellExecute=$false;$si.CreateNoWindow=$true;$si.RedirectStandardOutput=$true;$si.RedirectStandardError=$true
foreach($a in @('-NoProfile','-File',(Join-Path $PSScriptRoot 'suite.ps1'),'-Evidence',$root)){$si.ArgumentList.Add($a)}
$p=[Diagnostics.Process]::new();$p.StartInfo=$si;$timer=[Diagnostics.Stopwatch]::StartNew();$null=$p.Start();$out=$p.StandardOutput.ReadToEndAsync();$err=$p.StandardError.ReadToEndAsync()
try{
 $timeout=!$p.WaitForExit(15000);if($timeout){$p.Kill($true);$p.WaitForExit(1000)|Out-Null}
 $receipt=@{executable=$exe;script='labs/tiktok/ui-source-direct-win32/suite.ps1';actualExit=$(if($p.HasExited){$p.ExitCode}else{$null});timedOut=$timeout;limitMs=15000;elapsedMs=$timer.ElapsedMilliseconds;pid=$p.Id;stdout=$out.GetAwaiter().GetResult();stderr=$err.GetAwaiter().GetResult();utc=[DateTimeOffset]::UtcNow.ToString('o');vn=[TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTimeOffset]::UtcNow,'SE Asia Standard Time').ToString('o')}
 $receipt|ConvertTo-Json|Set-Content (Join-Path $root 'suite-native.json') -Encoding utf8
 if($timeout -or $receipt.actualExit -ne 0){Write-Output 'OFFLINE_POC_FAILED_EVIDENCE_RETAINED';exit 1}
 Write-Output 'OFFLINE_POC_SUITE_NATIVE_ZERO';exit 0
}finally{$p.Dispose()}
