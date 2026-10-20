param([Parameter(Mandatory)][string]$Evidence)
. (Join-Path $PSScriptRoot 'common.ps1')
Initialize-Diagnostic $Evidence
$inventory='docs/evidence/ui-source-environment-readonly-20261019/backend/inventory-1'
$version=Get-Content (Join-Path $inventory 'docker-version.json') -Raw|ConvertFrom-Json
if($version.version -cne '29.8.1' -or !$script:Tools.ContainsKey('docker') -or $version.executable.sha256 -cne $script:Tools.docker.sha256){throw 'OFFICIAL_API_VERSION_OR_CLIENT_PIN_NOT_VERIFIED'}
# Gate unit vectors, no process/network calls and no remote values persisted.
$denied=0
foreach($value in @('tcp://127.0.0.1:2375','ssh://offline.invalid','npipe:////other/pipe/docker_engine','npipe:////./pipe/UNAPPROVED')){try{Assert-LocalEndpoint $value}catch{$denied++}}
$verbDenied=$false;try{Register-Query 'FORBIDDEN' docker @('run','OFFLINE_TEST_ONLY')}catch{$verbDenied=$true}
if($denied -ne 4 -or !$verbDenied){throw 'READONLY_ENDPOINT_GATE_UNIT_FAIL'}
Save-NewJSON 'gate-unit.json' @{status='PASS_OFFLINE_VECTORS';remoteOrUnknownEndpointDenied=4;mutatingVerbDenied=$true;networkCalls=0}
$progress='CONTEXT_NOT_OBSERVED';$stopCode=$null
try{
 Register-Query 'context-show' docker @('context','show')
 $r=Invoke-Query 'context-show';if(!$r.OK){throw 'CONTEXT_SHOW_FAILED'}
 $context=$r.Out.Trim();if($context -cnotin @('default','desktop-linux','desktop-windows')){throw 'CONTEXT_NAME_UNRECOGNIZED_NO_DAEMON_REQUEST'}
 Register-Query 'context-endpoint' docker @('context','inspect',$context,'--format','{{json .Endpoints.docker.Host}}')
 $r=Invoke-Query 'context-endpoint';if(!$r.OK){throw 'CONTEXT_INSPECT_FAILED'}
 $candidate=$r.Out|ConvertFrom-Json;Assert-LocalEndpoint $candidate
 $script:Endpoint=$candidate
 Save-NewJSON 'endpoint.json' @{status='OBSERVED_READONLY_LOCAL_NAMED_PIPE';context=$context;endpoint=$script:Endpoint;explicitHostEveryDaemonQuery=$true;globalEnvironmentOrContextChanged=$false}
 $progress='LOCAL_ENDPOINT_VERIFIED'
 $versionTemplate='{"client":{{json .Client.Version}},"clientAPI":{{json .Client.APIVersion}},"server":{{if .Server}}{{json .Server.Version}}{{else}}null{{end}},"serverAPI":{{if .Server}}{{json .Server.APIVersion}}{{else}}null{{end}},"serverOS":{{if .Server}}{{json .Server.Os}}{{else}}null{{end}},"serverArch":{{if .Server}}{{json .Server.Arch}}{{else}}null{{end}}}'
 Register-Query 'daemon-version' docker @('version','--format',$versionTemplate) $true
 $r=Invoke-Query 'daemon-version';if(!$r.OK){throw 'DAEMON_VERSION_FAILED_DEPENDENCIES_NOT_RUN'}
 $data=$r.Out|ConvertFrom-Json
 foreach($key in @('client','server','clientAPI','serverAPI')){if($data.$key -cnotmatch '^[0-9]+\.[0-9]+(\.[0-9]+)?([A-Za-z0-9.+-]*)$'){throw 'VERSION_FIELDS_UNRECOGNIZED'}}
 if($data.serverOS -cnotin @('linux','windows') -or $data.serverArch -cnotin @('amd64','arm64','x86_64')){throw 'SERVER_PLATFORM_UNRECOGNIZED'}
 Save-NewJSON 'daemon-version.json' @{status='OBSERVED_READONLY';fields=$data;runtimeSourceProof='NOT_RUN'}
 $progress='DAEMON_VERSION_OBSERVED'
 $infoTemplate='{"serverVersion":{{json .ServerVersion}},"os":{{json .OSType}},"architecture":{{json .Architecture}},"kernel":{{json .KernelVersion}},"operatingSystem":{{json .OperatingSystem}},"cpus":{{json .NCPU}},"memoryBytes":{{json .MemTotal}},"cgroupVersion":{{json .CgroupVersion}},"cgroupDriver":{{json .CgroupDriver}},"securityOptions":{{json .SecurityOptions}}}'
 Register-Query 'daemon-info' docker @('info','--format',$infoTemplate) $true
 $r=Invoke-Query 'daemon-info';if(!$r.OK){throw 'DAEMON_INFO_FAILED_DEPENDENCIES_NOT_RUN'}
 $data=$r.Out|ConvertFrom-Json
 foreach($key in @('serverVersion','os','architecture','kernel','operatingSystem','cgroupVersion','cgroupDriver')){if([string]$data.$key -cnotmatch '^[A-Za-z0-9._+ ()-]{0,128}$'){throw 'INFO_FIELDS_UNRECOGNIZED'}}
 $safe=@{};foreach($key in @('serverVersion','os','architecture','kernel','operatingSystem','cgroupVersion','cgroupDriver')){$safe[$key]=$data.$key}
 if($data.cpus -isnot [int] -or $data.memoryBytes -isnot [long] -and $data.memoryBytes -isnot [int]){throw 'INFO_NUMERIC_FIELDS_UNRECOGNIZED'}
 $safe.cpus=$data.cpus;$safe.memoryBytes=$data.memoryBytes
 $safe.seccompAdvertised=@($data.securityOptions|Where-Object{$_ -match '^name=seccomp(,|$)'}).Count -gt 0
 $safe.cgroupnsAdvertised=@($data.securityOptions|Where-Object{$_ -ceq 'name=cgroupns'}).Count -gt 0
 Save-NewJSON 'daemon-info.json' @{status='OBSERVED_READONLY_METADATA';fields=$safe;roleIsolation='NOT_RUN_NOT_INFERRED_FROM_ENGINE_CAPABILITIES'}
 $progress='DAEMON_INFO_OBSERVED'
 $hostPlan=Get-Content (Join-Path $inventory 'host-plan-path-port.json') -Raw|ConvertFrom-Json
 if($hostPlan.status -cne 'OBSERVED_READONLY'){throw 'PLANNED_IMAGES_NOT_AVAILABLE'}
 $imageTemplate='{"id":{{json .Id}},"os":{{json .Os}},"architecture":{{json .Architecture}},"sizeBytes":{{json .Size}}}'
 $i=0
 foreach($id in @($hostPlan.plan.images.image|Sort-Object -Unique)){
  if($id -cnotmatch '^sha256:[a-f0-9]{64}$'){throw 'PLANNED_IMAGE_ID_INVALID'}
  $i++;$name='cache-image-'+$i
  Register-Query $name docker @('image','inspect',$id,'--format',$imageTemplate) $true
  $r=Invoke-Query $name;if(!$r.OK){throw 'PLANNED_IMAGE_QUERY_FAILED_NO_RETRY'}
  $data=$r.Out|ConvertFrom-Json
  if($data.id -cne $id -or $data.os -cnotin @('linux','windows') -or $data.architecture -cnotin @('amd64','arm64','x86_64') -or $data.sizeBytes -isnot [long] -and $data.sizeBytes -isnot [int]){throw 'IMAGE_FIELDS_UNRECOGNIZED'}
  Save-NewJSON ($name+'.json') @{status='OBSERVED_READONLY_CACHE_METADATA';roles=@($hostPlan.plan.images|Where-Object image -CEQ $id|ForEach-Object role);fields=$data;node22Imports='NOT_RUN';dependenciesRuntime='NOT_RUN';mountMapping='NOT_RUN'}
 }
 $progress='FOUR_PLANNED_CACHE_IMAGES_OBSERVED'
 $psTemplate='{"id":{{json .ID}},"name":{{json .Names}},"state":{{json .State}},"run":{{json (.Label "com.wed-snap.run")}}}'
 Register-Query 'scoped-containers' docker @('ps','--all','--no-trunc','--filter','label=com.wed-snap.run','--filter','name=wed-source-','--format',$psTemplate) $true
 $r=Invoke-Query 'scoped-containers';if(!$r.OK){throw 'SCOPED_CONTAINER_QUERY_FAILED'}
 $containers=@(foreach($line in @($r.Out -split '\r?\n'|Where-Object{$_})){ $row=$line|ConvertFrom-Json;if($row.id -cnotmatch '^[a-f0-9]{64}$' -or $row.name -cnotmatch '^wed-source-[a-f0-9]{32}-[a-z-]+$' -or $row.run -cnotmatch '^[a-f0-9]{32}$' -or $row.state -cnotin @('created','restarting','running','removing','paused','exited','dead')){throw 'SCOPED_CONTAINER_FIELDS_UNRECOGNIZED'};$row })
 Save-NewJSON 'scoped-containers.json' @{status='OBSERVED_READONLY_SCOPED_SNAPSHOT';rows=$containers;count=$containers.Count;filterLabel='com.wed-snap.run';filterName='wed-source-';cleanup='NOT_PERFORMED_NO_RESOURCE_AUTHORITY';globalAbsence='NOT_CLAIMED'}
 $networkTemplate='{"id":{{json .ID}},"name":{{json .Name}},"driver":{{json .Driver}},"scope":{{json .Scope}}}'
 Register-Query 'scoped-networks' docker @('network','ls','--no-trunc','--filter','label=com.wed-snap.run','--filter','name=wed-source-','--format',$networkTemplate) $true
 $r=Invoke-Query 'scoped-networks';if(!$r.OK){throw 'SCOPED_NETWORK_QUERY_FAILED'}
 $networks=@(foreach($line in @($r.Out -split '\r?\n'|Where-Object{$_})){ $row=$line|ConvertFrom-Json;if($row.id -cnotmatch '^[a-f0-9]{64}$' -or $row.name -cnotmatch '^wed-source-[a-f0-9]{32}-[a-z-]+$' -or $row.driver -cnotin @('bridge','host','null','overlay','macvlan','ipvlan','nat') -or $row.scope -cnotin @('local','swarm','global')){throw 'SCOPED_NETWORK_FIELDS_UNRECOGNIZED'};$row })
 Save-NewJSON 'scoped-networks.json' @{status='OBSERVED_READONLY_SCOPED_SNAPSHOT';rows=$networks;count=$networks.Count;filterLabel='com.wed-snap.run';filterName='wed-source-';cleanup='NOT_PERFORMED_NO_RESOURCE_AUTHORITY';globalAbsence='NOT_CLAIMED'}
 $progress='READONLY_QUERIES_COMPLETE'
}catch{
 # Only our fixed codes reach disk, never parser/CLI exception messages.
 $known=@('CONTEXT_SHOW_FAILED','CONTEXT_NAME_UNRECOGNIZED_NO_DAEMON_REQUEST','CONTEXT_INSPECT_FAILED','NONLOCAL_OR_UNKNOWN_ENDPOINT_REFUSED','DAEMON_VERSION_FAILED_DEPENDENCIES_NOT_RUN','VERSION_FIELDS_UNRECOGNIZED','SERVER_PLATFORM_UNRECOGNIZED','DAEMON_INFO_FAILED_DEPENDENCIES_NOT_RUN','INFO_FIELDS_UNRECOGNIZED','INFO_NUMERIC_FIELDS_UNRECOGNIZED','PLANNED_IMAGES_NOT_AVAILABLE','PLANNED_IMAGE_ID_INVALID','PLANNED_IMAGE_QUERY_FAILED_NO_RETRY','IMAGE_FIELDS_UNRECOGNIZED','SCOPED_CONTAINER_QUERY_FAILED','SCOPED_CONTAINER_FIELDS_UNRECOGNIZED','SCOPED_NETWORK_QUERY_FAILED','SCOPED_NETWORK_FIELDS_UNRECOGNIZED','DAEMON_OVERRIDE_NOT_CLEARED_OR_GUESSED','DOCKER_OVERRIDE_CHANGED')
 $stopCode=if($_.Exception.Message -cin $known){$_.Exception.Message}else{'UNCLASSIFIED_DIAGNOSTIC_FAILURE_NO_MESSAGE'}
}
Save-NewJSON 'readiness.json' @{status=$(if($stopCode){'STOPPED_READONLY_OBSERVATION'}else{'READONLY_METADATA_COMPLETE_RUNTIME_STILL_HOLD'});lastObservedStage=$progress;stopCode=$stopCode;endpointLocal=!!$script:Endpoint;sourceGate=$false;node22Imports='NOT_RUN';runtimePublicSchema='NOT_RUN';containerCgroupIsolation='NOT_RUN';bindMapping='NOT_RUN';egressTLSPhaseClosure='NOT_RUN';browserSource='NOT_RUN'}
Finish-Diagnostic $(if($stopCode){'READONLY_STOP_SOURCE_HOLD'}else{'READONLY_COMPLETE_SOURCE_HOLD'})
Write-Output $(if($stopCode){'READONLY_STOP_SOURCE_HOLD'}else{'READONLY_COMPLETE_SOURCE_HOLD'})
if($stopCode){exit 20};exit 0
