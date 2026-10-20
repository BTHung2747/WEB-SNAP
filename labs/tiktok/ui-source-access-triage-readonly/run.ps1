param([Parameter(Mandatory)][string]$Evidence)
$ErrorActionPreference='Stop'
$workspace=(Get-Location).Path;$root=[IO.Path]::GetFullPath($Evidence)
if(!$root.StartsWith((Join-Path $workspace 'docs/evidence/ui-source-access-triage-readonly-20261019/backend')+[IO.Path]::DirectorySeparatorChar) -or (Test-Path $root)){throw 'NEW_TRIAGE_NAMESPACE_REQUIRED'}
New-Item -ItemType Directory -Path $root|Out-Null
function Save([string]$Name,$Value){$f=[IO.FileStream]::new((Join-Path $root $Name),[IO.FileMode]::CreateNew);try{$b=[Text.Encoding]::UTF8.GetBytes(($Value|ConvertTo-Json -Depth 30));$f.Write($b,0,$b.Length);$f.Flush($true)}finally{$f.Dispose()}}
function Frozen {
 $oldRoot='docs/evidence/ui-source-environment-readonly-20261019/backend';$oldManifest=Join-Path $oldRoot 'manifest.json';$ownerManifest='docs/evidence/ui-source-direct-win32-integration-20261017/backend/manifest.json'
 if((Get-FileHash $oldManifest).Hash.ToLowerInvariant() -cne '576270fad71f9472d4eccd04fd39b26b9e7f2db34b477ebd745fe350960109b3' -or (Get-FileHash $ownerManifest).Hash.ToLowerInvariant() -cne '95d0baad0de5ed95d29fb0bd5c49a6659fed18de5a584c03297f25190dd6dd07'){throw 'BASELINE_MANIFEST_DRIFT'}
 $old=Get-Content $oldManifest -Raw|ConvertFrom-Json;$owner=Get-Content $ownerManifest -Raw|ConvertFrom-Json
 foreach($p in @($owner.implementation)+@($old.implementation)){if((Get-FileHash $p.path).Hash.ToLowerInvariant() -cne $p.sha256){throw 'FROZEN_CODE_DRIFT'}}
 foreach($p in $old.artifacts){if((Get-FileHash (Join-Path $oldRoot $p.path)).Hash.ToLowerInvariant() -cne $p.sha256){throw 'FROZEN_READONLY_EVIDENCE_DRIFT'}}
 @{ownerSource=@($owner.implementation).Count;diagnosticSource=@($old.implementation).Count;diagnosticArtifacts=@($old.artifacts).Count;ownerPins=$owner.implementation;diagnosticPins=$old.implementation;historicalEvidence='UNCHANGED_HASH_CHECK_NO_QUERY_RERUN'}
}
function SourcePins {@(Get-ChildItem $PSScriptRoot -File|Sort-Object Name|ForEach-Object{@{path=[IO.Path]::GetRelativePath($workspace,$_.FullName).Replace('\','/');bytes=$_.Length;sha256=(Get-FileHash $_.FullName).Hash.ToLowerInvariant()}})}
$before=SourcePins;Save 'source-pins-before.json' $before;Save 'frozen-before.json' (Frozen)
$helper=(Resolve-Path 'labs/tiktok/ui-source-owner-native/Win32Adapter.cs').Path;$helperSHA='5ed79b96326b56535077c6a97b7b0b30fee1031379f74dc845cfc6fcebbf7f19'
if((Get-FileHash $helper).Hash.ToLowerInvariant() -cne $helperSHA -or ('WedOwnerWin32.Engine' -as [type]) -or ('WedReadOnlyTriage.Metadata' -as [type])){throw 'SOURCE_PIN_OR_PRELOADED_TYPE'}
$private=Join-Path $root 'assemblies';New-Item -ItemType Directory -Path $private|Out-Null
$engineDLL=Join-Path $private 'DiagnosticBoundary.dll';$metadataDLL=Join-Path $private 'TokenMetadata.dll';$compile=[Diagnostics.Stopwatch]::StartNew()
Add-Type -Path $helper -OutputAssembly $engineDLL
if(!('WedOwnerWin32.Engine' -as [type])){Add-Type -Path $engineDLL}
Add-Type -Path (Join-Path $PSScriptRoot 'TokenMetadata.cs') -OutputAssembly $metadataDLL
if(!('WedReadOnlyTriage.Metadata' -as [type])){Add-Type -Path $metadataDLL}
$metadataSHA=(Get-FileHash $metadataDLL).Hash.ToLowerInvariant()
$engineSHA=(Get-FileHash $engineDLL).Hash.ToLowerInvariant()
$layout=[WedReadOnlyTriage.Metadata]::Layout();$engineLayout=[WedOwnerWin32.Engine]::Layout()
Save 'provenance.json' @{helperSource=$helper;helperSHA=$helperSHA;engineDLL=$engineDLL;engineSHA=$engineSHA;engineMVID=[WedOwnerWin32.Engine].Module.ModuleVersionId.ToString();engineLayout=$engineLayout;metadataSourceSHA=(Get-FileHash (Join-Path $PSScriptRoot 'TokenMetadata.cs')).Hash.ToLowerInvariant();metadataDLL=$metadataDLL;metadataSHA=$metadataSHA;metadataMVID=[WedReadOnlyTriage.Metadata].Module.ModuleVersionId.ToString();layout=$layout;compileMs=$compile.ElapsedMilliseconds;compilerHardCancel='NOT_CLAIMED';powershell=$PSVersionTable.PSVersion.ToString();dotnet=[Environment]::Version.ToString()}
$pwsh=(Get-Process -Id $PID).Path;$pwshSHA=(Get-FileHash $pwsh).Hash.ToLowerInvariant()
$dockerPath=(Get-Content 'docs/evidence/ui-source-environment-readonly-20261019/backend/inventory-1/docker-version.json' -Raw|ConvertFrom-Json).executable.path
$dockerRoot=[IO.Path]::GetFullPath((Join-Path ([IO.Path]::GetDirectoryName($dockerPath)) '../..'))
if(![IO.Path]::IsPathFullyQualified($dockerRoot) -or $dockerRoot.StartsWith('\\')){throw 'LOCAL_DOCKER_INSTALL_SCOPE_REQUIRED'}
$argv=@('-NoLogo','-NoProfile','-File',(Join-Path $PSScriptRoot 'inventory.ps1'),'-Assembly',$metadataDLL,'-AssemblySHA',$metadataSHA,'-DockerRoot',$dockerRoot)
if((Get-FileHash $pwsh).Hash.ToLowerInvariant() -cne $pwshSHA -or (Get-FileHash $engineDLL).Hash.ToLowerInvariant() -cne $engineSHA -or (Get-FileHash $metadataDLL).Hash.ToLowerInvariant() -cne $metadataSHA -or ($before|ConvertTo-Json -Compress) -cne ((SourcePins)|ConvertTo-Json -Compress)){throw 'EXECUTION_PIN_CHANGED'}
$utc=[DateTimeOffset]::UtcNow
$r=[WedOwnerWin32.Engine]::Run($pwsh,[string[]]$argv,$workspace,15000,65536,'None',$null)
$ok=$r.Status -ceq 'PASS' -and $r.RootExit -eq 0 -and !$r.TerminationRequested -and !$r.Timeout -and !$r.ByteCapExceeded -and $r.CleanupClosed -and $r.FinalActive -eq 0 -and $r.PipesEOF
Save 'inventory-receipt.json' @{command=@($pwsh)+$argv;executableSHA=$pwshSHA;actualExit=$r.RootExit;nativeStatus=$r.Status;forcedTermination=$r.TerminationRequested;timedOut=$r.Timeout;byteCapExceeded=$r.ByteCapExceeded;limitMs=15000;byteCap=65536;elapsedMs=$r.ElapsedMs;stdoutBytes=$r.StdoutBytes;stderrBytes=$r.StderrBytes;jobFinalActive=$r.FinalActive;jobAfterRootRelease=$r.AfterRootRelease;rootCreationFileTime=$r.RootCreationFileTime;rootPID=$r.RootPID;treeClosed=$r.TreeClosed;pipesEOF=$r.PipesEOF;cleanupClosed=$r.CleanupClosed;liveHandles=$r.LiveHandles;liveBuffers=$r.LiveBuffers;backgroundReaders=$r.BackgroundReaders;nativePhase=$r.Phase;win32Error=$r.Win32Error;rawOutput='RAM_ONLY_NOT_PERSISTED';utc=$utc.ToString('o');vn=[TimeZoneInfo]::ConvertTimeBySystemTimeZoneId($utc,'SE Asia Standard Time').ToString('o')}
if($ok){try{$data=$r.RawOut|ConvertFrom-Json -DateKind String;Save 'inventory.json' $data}catch{$ok=$false;Save 'inventory.json' @{status='UNKNOWN_JSON_CONTRACT';message='OMITTED'}}}else{Save 'inventory.json' @{status='UNKNOWN_NATIVE_OUTCOME_FAILED';metadataNotAccepted=$true}}
Save 'frozen-after.json' (Frozen);$after=SourcePins;if(($before|ConvertTo-Json -Compress) -cne ($after|ConvertTo-Json -Compress)){throw 'TRIAGE_SOURCE_DRIFT'};Save 'source-pins-after.json' $after
Save 'status.json' @{status='INCONCLUSIVE_ACCESS_DENIED_CAUSE_SOURCE_HOLD';nativeInventoryAccepted=$ok;inventoryAttempts=1;daemonQueries=0;pipeOpenConnect=0;pythonVersionRerun=0;timePortRerun=0;processOrServiceMutation=0;tokenMutation=0;sourceCalls=0;liveKeys=0;liveApproval=0;liveClaim=0;sourceGate=$false;mainChanges=0;utc=[DateTimeOffset]::UtcNow.ToString('o')}
Write-Output 'INCONCLUSIVE_METADATA_INVENTORY_COMPLETE_SOURCE_HOLD';exit 0
