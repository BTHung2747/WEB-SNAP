. (Join-Path $PSScriptRoot 'contracts.ps1')
$script:Root=Join-Path (Get-Location).Path 'docs/evidence/ui-source-cache-metadata-readonly-20261019/backend'
$script:HelperSHA='5ed79b96326b56535077c6a97b7b0b30fee1031379f74dc845cfc6fcebbf7f19'
$script:DockerSHA='1aaf3dd59c24ff4c83d930bc51ecac8bf6f6f4e7a310573ee69d14ca3a7ef85c'
$script:Endpoint='npipe:////./pipe/dockerDesktopLinuxEngine'
function Write-New([string]$Path,$Value){$f=[IO.FileStream]::new($Path,[IO.FileMode]::CreateNew);try{$b=[Text.Encoding]::UTF8.GetBytes(($Value|ConvertTo-Json -Depth 24));$f.Write($b,0,$b.Length);$f.Flush($true)}finally{$f.Dispose()}}
function ScriptPins {@(Get-ChildItem $PSScriptRoot -File|Sort-Object Name|ForEach-Object{@{path=[IO.Path]::GetRelativePath((Get-Location).Path,$_.FullName).Replace('\','/');sha256=(Get-FileHash $_.FullName).Hash.ToLowerInvariant();bytes=$_.Length}})}
function Assert-EmptyOverrides {
 $flags=@{};foreach($name in @('DOCKER_HOST','DOCKER_CONTEXT','DOCKER_CONFIG','DOCKER_TLS_VERIFY','DOCKER_CERT_PATH','DOCKER_CUSTOM_HEADERS','DOCKER_API_VERSION','DOCKER_DEFAULT_PLATFORM')){$present=![string]::IsNullOrEmpty([Environment]::GetEnvironmentVariable($name));$flags[$name]=$present;if($present){throw 'DOCKER_OVERRIDE_PRESENT_NO_CLEAR_OR_FALLBACK'}};return $flags
}
function Frozen {
 $records=@();$allCode=@()
 foreach($entry in @(@{root='docs/evidence/ui-source-direct-win32-integration-20261017/backend';sha='95d0baad0de5ed95d29fb0bd5c49a6659fed18de5a584c03297f25190dd6dd07';artifacts=$false},@{root='docs/evidence/ui-source-environment-readonly-20261019/backend';sha='576270fad71f9472d4eccd04fd39b26b9e7f2db34b477ebd745fe350960109b3';artifacts=$true},@{root='docs/evidence/ui-source-access-triage-readonly-20261019/backend';sha='44db03911362f2ffb8b6b3881f34b8935a8ec447f33e35b8f7147d273b7e1bb7';artifacts=$true},@{root='docs/evidence/ui-source-local-access-probe-20261019/reviewer';sha=$null;artifacts=$true})){
  $manifest=Join-Path $entry.root 'manifest.json';$sha=(Get-FileHash $manifest).Hash.ToLowerInvariant();if($entry.sha -and $entry.sha -cne $sha){throw 'FROZEN_MANIFEST_DRIFT'}
  $m=Get-Content $manifest -Raw|ConvertFrom-Json
  foreach($p in @($m.implementation)){if(!$p){continue};if((Get-FileHash $p.path).Hash.ToLowerInvariant() -cne $p.sha256){throw 'FROZEN_SOURCE_DRIFT'};$allCode+=$p}
  if($entry.artifacts){foreach($p in $m.artifacts){if((Get-FileHash (Join-Path $entry.root $p.path)).Hash.ToLowerInvariant() -cne $p.sha256){throw 'FROZEN_ARTIFACT_DRIFT'}}}
  $records+=@{manifest=$manifest;sha256=$sha;implementation=@($m.implementation|Where-Object{$_}).Count;artifacts=@($m.artifacts).Count;artifactsRehashed=$entry.artifacts}
 };return @{records=$records;sourcePins=$allCode}
}
