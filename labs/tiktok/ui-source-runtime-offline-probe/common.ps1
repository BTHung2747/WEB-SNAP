$ErrorActionPreference='Stop'
$script:Root=Join-Path (Get-Location).Path 'docs/evidence/ui-source-runtime-offline-probe-20261019/backend'
$script:TaskMarker='runtime-offline-probe-20261019'
$script:HelperSHA='5ed79b96326b56535077c6a97b7b0b30fee1031379f74dc845cfc6fcebbf7f19'
$script:DockerSHA='1aaf3dd59c24ff4c83d930bc51ecac8bf6f6f4e7a310573ee69d14ca3a7ef85c'
$script:Docker='C:\Program Files\Docker\Docker\resources\bin\docker.exe'
$script:Endpoint='npipe:////./pipe/dockerDesktopLinuxEngine'
function Save([string]$Path,$Value){$f=[IO.FileStream]::new($Path,[IO.FileMode]::CreateNew);try{$bytes=[Text.Encoding]::UTF8.GetBytes(($Value|ConvertTo-Json -Depth 32));$f.Write($bytes,0,$bytes.Length);$f.Flush($true)}finally{$f.Dispose()}}
function Pins {@(Get-ChildItem $PSScriptRoot -File|Sort-Object Name|ForEach-Object{@{path=$_.FullName;sha256=(Get-FileHash $_.FullName).Hash.ToLowerInvariant();bytes=$_.Length}})}
function No-Overrides {
 foreach($key in @('DOCKER_HOST','DOCKER_CONTEXT','DOCKER_CONFIG','DOCKER_TLS_VERIFY','DOCKER_CERT_PATH','DOCKER_CUSTOM_HEADERS','DOCKER_API_VERSION','DOCKER_DEFAULT_PLATFORM')){if(![string]::IsNullOrEmpty([Environment]::GetEnvironmentVariable($key))){throw 'OVERRIDE_PRESENT_NO_MUTATION_OR_FALLBACK'}}
}
function Frozen {
 $out=@()
 foreach($entry in @(@{root='docs/evidence/ui-source-direct-win32-integration-20261017/backend';sha='95d0baad0de5ed95d29fb0bd5c49a6659fed18de5a584c03297f25190dd6dd07';artifacts=$false},@{root='docs/evidence/ui-source-cache-metadata-readonly-20261019/backend';sha='438c94783dec242461ba7122f449787793e7dcc2b317f50f9f0cf464d01c256a';artifacts=$true})){
  $mfile=Join-Path $entry.root 'manifest.json';if((Get-FileHash $mfile).Hash.ToLowerInvariant() -cne $entry.sha){throw 'BASELINE_MANIFEST_DRIFT'};$m=Get-Content $mfile -Raw|ConvertFrom-Json
  foreach($pin in $m.implementation){if((Get-FileHash $pin.path).Hash.ToLowerInvariant() -cne $pin.sha256){throw 'BASELINE_SOURCE_DRIFT'}}
  if($entry.artifacts){foreach($a in $m.artifacts){if((Get-FileHash (Join-Path $entry.root $a.path)).Hash.ToLowerInvariant() -cne $a.sha256){throw 'BASELINE_ARTIFACT_DRIFT'}}}
  $out+=@{manifest=$mfile;sha256=$entry.sha;sourceCount=@($m.implementation).Count;artifactsRehashed=$(if($entry.artifacts){@($m.artifacts).Count}else{0})}
 }
 # Prior diagnostics/triage were pinned by accepted metadata and must stay intact.
 foreach($old in @(@{root='docs/evidence/ui-source-environment-readonly-20261019/backend';sha='576270fad71f9472d4eccd04fd39b26b9e7f2db34b477ebd745fe350960109b3'},@{root='docs/evidence/ui-source-access-triage-readonly-20261019/backend';sha='44db03911362f2ffb8b6b3881f34b8935a8ec447f33e35b8f7147d273b7e1bb7'})){
  $mp=Join-Path $old.root 'manifest.json';if((Get-FileHash $mp).Hash.ToLowerInvariant() -cne $old.sha){throw 'PRIOR_MANIFEST_DRIFT'};$m=Get-Content $mp -Raw|ConvertFrom-Json
  foreach($p in $m.implementation){if((Get-FileHash $p.path).Hash.ToLowerInvariant() -cne $p.sha256){throw 'PRIOR_CODE_DRIFT'}};foreach($a in $m.artifacts){if((Get-FileHash (Join-Path $old.root $a.path)).Hash.ToLowerInvariant() -cne $a.sha256){throw 'PRIOR_EVIDENCE_DRIFT'}}
  $out+=@{manifest=$mp;sha256=$old.sha;sourceCount=@($m.implementation).Count;artifactsRehashed=@($m.artifacts).Count}
 };return $out
}
function Native-OK($R){$R.Status -ceq 'PASS' -and $R.Created -and $R.RootInOwnJob -and $R.RootExit -eq 0 -and $null -ne $R.RootExit -and !$R.TerminationRequested -and !$R.Timeout -and !$R.ByteCapExceeded -and $R.FinalActive -eq 0 -and $null -ne $R.FinalActive -and $R.PipesEOF -and $R.CleanupClosed}
function Assert-Owner($Role,$G,[string]$CID=''){
 if($G.id -cnotmatch '^[a-f0-9]{64}$' -or ($CID -and $G.id -cne $CID) -or $G.name -cne ('/'+$Role.name) -or $G.image -cne $Role.image -or $G.run -cne $script:Plan.runID -or $G.task -cne $script:TaskMarker){throw 'OWNERSHIP_UNPROVEN_NO_DESTRUCTIVE_ACTION'}
}
function Assert-Guards($Role,$G){
 Assert-Owner $Role $G
 if($G.user -cne $Role.user -or !$G.rootRO -or $G.privileged -or @($G.capAdd|Where-Object{$_}).Count -or $G.capDrop -cnotcontains 'ALL' -or $G.security -cnotcontains 'no-new-privileges:true' -or $G.memory -ne $Role.memoryMiB*1MB -or $G.swap -ne $G.memory -or $G.pids -ne $Role.pids -or $G.nanoCPU -ne [long]($Role.cpu*1e9) -or $G.ipc -cne 'private' -or $G.cgroupns -cne 'private' -or $G.network -cne 'none' -or $G.portCount -ne 0 -or $G.networks.Count -ne 1 -or $G.networks[0] -cne 'none'){throw 'HOSTCONFIG_GUARD_MISMATCH'}
 foreach($m in $Role.mounts){$found=@($G.mounts|Where-Object target -CEQ $m.target);if($found.Count -ne 1 -or $found[0].type -cne 'bind' -or $found[0].rw){throw 'READONLY_BIND_GUARD'}}
 if(@($G.mounts|Where-Object type -CEQ volume).Count){throw 'UNEXPECTED_PERSISTENT_VOLUME'}
}
