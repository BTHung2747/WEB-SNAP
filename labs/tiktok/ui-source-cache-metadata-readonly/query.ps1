param([Parameter(Mandatory)][ValidateSet('info','image-app-gateway','image-proxy','image-postgres','image-redis','containers','networks')][string]$Query,[Parameter(Mandatory)][ValidatePattern('^[a-f0-9]{64}$')][string]$PreparedSHA)
. (Join-Path $PSScriptRoot 'common.ps1')
if((Get-FileHash (Join-Path $script:Root 'prepared.json')).Hash.ToLowerInvariant() -cne $PreparedSHA){throw 'APPROVED_PLAN_HASH_MISMATCH'}
$p=Get-Content (Join-Path $script:Root 'prepared.json') -Raw|ConvertFrom-Json
if($p.endpoint -cne $script:Endpoint -or $p.dockerSHA -cne $script:DockerSHA -or $p.helperSourceSHA -cne $script:HelperSHA -or $p.sourceGate -ne $false -or $p.queryLimit -ne 7 -or $p.watchdogMs -ne 15000 -or $p.combinedByteCap -ne 65536){throw 'EXACT_READONLY_PLAN_REQUIRED'}
if(Test-Path (Join-Path $script:Root 'STOP.json')){throw 'STOPPED_NO_FURTHER_QUERY'}
foreach($pin in @($p.sourcePins)+@($p.planSource)+@(@{path=$p.docker;sha256=$script:DockerSHA},@{path=$p.helperSource;sha256=$script:HelperSHA},@{path=$p.binary;sha256=$p.binarySHA})){if((Get-FileHash $pin.path).Hash.ToLowerInvariant() -cne $pin.sha256){throw 'QUERY_PIN_DRIFT'}}
$safeSpecs=@(New-Specs $p.roles)
if(($safeSpecs|ConvertTo-Json -Depth 8 -Compress) -cne ($p.specs|ConvertTo-Json -Depth 8 -Compress)){throw 'READONLY_SPEC_DRIFT'}
$spec=@($safeSpecs|Where-Object key -CEQ $Query)[0];$order=@($safeSpecs.key);$index=[Array]::IndexOf($order,$Query)
foreach($prior in @($order|Select-Object -First $index)){$previous=Get-Content (Join-Path $script:Root ($prior+'/result.json')) -Raw|ConvertFrom-Json;if($previous.operationStatus -cne 'OBSERVED_READONLY'){throw 'PRIOR_OPERATION_NOT_SUCCESSFUL'}}
$dir=Join-Path $script:Root $Query;if(Test-Path $dir){throw 'NO_RETRY_QUERY_NAMESPACE'}
New-Item -ItemType Directory -Path $dir|Out-Null
Write-New (Join-Path $dir 'attempt.json') @{query=$Query;scope='ONE_EXPLICITLY_APPROVED_READONLY_EXEC_REQUEST';utc=[DateTimeOffset]::UtcNow.ToString('o')}
$accepted=$false;$code=$null
try{
 $flags=Assert-EmptyOverrides
 if('WedOwnerWin32.Engine' -as [type]){throw 'UNOWNED_PRELOADED_TYPE'}
 Add-Type -Path $p.binary;$type='WedOwnerWin32.Engine' -as [type]
 if($type.Assembly.Location -cne $p.binary -or $type.Module.ModuleVersionId.ToString() -cne $p.MVID){throw 'BINARY_PROVENANCE'}
 $null=$type::Layout();$utc=[DateTimeOffset]::UtcNow
 $argv=@('--host',$script:Endpoint)+@($spec.argv)
 $r=$type::Run($p.docker,[string[]]$argv,(Get-Location).Path,15000,65536,'None',$null)
 $nativeOK=Test-NativeOperation $r
 $err=if($r.RawErr -match '(?i)access is denied|permission denied'){'ACCESS_DENIED'}elseif($r.RawErr -match '(?i)no such image|not found'){'NOT_FOUND'}elseif($r.StderrBytes){'STDERR_PRESENT_MESSAGE_OMITTED'}else{$null}
 Write-New (Join-Path $dir 'receipt.json') @{query=$Query;argv=@($p.docker)+$argv;actualExit=$r.RootExit;nativeStatus=$r.Status;nativeAccepted=$nativeOK;rootCreated=$r.Created;rootInOwnJob=$r.RootInOwnJob;forcedTermination=$r.TerminationRequested;timedOut=$r.Timeout;byteCapExceeded=$r.ByteCapExceeded;limitMs=15000;byteCap=65536;elapsedMs=$r.ElapsedMs;stdoutBytes=$r.StdoutBytes;stderrBytes=$r.StderrBytes;retainedBytes=$r.RetainedBytes;jobAfterRootRelease=$r.AfterRootRelease;jobFinalActive=$r.FinalActive;treeClosed=$r.TreeClosed;pipesEOF=$r.PipesEOF;cleanupClosed=$r.CleanupClosed;liveHandles=$r.LiveHandles;liveBuffers=$r.LiveBuffers;backgroundReaders=$r.BackgroundReaders;nativePhase=$r.Phase;win32Error=$r.Win32Error;stderrCode=$err;rawOutput='BOUNDED_RAM_ONLY_NOT_PERSISTED';executableSHA=$script:DockerSHA;helperSHA=$script:HelperSHA;binarySHA=$p.binarySHA;MVID=$p.MVID;overridePresence=$flags;utc=$utc.ToString('o');vn=[TimeZoneInfo]::ConvertTimeBySystemTimeZoneId($utc,'SE Asia Standard Time').ToString('o')}
 if(!$nativeOK){throw 'NATIVE_OPERATION_FAILED'}
 $projection=Read-Projection $spec $r.RawOut
 Write-New (Join-Path $dir 'projection.json') $projection
 $accepted=$true
}catch{
 $known=@('DOCKER_OVERRIDE_PRESENT_NO_CLEAR_OR_FALLBACK','UNOWNED_PRELOADED_TYPE','BINARY_PROVENANCE','NATIVE_OPERATION_FAILED','PROJECTION_KEYS','CONTAINER_SCOPE_FIELDS','CONTAINER_STATE_LABEL','NETWORK_SCOPE_FIELDS','IMAGE_ID_PLATFORM_SIZE','INFO_IDENTITY_NUMERIC_FIELDS','INFO_TEXT_FIELDS')
 $code=if($_.Exception.Message -cin $known){$_.Exception.Message}else{'READONLY_QUERY_ERROR_NO_MESSAGE'}
 Write-New (Join-Path $script:Root 'STOP.json') @{query=$Query;code=$code;retry=$false;remaining='NOT_RUN'}
}
Write-New (Join-Path $dir 'result.json') @{operationStatus=$(if($accepted){'OBSERVED_READONLY'}else{'FAIL_OR_UNKNOWN_STOPPED'});query=$Query;code=$code;sourceGate=$false;runtimeAcceptance='NOT_RUN';utc=[DateTimeOffset]::UtcNow.ToString('o')}
Write-Output $(if($accepted){'OBSERVED_READONLY_'+$Query}else{'READONLY_STOP_'+$Query})
if(!$accepted){exit 20};exit 0
