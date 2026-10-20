$ErrorActionPreference='Stop'
. (Join-Path (Get-Location).Path 'labs/tiktok/ui-source-runtime-probe-fix/core.ps1')
. (Join-Path (Get-Location).Path 'labs/tiktok/ui-source-runtime-probe-fix/native.ps1')
$script:EvidenceRoot=Join-Path (Get-Location).Path 'docs/evidence/ui-source-job-residual-diagnostic-20261019/backend'
function Check-Baseline {
 $base=Get-OldBaseline
 foreach($entry in @(@{root='docs/evidence/ui-source-runtime-probe-fix-20261019/backend';sha='eaf17b5526d098447e2e5bfa6d2bf3745791c91860d9dba68ab833f4a3ae1850'},@{root='docs/evidence/ui-source-runtime-probe-fixed-attempt-20261019/backend';sha='cd36a89cbfe752d08167ded43d4f26b7604fc6e77514344ddc2dad954caf4081'})){
  $mf=Join-Path $entry.root 'manifest.json';if((Get-FileHash $mf).Hash.ToLowerInvariant() -cne $entry.sha){throw 'BASELINE_DRIFT'}
  $m=Get-Content $mf -Raw|ConvertFrom-Json;Assert-Pins $m.implementation
  foreach($a in $m.artifacts){Assert-Pins @(@{path=(Join-Path $entry.root $a.path);sha256=$a.sha256})}
  if($m.externalArtifacts){Assert-Pins $m.externalArtifacts}
 }
 return @{baselineEntries=@($base.pins).Count;oldSource=$base.oldSources;oldArtifacts=$base.oldArtifacts;frozen=$base.frozen;fixSource=6;fixArtifacts=17;epochArtifacts=8;overviewArtifacts=7;originalHelperSHA=(Get-FileHash labs/tiktok/ui-source-owner-native/Win32Adapter.cs).Hash.ToLowerInvariant()}
}
function Load-Diagnostic([ValidateSet('compile.json','compile-final.json')][string]$Compile='compile.json') {
 $c=Get-Content (Join-Path $script:EvidenceRoot $Compile) -Raw|ConvertFrom-Json
 Assert-Pins @(@{path=(Join-Path $PSScriptRoot 'DiagnosticAdapter.cs');sha256=$c.cloneSHA},@{path=(Join-Path $PSScriptRoot 'Diagnostic.cs');sha256=$c.collectorSHA},@{path=$c.dll;sha256=$c.dllSHA})
 if('WedJobDiagnostic.Engine' -as [type]){throw 'UNOWNED_PRELOADED_DIAGNOSTIC'}
 Add-Type -Path $c.dll
 $e='WedJobDiagnostic.Engine' -as [type]
 if($e.Assembly.Location -cne $c.dll -or $e.Module.ModuleVersionId.ToString() -cne $c.MVID){throw 'DLL_PROVENANCE'}
 $null=$e::Layout();$null=[WedJobDiagnostic.Collector]::Layout();return $e
}
function Diagnostic-SourcePins {return @(Get-ChildItem $PSScriptRoot -File|Sort-Object Name|ForEach-Object{@{path=$_.FullName;sha256=(Get-FileHash $_.FullName).Hash.ToLowerInvariant()}})}
function Persist-Operation([string]$Name,$R,[string]$Kind){
 $d=$R.Diagnostics;$bytes=[Text.Encoding]::UTF8.GetByteCount(($d|ConvertTo-Json -Depth 16 -Compress));$complete=$bytes -le 16384
 if(!$complete){$d=@{Complete=$false;Code='DIAGNOSTIC_SERIALIZED_CAP';bytes=$bytes}}
 $record=@{kind=$Kind;nativeStatus=$R.Status;rootPID=$R.RootPID;rootCreation=$R.RootCreationFileTime;rootExit=$R.RootExit;created=$R.Created;rootInOwnJob=$R.RootInOwnJob;flags=$R.LimitFlagsActual;limitMs=$R.LimitMs;cap=$R.ByteCap;forced=$R.TerminationRequested;timeout=$R.Timeout;capExceeded=$R.ByteCapExceeded;treeClosed=$R.TreeClosed;beforeRootRelease=$R.BeforeRootRelease;afterRootRelease=$R.AfterRootRelease;jobFinal=$R.FinalActive;EOF=$R.PipesEOF;cleanupClosed=$R.CleanupClosed;liveHandles=$R.LiveHandles;liveBuffers=$R.LiveBuffers;closeErrors=$R.CloseErrors;readers=$R.BackgroundReaders;elapsedMs=$R.ElapsedMs;stdoutBytes=$R.StdoutBytes;stderrBytes=$R.StderrBytes;phase=$R.Phase;win32Error=$R.Win32Error;events=$R.Events;diagnostics=$d;diagnosticCap=16384;diagnosticSerializedBytes=$(if($complete){$bytes}else{$null});rawOutput='BOUNDED_RAM_ONLY_NOT_PERSISTED';utc=[DateTimeOffset]::UtcNow.ToString('o')}
 if([Text.Encoding]::UTF8.GetByteCount(($record|ConvertTo-Json -Depth 20 -Compress)) -gt 65536){throw 'OPERATION_RECEIPT_CAP'}
 Save-New (Join-Path $script:EvidenceRoot ($Name+'.json')) $record
 if(!$complete){throw 'DIAGNOSTIC_RECEIPT_CAPPED'}
 return $record
}
