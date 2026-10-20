param([Parameter(Mandatory)][string]$Evidence)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'Owner.psm1') -Force -DisableNameChecking
$ev=(Resolve-Path -LiteralPath $Evidence).Path
if(Test-Path (Join-Path $ev 'native-tests.json')){throw 'REFUSE_TEST_REUSE'}
$ctx=New-OfflineNativeTestContext $ev;$cases=[Collections.Generic.List[object]]::new()
Initialize-OfflineNativeAdapter $ctx|Out-Null
function Check([bool]$Condition,[string]$Code){if(!$Condition){throw $Code}}
foreach($case in @('pass','exit20','stderr','invalid','missing','late','flood','tree','clock')){
 $cap=if($case -ceq 'flood'){2048}else{8192};$r=Invoke-OfflineNativeChild $ctx $case 1600 $cap
 if($case -cin @('pass','stderr','clock')){Assert-NativeSuccess $r;Check ($r.Receipt.treeClosure -ceq 'CLOSED') 'TREE_NOT_PROVEN';$json=Read-NativeJSON $r;if($case -ceq 'clock'){
  $nowNS=[decimal][Diagnostics.Stopwatch]::GetTimestamp()*1000000000/[decimal][Diagnostics.Stopwatch]::Frequency
  Check ([decimal]$json.monotonicNS -le $nowNS -and $nowNS-[decimal]$json.monotonicNS -lt 5000000000) 'HOST_CLOCK_DOMAIN'
 }else{Check ($json.status -ceq 'PASS') 'VALID_NATIVE_JSON'}}
 if($case -ceq 'exit20'){Check ($r.Receipt.actualExit -eq 20 -and $r.RawOut.Contains('PASS')) 'EXIT20_FIXTURE';$rejected=$false;try{Read-NativeJSON $r|Out-Null}catch{$rejected=$true};Check $rejected 'PACKET_OVERRULED_EXIT'}
 if($case -cin @('invalid','missing')){$rejected=$false;try{Read-OfflineRootJSON $ctx $r|Out-Null}catch{$rejected=$true};Check $rejected 'INVALID_JSON_ACCEPTED';Check ($r.Receipt.actualExit -eq 0) 'INVALID_JSON_EXIT_NOT_ZERO'}
 if($case -cin @('late','tree')){Check ($r.Receipt.timedOut -and $r.Receipt.killTreeRequested -and $r.Receipt.nativeProcessClosed -and $r.Receipt.elapsedMs -lt 1900) 'TIMEOUT_NOT_BOUNDED'}
 if($case -ceq 'flood'){Check ($r.Receipt.byteCapExceeded -and $r.Receipt.retainedBytes -le 2048 -and $r.Receipt.killTreeRequested -and $r.Receipt.nativeProcessClosed) 'BYTECAP_NOT_DURING_READ'}
 $tree='NOT_APPLICABLE'
 if($case -ceq 'tree'){
  $childPID=(ConvertFrom-Json $r.RawOut).childPID;$alive=$null
  try{$alive=[Diagnostics.Process]::GetProcessById([int]$childPID)}catch{}
  if($alive){try{Check ($alive.HasExited -or $alive.StartTime.ToUniversalTime() -gt [DateTime]::Parse($r.Receipt.utcEnd).ToUniversalTime()) 'OWN_CHILD_TREE_STILL_LIVE'}finally{$alive.Dispose()}}
  $tree='OWNED_FIXTURE_CHILD_ABSENT_OR_EXITED'
 }
 $serialized=$r.Receipt|ConvertTo-Json -Depth 8 -Compress
 foreach($needle in @('OFFLINE_TEST_ONLY_SECRET','OFFLINE_TEST_ONLY_ARG_SECRET','TOKEN_PATH','TOKEN_QUERY','https://')){Check (!$serialized.Contains($needle)) 'SECRET_OR_ARGUMENT_IN_RECEIPT'}
 $cases.Add(@{case=$case;status='PASS';receipt=$r.Receipt;tree=$tree})
}
Check (@($ctx.NativeChildren|Where-Object {!$_.Disposed}).Count -eq 0) 'OWN_NATIVE_HANDLE_NOT_CLOSED'
$b=(Get-OwnerBudget).Value
Check ($b.ownerSeconds -eq 341 -and $b.browserSeconds -eq 40 -and $b.appBootstrapSeconds+$b.browserSeconds+$b.analyzeSeconds+$b.prepareSeconds+$b.finalProofSeconds -eq 280) 'BUDGET_SUM'
$cases.Add(@{case='BUDGET_RELATIVE_WATCHDOGS_NOT_MINIMUM_RESET';status='PASS'})
foreach($mode in @('closed','foreign','missing','absence-unknown','failure-after-create')){
 $c=New-OfflineNativeTestContext $ev;$registry=[Collections.Generic.List[object]]::new();foreach($kind in @('network','container')){$registry.Add([pscustomobject]@{Kind=$kind;Name='OFFLINE_TEST_ONLY_'+$kind;Owner='OFFLINE_TEST_ONLY_OWNER'})};$c|Add-Member NoteProperty Registry $registry
 $removed=[Collections.Generic.List[string]]::new()
 $inspect={param($r)if($mode -ceq 'missing'){throw 'STUB_MISSING_PROOF'};[pscustomobject]@{Owner=$(if($mode -ceq 'foreign'){'OFFLINE_FOREIGN'}else{$r.Owner});ID=$r.Name}}.GetNewClosure()
 $remove={param($r,$g)$removed.Add($r.Kind)}.GetNewClosure()
 $absent={@{Containers=$(if($mode -ceq 'absence-unknown'){'UNKNOWN'}else{''});Networks=''}}.GetNewClosure()
 $result=Test-OwnedRegistryCleanup $c $inspect $remove $absent
 if($mode -cin @('closed','failure-after-create')){Check ($result.closed -and ($removed -join ',') -ceq 'container,network') 'RESOURCE_ORDER_OR_ORPHAN_NAME'}else{Check (!$result.closed) 'UNKNOWN_CLEANUP_UPGRADED'}
 if($mode -cin @('foreign','missing')){Check ($removed.Count -eq 0) 'REMOVED_FOREIGN_OR_UNPROVEN'}
 $cases.Add(@{case='REGISTRY_'+$mode;status='PASS';evidenceKind='OFFLINE_STUB_LOGIC_NOT_DOCKER_CLOSURE';removed=@($removed);cleanupClosed=$result.closed})
}
@{status='PASS_ACTUAL_OWNED_CHILD_BOUNDARY_AND_REGISTRY_DELTA';powershell=$PSVersionTable.PSVersion.ToString();dotnet=[Environment]::Version.ToString();caseCount=$cases.Count;cases=$cases.ToArray();actualDockerCalls=0;sourceCalls=0;liveClaims=0;utc=[DateTimeOffset]::UtcNow.ToString('o')}|ConvertTo-Json -Depth 12|Set-Content (Join-Path $ev 'native-tests.json') -Encoding utf8
Write-Output "PASS_NATIVE_BOUNDARY_CASES_$($cases.Count)"
exit 0
