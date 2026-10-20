. (Join-Path $PSScriptRoot '../ui-combined-wired/wiring.ps1')
function Get-FinalMountMap([string]$Control){
 $map=@(Get-WiredMountMap $Control)
 $observation=(Resolve-Path labs/tiktok/ui-observation-fix).Path
 $map+=[pscustomobject]@{source=$observation;target='/observationfix';type='directory';roles=@('generate','app','gateway');readOnly=$true}
 $map+=[pscustomobject]@{source=(Resolve-Path labs/tiktok/ui-observation-fix/controller.ts).Path;target='/newlab/controller.ts';type='file';roles=@('generate','app');readOnly=$true}
 $map+=[pscustomobject]@{source=$PSScriptRoot;target='/finalfixture';type='directory';roles=@('generate');readOnly=$true}
 foreach($root in @('labs/tiktok/ui-observation-fix','labs/tiktok/ui-final-fixture')){$map+=[pscustomobject]@{source=(Resolve-Path $root).Path;target="/repo/$root";type='directory';roles=@('generate','app','proxy');readOnly=$true}}
 return $map
}
function Get-FinalCommands{
 return [pscustomobject]@{
  generator=@('bash','-c','python3 /offline/generate.py generate && node /compat/check.cjs && node /finalfixture/generator-check.cjs')
  app=@('/usr/bin/timeout','--signal=KILL','340s','python3','-I','/mountfix/entry.py')
  gateway=@('node','/observationfix/gateway.cjs')
 }
}
function Assert-FinalPlan($Map,$Commands){
 $proof=@(Assert-CombinedMountMap $Map)
 if(@($Map|Where-Object target -CEQ '/app/apps/media/src').Count -ne 0 -or @($Map|Where-Object target -CLike '/app/apps/media/src/*').Count -ne 30){throw 'MEDIA_LEAF_WIRING'}
 $expected=Get-FinalCommands;if(($Commands|ConvertTo-Json -Compress) -cne ($expected|ConvertTo-Json -Compress)){throw 'FINAL_COMMAND_WIRING'}
 foreach($role in @('generate','app')){if((Resolve-CombinedTarget $Map $role '/newlab/controller.ts') -cne (Resolve-Path labs/tiktok/ui-observation-fix/controller.ts).Path){throw 'CONTROLLER_DEEPEST_MOUNT'}}
 foreach($role in @('generate','app','gateway')){foreach($target in @('/observationfix/gateway.cjs','/observationfix/failure-path.cjs','/observationfix/event-writer.cjs','/observationfix/reasons.cjs')){
  $source=Resolve-CombinedTarget $Map $role $target;if(!(Test-Path -LiteralPath $source -PathType Leaf)){throw 'OBSERVATION_ENTRY_IMPORT'}
  $proof+=[pscustomobject]@{role=$role;target=$target;source=$source;sha256=(Get-FileHash -LiteralPath $source).Hash.ToLowerInvariant()}
 }}
 foreach($target in @('/finalfixture/generator-check.cjs','/finalfixture/final-gate.cjs')){$source=Resolve-CombinedTarget $Map 'generate' $target;if(!(Test-Path -LiteralPath $source -PathType Leaf)){throw 'FINAL_GENERATOR_ENTRY'}}
 return $proof
}
