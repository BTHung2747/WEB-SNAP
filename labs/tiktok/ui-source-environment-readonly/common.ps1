$ErrorActionPreference='Stop'
$script:HelperSHA='5ed79b96326b56535077c6a97b7b0b30fee1031379f74dc845cfc6fcebbf7f19'
$script:OwnerManifestSHA='95d0baad0de5ed95d29fb0bd5c49a6659fed18de5a584c03297f25190dd6dd07'
function Save-NewJSON([string]$Name,$Value){
 $f=[IO.FileStream]::new((Join-Path $script:Evidence $Name),[IO.FileMode]::CreateNew)
 try{$bytes=[Text.Encoding]::UTF8.GetBytes(($Value|ConvertTo-Json -Depth 30));$f.Write($bytes,0,$bytes.Length);$f.Flush($true)}finally{$f.Dispose()}
}
function Initialize-Diagnostic([string]$Root){
 $script:Evidence=[IO.Path]::GetFullPath($Root);$workspace=(Get-Location).Path
 if(!$script:Evidence.StartsWith((Join-Path $workspace 'docs/evidence/ui-source-environment-readonly-20261019/backend')+[IO.Path]::DirectorySeparatorChar) -or (Test-Path $script:Evidence)){throw 'FRESH_SCOPED_EVIDENCE_REQUIRED'}
 New-Item -ItemType Directory -Path $script:Evidence|Out-Null
 $manifest='docs/evidence/ui-source-direct-win32-integration-20261017/backend/manifest.json'
 if((Get-FileHash $manifest).Hash.ToLowerInvariant() -cne $script:OwnerManifestSHA){throw 'REVIEWED_OWNER_MANIFEST_PIN'}
 $script:OwnerPins=@((Get-Content $manifest -Raw|ConvertFrom-Json).implementation)
 Assert-OwnerPins;Save-NewJSON 'owner-pins-before.json' $script:OwnerPins
 $script:HelperPath=(Resolve-Path 'labs/tiktok/ui-source-owner-native/Win32Adapter.cs').Path
 if((Get-FileHash $script:HelperPath).Hash.ToLowerInvariant() -cne $script:HelperSHA -or !(Select-String -LiteralPath 'labs/tiktok/ui-source-owner-native/loader.ps1' -SimpleMatch "NativeHelperSHA='$script:HelperSHA'" -Quiet)){throw 'HELPER_SOURCE_PIN'}
 if('WedOwnerWin32.Engine' -as [type]){throw 'UNOWNED_PRELOADED_TYPE'}
 $cache=Join-Path $script:Evidence ('helper-'+$PID);New-Item -ItemType Directory -Path $cache|Out-Null
 $script:AssemblyPath=Join-Path $cache 'ReadonlyDiagnostics.dll'
 $compile=[Diagnostics.Stopwatch]::StartNew();Add-Type -Path $script:HelperPath -OutputAssembly $script:AssemblyPath
 if(!('WedOwnerWin32.Engine' -as [type])){Add-Type -Path $script:AssemblyPath}
 $script:Engine='WedOwnerWin32.Engine' -as [type];$script:AssemblySHA=(Get-FileHash $script:AssemblyPath).Hash.ToLowerInvariant();$script:Assembly=$script:Engine.Assembly;$script:MVID=$script:Engine.Module.ModuleVersionId
 if([IO.Path]::GetFullPath($script:Assembly.Location) -cne $script:AssemblyPath){throw 'HELPER_ASSEMBLY_LOCATION'}
 Save-NewJSON 'helper-provenance.json' @{sourceSHA=$script:HelperSHA;source=$script:HelperPath;binarySHA=$script:AssemblySHA;binary=$script:AssemblyPath;MVID=$script:MVID.ToString();layout=$script:Engine::Layout();compileMs=$compile.ElapsedMilliseconds;compileWatchdog='NOT_UNIVERSAL_HARD_CANCEL';powershell=$PSVersionTable.PSVersion.ToString();dotnet=[Environment]::Version.ToString();scope='DIAGNOSTIC_ONLY_NO_OWNER_MODULE_IMPORT_OR_SOURCE_CONTEXT'}
 $script:Tools=@{}
 $foundDocker=@(Get-Command docker -CommandType Application -ErrorAction SilentlyContinue)
 $paths=@{pwsh=(Get-Process -Id $PID).Path;node=@(Get-Command node -CommandType Application)[0].Source;python='C:/Users/LENOVO/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe';w32tm=(Join-Path $env:SystemRoot 'System32/w32tm.exe')}
 if($foundDocker.Count){$paths.docker=$foundDocker[0].Source}
 foreach($name in $paths.Keys){$path=[IO.Path]::GetFullPath($paths[$name]);if(!(Test-Path -LiteralPath $path -PathType Leaf)){continue};$script:Tools[$name]=@{path=$path;sha256=(Get-FileHash $path).Hash.ToLowerInvariant();fileVersion=(Get-Item $path).VersionInfo.FileVersion}}
 Save-NewJSON 'tools.json' $script:Tools
 $script:Commands=[Collections.Generic.List[object]]::new();$script:Specs=@{};$script:Endpoint=$null
 $script:EnvironmentSnapshot=Get-DockerOverrideState
 Save-NewJSON 'docker-override-presence.json' $script:EnvironmentSnapshot.Presence
}
function Assert-OwnerPins {foreach($pin in $script:OwnerPins){if((Get-FileHash $pin.path).Hash.ToLowerInvariant() -cne $pin.sha256){throw 'OWNER_SOURCE_DRIFT'}}}
function Get-DockerOverrideState {
 $values=@{};$presence=@{}
 foreach($name in @('DOCKER_HOST','DOCKER_CONTEXT','DOCKER_CONFIG','DOCKER_TLS_VERIFY','DOCKER_CERT_PATH','DOCKER_CUSTOM_HEADERS','DOCKER_API_VERSION','DOCKER_DEFAULT_PLATFORM')){$v=[Environment]::GetEnvironmentVariable($name);$values[$name]=$v;$presence[$name]=![string]::IsNullOrEmpty($v)}
 [pscustomobject]@{Values=$values;Presence=$presence}
}
function Assert-LocalEndpoint([string]$Value){
 if($Value -cnotmatch '^npipe:////\./pipe/(docker_engine|dockerDesktopLinuxEngine|dockerDesktopWindowsEngine)$'){throw 'NONLOCAL_OR_UNKNOWN_ENDPOINT_REFUSED'}
}
function Register-Query([string]$Name,[string]$Tool,[string[]]$Argv,[bool]$Daemon=$false){
 if($script:Specs.ContainsKey($Name)){throw 'DUPLICATE_QUERY_SPEC'}
 if($Tool -ceq 'docker'){
  # Fixed task verbs only; subcommands are supplied by this diagnostic script.
  $ok=($Argv[0] -cin @('--version','version','info','ps')) -or ($Argv.Count -ge 2 -and (($Argv[0] -ceq 'context' -and $Argv[1] -cin @('show','inspect')) -or ($Argv[0] -ceq 'image' -and $Argv[1] -ceq 'inspect') -or ($Argv[0] -ceq 'network' -and $Argv[1] -cin @('ls','inspect'))))
  if(!$ok){throw 'NON_READONLY_DOCKER_VERB'}
  if(!$Daemon -and !($Argv[0] -ceq '--version' -or $Argv[0] -ceq 'context')){throw 'DAEMON_QUERY_REQUIRES_ENDPOINT'}
 }
 $script:Specs[$Name]=[pscustomobject]@{Tool=$Tool;Argv=$Argv.Clone();Daemon=$Daemon}
}
function Invoke-Query([string]$Name){
 if(@($script:Commands|Where-Object name -CEQ $Name).Count){throw 'QUERY_ALREADY_ATTEMPTED_NO_RETRY'}
 $spec=$script:Specs[$Name];if(!$spec -or !$script:Tools.ContainsKey($spec.Tool)){throw 'PINNED_QUERY_TOOL_REQUIRED'}
 Assert-OwnerPins
 foreach($pair in @(@($script:HelperPath,$script:HelperSHA),@($script:AssemblyPath,$script:AssemblySHA),@($script:Tools[$spec.Tool].path,$script:Tools[$spec.Tool].sha256))){if((Get-FileHash $pair[0]).Hash.ToLowerInvariant() -cne $pair[1]){throw 'EXECUTION_PIN_CHANGED'}}
 if(![object]::ReferenceEquals($script:Engine.Assembly,$script:Assembly) -or $script:Engine.Module.ModuleVersionId -ne $script:MVID){throw 'ASSEMBLY_IDENTITY_CHANGED'}
 $argv=$spec.Argv
 if($spec.Daemon){
  Assert-LocalEndpoint $script:Endpoint
  $now=Get-DockerOverrideState
  foreach($key in $now.Values.Keys){if($now.Values[$key] -cne $script:EnvironmentSnapshot.Values[$key]){throw 'DOCKER_OVERRIDE_CHANGED'}}
  # Do not override a conflicting environment or depend on context precedence.
  foreach($key in @('DOCKER_CONTEXT','DOCKER_HOST','DOCKER_TLS_VERIFY','DOCKER_CERT_PATH','DOCKER_CUSTOM_HEADERS')){if($now.Presence[$key]){throw 'DAEMON_OVERRIDE_NOT_CLEARED_OR_GUESSED'}}
  $argv=@('--host',$script:Endpoint)+$argv
 }
 $start=[DateTimeOffset]::UtcNow
 $result=$script:Engine::Run($script:Tools[$spec.Tool].path,[string[]]$argv,(Get-Location).Path,15000,65536,'None',$null)
 $phase=if($result.Phase -cin @('CREATE_PROCESS','ATTRIBUTE_JOB_LIST','QUERY_ACTIVE','PEEK_PIPE','READ_AVAILABLE','MANAGED_GUARD')){$result.Phase}elseif($result.Phase){'OTHER_NATIVE_FAILURE'}else{$null}
 $errorCode=if($result.RawErr -match '(?i)access is denied|permission denied|access denied'){'ACCESS_DENIED'}elseif($result.RawErr -match '(?i)cannot find the file|cannot connect|is the docker daemon running|connection refused'){'ENDPOINT_UNAVAILABLE'}elseif($result.RawErr -match '0x80070426'){'TIME_SERVICE_NOT_RUNNING'}elseif($result.StderrBytes -gt 0){'STDERR_PRESENT_MESSAGE_OMITTED'}else{$null}
 $receipt=@{name=$Name;tool=$spec.Tool;argv=$argv;daemonQuery=$spec.Daemon;actualExit=$result.RootExit;nativeStatus=$result.Status;created=$result.Created;elapsedMs=$result.ElapsedMs;limitMs=15000;byteCap=65536;stdoutBytes=$result.StdoutBytes;stderrBytes=$result.StderrBytes;retainedBytes=$result.RetainedBytes;timedOut=$result.Timeout;byteCapExceeded=$result.ByteCapExceeded;forcedTermination=$result.TerminationRequested;rootInOwnJob=$result.RootInOwnJob;jobFinalActive=$result.FinalActive;treeClosed=$result.TreeClosed;pipesEOF=$result.PipesEOF;cleanupClosed=$result.CleanupClosed;liveHandles=$result.LiveHandles;liveBuffers=$result.LiveBuffers;backgroundReaders=$result.BackgroundReaders;phase=$phase;win32Error=$result.Win32Error;stderrCode=$errorCode;rawOutput='RAM_ONLY_NOT_PERSISTED';utc=$start.ToString('o');vn=[TimeZoneInfo]::ConvertTimeBySystemTimeZoneId($start,'SE Asia Standard Time').ToString('o')}
 $script:Commands.Add($receipt);Save-NewJSON ($Name+'-receipt.json') $receipt
 [pscustomobject]@{OK=($result.Status -ceq 'PASS' -and $result.CleanupClosed -and $result.RootExit -eq 0 -and $result.FinalActive -eq 0 -and $result.PipesEOF);Out=$result.RawOut;Err=$result.RawErr;Receipt=$receipt}
}
function Finish-Diagnostic($Status){
 Assert-OwnerPins;Save-NewJSON 'owner-pins-after.json' $script:OwnerPins
 Save-NewJSON 'commands.json' $script:Commands.ToArray()
 Save-NewJSON 'status.json' @{status=$Status;queryCount=$script:Commands.Count;sourceGate=$false;sourceCalls=0;resourceMutations=0;liveKeys=0;liveApprovals=0;liveClaims=0;ownership=$script:Engine::Ownership();utc=[DateTimeOffset]::UtcNow.ToString('o')}
}
