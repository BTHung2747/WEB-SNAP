param([Parameter(Mandatory)][string]$Evidence,[Parameter(Mandatory)][string]$Ready)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'Owner.psm1') -Force -DisableNameChecking
$ctx=New-OfflineNativeTestContext (Resolve-Path $Evidence).Path
Initialize-OfflineNativeAdapter $ctx|Out-Null
$module=Get-Module Owner
&$module {param($c,$path)(Get-NativeContext $c).Ready=$path} $ctx $Ready
# Only this offline registered context may use the ready hook. The adapter
# verifies own-job membership and creation FILETIMEs before publishing identities.
$r=Invoke-OfflineNativeCommand $ctx node @('--max-old-space-size=32',(Join-Path $PSScriptRoot 'child.cjs'),'crashhold') 5000 8192
Write-Output 'OFFLINE_OWNER_SELF_EXPIRY_NOT_CRASH_TEST_SUCCESS'
exit 20
