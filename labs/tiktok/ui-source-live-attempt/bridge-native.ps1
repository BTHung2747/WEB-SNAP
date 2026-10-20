. (Join-Path $PSScriptRoot '../ui-source-diagnostic-runtime/logger.ps1')
$script:NativeImportPins+=@{path=(Resolve-Path (Join-Path $PSScriptRoot '../ui-source-diagnostic-runtime/logger.ps1')).Path;sha=(Get-FileHash (Join-Path $PSScriptRoot '../ui-source-diagnostic-runtime/logger.ps1')).Hash.ToLowerInvariant()}
$script:BridgeCachedEngine=$null
function Assert-BridgeState($Context,$State){
 $b=$State.Bridge
 foreach($pair in @(@('payload','Payload'),@('tools','Tools'),@('pins','Pins'),@('environment','EnvironmentProof'),@('allocation','Allocation'))){if(($Context.($pair[1])|ConvertTo-Json -Depth 20 -Compress) -cne $b.($pair[0])){throw 'BRIDGE_CONTEXT_MUTATED'}}
 if($Context.Root -and [IO.Path]::GetFullPath($Context.Root) -cne $b.root){throw 'BRIDGE_CONTEXT_ROOT'}
 if((Get-Location).Path -cne $State.Cwd){throw 'BRIDGE_CWD_CHANGED'}
 if(![object]::ReferenceEquals($Context.Registry,$b.registry)){throw 'BRIDGE_REGISTRY_MUTATED'}
 if($Context.StartTicks -ne $b.startTicks -or $Context.UtcStart -ne $b.utcStart){throw 'BRIDGE_CLOCK_OR_DEADLINE_MUTATED'}
 foreach($key in @('WorkDeadline','CleanupDeadline','HardDeadline','StartupDeadline')){if($Context.$key -gt $b.deadlines[$key]){throw 'BRIDGE_CLOCK_OR_DEADLINE_MUTATED'};$b.deadlines[$key]=$Context.$key}
 if($Context.Registry.Count -ne $b.records.Count){throw 'BRIDGE_REGISTRY_MUTATED'}
 $admission=@{};foreach($key in @('ClaimConsumed','ClaimPath','ClaimSHA','RunPath','RunSHA','IntentPath','IntentSHA','HumanPath','HumanSHA','LedgerPath','ApprovalSHA')){$admission[$key]=$Context.$key};if(($admission|ConvertTo-Json -Compress) -cne $b.admission){throw 'BRIDGE_ADMISSION_MUTATED'}
 foreach($proof in $b.records){$r=$proof.entry;if(($r.Name+'|'+$r.Kind+'|'+$r.Role+'|'+$r.Owner+'|'+$r.Image) -cne $proof.identity -or $r.ID -cne $proof.id){throw 'BRIDGE_REGISTRY_MUTATED'}}
 if($Context.Mode -cne $(if($b.managed){'MANAGED_ADAPTER_TEST'}else{'UI_SINGLE_PHOTO_SOURCE'})){throw 'BRIDGE_CONTEXT_MODE'}
}
function Bridge-Exception($ErrorRecord){
 $t=$ErrorRecord.Exception.GetType().FullName
 $types=@{'System.Management.Automation.RuntimeException'='RUNTIME';'System.Management.Automation.CommandNotFoundException'='COMMAND_NOT_FOUND';'System.Management.Automation.ParameterBindingException'='PARAMETER_BINDING';'System.Management.Automation.MethodInvocationException'='METHOD_INVOCATION';'System.InvalidOperationException'='INVALID_OPERATION'}
 $ids=@('EXECUTOR_SCOPE','OVERRIDE_PRESENT','NATIVE_LIMIT','BRIDGE_CONTEXT_MUTATED','BRIDGE_SIGNATURE_DENIED','BRIDGE_CWD_CHANGED','NATIVE_NOT_SUCCESSFUL_OR_CLOSURE_UNKNOWN','BRIDGE_UNKNOWN_VOLUME','BRIDGE_OWNER_MISMATCH','BRIDGE_TRACE_INCOMPLETE','BRIDGE_ENDPOINT_OVERRIDE','NATIVE_EXECUTABLE_PIN','NATIVE_WORKING_DIRECTORY_CHANGED','BRIDGE_RUNTIME_LAYOUT_FAIL','BRIDGE_SPY_RESULT_SHAPE','HELPER_PREPARATION_EXHAUSTED_COMMAND_DEADLINE')
 return @{exceptionClass=$(if($types.ContainsKey($t)){$types[$t]}else{'OTHER_NO_MESSAGE'});errorID=$(if($ErrorRecord.FullyQualifiedErrorId -cin $ids){$ErrorRecord.FullyQualifiedErrorId}else{'UNCLASSIFIED_NO_MESSAGE'})}
}
function Write-BridgeTrace($Context,[string]$Stage,[string]$Operation,$Fields=$null){
 $state=Get-NativeContext $Context;if(!$state.PSObject.Properties['Bridge']){return};$b=$state.Bridge
 if($Stage -cnotin @('WRAPPER_ENTER','WRAPPER_ERROR','ENTER','VALIDATED','BEFORE_ENGINE_LOOKUP','ENGINE_VERIFIED','BEFORE_METHOD_CALL','RESULT_RETURNED','BEFORE_PROJECTION','PROJECTED','BEFORE_SINK','SINK_COMPLETE','ERROR','REGISTER_INTENT','CREATED_CID','WINDOW_SAMPLE')){throw 'BRIDGE_TRACE_STAGE'}
 if(!$b.ContainsKey('traceFailed')){$b.traceFailed=$false}
 if($b.trace.Count -ge 768){$b.traceFailed=$true;return}
 $leaf=if($Stage -cin @('WRAPPER_ENTER','WRAPPER_ERROR','REGISTER_INTENT','WINDOW_SAMPLE','BEFORE_SINK','SINK_COMPLETE')){'runtime.ps1'}elseif($Stage -ceq 'BEFORE_METHOD_CALL'){'../ui-source-live-attempt/bridge-native.ps1'}else{'native.ps1'}
 $source=[IO.Path]::GetFullPath((Join-Path $script:BridgeOwnerRoot $leaf))
 $row=@{stage=$Stage;operation=$(if($Operation -cmatch '^[A-Z_]{1,48}$'){$Operation}else{'INVALID_OPERATION'});boundaryMode=$(if($b.managed){'MANAGED_SPY_NOT_NATIVE'}else{'ORIGINAL_WIN32_HELPER'});sourceRef=[IO.Path]::GetRelativePath((Get-Location).Path,$source).Replace('\','/');sourceSHA=(Get-FileHash $source).Hash.ToLowerInvariant();sourceSite=$Stage;elapsedMs=[long](([Diagnostics.Stopwatch]::GetTimestamp()-$Context.StartTicks)*1000/[Diagnostics.Stopwatch]::Frequency);fields=$Fields;utc=[DateTimeOffset]::UtcNow.ToString('o')}
 $b.trace.Add($row)
 if(!$Context.Root){return}
 try{
  if($b.ContainsKey('traceSink') -and $b.traceSink){& $b.traceSink $row}
  # Group events with the reviewed exact-byte logger. Persist a durable prefix
  # before the method, and the tail/error afterwards, not one fsync per event.
  if($Stage -cin @('BEFORE_METHOD_CALL','SINK_COMPLETE','ERROR','WRAPPER_ERROR','CREATED_CID','WINDOW_SAMPLE')){
   if(!$b.ContainsKey('traceSaved')){$b.traceSaved=0}
   $chunk=@($b.trace.ToArray()|Select-Object -Skip $b.traceSaved);$b.traceSaved=$b.trace.Count
   $null=Write-CappedReceipt (Join-Path $Context.Root ('owner-private/trace-'+$b.trace.Count.ToString('D4')+'.json')) @{schema='wed-owner-stage-chunk-v2';events=$chunk;totalEvents=$b.trace.Count} $null
  }
 }catch{$b.traceFailed=$true}
}
function Get-BridgeEngine($Context,$State){
 Assert-BridgeState $Context $State;$h=$State.Bridge.helper
 foreach($ref in @($State.Bridge.review,$State.Bridge.bundle)){if((Get-FileHash (Join-Path (Get-Location).Path $ref.ref)).Hash.ToLowerInvariant() -cne $ref.sha256){throw 'BRIDGE_REFERENCE_DRIFT'}}
 if($h.helperSHA -cne $script:NativeHelperSHA -or (Get-FileHash $h.helperSource).Hash.ToLowerInvariant() -cne $h.helperSHA -or (Get-FileHash $h.binary).Hash.ToLowerInvariant() -cne $h.binarySHA){throw 'BRIDGE_CACHED_HELPER_DRIFT'}
 if(!$script:BridgeCachedEngine){
  if('WedOwnerWin32.Engine' -as [type]){throw 'UNOWNED_PRELOADED_HELPER_TYPE'}
  $assembly=[Reflection.Assembly]::LoadFrom($h.binary);$type=$assembly.GetType('WedOwnerWin32.Engine',$true)
  if($type.Assembly.Location -cne $h.binary -or $type.Module.ModuleVersionId.ToString() -cne $h.MVID){throw 'BRIDGE_HELPER_IDENTITY'}
  $layout=$type::Layout();$script:BridgeCachedEngine=[pscustomobject]@{Type=$type;Path=$h.binary;SHA=$h.binarySHA;Assembly=$assembly;MVID=$type.Module.ModuleVersionId;SourceSHA=$h.helperSHA;Layout=($layout|ConvertTo-Json -Compress)}
 }
 $e=$script:BridgeCachedEngine
 if($e.Path -cne $h.binary -or $e.SHA -cne $h.binarySHA -or $e.MVID.ToString() -cne $h.MVID -or ![object]::ReferenceEquals($e.Type.Assembly,$e.Assembly) -or ($e.Type::Layout()|ConvertTo-Json -Compress) -cne $e.Layout){throw 'BRIDGE_LOADED_HELPER_DRIFT'}
 return $e
}
function Invoke-BridgeMethod($Context,$Engine,[string]$Exe,[string[]]$Argv,[int]$Remaining,[int]$Cap,[string]$Operation,[long]$Due){
 $state=Get-NativeContext $Context;Assert-BridgeState $Context $state
 Write-BridgeTrace $Context 'BEFORE_METHOD_CALL' $Operation @{argumentCount=$Argv.Count;limitMs=$Remaining;byteCap=$Cap;spawnObserved=$false}
 if($state.Bridge.traceFailed -and $state.Bridge.methodStage -cne 'cleanup'){throw 'BRIDGE_TRACE_INCOMPLETE'}
 $Remaining=[int][Math]::Min($Remaining,($Due-[Diagnostics.Stopwatch]::GetTimestamp())*1000.0/[Diagnostics.Stopwatch]::Frequency)
 $stage=if($state.Bridge.ContainsKey('methodStage')){$state.Bridge.methodStage}else{'work'}
 $Remaining=[Math]::Min($Remaining,(Get-RemainingNativeMs $Context $stage))
 if($Remaining -lt 401){throw 'HELPER_PREPARATION_EXHAUSTED_COMMAND_DEADLINE'}
 if($state.Bridge.managed){
  if($Context.Mode -cne 'MANAGED_ADAPTER_TEST' -or ![object]::ReferenceEquals($Context.Seal,$script:BridgeTestSeal)){throw 'BRIDGE_SPY_FORBIDDEN'}
  return & $state.Bridge.spy $Exe $Argv $state.Cwd $Remaining $Cap
 }
 # The only live process call is the unchanged, provenance-checked helper.
 return $Engine.Type::Run($Exe,$Argv,$state.Cwd,$Remaining,$Cap,'None',$null)
}
function Get-SourceAdapterTrace($Context){$s=Get-NativeContext $Context;if(!$s.PSObject.Properties['Bridge']){throw 'BRIDGE_CONTEXT_REQUIRED'};$rows=@($s.Bridge.trace.ToArray()|ConvertTo-Json -Depth 24|ConvertFrom-Json);return @{mode=$(if($s.Bridge.managed){'MANAGED_SPY_NOT_NATIVE'}else{'LIVE_TRACE'});incomplete=$s.Bridge.traceFailed;rows=$rows}}
function Capture-BridgeCID($Context,[string]$Operation,$Native){
 if($Operation -cnotin @('CREATE_OWN_NETWORK','CREATE_PRIVATE_SERVICE','CREATE_SOURCE_APP','CREATE_SOURCE_GATEWAY','MANAGED_CREATE')){return}
 $entry=@($Context.Registry|Where-Object{$_.CreatePending})
 if($entry.Count -ne 1){throw 'BRIDGE_CREATE_INTENT_REQUIRED'}
 $entry=$entry[0];$entry.CreatePending=$false
 $s=Get-NativeContext $Context;$s.Bridge.createResultMissing=$false
 if($Native.RawOut.Trim() -cmatch '^[a-f0-9]{64}$'){$entry.ID=$Native.RawOut.Trim();Set-BridgeRegistryID $Context $entry;Write-BridgeTrace $Context 'CREATED_CID' $Operation @{cid=$entry.ID;name=$entry.Name};Write-ExclusiveJSON (Join-Path $Context.Root ('owner-private/created-'+$Context.Registry.IndexOf($entry)+'.json')) @{id=$entry.ID;name=$entry.Name;task=$script:BridgeTaskMarker;run=$Context.Payload.runID}}else{$s.Bridge.createResultMissing=$true}
}
function Set-BridgeRegistryID($Context,$Entry){$s=$null;if(!$script:NativeContexts.TryGetValue($Context,[ref]$s)){throw 'REGISTERED_NATIVE_CONTEXT_REQUIRED'};$p=@($s.Bridge.records|Where-Object{[object]::ReferenceEquals($_.entry,$Entry)});if($p.Count -ne 1){throw 'BRIDGE_REGISTRY_MUTATED'};$p[0].id=$Entry.ID}
