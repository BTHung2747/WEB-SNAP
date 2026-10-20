param([Parameter(Mandatory)][string]$Assembly,[Parameter(Mandatory)][string]$AssemblySHA,[Parameter(Mandatory)][string]$DockerRoot)
$ErrorActionPreference='Stop'
try{
 if((Get-FileHash -LiteralPath $Assembly).Hash.ToLowerInvariant() -cne $AssemblySHA){throw 'ASSEMBLY_PIN'}
 Add-Type -Path $Assembly
 $snapshot=[WedReadOnlyTriage.Metadata]::Capture($DockerRoot)
 $service=@{name='com.docker.service';existence='UNKNOWN';status='UNKNOWN';errorCode=$null;processID='NOT_EXPOSED_BY_THIS_API'}
 $controller=$null
 try{$controller=Get-Service -Name 'com.docker.service' -ErrorAction Stop;$service.existence='OBSERVED';$state=$controller.Status.ToString();if($state -cin @('Running','Stopped','StartPending','StopPending','ContinuePending','PausePending','Paused')){$service.status=$state}}
 catch{if($_.FullyQualifiedErrorId -like 'NoServiceFoundForGivenName*'){$service.existence='NOT_FOUND_IN_SCOPED_QUERY';$service.errorCode='SERVICE_NOT_FOUND'}else{$service.errorCode='SERVICE_METADATA_UNAVAILABLE'}}
 finally{if($controller){$controller.Dispose()}}
 @{status='METADATA_INVENTORY_ONLY_NOT_ENVIRONMENT_PASS';tokenAndProcesses=$snapshot;service=$service;pipe=@{endpoint='npipe:////./pipe/dockerDesktopLinuxEngine';presence='UNKNOWN';acl='NOT_RUN';openConnectReadWrite=0};layout=[WedReadOnlyTriage.Metadata]::Layout();daemonQueries=0;sourceCalls=0}|ConvertTo-Json -Depth 24 -Compress -EscapeHandling EscapeNonAscii
 exit 0
}catch{Write-Output 'METADATA_INVENTORY_FAILED_NO_MESSAGE';exit 20}
