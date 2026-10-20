param([Parameter(Mandatory)][string]$Evidence,[ValidateSet('ProcessMount','Admission')][string]$Group='ProcessMount')
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'Owner.psm1') -Force -DisableNameChecking
$module=Get-Module Owner;$ev=(Resolve-Path -LiteralPath $Evidence).Path
if(Test-Path (Join-Path $ev ('regressions-'+$Group+'.json'))){throw 'REFUSE_TEST_REUSE'}
$rows=[Collections.Generic.List[object]]::new()
function Check([bool]$OK,[string]$Code){if(!$OK){throw $Code}}
function Reject($Action){$denied=$false;try{&$Action|Out-Null}catch{$denied=$true};Check $denied 'EXPECTED_DENIAL'}
function NewJSON([string]$Path,$Value){$f=[IO.FileStream]::new($Path,[IO.FileMode]::CreateNew);try{$b=[Text.Encoding]::UTF8.GetBytes(($Value|ConvertTo-Json -Depth 20 -Compress));$f.Write($b,0,$b.Length);$f.Flush($true)}finally{$f.Dispose()}}
function Ref([string]$Path){@{ref=[IO.Path]::GetRelativePath((Get-Location).Path,$Path).Replace('\','/');sha256=(Get-FileHash $Path).Hash.ToLowerInvariant()}}

if($Group -ceq 'ProcessMount'){
# Same integration boundary now owns the Job Object; operation FAIL can still close.
foreach($kind in @('orphan','latepipe')){
 $ctx=New-OfflineNativeTestContext $ev;Initialize-OfflineNativeAdapter $ctx|Out-Null
 $result=Invoke-OfflineNativeChild $ctx $kind 1200 8192
 Check ($result.Receipt.actualExit -eq 0 -and $result.Receipt.treeClosure -ceq 'CLOSED' -and $result.Receipt.jobAfterRootRelease -gt 0 -and $result.Receipt.jobFinalActive -eq 0 -and $result.Receipt.killTreeRequested) 'INTEGRATED_ORPHAN_CLOSURE'
 Reject {Assert-NativeSuccess $result};Reject {Read-NativeJSON $result}
 $ctx|Add-Member NoteProperty Registry ([Collections.Generic.List[object]]::new())
 $clean=Test-OwnedRegistryCleanup $ctx {throw 'NO_RESOURCE_EXPECTED'} {throw 'NO_RESOURCE_EXPECTED'} {@{Containers='';Networks=''}}
 Check ($clean.closed -and $clean.nativeTrees -ceq 'CLOSED_ALL_REGISTERED') 'ACTUAL_CLOSURE_NOT_RECOGNIZED'
 $rows.Add(@{case='F_NATIVE_ORPHAN_'+$kind;status='PASS_NATIVE_FAIL_CLEANUP_CLOSED';receipt=$result.Receipt;rootHandleDisposed=$ctx.NativeChildren[0].Disposed;recordStillRegistered=$ctx.NativeChildren.Count;ownerCleanupClosed=$clean.closed;containment='INTEGRATED_WIN32_OWN_JOB'})
}
Reject {&$module {Assert-NativeTreeCapability}};$rows.Add(@{case='MISSING_CONTEXT_NATIVE_PRECONDITION_NO_EXTERNAL_CALL';status='PASS_REJECT_UNTRUSTED'})
NewJSON (Join-Path $ev 'regression-native.json') @{cases=$rows.ToArray();sourceGate='HOLD_NO_SOURCE_AUTH';containment='INTEGRATED_OFFLINE_TESTED'}
# Mount guard vectors call the runtime guard, including Windows filesystem checks.
$temp=Join-Path $ev 'OFFLINE_TEST_ONLY_MOUNTS';New-Item -ItemType Directory -Path (Join-Path $temp 'owner-private')|Out-Null;New-Item -ItemType Directory -Path (Join-Path $temp 'control')|Out-Null
$run='OFFLINE_TEST_ONLY_GUARD';$file=(Resolve-Path (Join-Path $PSScriptRoot 'child.cjs')).Path
$expected=[pscustomobject]@{source=$file;target='/app/expected.cjs';roles=@('app');readOnly=$true}
$guard=[pscustomobject]@{Mode='OFFLINE_TEST_ONLY';Root=$temp;Control=(Join-Path $temp 'control');Payload=[pscustomobject]@{runID=$run};Plan=[pscustomobject]@{mounts=@($expected);supervisorMirrors=@();controlMounts=@()};EnvironmentProof=[pscustomobject]@{mode='OFFLINE_TEST_ONLY';mountSourceMap=@()}}
$role=[pscustomobject]@{role='app';image='OFFLINE_TEST_ONLY_IMAGE';user='1000:1000';memoryMiB=16;pids=8;cpu=0.25;networks=@('internal')}
$mount=[pscustomobject]@{Type='bind';Destination='/app/expected.cjs';RW=$false;Source=$file}
$inspect=[pscustomobject]@{Image=$role.image;Name='/wed-source-'+$run+'-app';Config=[pscustomobject]@{Labels=[pscustomobject]@{'com.wed-snap.run'=$run};User=$role.user;Env=@()};HostConfig=[pscustomobject]@{ReadonlyRootfs=$true;Privileged=$false;CapAdd=@();CapDrop=@('ALL');SecurityOpt=@('no-new-privileges:true');IpcMode='private';Memory=16MB;MemorySwap=16MB;PidsLimit=8;NanoCpus=250000000;PortBindings=[pscustomobject]@{}};NetworkSettings=[pscustomobject]@{Networks=[pscustomobject]@{('wed-source-'+$run+'-internal')=[pscustomobject]@{}}};Mounts=@($mount)}
function Guard {&$module {param($c,$r,$i)Assert-ContainerGuard $c $r $i 1} $guard $role $inspect}
Guard;$rows.Add(@{case='MOUNT_EXACT_WINDOWS_SOURCE';status='PASS_SYNTHETIC_INSPECT'})
foreach($tag in @('OTHER_FILE','TYPE','RW','PRIVATE','ANCESTOR','MAPPING_UNKNOWN','ALIAS')){
 $mount.Type='bind';$mount.RW=$false;$mount.Source=$file
 switch($tag){
  OTHER_FILE{$mount.Source=(Resolve-Path (Join-Path $PSScriptRoot 'child.cjs')).Path.Replace('child.cjs','native.ps1')}
  TYPE{$mount.Type='volume'} RW{$mount.RW=$true}
  PRIVATE{$mount.Source=Join-Path $temp 'owner-private/native-exits.json';[IO.File]::WriteAllText($mount.Source,'{"mode":"OFFLINE_TEST_ONLY"}')}
  ANCESTOR{$mount.Source=(Get-Location).Path}
  MAPPING_UNKNOWN{$mount.Source='/OFFLINE_TEST_ONLY_UNOBSERVED/child.cjs'}
  ALIAS{$mount.Source='/OFFLINE_TEST_ONLY//child.cjs'}
 };Reject {Guard};$rows.Add(@{case='MOUNT_DENY_'+$tag;status='PASS_SYNTHETIC_INSPECT'})
}
Reject {&$module {Assert-NoReparseAttributes ([IO.FileAttributes]::Directory -bor [IO.FileAttributes]::ReparsePoint)}}
$rows.Add(@{case='MOUNT_REPARSE_ATTRIBUTE_POLICY_REJECT';status='PASS_ATTRIBUTE_VECTOR_ONLY';actualJunction='NOT_TESTED_CREATION_ACCESS_DENIED_ATTEMPT_1';usedBy='Resolve-WorkspaceFile_called_by_runtime_mount_guard'})
$proof=Join-Path $temp 'OFFLINE_TEST_ONLY_MAPPING_PROOF.json';NewJSON $proof @{mode='OFFLINE_TEST_ONLY';notDockerObservation=$true}
$mount.Source='/OFFLINE_TEST_ONLY_EXPLICIT_MAPPING/child.cjs';$guard.EnvironmentProof.mountSourceMap=@([pscustomobject]@{hostSource=$file;observedSource=$mount.Source;status='OFFLINE_TEST_ONLY';proof=(Ref $proof)})
Guard;$rows.Add(@{case='MOUNT_EXPLICIT_MAPPING_FIXTURE_ONLY';status='PASS_SYNTHETIC_NOT_DOCKER_MAPPING_PROOF'})
$guard.EnvironmentProof.mountSourceMap[0].proof.sha256='0'*64;Reject {Guard};$rows.Add(@{case='MOUNT_MAPPING_PROOF_HASH_CHANGED';status='PASS_SYNTHETIC_INSPECT'})
$guard.EnvironmentProof.mountSourceMap=@();$mount.Source=$guard.Control;$expected.source='<OWN_CONTROL>';$expected.target='/control';$expected.readOnly=$false;$mount.Destination='/control';$mount.RW=$true
Guard;$rows.Add(@{case='MOUNT_OWNER_CONTROL_DIRECTORY';status='PASS_SYNTHETIC_INSPECT'})
$mount.Source=Join-Path $guard.Control 'wrong';[IO.File]::WriteAllText($mount.Source,'OFFLINE_TEST_ONLY');Reject {Guard};$rows.Add(@{case='MOUNT_WRONG_CONTROL_SOURCE';status='PASS_SYNTHETIC_INSPECT'})
}

# Signature vectors are fake authority only. Private key never leaves this process.
if($Group -ceq 'Admission'){
$sigRoot=Join-Path $ev 'OFFLINE_TEST_ONLY_ADMISSION';New-Item -ItemType Directory -Path $sigRoot|Out-Null
$rsa=[Security.Cryptography.RSA]::Create();$rsa.KeySize=2048
try{
 $target=@{canonicalURL='https://www.tiktok.com/@offline_vector/photo/7000000000000000007';expectedPostID='7000000000000000007';selectedIndex=2}
 $anchor=Join-Path $sigRoot 'anchor.json';NewJSON $anchor @{schema='OFFLINE_TEST_ONLY_ANCHOR';target=$target;keys=@(@{keyID='OFFLINE_TEST_ONLY_KEY';publicKeySPKI=[Convert]::ToBase64String($rsa.ExportSubjectPublicKeyInfo())})}
 $human=Join-Path $sigRoot 'not-human.json';NewJSON $human @{mode='OFFLINE_TEST_ONLY_NOT_HUMAN'}
 $pins=Join-Path $sigRoot 'pins.json';NewJSON $pins @(@{path='labs/tiktok/ui-source-owner-native/Owner.psm1';sha256=(Get-FileHash 'labs/tiktok/ui-source-owner-native/Owner.psm1').Hash.ToLowerInvariant()})
 $allocation=(Get-FileHash 'labs/tiktok/ui-source-owner-native/allocation.json').Hash.ToLowerInvariant();$budget=(Get-FileHash 'labs/tiktok/ui-source-glue/budget-policy.json').Hash.ToLowerInvariant()
 $environment=Join-Path $sigRoot 'environment.json';NewJSON $environment @{mode='OFFLINE_TEST_ONLY';codePinsSHA256=(Ref $pins).sha256;allocationSHA256=$allocation;checks=@{node22Imports='OFFLINE_TEST_ONLY';cacheImages='OFFLINE_TEST_ONLY';publicSchema='OFFLINE_TEST_ONLY';utcClockSkew='OFFLINE_TEST_ONLY';cgroupIsolation='OFFLINE_TEST_ONLY';egressPhaseClosure='OFFLINE_TEST_ONLY'}}
 function Sign([string]$Name,[string]$Run,[string]$Claim){
  $p=@{schema='wed-source-owner-approval-v1';mode='OFFLINE_TEST_ONLY';state='OFFLINE_TEST_ONLY';scope='ONE_TIKTOK_PHOTO_UI_WORKFLOW';runID='OFFLINE_TEST_ONLY_'+$Run;claimID='OFFLINE_TEST_ONLY_'+$Claim;target=$target;expiresAt=[DateTimeOffset]::UtcNow.AddSeconds(420).ToString('o');allocationSHA256=$allocation;budgetSHA256=$budget;humanInstruction=(Ref $human);task=(Ref $human);codePins=(Ref $pins);environmentProof=(Ref $environment);evidenceRef='docs/evidence/OFFLINE_TEST_ONLY_NOT_SOURCE'}
  $raw=[Text.Encoding]::UTF8.GetBytes(($p|ConvertTo-Json -Depth 20 -Compress));$signed=$rsa.SignData($raw,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pss)
  $path=Join-Path $sigRoot ($Name+'.json');NewJSON $path @{keyID='OFFLINE_TEST_ONLY_KEY';payloadBase64=[Convert]::ToBase64String($raw);signatureBase64=[Convert]::ToBase64String($signed)};return $path
 }
 $ledger=Join-Path $sigRoot 'ledger';New-Item -ItemType Directory -Path $ledger|Out-Null
 $valid=Sign 'valid' 'RUN_A' 'CLAIM_A';$ad=Test-ApprovalConsumer $valid $anchor $ledger
 Check ($ad.ClaimConsumed -and (Test-Path $ad.RunPath) -and (Test-Path $ad.IntentPath) -and !(Test-Path (Join-Path $ledger '.admission-pending.json'))) 'DUAL_ADMISSION_NOT_COMMITTED'
 $before=@(Get-ChildItem $ledger -File|Sort-Object Name|ForEach-Object{(Ref $_.FullName).sha256}) -join '|'
 foreach($tag in @('SAME_CLAIM_SAME_RUN','NEW_CLAIM_SAME_RUN','SAME_CLAIM_NEW_RUN')){
  $path=switch($tag){SAME_CLAIM_SAME_RUN{$valid}NEW_CLAIM_SAME_RUN{Sign $tag 'RUN_A' 'CLAIM_B'}SAME_CLAIM_NEW_RUN{Sign $tag 'RUN_B' 'CLAIM_A'}}
  Reject {Test-ApprovalConsumer $path $anchor $ledger};$after=@(Get-ChildItem $ledger -File|Sort-Object Name|ForEach-Object{(Ref $_.FullName).sha256}) -join '|';Check ($after -ceq $before) 'REPLAY_CHANGED_LEDGER'
  $rows.Add(@{case='ADMISSION_'+$tag;status='PASS_ACTUAL_SIGNATURE_AND_FILESYSTEM';oldMarkersUnchanged=$true})
 }
 $new=Sign 'fresh' 'FRESH_RUN' 'FRESH_CLAIM';Test-ApprovalConsumer $new $anchor $ledger|Out-Null;$rows.Add(@{case='ADMISSION_FRESH_INDEPENDENT_RUN';status='PASS_ACTUAL_SIGNATURE_AND_FILESYSTEM'})
 $partial=Join-Path $sigRoot 'partial';New-Item -ItemType Directory -Path $partial|Out-Null
 $fault=Sign 'fault' 'PARTIAL_RUN' 'PARTIAL_CLAIM';Reject {Test-ApprovalConsumer $fault $anchor $partial -OfflineFailure AfterRun}
 Check ((Test-Path (Join-Path $partial '.admission-pending.json')) -and (Test-Path (Join-Path $partial 'run-OFFLINE_TEST_ONLY_PARTIAL_RUN.json')) -and !(Test-Path (Join-Path $partial 'OFFLINE_TEST_ONLY_PARTIAL_CLAIM.json'))) 'PARTIAL_INTENT_LOST'
 $partialBefore=@(Get-ChildItem $partial -File|Sort-Object Name|ForEach-Object{(Ref $_.FullName).sha256}) -join '|'
 Reject {Test-ApprovalConsumer $fault $anchor $partial};$other=Sign 'afterfault' 'OTHER_RUN' 'OTHER_CLAIM';Reject {Test-ApprovalConsumer $other $anchor $partial}
 Check (($partialBefore) -ceq (@(Get-ChildItem $partial -File|Sort-Object Name|ForEach-Object{(Ref $_.FullName).sha256}) -join '|')) 'PARTIAL_LEDGER_RESET'
 $rows.Add(@{case='ADMISSION_PARTIAL_FAILURE_HOLDS_LEDGER';status='PASS_ACTUAL_FILESYSTEM_INJECTED_OFFLINE_EXCEPTION_NOT_HOST_CRASH';markersNeverReset=$true})
 NewJSON (Join-Path $ev 'regression-admission-before-race.json') @{cases=$rows.ToArray();mode='OFFLINE_TEST_ONLY'}

 $race=Join-Path $sigRoot 'race';New-Item -ItemType Directory -Path (Join-Path $race 'ledger')|Out-Null
 [IO.File]::Copy($anchor,(Join-Path $race 'anchor.json'))
 foreach($tag in @('A','B')){$path=Sign ('race'+$tag) 'RACE_RUN' ('RACE_CLAIM_'+$tag);[IO.File]::Copy($path,(Join-Path $race ($tag+'.json')))}
 $processes=[Collections.Generic.List[object]]::new();$nativeRows=[Collections.Generic.List[object]]::new();$watch=[Diagnostics.Stopwatch]::StartNew()
 try{
  foreach($tag in @('A','B')){
   # Fixed offline children emit only fixed status constants. Inherit suite
   # stdio into the outer adapter's combined cap; create no async pipe readers.
   $si=[Diagnostics.ProcessStartInfo]::new((Get-Process -Id $PID).Path);$si.UseShellExecute=$false;$si.CreateNoWindow=$true
   foreach($a in @('-NoProfile','-File',(Join-Path $PSScriptRoot 'test-admission-child.ps1'),'-Root',$race,'-Tag',$tag)){$si.ArgumentList.Add($a)}
   $p=[Diagnostics.Process]::new();$p.StartInfo=$si;$null=$p.Start();$processes.Add(@{Process=$p;Tag=$tag})
  }
  while(!(Test-Path (Join-Path $race 'ready-A')) -or !(Test-Path (Join-Path $race 'ready-B'))){Check ($watch.ElapsedMilliseconds -lt 5000) 'RACE_BARRIER_TIMEOUT';Start-Sleep -Milliseconds 5}
  [IO.File]::WriteAllText((Join-Path $race 'go'),'OFFLINE_TEST_ONLY')
  foreach($r in $processes){Check ($r.Process.WaitForExit([Math]::Max(0,7000-$watch.ElapsedMilliseconds))) 'RACE_CHILD_TIMEOUT';$nativeRows.Add(@{tag=$r.Tag;actualExit=$r.Process.ExitCode;stdio='INHERITED_TO_BOUNDED_SUITE_NO_CHILD_READERS'})}
  Check (@($nativeRows|Where-Object actualExit -EQ 0).Count -eq 1 -and @($nativeRows|Where-Object actualExit -EQ 23).Count -eq 1) 'DOUBLE_RACE_ADMISSION'
  Check (@(Get-ChildItem (Join-Path $race 'ledger') -Filter 'OFFLINE_TEST_ONLY_RACE_CLAIM_*.json').Count -eq 1) 'DOUBLE_RACE_CLAIM_MARKER'
  $rows.Add(@{case='ADMISSION_TWO_REAL_CHILDREN_COMPETE_SAME_RUN';status='PASS_ACTUAL_SIGNED_CONSUMER_RACE';children=$nativeRows.ToArray();elapsedMs=$watch.ElapsedMilliseconds;limitMs=7000;sourceAuthority=$false})
 }finally{
  $raceClosed=$true
  foreach($r in $processes){
   try{if(!$r.Process.HasExited){$r.Process.Kill();if(!$r.Process.WaitForExit(1000)){$raceClosed=$false}}}
   catch{$raceClosed=$false}
   finally{$r.Process.Dispose()}
  }
  if(!$raceClosed){throw 'RACE_OWNED_PROCESS_CLOSURE_UNKNOWN'}
 }
}finally{$rsa.Dispose()}
}
NewJSON (Join-Path $ev ('regressions-'+$Group+'.json')) @{status='PASS_OFFLINE_REGRESSIONS_SOURCE_HOLD';group=$Group;caseCount=$rows.Count;cases=$rows.ToArray();treeContainment='INTEGRATED_OFFLINE_TESTED_SOURCE_NOT_RUN';liveKeys=0;liveApprovals=0;liveClaims=0;sourceCalls=0;dockerCalls=0;utc=[DateTimeOffset]::UtcNow.ToString('o')}
Write-Output "PASS_REGRESSIONS_$($rows.Count)_SOURCE_HOLD"
exit 0
