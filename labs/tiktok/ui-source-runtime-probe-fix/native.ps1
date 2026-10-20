# Thin delegate to the reviewed Win32 helper; no executor implementation here.
function No-DockerOverrides {
 foreach($k in @('DOCKER_HOST','DOCKER_CONTEXT','DOCKER_CONFIG','DOCKER_TLS_VERIFY','DOCKER_CERT_PATH','DOCKER_CUSTOM_HEADERS','DOCKER_API_VERSION','DOCKER_DEFAULT_PLATFORM')){if(![string]::IsNullOrEmpty([Environment]::GetEnvironmentVariable($k))){throw 'OVERRIDE_PRESENT'}}
}
function Assert-Pins($Pins){foreach($p in $Pins){if((Get-FileHash $p.path).Hash.ToLowerInvariant() -cne $p.sha256){throw 'PIN_DRIFT'}}}
function Get-OldBaseline {
 $root=Join-Path (Get-Location).Path 'docs/evidence/ui-source-runtime-offline-probe-20261019/backend'
 $manifest=Join-Path $root 'manifest.json'
 if((Get-FileHash $manifest).Hash.ToLowerInvariant() -cne 'ab3dc3380a9604e9b2cc6f008a094e78e1a8c203645897bcc099b14e15a03949'){throw 'PIN_DRIFT'}
 $m=Get-Content $manifest -Raw|ConvertFrom-Json
 Assert-Pins $m.implementation
 $pins=@($m.implementation)+@{path=$manifest;sha256=(Get-FileHash $manifest).Hash.ToLowerInvariant()}
 foreach($a in $m.artifacts){$pins+=@{path=(Join-Path $root $a.path);sha256=$a.sha256}}
 $old=Get-Content (Join-Path $root 'plan.json') -Raw|ConvertFrom-Json
 $pins+=@($old.baselinePins);Assert-Pins $pins
 # Read the already manifest-pinned snapshot; do not dot-source old common,
 # whose script-scoped Root would mutate this successor's namespace.
 $frozen=Get-Content (Join-Path $root 'frozen-after.json') -Raw|ConvertFrom-Json
 foreach($f in $frozen){
  if((Get-FileHash $f.manifest).Hash.ToLowerInvariant() -cne $f.sha256){throw 'PIN_DRIFT'}
  $fm=Get-Content $f.manifest -Raw|ConvertFrom-Json;Assert-Pins $fm.implementation
  if($f.artifactsRehashed){if(@($fm.artifacts).Count -ne $f.artifactsRehashed){throw 'PIN_DRIFT'};foreach($a in $fm.artifacts){Assert-Pins @(@{path=(Join-Path (Split-Path $f.manifest) $a.path);sha256=$a.sha256})}}
 }
 return @{pins=$pins;frozen=$frozen;oldSources=@($m.implementation).Count;oldArtifacts=@($m.artifacts).Count;oldPlan=$old}
}
function New-NativeDelegate($Plan){
 No-DockerOverrides
 Assert-Pins (@($Plan.sourcePins)+@($Plan.baselinePins)+@(@{path=$Plan.docker;sha256=$Plan.dockerSHA},@{path=$Plan.helperSource;sha256=$Plan.helperSHA},@{path=$Plan.binary;sha256=$Plan.binarySHA}))
 if($Plan.endpoint -cne 'npipe:////./pipe/dockerDesktopLinuxEngine' -or $Plan.docker -cne 'C:\Program Files\Docker\Docker\resources\bin\docker.exe' -or ('WedOwnerWin32.Engine' -as [type])){throw 'EXECUTOR_PROVENANCE'}
 Add-Type -Path $Plan.binary;$engine='WedOwnerWin32.Engine' -as [type]
 if($engine.Assembly.Location -cne $Plan.binary -or $engine.Module.ModuleVersionId.ToString() -cne $Plan.MVID){throw 'EXECUTOR_PROVENANCE'};$null=$engine::Layout()
 return {
  param($op,[string[]]$argv,[int]$limit,[int]$cap)
  No-DockerOverrides
  Assert-Pins @(@{path=$Plan.docker;sha256=$Plan.dockerSHA},@{path=$Plan.binary;sha256=$Plan.binarySHA},@{path=$Plan.helperSource;sha256=$Plan.helperSHA})
  if($argv[0] -cnotin @('image','container','ps','create','start','rm') -or $limit -gt 20000 -or $limit -lt 600 -or $cap -ne 65536){throw 'EXECUTOR_SCOPE'}
  return $engine::Run($Plan.docker,[string[]](@('--host',$Plan.endpoint)+$argv),(Get-Location).Path,$limit,$cap,'None',$null)
 }.GetNewClosure()
}
