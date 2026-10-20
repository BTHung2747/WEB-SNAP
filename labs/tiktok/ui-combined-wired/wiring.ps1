. (Join-Path $PSScriptRoot '../ui-gateway-failurefix/mounts.ps1')
function Get-WiredMountMap([string]$Control){
 $map=@(Get-FailurefixMountMap $Control)
 foreach($root in @('labs/tiktok/ui-gateway-failurefix','labs/tiktok/ui-combined-wired')){
  $map+=[pscustomobject]@{source=(Resolve-Path $root).Path;target="/repo/$root";type='directory';roles=@('generate','proxy','app');readOnly=$true}
 }
 return $map
}
function Get-WiredCommands{
 return [pscustomobject]@{
  generator=@('bash','-c','python3 /offline/generate.py generate && node /compat/check.cjs && node --check /gatewayfix/gateway.cjs && node --check /gatewayfix/failure-path.cjs')
  app=@('/usr/bin/timeout','--signal=KILL','340s','python3','-I','/mountfix/entry.py')
  gateway=@('node','/gatewayfix/gateway.cjs')
 }
}
function Assert-WiredPlan($Map,$Commands){
 $proof=@(Assert-CombinedMountMap $Map)
 if(@($Map|Where-Object target -CEQ '/app/apps/media/src').Count -ne 0 -or @($Map|Where-Object target -CLike '/app/apps/media/src/*').Count -ne 30){throw 'MEDIA_LEAF_WIRING'}
 if(($Commands.gateway -join ' ') -cne 'node /gatewayfix/gateway.cjs' -or $Commands.generator.Count -ne 3 -or $Commands.generator[2] -cne 'python3 /offline/generate.py generate && node /compat/check.cjs && node --check /gatewayfix/gateway.cjs && node --check /gatewayfix/failure-path.cjs' -or ($Commands.app -join ' ') -cne '/usr/bin/timeout --signal=KILL 340s python3 -I /mountfix/entry.py'){throw 'COMMAND_WIRING'}
 foreach($role in @('generate','gateway')){foreach($target in @('/gatewayfix/gateway.cjs','/gatewayfix/failure-path.cjs')){
  $source=Resolve-CombinedTarget $Map $role $target
  if(!(Test-Path -LiteralPath $source -PathType Leaf)){throw 'GATEWAY_ENTRY_IMPORT'}
  $proof+=[pscustomobject]@{role=$role;target=$target;source=$source;sha256=(Get-FileHash -LiteralPath $source).Hash.ToLowerInvariant()}
 }}
 return $proof
}
