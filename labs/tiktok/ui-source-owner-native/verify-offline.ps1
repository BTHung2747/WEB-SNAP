param([Parameter(Mandatory)][string]$Evidence)
$ErrorActionPreference='Stop'
$base=(Get-Location).Path;$ev=[IO.Path]::GetFullPath($Evidence)
if(!$ev.StartsWith((Join-Path $base 'docs/evidence')+[IO.Path]::DirectorySeparatorChar) -or (Test-Path $ev)){throw 'NEW_OFFLINE_EVIDENCE_REQUIRED'}
New-Item -ItemType Directory -Path $ev|Out-Null
function SaveNew([string]$Name,$Value){$p=Join-Path $ev $Name;$f=[IO.FileStream]::new($p,[IO.FileMode]::CreateNew);try{$bytes=[Text.Encoding]::UTF8.GetBytes(($Value|ConvertTo-Json -Depth 18));$f.Write($bytes,0,$bytes.Length)}finally{$f.Dispose()}}
function Snapshot {
 @((Get-ChildItem $PSScriptRoot -File|Sort-Object Name)|ForEach-Object{@{path=[IO.Path]::GetRelativePath($base,$_.FullName).Replace('\','/');bytes=$_.Length;sha256=(Get-FileHash $_.FullName).Hash.ToLowerInvariant()}})
}
function Frozen {
 $out=@{}
 foreach($item in @(@{name='prelaunch';root='docs/evidence/ui-source-prelaunch-20261016/backend';pin='plan.json';key='pins'},@{name='guard';root='docs/evidence/ui-source-glue-fix-20261016/backend';pin='final-source-pins.json';key=$null})){
  $m=Get-Content (Join-Path $item.root 'manifest.json') -Raw|ConvertFrom-Json
  foreach($p in $m.implementation){if((Get-FileHash $p.path).Hash.ToLowerInvariant() -cne $p.sha256){throw 'FROZEN_IMPLEMENTATION_DRIFT'}}
  foreach($p in $m.artifacts){if((Get-FileHash (Join-Path $item.root $p.path)).Hash.ToLowerInvariant() -cne $p.sha256){throw 'FROZEN_ARTIFACT_DRIFT'}}
  $pins=Get-Content (Join-Path $item.root $item.pin) -Raw|ConvertFrom-Json;if($item.key){$pins=$pins.($item.key)}
  foreach($p in $pins){if((Get-FileHash $p.path).Hash.ToLowerInvariant() -cne $p.sha256){throw 'FROZEN_PIN_DRIFT'}}
  $out[$item.name]=@{implementation=@($m.implementation).Count;artifacts=@($m.artifacts).Count;pins=@($pins).Count;status='UNCHANGED_HASHES_ONLY_NO_HISTORICAL_TEST_RERUN'}
 }
 $historical='docs/evidence/ui-source-owner-native-20261016/backend';$old=Get-Content (Join-Path $historical 'manifest.json') -Raw|ConvertFrom-Json
 foreach($p in $old.artifacts){if((Get-FileHash (Join-Path $historical $p.path)).Hash.ToLowerInvariant() -cne $p.sha256){throw 'HISTORICAL_NATIVE_EVIDENCE_DRIFT'}}
 foreach($name in @('trust-anchor.json','allocation.json','protocol.py','run.ps1')){$p=@($old.implementation|Where-Object path -CEQ ('labs/tiktok/ui-source-owner-native/'+$name))[0];if((Get-FileHash $p.path).Hash.ToLowerInvariant() -cne $p.sha256){throw 'FROZEN_NATIVE_POLICY_DRIFT'}}
 $out.nativeHistorical=@{artifacts=@($old.artifacts).Count;policyFiles=4;codeChange='AUTHORIZED_FIX_ALLOWLIST_NOT_HISTORICAL_EVIDENCE_REWRITE'}
 foreach($entry in @(@{name='poc';root='docs/evidence/ui-source-direct-win32-20261017/backend';sha='e4f195a578c979142417a6c38327cc06bc00245f0645d6e6ac04eaaa033fa832';code=$true},@{name='ownerFix';root='docs/evidence/ui-source-owner-native-fix-20261017/backend';sha='9f250edc6d89088d6fd08d5f0d83dc80f7b764441a88fa8d4c9313fc117899a5';code=$false})){
  $mp=Join-Path $entry.root 'manifest.json';if((Get-FileHash $mp).Hash.ToLowerInvariant() -cne $entry.sha){throw 'FROZEN_MANIFEST_DRIFT'}
  $m=Get-Content $mp -Raw|ConvertFrom-Json
  foreach($p in $m.artifacts){if((Get-FileHash (Join-Path $entry.root $p.path)).Hash.ToLowerInvariant() -cne $p.sha256){throw 'FROZEN_ARTIFACT_DRIFT'}}
  if($entry.code){foreach($p in $m.implementation){if((Get-FileHash $p.path).Hash.ToLowerInvariant() -cne $p.sha256){throw 'FROZEN_POC_CODE_DRIFT'}}}
  $out[$entry.name]=@{artifacts=@($m.artifacts).Count;manifestSHA=$entry.sha;codeChecked=$entry.code}
 }
 return $out
}
$initial=Snapshot;SaveNew 'source-pins-before.json' $initial;SaveNew 'frozen-before.json' (Frozen)
Import-Module (Join-Path $PSScriptRoot 'Owner.psm1') -Force -DisableNameChecking
$ctx=New-OfflineNativeTestContext $ev;Initialize-OfflineNativeAdapter $ctx|Out-Null
$rows=[Collections.Generic.List[object]]::new()
function Child([string]$Name,[string[]]$Argv,[int]$Expected=0,[int]$LimitMs=15000){
 $result=Invoke-OfflineNativeCommand $ctx pwsh $Argv $LimitMs 65536
 $receipt=$result.Receipt
 $r=@{name=$Name;actualExit=$receipt.actualExit;receipt=$receipt;stdoutBytes=$receipt.stdoutBytes;stderrBytes=$receipt.stderrBytes;output='BOUNDED_IN_RAM_OMITTED_FROM_EVIDENCE';utc=[DateTimeOffset]::UtcNow.ToString('o');vn=[TimeZoneInfo]::ConvertTimeBySystemTimeZoneId([DateTimeOffset]::UtcNow,'SE Asia Standard Time').ToString('o')}
 SaveNew ('execution-'+$Name+'.json') $r;$rows.Add($r)
 if($receipt.actualExit -ne $Expected -or $receipt.timedOut -or $receipt.byteCapExceeded -or $receipt.killTreeRequested -or !$receipt.pipesClosed -or $receipt.treeClosure -cne 'CLOSED' -or $receipt.jobFinalActive -ne 0){throw ('ACTUAL_CHILD_REJECTED_'+$Name)}
 if($Expected -eq 0){Assert-NativeSuccess $result}
}
foreach($name in @('native','trust','integration')){Child ('native-'+$name) @('-NoProfile','-File',(Join-Path $PSScriptRoot ('test-'+$name+'.ps1')),'-Evidence',$ev)}
foreach($group in @('ProcessMount','Admission')){Child ('native-regressions-'+$group) @('-NoProfile','-File',(Join-Path $PSScriptRoot 'test-regressions.ps1'),'-Evidence',$ev,'-Group',$group)}
$runner=Join-Path $PSScriptRoot 'run.ps1';$target='docs/tasks/UI_SOURCE_TARGET_20261016.json';$offline=Join-Path $ev 'OFFLINE_TEST_ONLY_SIGNATURES/OFFLINE_TEST_ONLY_VALID.json'
Child 'deny-default' @('-NoProfile','-File',$runner) 78
Child 'deny-missing-approval' @('-NoProfile','-File',$runner,'-ExecuteSource') 78
Child 'deny-target-only' @('-NoProfile','-File',$runner,'-Approval',$target) 78
Child 'deny-execute-target' @('-NoProfile','-File',$runner,'-ExecuteSource','-Approval',$target) 78
Child 'deny-offline-flag' @('-NoProfile','-File',$runner,'-ExecuteSource','-Approval',$offline,'-OfflineTestOnly') 78
Child 'deny-offline-envelope' @('-NoProfile','-File',$runner,'-ExecuteSource','-Approval',$offline) 78
foreach($group in @('runtime','security')){Child ('adapter-'+$group) @('-NoProfile','-File',(Join-Path $PSScriptRoot 'test-adapter.ps1'),'-Evidence',$ev,'-Group',$group)}
foreach($case in @('fake-context','source-pin','missing-source','compile-fault','preloaded-type','binary-pin')){Child ('loader-'+$case) @('-NoProfile','-File',(Join-Path $PSScriptRoot 'test-loader.ps1'),'-Evidence',$ev,'-Case',$case)}
Child 'adapter-crash' @('-NoProfile','-File',(Join-Path $PSScriptRoot 'test-crash.ps1'),'-Evidence',$ev)
$after=Snapshot
if(($initial|ConvertTo-Json -Depth 3 -Compress) -cne ($after|ConvertTo-Json -Depth 3 -Compress)){throw 'CURRENT_CODE_DRIFT'}
SaveNew 'source-pins-after.json' $after;SaveNew 'frozen-after.json' (Frozen)
$regCount=0;foreach($group in @('ProcessMount','Admission')){$regCount+=(Get-Content (Join-Path $ev ('regressions-'+$group+'.json')) -Raw|ConvertFrom-Json).caseCount}
$baseline=46+$regCount;$added=6
foreach($group in @('runtime','security','crash')){$added+=(Get-Content (Join-Path $ev ('adapter-'+$group+'-summary.json')) -Raw|ConvertFrom-Json).caseCount}
SaveNew 'summary.json' @{status='PASS_OFFLINE_INTEGRATED_OWNER_SOURCE_HOLD';harnessChildren=$rows.Count;cases=$baseline+$added;baselineCases=$baseline;addedCases=$added;caseBreakdown=@{nativeChildAndRegistry=15;signatureConsumer=9;privateProofBudgetAPIStateGuards=16;entryDeny=6;regressions=$regCount;runtime=12;security=11;loader=6;crash=1};legacy68='RERUN_NATIVE_POSITIVE_NOW_BOUND_ACTUAL_JOB_ZERO_EOF_CLOSURE';sourceCodeFiles=$after.Count;nativeExits=@($rows|ForEach-Object{@{name=$_.name;exit=$_.actualExit}});treeContainment='INTEGRATED_JOB_AT_CREATE_OFFLINE_OBSERVED';liveKeys=0;liveApprovals=0;liveClaims=0;dockerCalls=0;httpDNSCalls=0;historicalGuard95='NOT_RERUN';historicalDelta34='NOT_RERUN';runtimeDocker='NOT_RUN';utc=[DateTimeOffset]::UtcNow.ToString('o')}
Write-Output "PASS_OFFLINE_INTEGRATED_OWNER_$($baseline+$added)_SOURCE_HOLD"
exit 0
