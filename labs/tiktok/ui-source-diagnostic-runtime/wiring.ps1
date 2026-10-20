. (Join-Path (Get-Location).Path 'labs/tiktok/ui-source-runtime-probe-fix/core.ps1')
. (Join-Path (Get-Location).Path 'labs/tiktok/ui-source-runtime-probe-fix/native.ps1')
. (Join-Path $PSScriptRoot 'logger.ps1')
function Verify-Dependencies {
 $b=Get-OldBaseline
 $refs=@(@{root='docs/evidence/ui-source-runtime-probe-fix-20261019/backend';sha='eaf17b5526d098447e2e5bfa6d2bf3745791c91860d9dba68ab833f4a3ae1850'},@{root='docs/evidence/ui-source-runtime-probe-fixed-attempt-20261019/backend';sha='cd36a89cbfe752d08167ded43d4f26b7604fc6e77514344ddc2dad954caf4081'},@{root='docs/evidence/ui-source-job-residual-diagnostic-20261019/backend';sha='5d22c3fe39675a9b636bdf2256015ffbea9d4ed26d8dae190be444f51666f902'})
 $pins=@($b.pins)
 foreach($ref in $refs){$mf=Join-Path $ref.root 'manifest.json';if((Get-FileHash $mf).Hash.ToLowerInvariant() -cne $ref.sha){throw 'DEPENDENCY_DRIFT'};$m=Get-Content $mf -Raw|ConvertFrom-Json;Assert-Pins $m.implementation;$pins+=@($m.implementation)+@{path=(Resolve-Path $mf).Path;sha256=$ref.sha};foreach($a in $m.artifacts){$pin=@{path=(Resolve-Path (Join-Path $ref.root $a.path)).Path;sha256=$a.sha256};Assert-Pins @($pin);$pins+=$pin};if($m.externalArtifacts){Assert-Pins $m.externalArtifacts;$pins+=@($m.externalArtifacts)}}
 return @{pins=$pins;frozen=$b.frozen;oldSources=$b.oldSources;oldArtifacts=$b.oldArtifacts}
}
function Native-Projection($R,[string]$Name){
 # Only trusted numeric/fixed-code public Result projection. No RawOut/RawErr.
 return @{operation=$Name;nativeStatus=$R.Status;actualExit=$R.RootExit;rootPID=$R.RootPID;creation=$R.RootCreationFileTime;created=$R.Created;rootInOwnJob=$R.RootInOwnJob;forced=$R.TerminationRequested;timeout=$R.Timeout;capExceeded=$R.ByteCapExceeded;EOF=$R.PipesEOF;jobBefore=$R.BeforeRootRelease;jobAfter=$R.AfterRootRelease;jobFinal=$R.FinalActive;cleanupClosed=$R.CleanupClosed;liveHandles=$R.LiveHandles;liveBuffers=$R.LiveBuffers;readers=$R.BackgroundReaders;events=$R.Events;limitMs=$R.LimitMs;byteCap=$R.ByteCap;elapsedMs=$R.ElapsedMs;stdoutBytes=$R.StdoutBytes;stderrBytes=$R.StderrBytes;phase=$R.Phase;win32Error=$R.Win32Error}
}
function New-LoggedPipeline([string]$Root,[scriptblock]$NativeInvoker,[scriptblock]$FaultHook=$null,[scriptblock]$IOHook=$null){
 $state=@{failed=$false;pending=$false;sequence=0;failures=[Collections.Generic.List[object]]::new();receipts=[Collections.Generic.List[object]]::new()}
 $store={param($name,$op,$diag)
  if($name -cnotmatch '^[a-zA-Z0-9-]{1,100}$'){throw 'LOG_NAME_INVALID'}
  try{
   if($FaultHook){$patch=& $FaultHook $name $op $diag;if($patch){if($patch.ContainsKey('operation')){$op=$patch.operation};if($patch.ContainsKey('diagnostics')){$diag=$patch.diagnostics}}}
   $proof=Write-CappedReceipt (Join-Path $Root ($name+'.json')) $op $diag $IOHook
   $state.receipts.Add(@{name=$name;operationBytes=$proof.operationBytes;diagnosticBytes=$proof.diagnosticBytes;sha256=$proof.sha256})
  }catch{
   $code=Logger-Code $_;$state.failed=$true;$state.failures.Add(@{name=$name;code=$code})
   # Optional tiny marker uses the same serializer, never overflow data or a
   # success-shaped partial record. If sink is unavailable, remember RAM state.
   try{$null=Write-CappedReceipt (Join-Path $Root ($name+'-incomplete.json')) @{complete=$false;code=$code;name=$name} @{Complete=$false;Code='EVIDENCE_INCOMPLETE'}}catch{}
   throw 'LOGGER_INCOMPLETE'
  }
 }.GetNewClosure()
 $executor={param($op,[string[]]$argv,[int]$limit,[int]$cap)
  $r=& $NativeInvoker $op $argv $limit $cap
  $state.sequence++
  try{& $store ('diagnostic-'+$state.sequence.ToString('D3')) (Native-Projection $r $op) $r.Diagnostics}catch{$state.pending=$true}
  # Preserve the exact native object/status/exit/force. Sink informs core of
  # persistence failure after the result has been captured, even for create.
  return $r
 }.GetNewClosure()
 $sink={param($name,$value)
  $out=$value
  if($name -ceq 'summary'){
   # Full argv already sealed in plan and individual core-native receipts.
   # Keep crossrefs here to avoid duplicate unbounded summary accumulation.
   $out=$value.Clone();$out.calls=@($value.calls|ForEach-Object{@{operation=$_.operation;actualExit=$_.actualExit;nativeStatus=$_.nativeStatus;accepted=$_.accepted;elapsedMs=$_.elapsedMs}})
  }
  try{& $store ('core-'+$name) $out $null}finally{
   if($state.pending){$state.pending=$false;throw 'DIAGNOSTIC_EVIDENCE_INCOMPLETE'}
  }
 }.GetNewClosure()
 return @{executor=$executor;sink=$sink;state=$state}
}
function Invoke-LoggedAttempt($Plan,[scriptblock]$NativeInvoker,[scriptblock]$Now,[scriptblock]$CheckPins,[scriptblock]$FaultHook=$null,[scriptblock]$IOHook=$null){
 $pipe=New-LoggedPipeline $Plan.evidenceRoot $NativeInvoker $FaultHook $IOHook
 $core=Invoke-ProbeAttempt $Plan $pipe.executor $pipe.sink $Now $CheckPins
 return @{core=$core;loggerFailed=$pipe.state.failed;loggerFailures=$pipe.state.failures.ToArray();receiptIndex=$pipe.state.receipts.ToArray();completionPASS=($core.runtimePASS -and !$pipe.state.failed);cleanupClosed=$core.closed}
}
function Load-FinalDiagnostic($Plan){
 No-DockerOverrides;Assert-Pins (@($Plan.sourcePins)+@($Plan.baselinePins))
 if('WedJobDiagnostic.Engine' -as [type]){throw 'UNOWNED_DIAGNOSTIC_TYPE'}
 Assert-Pins @(@{path=$Plan.binary;sha256=$Plan.binarySHA})
 Add-Type -Path $Plan.binary;$engine='WedJobDiagnostic.Engine' -as [type]
 if($engine.Assembly.Location -cne $Plan.binary -or $engine.Module.ModuleVersionId.ToString() -cne $Plan.MVID -or !$Plan.restoredBaseTextEqual){throw 'DIAGNOSTIC_PROVENANCE'}
 $layout=$engine::Layout();$dl=[WedJobDiagnostic.Collector]::Layout()
 if(($layout|ConvertTo-Json -Compress) -cne ($Plan.layout|ConvertTo-Json -Compress) -or ($dl|ConvertTo-Json -Compress) -cne ($Plan.diagnosticLayout|ConvertTo-Json -Compress)){throw 'LAYOUT_DRIFT'}
 return $engine
}
function New-DiagnosticDelegate($Plan){
 $engine=Load-FinalDiagnostic $Plan
 return {param($op,[string[]]$argv,[int]$limit,[int]$cap)
  No-DockerOverrides
  Assert-Pins @(@{path=$Plan.docker;sha256=$Plan.dockerSHA},@{path=$Plan.binary;sha256=$Plan.binarySHA})
  if($Plan.endpoint -cne 'npipe:////./pipe/dockerDesktopLinuxEngine' -or $argv[0] -cnotin @('image','container','ps','create','start','rm') -or $cap -ne 65536 -or $limit -gt 20000 -or $limit -lt 600){throw 'NATIVE_SCOPE'}
  return $engine::Run($Plan.docker,[string[]](@('--host',$Plan.endpoint)+$argv),(Get-Location).Path,$limit,$cap,'None',$null)
 }.GetNewClosure()
}
