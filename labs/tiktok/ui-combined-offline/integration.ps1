# Combined fixture contract; same wait/complete primitives as accepted handshake.
function Invoke-BrowserHandshake([string]$Command,[string]$Root,[string[]]$Extra=@(),[int]$WaitMs=5000){
 $info=[Diagnostics.ProcessStartInfo]::new($PythonPath);$info.UseShellExecute=$false;$info.CreateNoWindow=$true;$info.RedirectStandardOutput=$true;$info.RedirectStandardError=$true
 foreach($arg in @('-I','-B',(Join-Path $PSScriptRoot 'handshake.py'),$Command,'--root',$Root)+$Extra){$info.ArgumentList.Add($arg)}
 $p=[Diagnostics.Process]::new();$p.StartInfo=$info;$at=[DateTimeOffset]::UtcNow
 try{
  if(!$p.Start()){throw 'HANDSHAKE_START'};$stdout=$p.StandardOutput.ReadToEndAsync();$stderr=$p.StandardError.ReadToEndAsync();$timeout=!$p.WaitForExit($WaitMs)
  if($timeout){$p.Kill($true);$p.WaitForExit(1000)|Out-Null};$output=$stdout.GetAwaiter().GetResult();$errorOutput=$stderr.GetAwaiter().GetResult();$code=if($p.HasExited){$p.ExitCode}else{$null}
  $safe=$null;try{$candidate=$output|ConvertFrom-Json;if($output.Length -le 1024 -and $candidate.status -cmatch '^[A-Z_]{1,40}$'){$safe=@{status=$candidate.status;code=$(if($candidate.code -cmatch '^[A-Z_]{1,40}$'){$candidate.code}else{$null});waitMs=$candidate.waitMs}}}catch{}
  @{command=$Command;actualExit=$code;timedOut=$timeout;waitLimitMs=$WaitMs;stderrPresent=($errorOutput.Length -gt 0);result=$safe;utcStart=$at.ToString('o');utcEnd=[DateTimeOffset]::UtcNow.ToString('o')}|ConvertTo-Json -Depth 5 -Compress|Add-Content -LiteralPath (Join-Path $Root 'handshake-process.jsonl')
  if($timeout -or $null -eq $code){throw 'HANDSHAKE_PROCESS_DEADLINE'}
  return [pscustomobject]@{actualExit=$code;result=$safe}
 }finally{$p.Dispose()}
}
function Wait-BrowserHandshake([string]$Root){
 $budget=Invoke-BrowserHandshake 'budget' $Root
 if($budget.actualExit -ne 0 -or $budget.result.waitMs -lt 1000 -or $budget.result.waitMs -gt 480000){throw 'HANDSHAKE_BUDGET'}
 return Invoke-BrowserHandshake 'wait' $Root @() ([int]$budget.result.waitMs)
}
function Complete-BrowserHandshake([string]$Root,[string]$CleanupState,[string]$ExecutionState){
 return Invoke-BrowserHandshake 'complete' $Root @('--cleanup-state',$CleanupState,'--execution-state',$ExecutionState)
}
