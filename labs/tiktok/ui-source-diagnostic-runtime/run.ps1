param([Parameter(Mandatory)][ValidatePattern('^[a-z0-9-]{1,40}$')][string]$Namespace,[Parameter(Mandatory)][ValidatePattern('^[a-f0-9]{64}$')][string]$PlanSHA,[switch]$AuthorizedOfflineRuntime)
if(!$AuthorizedOfflineRuntime){throw 'SEPARATE_RUNTIME_TASK_REQUIRED'}
. (Join-Path $PSScriptRoot 'wiring.ps1')
$root=Join-Path (Get-Location).Path ('docs/evidence/ui-source-diagnostic-runtime-20261019/backend/'+$Namespace)
$path=Join-Path $root 'plan.json'
if((Get-FileHash $path).Hash.ToLowerInvariant() -cne $PlanSHA){throw 'PLAN_DRIFT'}
$p=Get-Content $path -Raw|ConvertFrom-Json -AsHashtable -Depth 64
if($p.evidenceRoot -cne $root -or (Test-Path (Join-Path $root 'core-attempt-once.json'))){throw 'FRESH_ATTEMPT_REQUIRED'}
$invoke=New-DiagnosticDelegate $p
$clock=[Diagnostics.Stopwatch]::StartNew();$now={$clock.ElapsedMilliseconds}.GetNewClosure();$check={Assert-Pins (@($p.sourcePins)+@($p.baselinePins))}.GetNewClosure()
$out=Invoke-LoggedAttempt $p $invoke $now $check
Write-Output ('DIAGNOSTIC_RUNTIME_PASS_'+$out.completionPASS+'_CLEANUP_'+$out.cleanupClosed+'_LOGGER_FAILED_'+$out.loggerFailed)
if(!$out.completionPASS){exit 20};exit 0
