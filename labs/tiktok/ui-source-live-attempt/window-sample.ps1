param([Parameter(Mandatory)][string]$Control,[Parameter(Mandatory)][ValidatePattern('^[a-f0-9]{64}$')][string]$ContractSHA)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot '../ui-source-owner-native/Owner.psm1') -DisableNameChecking
try{Request-OwnerWindowSample $Control $ContractSHA|ConvertTo-Json -Depth 12 -Compress}catch{Write-Output '{"status":"WINDOW_FAIL_CLOSED_NO_RETRY"}';exit 20}
