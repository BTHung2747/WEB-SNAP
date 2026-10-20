param([Parameter(Mandatory)][ValidatePattern('^[a-z0-9-]{1,40}$')][string]$Namespace)
. (Join-Path $PSScriptRoot 'core.ps1')
. (Join-Path $PSScriptRoot 'native.ps1')
Assert-ProjectionContracts;No-DockerOverrides
$root=Join-Path (Get-Location).Path ('docs/evidence/ui-source-runtime-probe-fix-20261019/backend/'+$Namespace)
if(Test-Path $root){throw 'FRESH_NAMESPACE_REQUIRED'}
$baseline=Get-OldBaseline
$plan=$baseline.oldPlan|ConvertTo-Json -Depth 64|ConvertFrom-Json -AsHashtable -Depth 64
$oldRun=$plan.runID;$oldTask=$plan.task;$plan.runID=[Guid]::NewGuid().ToString('N');$plan.task='runtime-probe-fix-20261019';$plan.schema='wed-runtime-offline-probe-fix-v1';$plan.mode='PREPARED_NOT_AUTHORIZED_NOT_EXECUTED';$plan.Remove('compileMs');$plan.Remove('compileHardCancel')
foreach($role in $plan.roles){
 $oldName=$role.name;$role.name='wed-source-'+$plan.runID+'-offline-'+$role.role
 $role.argv=@(foreach($v in $role.argv){if($v -ceq $oldName){$role.name}elseif($v -ceq ('com.wed-snap.run='+$oldRun)){'com.wed-snap.run='+$plan.runID}elseif($v -ceq ('com.wed-snap.task='+$oldTask)){'com.wed-snap.task='+$plan.task}else{$v}})
}
$plan.sourcePins=@(Get-ChildItem $PSScriptRoot -File|Sort-Object Name|ForEach-Object{@{path=$_.FullName;sha256=(Get-FileHash $_.FullName).Hash.ToLowerInvariant()}})
$plan.baselinePins=$baseline.pins
$plan.delta.projection='TYPED_ONLY_SPLIT_OWNER_STATE_GUARD_MOUNT_TYPES'
$plan.delta.cleanup='MINIMAL_IDENTITY_FROM_FRESH_LEDGER_INDEPENDENT_OF_GUARD'
$plan.delta.observers='PINNED_ORIGINAL_FILES_UNCHANGED_NO_COPY'
$plan.evidenceRoot=$root;$plan.utc=[DateTimeOffset]::UtcNow.ToString('o')
New-Item -ItemType Directory -Path $root|Out-Null
Save-New (Join-Path $root 'baseline-before.json') @{sources=$baseline.oldSources;artifacts=$baseline.oldArtifacts;frozen=$baseline.frozen;baselinePins=@($baseline.pins).Count}
Save-New (Join-Path $root 'plan.json') $plan
Write-Output ('PREPARED_ZERO_DAEMON '+(Get-FileHash (Join-Path $root 'plan.json')).Hash.ToLowerInvariant())
