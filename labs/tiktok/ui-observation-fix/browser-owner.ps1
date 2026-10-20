param([string]$RunID,[string]$NodePath)
$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
$ev='docs/evidence/ui-observation-fix-20261016/browser';$at=[DateTimeOffset]::UtcNow;$clock=[Diagnostics.Stopwatch]::StartNew();$p=$null;$code=$null;$killed=$false
try{
 if($RunID -cnotmatch '^[a-f0-9]{32}$' -or !(Test-Path -LiteralPath $NodePath -PathType Leaf)){throw 'OWNER_SCOPE'}
 $info=[Diagnostics.ProcessStartInfo]::new($NodePath);$info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
 foreach($arg in @('--max-old-space-size=64','labs/tiktok/ui-observation-fix/browser-server.cjs',$ev,$RunID)){$info.ArgumentList.Add($arg)}
 $p=[Diagnostics.Process]::new();$p.StartInfo=$info;$p.Start()|Out-Null;$o=$p.StandardOutput.ReadToEndAsync();$e=$p.StandardError.ReadToEndAsync()
 @{ownerPID=$PID;ownPID=$p.Id;runID=$RunID;utcStart=$at.ToString('o');serverWaitMs=29000;outerLimitMs=60000;hidden=$true}|ConvertTo-Json|Set-Content "$ev/owner-start.json"
 if(!$p.WaitForExit(29000)){$p.Kill($true);$p.WaitForExit(1000)|Out-Null;$killed=$true}
 $code=if($p.HasExited){$p.ExitCode}else{$null};$stdout=$o.GetAwaiter().GetResult();$stderr=$e.GetAwaiter().GetResult()
 @{runID=$RunID;ownerPID=$PID;ownPID=$p.Id;actualProcessExit=$code;processExited=$p.HasExited;watchdogKilled=$killed;stdoutBytes=$stdout.Length;stderrBytes=$stderr.Length;utcStart=$at.ToString('o');utcEnd=[DateTimeOffset]::UtcNow.ToString('o');elapsedMs=$clock.Elapsed.TotalMilliseconds;outerLimitMs=60000;sourceCalls=0}|ConvertTo-Json|Set-Content "$ev/owner-completion.json"
}catch{@{runID=$RunID;code='OWNER_ERROR';processExited=$(if($p){$p.HasExited}else{'NOT_STARTED'});utc=[DateTimeOffset]::UtcNow.ToString('o')}|ConvertTo-Json|Set-Content "$ev/owner-error.json"}
finally{if($p){if(!$p.HasExited){$p.Kill($true);$p.WaitForExit(1000)|Out-Null};$p.Dispose()}}
if($code -eq 0){exit 0}else{exit 1}
