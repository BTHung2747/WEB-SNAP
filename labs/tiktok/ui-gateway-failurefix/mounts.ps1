. (Join-Path $PSScriptRoot '../ui-combined-mountfix/mounts.ps1')
function Get-MediaLeafMounts([string[]]$Roles=@('generate','app')){
 foreach($file in Get-ChildItem -LiteralPath apps/media/src -File -Recurse|Where-Object{$_.FullName -notmatch '[\\/](node_modules|__pycache__)[\\/]'}){
  $relative=[IO.Path]::GetRelativePath((Resolve-Path apps/media/src).Path,$file.FullName).Replace('\','/')
  [pscustomobject]@{source=$file.FullName;target="/app/apps/media/src/$relative";type='file';roles=$Roles;readOnly=$true}
 }
}
function Get-FailurefixMountMap([string]$Control){
 # Controller stays /newlab; new gateway entry becomes /gatewayfix/gateway.cjs.
 $map=@(Get-CombinedMountMap $Control|Where-Object target -CNE '/app/apps/media/src')+@(Get-MediaLeafMounts)
 $map+=[pscustomobject]@{source=$PSScriptRoot;target='/gatewayfix';type='directory';roles=@('generate','gateway');readOnly=$true}
 return $map
}
