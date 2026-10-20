param([Parameter(Mandatory)][string]$Evidence)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'Owner.psm1') -Force -DisableNameChecking
$ev=(Resolve-Path $Evidence).Path;$ctx=New-OfflineNativeTestContext $ev
Initialize-OfflineNativeAdapter $ctx|Out-Null
$module=Get-Module Owner;$engine=&$module {param($c)Get-NativeEngine $c} $ctx
$type=$engine.Type;$assembly=$engine.Assembly
$ready=Join-Path $ev 'integrated-crash-ready.txt'
if(Test-Path $ready){throw 'NEW_CRASH_EVIDENCE_REQUIRED'}
$si=[Diagnostics.ProcessStartInfo]::new((Get-Process -Id $PID).Path)
$si.UseShellExecute=$false;$si.CreateNoWindow=$true;$si.RedirectStandardOutput=$true;$si.RedirectStandardError=$true
foreach($word in @('-NoLogo','-NoProfile','-File',(Join-Path $PSScriptRoot 'test-crash-owner.ps1'),'-Evidence',$ev,'-Ready',$ready)){$si.ArgumentList.Add($word)}
$p=[Diagnostics.Process]::new();$p.StartInfo=$si
$observers=[Collections.Generic.List[object]]::new();$clock=[Diagnostics.Stopwatch]::StartNew();$started=$false;$success=$false
try{
 $null=$p.Start();$started=$true;$ownerID=$p.Id
 # No unbounded ReadToEnd/async reader. This fixture emits no output before
 # crash; its two streams are explicitly closed after a finite process wait.
 while(!(Test-Path $ready)){if($p.HasExited -or $clock.ElapsedMilliseconds -ge 4500){throw 'CRASH_READY_UNAVAILABLE'};Start-Sleep -Milliseconds 5}
 $parts=([IO.File]::ReadAllText($ready)).Split('|')
 if($parts.Count -ne 6 -or $parts[0] -cne 'OFFLINE_TEST_ONLY' -or [int]$parts[1] -ne $ownerID){throw 'CRASH_IDENTITY_PACKET'}
 foreach($offset in @(2,4)){
  $identity=[Activator]::CreateInstance($assembly.GetType('WedOwnerWin32.Identity'))
  $identity.PID=[uint32]$parts[$offset];$identity.CreationFileTime=[long]$parts[$offset+1];$identity.VerifiedInOwnedJob=$true
  $observer=$type::Observe($identity);$observers.Add($observer)
  if($observer.Wait(0)){throw 'CRASH_FIXTURE_ALREADY_EXITED'}
 }
 $kill=[Diagnostics.Stopwatch]::StartNew();$p.Kill()
 if(!$p.WaitForExit(1000)){throw 'OWNED_OWNER_NOT_SIGNALED'}
 $observed=@(foreach($observer in $observers){if(!$observer.Wait([Math]::Max(0,1500-$kill.ElapsedMilliseconds))){throw 'KILL_ON_CLOSE_NOT_OBSERVED'};@{PID=$observer.PID;actualExit=$observer.Exit;signaled=$true}})
 $doc=@{status='PASS_INTEGRATED_OWNER_CRASH';caseCount=1;ownerPID=$ownerID;ownerActualExit=$p.ExitCode;ownerKill='EXACT_OWNED_PROCESS_HANDLE_SINGLE_PROCESS';descendants=$observed;afterKillMs=$kill.ElapsedMilliseconds;totalMs=$clock.ElapsedMilliseconds;selfExpiryMs=3500;observerJobHandles=0;identity='OWNER_VERIFIED_JOB_MEMBERSHIP_THEN_OBSERVER_CREATION_FILETIME';jobQueryAfterDestruction='UNAVAILABLE_PROCESS_HANDLES_OBSERVED';sourceSuccess='NOT_CLAIMED';stdout='OMITTED_FIXED_OFFLINE_FIXTURE';stderr='OMITTED_FIXED_OFFLINE_FIXTURE'}
 $success=$true
}finally{
 foreach($observer in $observers){$observer.Dispose()}
 if($started){if(!$p.HasExited){$p.Kill();$null=$p.WaitForExit(1000)};$p.StandardOutput.Dispose();$p.StandardError.Dispose()};$p.Dispose()
}
$counts=$type::Ownership()
if(!$success -or $counts.liveHandles -ne 0 -or $counts.liveBuffers -ne 0 -or $counts.closeErrors -ne 0){throw 'CRASH_OBSERVER_CLEANUP'}
$doc.ownership=$counts;$doc.utc=[DateTimeOffset]::UtcNow.ToString('o')
$f=[IO.FileStream]::new((Join-Path $ev 'adapter-crash-summary.json'),[IO.FileMode]::CreateNew)
try{$b=[Text.Encoding]::UTF8.GetBytes(($doc|ConvertTo-Json -Depth 12));$f.Write($b,0,$b.Length)}finally{$f.Dispose()}
Write-Output 'PASS_ADAPTER_CRASH_1';exit 0
