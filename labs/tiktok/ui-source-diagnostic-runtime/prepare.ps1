param([Parameter(Mandatory)][ValidatePattern('^[a-z0-9-]{1,40}$')][string]$Namespace)
. (Join-Path $PSScriptRoot 'wiring.ps1')
No-DockerOverrides
$root=Join-Path (Get-Location).Path ('docs/evidence/ui-source-diagnostic-runtime-20261019/backend/'+$Namespace)
if(Test-Path $root){throw 'FRESH_NAMESPACE_REQUIRED'}
$deps=Verify-Dependencies
$p=Get-Content docs/evidence/ui-source-runtime-probe-fix-20261019/backend/runtime-reviewed-1/plan.json -Raw|ConvertFrom-Json -AsHashtable -Depth 64
$old=$p.runID;$p.runID=[Guid]::NewGuid().ToString('N');$p.evidenceRoot=$root;$p.mode='PREPARED_DIAGNOSTIC_NOT_RUNTIME_AUTHORITY';$p.schema='wed-diagnostic-runtime-v1'
# Keep the fixed coordinator's identity marker, not an authority token.
foreach($role in $p.roles){$oldname=$role.name;$role.name='wed-source-'+$p.runID+'-offline-'+$role.role;$role.argv=@(foreach($arg in $role.argv){if($arg -ceq $oldname){$role.name}elseif($arg -ceq ('com.wed-snap.run='+$old)){'com.wed-snap.run='+$p.runID}else{$arg}})}
$d=Get-Content docs/evidence/ui-source-job-residual-diagnostic-20261019/backend/compile-final.json -Raw|ConvertFrom-Json
$p.binary=$d.dll;$p.binarySHA=$d.dllSHA;$p.MVID=$d.MVID;$p.layout=$d.layout;$p.diagnosticLayout=$d.diagnosticLayout;$p.restoredBaseTextEqual=$d.restoredBaseTextEqual
$p.helperSource=(Resolve-Path labs/tiktok/ui-source-job-residual-diagnostic/DiagnosticAdapter.cs).Path;$p.helperSHA=$d.cloneSHA
$p.sourcePins=@(Get-ChildItem $PSScriptRoot -File|Sort-Object Name|ForEach-Object{@{path=$_.FullName;sha256=(Get-FileHash $_.FullName).Hash.ToLowerInvariant()}});$p.baselinePins=$deps.pins
$p.delta.logger='UTF8_JSON_SINGLE_BUFFER_EXACT_NESTED_SPAN_ATOMIC_NO_OVERWRITE';$p.delta.executor='REVIEWED_WedJobDiagnostic.Engine_FINAL_DLL_NO_SEMANTIC_CHANGE';$p.utc=[DateTimeOffset]::UtcNow.ToString('o')
New-Item -ItemType Directory -Path $root|Out-Null
Save-New (Join-Path $root 'baseline-before.json') @{frozen=$deps.frozen;pins=@($deps.pins).Count;sourceGate=$false}
Save-New (Join-Path $root 'plan.json') $p
Write-Output ('PREPARED_ONLY_NO_NATIVE '+(Get-FileHash (Join-Path $root 'plan.json')).Hash.ToLowerInvariant())
