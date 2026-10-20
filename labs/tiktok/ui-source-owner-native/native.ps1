function New-OfflineNativeTestContext([string]$Root){
 $path=Resolve-WorkspaceFile ([IO.Path]::GetRelativePath((Get-Location).Path,[IO.Path]::GetFullPath($Root)));$evidence=[IO.Path]::GetFullPath((Join-Path (Get-Location).Path 'docs/evidence'))
 if(!$path.StartsWith($evidence+[IO.Path]::DirectorySeparatorChar) -or !(Test-Path -LiteralPath $path -PathType Container)){throw 'OFFLINE_ROOT'}
 Register-NativeContext ([pscustomobject]@{Mode='OFFLINE_TEST_ONLY';Seal=$script:OfflineSeal;Root=$path;NativeChildren=[Collections.Generic.List[object]]::new();NativeReceipts=[Collections.Generic.List[object]]::new()})
}
function Assert-ExecutionContext($Context,[switch]$Docker){
 $state=Get-NativeContext $Context
 if($state.PSObject.Properties['Bridge'] -and $Context.Mode -ceq 'MANAGED_ADAPTER_TEST'){
  if(![object]::ReferenceEquals($Context.Seal,$script:BridgeTestSeal) -or !$Context.ClaimConsumed -or !$state.Bridge.managed){throw 'BRIDGE_MANAGED_CONTEXT_REQUIRED'}
  foreach($pair in @(@('ClaimPath','ClaimSHA'),@('RunPath','RunSHA'),@('IntentPath','IntentSHA'),@('HumanPath','HumanSHA'))){if((Get-FileHash $Context.($pair[0])).Hash.ToLowerInvariant() -cne $Context.($pair[1])){throw 'ADMISSION_CHANGED'}}
  return
 }
 if($Docker){if($Context.Mode -cne 'UI_SINGLE_PHOTO_SOURCE' -or ![object]::ReferenceEquals($Context.Seal,$script:SourceSeal) -or !$Context.ClaimConsumed){throw 'SOURCE_CAPABILITY_REQUIRED'};foreach($pair in @(@('ClaimPath','ClaimSHA'),@('RunPath','RunSHA'),@('IntentPath','IntentSHA'))){if((Get-FileHash -LiteralPath $Context.($pair[0])).Hash.ToLowerInvariant() -cne $Context.($pair[1])){throw 'ADMISSION_CHANGED'}}}
 elseif(!(($Context.Mode -ceq 'OFFLINE_TEST_ONLY' -and [object]::ReferenceEquals($Context.Seal,$script:OfflineSeal)) -or ($Context.Mode -ceq 'UI_SINGLE_PHOTO_SOURCE' -and [object]::ReferenceEquals($Context.Seal,$script:SourceSeal)))){throw 'NATIVE_CAPABILITY_REQUIRED'}
}
function Invoke-NativeBoundary($Context,[string]$Operation,[string]$Executable,[string[]]$Argv,[int]$LimitMs=30000,[int]$ByteCap=1048576){
 try{Invoke-NativeBoundaryCore $Context $Operation $Executable $Argv $LimitMs $ByteCap}catch{
  $original=$_;try{$s=Get-NativeContext $Context;if($s.PSObject.Properties['Bridge']){Write-BridgeTrace $Context 'ERROR' $Operation (Bridge-Exception $original)}}catch{};throw $original
 }
}
function Invoke-NativeBoundaryCore($Context,[string]$Operation,[string]$Executable,[string[]]$Argv,[int]$LimitMs=30000,[int]$ByteCap=1048576){
 $due=[Diagnostics.Stopwatch]::GetTimestamp()+[long]($LimitMs*[Diagnostics.Stopwatch]::Frequency/1000)
 Assert-ExecutionContext $Context;$state=Get-NativeContext $Context
 $bridge=[bool]$state.PSObject.Properties['Bridge'];if($bridge){Write-BridgeTrace $Context 'ENTER' $Operation @{argumentCount=$Argv.Count;limitMs=$LimitMs;byteCap=$ByteCap}}
 if($Operation -cnotmatch '^[A-Z_]{1,48}$' -or $LimitMs -lt 600 -or $LimitMs -gt 30000 -or $ByteCap -lt 256 -or $ByteCap -gt 1048576){throw 'NATIVE_LIMIT'}
 if(![IO.Path]::IsPathFullyQualified($Executable)){throw 'ABSOLUTE_EXECUTABLE_REQUIRED'};$exe=[IO.Path]::GetFullPath($Executable)
 if(!$state.Tools.ContainsKey($exe) -or (Get-FileHash -LiteralPath $exe).Hash.ToLowerInvariant() -cne $state.Tools[$exe].sha){throw 'NATIVE_EXECUTABLE_PIN'}
 if($bridge -and $state.Tools[$exe].role -ceq 'docker' -and ($Argv.Count -lt 3 -or $Argv[0] -cne '--host' -or $Argv[1] -cne 'npipe:////./pipe/dockerDesktopLinuxEngine')){throw 'BRIDGE_ENDPOINT_OVERRIDE'}
 if((Get-Location).Path -cne $state.Cwd){throw 'NATIVE_WORKING_DIRECTORY_CHANGED'}
 if($bridge){Write-BridgeTrace $Context 'VALIDATED' $Operation;Write-BridgeTrace $Context 'BEFORE_ENGINE_LOOKUP' $Operation}
 $utc=[DateTimeOffset]::UtcNow;$watch=[Diagnostics.Stopwatch]::StartNew();$engine=Get-NativeEngine $Context
 if($bridge){Write-BridgeTrace $Context 'ENGINE_VERIFIED' $Operation}
 $remaining=$LimitMs-[int]$watch.ElapsedMilliseconds;if($remaining -lt 401){throw 'HELPER_PREPARATION_EXHAUSTED_COMMAND_DEADLINE'}
 $record=[pscustomobject]@{PID=$null;CreationFileTime=$null;Disposed=$false;TreeClosure='UNKNOWN';Containment='WIN32_JOB_AT_CREATION'}
 $Context.NativeChildren.Add($record);$state.Records.Add($record)
 $recordProof=[pscustomobject]@{Context=$Context;Closed=$false;Serialized=$null};$script:NativeRecords.Add($record,$recordProof)
 if($state.Mode -cne 'OFFLINE_TEST_ONLY' -and ($state.Fault -cne 'None' -or $state.Ready)){throw 'TEST_INJECTION_FORBIDDEN'}
 try{
  $native=if($bridge){Invoke-BridgeMethod $Context $engine $exe $Argv $remaining $ByteCap $Operation $due}else{$engine.Type::Run($exe,$Argv,$state.Cwd,$remaining,$ByteCap,$state.Fault,$state.Ready)}
  if($bridge){Write-BridgeTrace $Context 'RESULT_RETURNED' $Operation @{resultObserved=($null -ne $native)};Capture-BridgeCID $Context $Operation $native;Write-BridgeTrace $Context 'BEFORE_PROJECTION' $Operation}
  if(!($bridge -and $state.Bridge.managed) -and ![object]::ReferenceEquals($native.GetType().Assembly,$engine.Assembly)){throw 'NATIVE_OUTCOME_ASSEMBLY'}
  if($bridge -and $state.Bridge.managed){foreach($key in @('CleanupClosed','TreeClosed','FinalActive','LiveHandles','LiveBuffers','CloseErrors','BackgroundReaders','RootExit','Created','RootInOwnJob','JobHandleNonInherited','LimitsVerified','TerminationRequested','Timeout','ByteCapExceeded','PipesEOF','Status','LimitMs','ByteCap')){if(!$native.PSObject.Properties[$key]){throw 'BRIDGE_SPY_RESULT_SHAPE'}}}
 }catch{if($bridge){Write-BridgeTrace $Context 'ERROR' $Operation (Bridge-Exception $_)};throw}
 $closed=$native.CleanupClosed -and $native.TreeClosed -and $native.FinalActive -eq 0 -and $native.LiveHandles -eq 0 -and $native.LiveBuffers -eq 0 -and $native.CloseErrors -eq 0 -and $native.BackgroundReaders -eq 0
 $recordProof.Closed=$closed;$record.PID=$native.RootPID;$record.CreationFileTime=$native.RootCreationFileTime;$record.Disposed=$native.LiveHandles -eq 0;$record.TreeClosure=if($closed){'CLOSED'}else{'UNKNOWN'}
 $recordProof.Serialized=$record|ConvertTo-Json -Compress
 $receipt=[pscustomobject]@{operation=$Operation;actualExit=$native.RootExit;actualSignal=$(if($native.TerminationRequested){'UNKNOWN'}else{$null});oom='NOT_INFERRED_FROM_EXIT';treeClosure=$record.TreeClosure;treeContainment='WIN32_JOB_AT_CREATION';pid=$native.RootPID;creationFileTime=$native.RootCreationFileTime;killTreeRequested=$native.TerminationRequested;timedOut=$native.Timeout;byteCapExceeded=$native.ByteCapExceeded;stdoutBytes=$native.StdoutBytes;stderrBytes=$native.StderrBytes;retainedBytes=$native.RetainedBytes;byteCap=$ByteCap;waitLimitMs=$LimitMs;executionSliceMs=$remaining-400;elapsedMs=$watch.Elapsed.TotalMilliseconds;pipesClosed=$native.PipesEOF;readFailed=(!$native.PipesEOF -and $native.Created);nativeProcessClosed=(!$native.Created -or $null -ne $native.RootExit);created=$native.Created;rootInOwnJob=$native.RootInOwnJob;hostInJob=$native.HostInJob;limitsVerified=$native.LimitsVerified;jobFlags=$native.LimitFlagsActual;additionalJobMemoryLimit=$native.MemoryLimitBytes;additionalActiveLimit=$native.ActiveLimitActual;jobBeforeRootRelease=$native.BeforeRootRelease;jobAfterRootRelease=$native.AfterRootRelease;jobFinalActive=$native.FinalActive;peakJobMemory=$native.PeakJobMemory;liveHandles=$native.LiveHandles;liveBuffers=$native.LiveBuffers;backgroundReaders=$native.BackgroundReaders;phase=$native.Phase;win32Error=$native.Win32Error;helperSHA=$engine.SourceSHA;binarySHA=$engine.SHA;utcStart=$utc.ToString('o');utcEnd=[DateTimeOffset]::UtcNow.ToString('o');argumentsAndOutput='OMITTED_NO_RAW_CONTENT'}
 $Context.NativeReceipts.Add($receipt)
 if($bridge){$receipt.executionSliceMs=$native.LimitMs-400;$receipt|Add-Member NoteProperty effectiveNativeLimitMs $native.LimitMs;$receipt|Add-Member NoteProperty helperElapsedMs $native.ElapsedMs}
 if($bridge){$receipt|Add-Member NoteProperty boundaryMode $(if($state.Bridge.managed){'MANAGED_SPY_NOT_NATIVE'}else{'ORIGINAL_WIN32_HELPER'});Write-BridgeTrace $Context 'PROJECTED' $Operation @{resultObserved=$true;rootExit=$native.RootExit;created=$native.Created}}
 $result=[pscustomobject]@{Receipt=$receipt;RawOut=$native.RawOut;RawErr=$native.RawErr}
 $proof=[pscustomobject]@{Context=$Context;Record=$record;Receipt=$receipt;Serialized=($receipt|ConvertTo-Json -Depth 14 -Compress);RawOut=$native.RawOut;RawErr=$native.RawErr;Closed=$closed;Success=($native.Status -ceq 'PASS' -and $closed -and $native.Created -and $native.RootInOwnJob -and $native.JobHandleNonInherited -and $native.LimitsVerified -and $native.RootExit -eq 0 -and !$native.TerminationRequested -and !$native.Timeout -and !$native.ByteCapExceeded -and $native.PipesEOF)}
 $script:NativeResults.Add($result,$proof)
 if($bridge -and $state.Bridge.ContainsKey('createResultMissing') -and $state.Bridge.createResultMissing -and $Operation -cin @('CREATE_OWN_NETWORK','CREATE_PRIVATE_SERVICE','CREATE_SOURCE_APP','CREATE_SOURCE_GATEWAY','MANAGED_CREATE') -and $proof.Success){throw 'BRIDGE_CREATE_RESULT_UNKNOWN'}
 return $result
}
function Assert-RootNativeOutcome($Result){
 $proof=Get-NativeResultProof $Result
 $r=$Result.Receipt;if($r.actualExit -ne 0 -or $null -eq $r.actualExit -or $r.timedOut -or $r.byteCapExceeded -or $r.readFailed -or !$r.nativeProcessClosed -or !$r.pipesClosed){throw 'NATIVE_NOT_SUCCESSFUL'}
}
function Assert-NativeSuccess($Result){
 $proof=Get-NativeResultProof $Result
 if(!$proof.Success){throw 'NATIVE_NOT_SUCCESSFUL_OR_CLOSURE_UNKNOWN'}
 Assert-RootNativeOutcome $Result
}
function Read-OfflineRootJSON($Context,$Result){
 Assert-ExecutionContext $Context;$proof=Get-NativeResultProof $Result
 if($Context.Mode -cne 'OFFLINE_TEST_ONLY' -or ![object]::ReferenceEquals($proof.Context,$Context)){throw 'OFFLINE_ROOT_DIAGNOSTICS_ONLY'}
 Read-NativeJSON $Result
}
function Assert-NativeTreeCapability($Context){Assert-ExecutionContext $Context;Get-NativeEngine $Context|Out-Null}
function Read-NativeJSON($Result){
 Assert-NativeSuccess $Result
 try{if([string]::IsNullOrWhiteSpace($Result.RawOut)){throw 'EMPTY'};return ConvertFrom-Json -InputObject $Result.RawOut -ErrorAction Stop}catch{throw 'NATIVE_JSON_REQUIRED'}
}
function Invoke-OfflineNativeCommand($Context,[ValidateSet('node','python','pwsh')][string]$Role,[string[]]$Argv,[int]$LimitMs=1600,[int]$ByteCap=8192){
 Assert-ExecutionContext $Context;if($Context.Mode -cne 'OFFLINE_TEST_ONLY'){throw 'OFFLINE_COMMAND_ONLY'};$state=Get-NativeContext $Context
 $paths=@($state.Tools.Keys|Where-Object{$state.Tools[$_].role -ceq $Role});if($paths.Count -ne 1){throw 'OFFLINE_ROLE_PIN'}
 Invoke-NativeBoundary $Context 'OFFLINE_COMMAND' $paths[0] $Argv $LimitMs $ByteCap
}
function Invoke-OfflineNativeChild($Context,[ValidateSet('pass','exit20','stderr','invalid','missing','late','flood','tree','clock','orphan','expires','latepipe')][string]$Case,[int]$LimitMs=1600,[int]$ByteCap=8192){
 if($Context.Mode -cne 'OFFLINE_TEST_ONLY' -or ![object]::ReferenceEquals($Context.Seal,$script:OfflineSeal)){throw 'OFFLINE_TEST_ONLY_REQUIRED'}
 if($Case -ceq 'clock'){return Invoke-OfflineNativeCommand $Context python @('-I','-B',(Join-Path $PSScriptRoot 'protocol.py'),'clock') $LimitMs $ByteCap}
 $childArgv=@('--max-old-space-size=32',(Join-Path $PSScriptRoot 'child.cjs'),$Case);if($Case -ceq 'stderr'){$childArgv+=,'OFFLINE_TEST_ONLY_ARG_SECRET'}
 Invoke-OfflineNativeCommand $Context node $childArgv $LimitMs $ByteCap
}
