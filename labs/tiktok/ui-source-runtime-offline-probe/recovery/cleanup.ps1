# Cleanup-only successor. Never create/start or change the sealed attempt.
. (Join-Path $PSScriptRoot '../common.ps1')
$script:Plan=Get-Content (Join-Path $script:Root 'plan.json') -Raw|ConvertFrom-Json
if((Get-FileHash (Join-Path $script:Root 'plan.json')).Hash.ToLowerInvariant() -cne '4f64e784358a4843ae9c61a7379b36c2702b7bc463e3912af7250060dc8b36e9'){throw 'PLAN_DRIFT'}
$cid='8fd0ea8d95d558b0180c45b4b1b09a8d83a69a094d94603429f329284eed0f7b'
$role=$script:Plan.roles|Where-Object role -CEQ app
foreach($pin in @($script:Plan.sourcePins)+@($script:Plan.baselinePins)+@(@{path=$script:Docker;sha256=$script:DockerSHA},@{path=$script:Plan.helperSource;sha256=$script:HelperSHA},@{path=$script:Plan.binary;sha256=$script:Plan.binarySHA})){if((Get-FileHash $pin.path).Hash.ToLowerInvariant() -cne $pin.sha256){throw 'PIN_DRIFT'}}
No-Overrides
Save (Join-Path $script:Root 'recovery-once.json') @{mode='CLEANUP_ONLY_AFTER_ORIGINAL_ATTEMPT_FAILED';cid=$cid;originalDeadlineNotExtended=$true;separateCleanupLimitMs=60000;utc=[DateTimeOffset]::UtcNow.ToString('o');scriptSHA=(Get-FileHash $PSCommandPath).Hash.ToLowerInvariant()}
Add-Type -Path $script:Plan.binary
$engine='WedOwnerWin32.Engine' -as [type]
if($engine.Assembly.Location -cne $script:Plan.binary -or $engine.Module.ModuleVersionId.ToString() -cne $script:Plan.MVID){throw 'ASSEMBLY_PROVENANCE'}
$clock=[Diagnostics.Stopwatch]::StartNew();$script:n=0;$closed=$false;$cause='NOT_COMPLETED'
function CleanupNative([string]$op,[string[]]$argv){
 No-Overrides
 $limit=[int][Math]::Min(15000,60000-$clock.ElapsedMilliseconds);if($limit -lt 600){throw 'RECOVERY_BUDGET_EXHAUSTED'}
 $r=$engine::Run($script:Docker,[string[]](@('--host',$script:Endpoint)+$argv),(Get-Location).Path,$limit,65536,'None',$null)
 $script:n++
 Save (Join-Path $script:Root ('recovery-native-'+$script:n+'-'+$op+'.json')) @{operation=$op;argv=@($script:Docker,'--host',$script:Endpoint)+$argv;actualExit=$r.RootExit;nativeStatus=$r.Status;accepted=(Native-OK $r);elapsedMs=$r.ElapsedMs;limitMs=$limit;cap=65536;forced=$r.TerminationRequested;timeout=$r.Timeout;capExceeded=$r.ByteCapExceeded;jobFinal=$r.FinalActive;jobAfterRoot=$r.AfterRootRelease;EOF=$r.PipesEOF;cleanup=$r.CleanupClosed;liveHandles=$r.LiveHandles;liveBuffers=$r.LiveBuffers;readers=$r.BackgroundReaders;stdoutBytes=$r.StdoutBytes;stderrBytes=$r.StderrBytes;errorCode=$(if($r.StderrBytes){'STDERR_PRESENT_NO_MESSAGE'}else{$null});utc=[DateTimeOffset]::UtcNow.ToString('o')}
 if(!(Native-OK $r)){throw 'RECOVERY_NATIVE_FAILED'};return $r.RawOut
}
try{
 # No HostConfig fields, Env or optional MountPoint.Name; ownership only.
 $template='{"id":{{json .ID}},"name":{{json .Name}},"image":{{json .Image}},"run":{{json (index .Config.Labels "com.wed-snap.run")}},"task":{{json (index .Config.Labels "com.wed-snap.task")}},"mountTypes":"{{range .Mounts}}{{.Type}};{{end}}"}'
 $g=(CleanupNative 'owner' @('container','inspect',$cid,'--format',$template))|ConvertFrom-Json
 Assert-Owner $role $g $cid
 if($g.mountTypes -match '(^|;)volume;'){throw 'VOLUME_PROVENANCE_UNKNOWN'}
 Save (Join-Path $script:Root 'recovery-owner.json') $g
 $null=CleanupNative 'remove-exact-cid' @('rm','--force',$cid)
 $c=CleanupNative 'cid-absence' @('ps','--all','--no-trunc','--filter',('id='+$cid),'--format','{{.ID}}')
 $names=CleanupNative 'name-absence' @('ps','--all','--no-trunc','--filter',('name=^/'+$role.name+'$'),'--format','{{.ID}}')
 $labels=CleanupNative 'label-absence' @('ps','--all','--no-trunc','--filter',('label=com.wed-snap.run='+$script:Plan.runID),'--filter',('label=com.wed-snap.task='+$script:TaskMarker),'--format','{{.ID}}')
 if(![string]::IsNullOrWhiteSpace($c+$names+$labels)){throw 'SCOPED_ABSENCE_FAILED'}
 $closed=$true;$cause='OWN_CID_REMOVED_SCOPED_ABSENCE_CONFIRMED'
}catch{
 $allowed=@('RECOVERY_BUDGET_EXHAUSTED','RECOVERY_NATIVE_FAILED','VOLUME_PROVENANCE_UNKNOWN','SCOPED_ABSENCE_FAILED','OWNERSHIP_UNPROVEN_NO_DESTRUCTIVE_ACTION')
 $cause=if($_.Exception.Message -cin $allowed){$_.Exception.Message}else{'RECOVERY_ERROR_NO_MESSAGE'}
}finally{
 Save (Join-Path $script:Root 'recovery-summary.json') @{closed=$closed;cause=$cause;cid=$cid;elapsedMs=$clock.ElapsedMilliseconds;calls=$script:n;runtimeAttemptStillFAIL=$true;noCreateOrStart=$true;originalReceiptsPreserved=$true;utc=[DateTimeOffset]::UtcNow.ToString('o')}
}
if(!$closed){exit 20};Write-Output 'CLEANUP_ONLY_CLOSED_RUNTIME_STILL_FAIL';exit 0
