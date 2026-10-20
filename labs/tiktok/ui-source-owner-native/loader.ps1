# Source pin is replaced only when this task changes the reviewed helper source.
$script:NativeHelperSHA='5ed79b96326b56535077c6a97b7b0b30fee1031379f74dc845cfc6fcebbf7f19'
$script:NativeEngine=$null
$script:NativeContexts=[Runtime.CompilerServices.ConditionalWeakTable[object,object]]::new()
$script:NativeResults=[Runtime.CompilerServices.ConditionalWeakTable[object,object]]::new()
$script:NativeRecords=[Runtime.CompilerServices.ConditionalWeakTable[object,object]]::new()
$script:NativeImportPins=@(foreach($n in @('Owner.psm1','trust.ps1','loader.ps1','native.ps1','runtime.ps1','mounts.ps1','Win32Adapter.cs')){$p=Join-Path $PSScriptRoot $n;@{path=$p;sha=(Get-FileHash -LiteralPath $p).Hash.ToLowerInvariant()}})
function Register-NativeContext($Context){
 $pins=@{}
 if($Context.Mode -ceq 'OFFLINE_TEST_ONLY'){
  $paths=@{node=@(Get-Command node -CommandType Application -ErrorAction Stop)[0].Source;python='C:/Users/LENOVO/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe';pwsh=(Get-Process -Id $PID).Path}
  foreach($key in $paths.Keys){$path=[IO.Path]::GetFullPath($paths[$key]);$pins[$path]=@{sha=(Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant();role=$key}}
 }elseif($Context.Mode -cin @('UI_SINGLE_PHOTO_SOURCE','MANAGED_ADAPTER_TEST')){
  foreach($key in $Context.Tools.Keys){$p=$Context.Tools[$key];$pins[[IO.Path]::GetFullPath($p.path)]=@{sha=$p.sha256;role=$key}}
 }else{throw 'NATIVE_CONTEXT_MODE'}
 $evidenceRef=if($Context.Mode -ceq 'UI_SINGLE_PHOTO_SOURCE'){$Context.Payload.evidenceRef}else{$null}
 $state=[pscustomobject]@{Mode=$Context.Mode;Seal=$Context.Seal;Root=$Context.Root;SourceEvidenceRef=$evidenceRef;Cwd=(Get-Location).Path;Tools=$pins;Children=$Context.NativeChildren;Receipts=$Context.NativeReceipts;Records=[Collections.Generic.List[object]]::new();Fault='None';Ready=$null}
 $script:NativeContexts.Add($Context,$state);return $Context
}
function Get-NativeContext($Context){
 $state=$null
 if(!$script:NativeContexts.TryGetValue($Context,[ref]$state) -or $state.Mode -cne $Context.Mode -or ![object]::ReferenceEquals($state.Seal,$Context.Seal) -or ![object]::ReferenceEquals($state.Children,$Context.NativeChildren) -or ![object]::ReferenceEquals($state.Receipts,$Context.NativeReceipts)){throw 'REGISTERED_NATIVE_CONTEXT_REQUIRED'}
 if($state.PSObject.Properties['Bridge']){Assert-BridgeState $Context $state}
 return $state
}
function Assert-NativeImportPins {
 foreach($p in $script:NativeImportPins){if((Get-FileHash -LiteralPath $p.path).Hash.ToLowerInvariant() -cne $p.sha){throw 'LOADED_OWNER_CODE_DRIFT'}}
 $path=Join-Path $PSScriptRoot 'Win32Adapter.cs';if((Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant() -cne $script:NativeHelperSHA){throw 'HELPER_SOURCE_PIN'}
}
function Get-NativeEngine($Context){
 $state=Get-NativeContext $Context;Assert-NativeImportPins
 if($state.PSObject.Properties['Bridge']){return Get-BridgeEngine $Context $state}
 if($script:NativeEngine){
  $e=$script:NativeEngine
  $checked=Resolve-WorkspaceFile ([IO.Path]::GetRelativePath((Get-Location).Path,$e.Path))
  if($checked -cne $e.Path -or (Get-FileHash -LiteralPath $e.Path).Hash.ToLowerInvariant() -cne $e.SHA -or ![object]::ReferenceEquals($e.Type.Assembly,$e.Assembly) -or $e.Type.Module.ModuleVersionId -ne $e.MVID){throw 'HELPER_LOADED_PROVENANCE'}
  return $e
 }
 if('WedOwnerWin32.Engine' -as [type]){throw 'UNOWNED_PRELOADED_HELPER_TYPE'}
 $root=if($state.Mode -ceq 'OFFLINE_TEST_ONLY'){$state.Root}else{Resolve-WorkspaceFile $state.SourceEvidenceRef}
 $relative=[IO.Path]::GetRelativePath((Get-Location).Path,(Join-Path $root 'owner-private'))
 $private=Resolve-WorkspaceFile $relative
 if(!(Test-Path -LiteralPath $private)){New-Item -ItemType Directory -Path $private -ErrorAction Stop|Out-Null}
 $cache=Join-Path $private ('native-helper-'+$PID);if(Test-Path -LiteralPath $cache){throw 'UNOWNED_HELPER_CACHE_REUSE'}
 New-Item -ItemType Directory -Path $cache -ErrorAction Stop|Out-Null
 $dll=Join-Path $cache 'OwnerWin32.dll';$timer=[Diagnostics.Stopwatch]::StartNew()
 Add-Type -Path (Join-Path $PSScriptRoot 'Win32Adapter.cs') -OutputAssembly $dll -ErrorAction Stop
 if(!('WedOwnerWin32.Engine' -as [type])){Add-Type -Path $dll -ErrorAction Stop}
 $type='WedOwnerWin32.Engine' -as [type];$sha=(Get-FileHash -LiteralPath $dll).Hash.ToLowerInvariant()
 if(!$type -or [IO.Path]::GetFullPath($type.Assembly.Location) -cne [IO.Path]::GetFullPath($dll)){throw 'HELPER_ASSEMBLY_LOCATION'}
 $layout=$type::Layout()
 $script:NativeEngine=[pscustomobject]@{Type=$type;Path=$dll;SHA=$sha;Assembly=$type.Assembly;MVID=$type.Module.ModuleVersionId;SourceSHA=$script:NativeHelperSHA}
 $proof=@{status='TOOLCHAIN_LAYOUT_VERIFIED_NOT_EXECUTION_PROOF';sourceSHA=$script:NativeHelperSHA;binarySHA=$sha;binaryPath=$dll;MVID=$script:NativeEngine.MVID.ToString();elapsedMs=$timer.ElapsedMilliseconds;layout=$layout;utc=[DateTimeOffset]::UtcNow.ToString('o')}
 Write-ExclusiveJSON (Join-Path $cache 'provenance.json') $proof
 return $script:NativeEngine
}
function Initialize-OfflineNativeAdapter($Context){
 Assert-ExecutionContext $Context
 if($Context.Mode -cne 'OFFLINE_TEST_ONLY'){throw 'OFFLINE_INITIALIZER_ONLY'}
 $e=Get-NativeEngine $Context
 [pscustomobject]@{status='TOOLCHAIN_ONLY_NOT_PROCESS_SUCCESS';sourceSHA=$e.SourceSHA;binarySHA=$e.SHA}
}
function Get-NativeResultProof($Result){
 $proof=$null;if(!$script:NativeResults.TryGetValue($Result,[ref]$proof)){throw 'UNREGISTERED_NATIVE_RESULT'}
 if(![object]::ReferenceEquals($Result.Receipt,$proof.Receipt) -or ($Result.Receipt|ConvertTo-Json -Depth 14 -Compress) -cne $proof.Serialized -or $Result.RawOut -cne $proof.RawOut -or $Result.RawErr -cne $proof.RawErr){throw 'NATIVE_RESULT_MUTATED'}
 $record=$null;if(!$script:NativeRecords.TryGetValue($proof.Record,[ref]$record) -or ($proof.Record|ConvertTo-Json -Compress) -cne $record.Serialized){throw 'NATIVE_RECORD_MUTATED'}
 return $proof
}
function Test-NativeContextClosed($Context){
 $state=Get-NativeContext $Context;$ok=$true
 if($state.Records.Count -ne $state.Children.Count){$ok=$false}
 foreach($record in $state.Children){$proof=$null;if(!$script:NativeRecords.TryGetValue($record,[ref]$proof) -or ![object]::ReferenceEquals($proof.Context,$Context) -or !$proof.Closed -or ($record|ConvertTo-Json -Compress) -cne $proof.Serialized){$ok=$false}}
 foreach($record in $state.Records){$proof=$null;if(!$script:NativeRecords.TryGetValue($record,[ref]$proof) -or !$proof.Closed -or ($record|ConvertTo-Json -Compress) -cne $proof.Serialized){$ok=$false}}
 return $ok
}
