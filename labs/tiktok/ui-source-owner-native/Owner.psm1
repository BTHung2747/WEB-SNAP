$ErrorActionPreference='Stop'
$script:SourceSeal=[object]::new();$script:OfflineSeal=[object]::new()
. (Join-Path $PSScriptRoot 'trust.ps1')
. (Join-Path $PSScriptRoot 'loader.ps1')
. (Join-Path $PSScriptRoot 'native.ps1')
. (Join-Path $PSScriptRoot 'mounts.ps1')
. (Join-Path $PSScriptRoot 'runtime.ps1')
. (Join-Path $PSScriptRoot '../ui-source-live-attempt/bridge-trust.ps1')
. (Join-Path $PSScriptRoot '../ui-source-live-attempt/bridge-native.ps1')
. (Join-Path $PSScriptRoot '../ui-source-live-attempt/bridge-runtime.ps1')
Export-ModuleMember -Function Read-SourceApproval,New-OfflineNativeTestContext,Initialize-OfflineNativeAdapter,Invoke-OfflineNativeCommand,Invoke-OfflineNativeChild,Read-NativeJSON,Read-OfflineRootJSON,Assert-NativeSuccess,Invoke-SourceOwner,Get-OwnerBudget,Test-OwnedRegistryCleanup,Test-ApprovalConsumer
Export-ModuleMember -Function New-ReviewedSourceBootstrap,New-ManagedAdapterBootstrap,New-SourceAuthority,New-ScopedSourceApproval,Read-ScopedSourceApproval,Close-SourceAuthority,Get-SourceAuthorityIdentity,Get-SourceAdapterTrace,New-OwnerWindowSample,Test-ManagedSourceDispatch,Test-ManagedWindow
Export-ModuleMember -Function Request-OwnerWindowSample,Read-OwnerWindowResponse
Export-ModuleMember -Function Initialize-ManagedAdapterHarness,Test-ManagedWindowService
