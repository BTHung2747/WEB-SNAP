param([Parameter(Mandatory)][string]$Evidence)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'Owner.psm1') -Force -DisableNameChecking
$ev=(Resolve-Path -LiteralPath $Evidence).Path
if(Test-Path (Join-Path $ev 'integration-tests.json')){throw 'REFUSE_TEST_REUSE'}
$temp=Join-Path $ev 'OFFLINE_TEST_ONLY_PROOF';New-Item -ItemType Directory -Path (Join-Path $temp 'owner-private') -ErrorAction Stop|Out-Null;New-Item -ItemType Directory -Path (Join-Path $temp 'control')|Out-Null
$ctx=New-OfflineNativeTestContext $temp;$ctx|Add-Member NoteProperty Control (Join-Path $temp 'control')
$module=Get-Module Owner;$cases=[Collections.Generic.List[object]]::new()
function Reject($Action){$rejected=$false;try{&$Action|Out-Null}catch{$rejected=$true};if(!$rejected){throw 'EXPECTED_DENIAL'}}
$proof=Join-Path $temp 'owner-private/native-exits.json';[IO.File]::WriteAllText($proof,'{"mode":"OFFLINE_TEST_ONLY_NOT_NATIVE_DOCKER"}')
$sha=(Get-FileHash $proof).Hash.ToLowerInvariant()
&$module {param($c,$p,$h)Assert-OwnerPrivateProof $c $p $h} $ctx $proof $sha
$cases.Add(@{case='EXACT_OWNER_PRIVATE_PROOF';status='PASS';evidenceKind='FILESYSTEM_OFFLINE_VECTOR'})
Reject {&$module {param($c,$p,$h)Assert-OwnerPrivateProof $c $p $h} $ctx (Join-Path $ctx.Control 'native-exits.json') $sha};$cases.Add(@{case='CONTROL_PACKET_NOT_OWNER_PROOF';status='PASS'})
Reject {&$module {param($c,$p)Assert-OwnerPrivateProof $c $p ('0'*64)} $ctx $proof};$cases.Add(@{case='CHANGED_PROOF_HASH_DENIED';status='PASS'})
Reject {&$module {param($c)Assert-ExecutionContext $c -Docker} $ctx};$cases.Add(@{case='SEALED_OFFLINE_CONTEXT_CANNOT_DOCKER';status='PASS'})
Reject {&$module {Assert-ExecutionContext ([pscustomobject]@{Mode='UI_SINGLE_PHOTO_SOURCE';Seal=[object]::new();ClaimConsumed=$true}) -Docker}};$cases.Add(@{case='SELF_DECLARED_SOURCE_CONTEXT_DENIED';status='PASS'})
Reject {&$module {Resolve-WorkspaceFile '../OUTSIDE_OFFLINE_ONLY'}};$cases.Add(@{case='WORKSPACE_ESCAPE_DENIED';status='PASS'})
$now=[Diagnostics.Stopwatch]::GetTimestamp();$freq=[Diagnostics.Stopwatch]::Frequency
$dead=[pscustomobject]@{WorkDeadline=$now-$freq;CleanupDeadline=$now+20*$freq;HardDeadline=$now+21*$freq;StartupDeadline=$now-$freq}
$times=&$module {param($c)@{work=(Get-RemainingNativeMs $c 'work');cleanup=(Get-RemainingNativeMs $c 'cleanup');seal=(Get-RemainingNativeMs $c 'seal');startup=(Get-RemainingNativeMs $c 'startup')}} $dead
if($times.work -ge 0 -or $times.startup -ge 0 -or $times.seal-$times.cleanup -lt 990 -or $times.seal -gt 21000){throw 'REMAINING_DEADLINE_OR_SEAL'}
$cases.Add(@{case='EXHAUSTED_WORK_SEPARATE_CLEANUP_SEAL';status='PASS';remainingMs=$times})
foreach($state in @(@{tag='EXIT_ZERO';exit=0;oom=$false;running=$false},@{tag='OOM_NONZERO';exit=137;oom=$true;running=$false},@{tag='RUNNING_NOT_CLOSED';exit=0;oom=$false;running=$true})){
 $result=&$module {param($s)Get-ContainerOutcome ([pscustomobject]@{State=[pscustomobject]@{ExitCode=$s.exit;OOMKilled=$s.oom;Running=$s.running}})} $state
 if($result.actualExit -ne $state.exit -or $result.oomKilled -ne $state.oom -or $result.running -ne $state.running -or !$result.observed){throw 'CONTAINER_NATIVE_STATE_LOST'}
 if($state.tag -ceq 'EXIT_ZERO'){if($null -ne $result.actualSignal){throw 'NORMAL_EXIT_SIGNAL'}}elseif($result.actualSignal -cne 'UNKNOWN'){throw 'INVENTED_SIGNAL'}
 $cases.Add(@{case='STATE_PROJECTION_'+$state.tag;status='PASS';evidenceKind='SYNTHETIC_DOCKER_STATE_NOT_RUNTIME';observedVector=$result})
}
Reject {&$module {Get-ContainerOutcome ([pscustomobject]@{State=[pscustomobject]@{ExitCode=0}})}};$cases.Add(@{case='MISSING_CONTAINER_STATE_DENIED';status='PASS'})
$guardContext=[pscustomobject]@{Payload=[pscustomobject]@{runID='OFFLINE_TEST_ONLY_GUARD'};Plan=[pscustomobject]@{mounts=@();supervisorMirrors=@();controlMounts=@()}}
$role=[pscustomobject]@{role='app';image='OFFLINE_TEST_ONLY_IMAGE';user='1000:1000';memoryMiB=16;pids=8;cpu=0.25;networks=@('internal')}
$info=[pscustomobject]@{Image=$role.image;Name='/wed-source-OFFLINE_TEST_ONLY_GUARD-app';Config=[pscustomobject]@{Labels=[pscustomobject]@{'com.wed-snap.run'='OFFLINE_TEST_ONLY_GUARD'};User=$role.user;Env=@()};HostConfig=[pscustomobject]@{ReadonlyRootfs=$true;Privileged=$false;CapAdd=@();CapDrop=@('ALL');SecurityOpt=@('no-new-privileges:true');IpcMode='private';Memory=16MB;MemorySwap=16MB;PidsLimit=8;NanoCpus=250000000;PortBindings=[pscustomobject]@{}};NetworkSettings=[pscustomobject]@{Networks=[pscustomobject]@{'wed-source-OFFLINE_TEST_ONLY_GUARD-internal'=[pscustomobject]@{}}};Mounts=@()}
&$module {param($c,$r,$i)Assert-ContainerGuard $c $r $i 1} $guardContext $role $info;$cases.Add(@{case='GUARD_EXPECTED_OWN_NETWORK_AND_IMAGE';status='PASS';evidenceKind='SYNTHETIC_INSPECT_NOT_DOCKER'})
$info.NetworkSettings.Networks=[pscustomobject]@{OFFLINE_TEST_ONLY_FOREIGN=[pscustomobject]@{}};Reject {&$module {param($c,$r,$i)Assert-ContainerGuard $c $r $i 1} $guardContext $role $info};$cases.Add(@{case='GUARD_FOREIGN_NETWORK_DENIED';status='PASS'})
$info.NetworkSettings.Networks=[pscustomobject]@{'wed-source-OFFLINE_TEST_ONLY_GUARD-internal'=[pscustomobject]@{}};$info.Mounts=@([pscustomobject]@{Type='bind';Destination='/owner-private';RW=$false});Reject {&$module {param($c,$r,$i)Assert-ContainerGuard $c $r $i 1} $guardContext $role $info};$cases.Add(@{case='GUARD_EXTRA_PRIVATE_BIND_DENIED';status='PASS'})
$info.Mounts=@();$info.Image='OFFLINE_TEST_ONLY_WRONG_IMAGE';Reject {&$module {param($c,$r,$i)Assert-ContainerGuard $c $r $i 1} $guardContext $role $info};$cases.Add(@{case='GUARD_WRONG_IMAGE_DENIED';status='PASS'})
$methods=@{}
foreach($name in @('Start','Kill','WaitForExit')){$methods['Process.'+$name]=@([Diagnostics.Process].GetMethods()|Where-Object Name -CEQ $name|ForEach-Object ToString|Sort-Object -Unique)}
$methods.ArgumentList=[Diagnostics.ProcessStartInfo].GetProperty('ArgumentList').PropertyType.FullName
$methods.RSA=@([Security.Cryptography.RSA].GetMethods()|Where-Object {$_.Name -cin @('ImportSubjectPublicKeyInfo','VerifyData')}|ForEach-Object ToString|Sort-Object -Unique)
$methods.ReadAsync=@([IO.Stream].GetMethods()|Where-Object Name -CEQ 'ReadAsync'|ForEach-Object ToString|Sort-Object -Unique)
$cases.Add(@{case='INSTALLED_DOTNET_PUBLIC_API_SIGNATURES';status='PASS';dotnet=[Environment]::Version.ToString();methods=$methods;verification='INSTALLED_OFFICIAL_RUNTIME_REFLECTION_AND_REAL_CHILD_BEHAVIOR_NOT_WEB_FETCH'})
@{status='PASS_INTEGRATION_DELTA_OFFLINE_ONLY';caseCount=$cases.Count;cases=$cases.ToArray();sourceCalls=0;dockerCalls=0}|ConvertTo-Json -Depth 12|Set-Content (Join-Path $ev 'integration-tests.json') -Encoding utf8
Write-Output "PASS_INTEGRATION_CASES_$($cases.Count)"
exit 0
