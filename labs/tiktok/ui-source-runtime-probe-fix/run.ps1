param(
 [Parameter(Mandatory)][ValidatePattern('^[a-z0-9-]{1,40}$')][string]$Namespace,
 [Parameter(Mandatory)][ValidatePattern('^[a-f0-9]{64}$')][string]$PlanSHA,
 [switch]$AuthorizedOfflineRuntime
)
# This switch is an admission check, not a capability or a replacement for
# a separate human task + tool approval. DO NOT invoke in offline-fix task.
if(!$AuthorizedOfflineRuntime){throw 'SEPARATE_RUNTIME_TASK_REQUIRED'}
. (Join-Path $PSScriptRoot 'core.ps1')
. (Join-Path $PSScriptRoot 'native.ps1')
$root=Join-Path (Get-Location).Path ('docs/evidence/ui-source-runtime-probe-fix-20261019/backend/'+$Namespace)
$path=Join-Path $root 'plan.json'
if((Get-FileHash $path).Hash.ToLowerInvariant() -cne $PlanSHA){throw 'PLAN_DRIFT'}
$plan=Get-Content $path -Raw|ConvertFrom-Json -AsHashtable -Depth 64
if($plan.evidenceRoot -cne $root -or (Test-Path (Join-Path $root 'attempt-once.json'))){throw 'FRESH_ATTEMPT_REQUIRED'}
$executor=New-NativeDelegate $plan
$sink={param($name,$value) Save-New (Join-Path $root ($name+'.json')) $value}.GetNewClosure()
$clock=[Diagnostics.Stopwatch]::StartNew();$now={$clock.ElapsedMilliseconds}.GetNewClosure()
$check={Assert-Pins (@($plan.sourcePins)+@($plan.baselinePins))}.GetNewClosure()
$summary=Invoke-ProbeAttempt $plan $executor $sink $now $check
Write-Output ('OFFLINE_PROBE_RUNTIME_PASS_'+$summary.runtimePASS+'_CLEANUP_'+$summary.closed)
if(!$summary.runtimePASS){exit 20};exit 0
