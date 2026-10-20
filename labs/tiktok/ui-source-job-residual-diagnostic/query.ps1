param([Parameter(Mandatory)][ValidatePattern('^[a-f0-9]{64}$')][string]$PlanSHA)
. (Join-Path $PSScriptRoot 'common.ps1')
$path=Join-Path $script:EvidenceRoot 'query-plan.json'
if((Get-FileHash $path).Hash.ToLowerInvariant() -cne $PlanSHA){throw 'PLAN_DRIFT'}
$p=Get-Content $path -Raw|ConvertFrom-Json
No-DockerOverrides;Assert-Pins $p.sourcePins;Assert-Pins $p.toolPins
$null=Check-Baseline
$a=Get-Content (Join-Path $script:EvidenceRoot 'final-phase-a-result.json') -Raw|ConvertFrom-Json
if($a.status -cne 'FINAL_CONTROLS_PASS_EXPECTED_ORPHAN_NATIVE_FAIL' -or $a.nativeOperations -ne 3 -or $a.taskTotalNativeControls -ne 6 -or $p.limitMs -ne 15000 -or $p.cap -ne 65536 -or $p.endpoint -cne 'npipe:////./pipe/dockerDesktopLinuxEngine' -or $p.sourceGate -ne $false){throw 'QUERY_GATE'}
Assert-Pins $a.sourcePins
$expected=@('--host',$p.endpoint,'ps','--all','--no-trunc','--filter','name=^/wed-source-990d89fe669647638c38a62e1db60b7b-offline-','--format','{{.ID}}')
if(($p.argv|ConvertTo-Json -Compress) -cne ($expected|ConvertTo-Json -Compress)){throw 'EXACT_QUERY_REQUIRED'}
Save-New (Join-Path $script:EvidenceRoot 'phase-b-once.json') @{mode='ONE_READONLY_DIAGNOSTIC_QUERY_NOT_RUNTIME_ADMISSION';planSHA=$PlanSHA;utc=[DateTimeOffset]::UtcNow.ToString('o')}
$engine=Load-Diagnostic 'compile-final.json'
$r=$engine::Run($p.docker,[string[]]$expected,(Get-Location).Path,15000,65536,'None',$null)
$record=Persist-Operation 'phase-b-receipt' $r 'ACTUAL_SINGLE_SCOPED_DOCKER_PS_READONLY'
Save-New (Join-Path $script:EvidenceRoot 'phase-b-result.json') @{classification=$(if($r.TerminationRequested -and $r.AfterRootRelease -gt 0){'RESIDUAL_FORCE_OBSERVED_IN_NEW_OPERATION'}else{'NOT_REPRODUCED_AT_SINGLE_OBSERVATION'});nativeStatus=$r.Status;nativeExit=$r.RootExit;observationIsHistoricalCause=$false;diagnosticComplete=$r.Diagnostics.Complete;scopedRowsEmpty=[string]::IsNullOrWhiteSpace($r.RawOut);sourceGate=$false;queryCount=1;resourceMutations=0;utc=[DateTimeOffset]::UtcNow.ToString('o')}
Write-Output ('PHASE_B_NATIVE_'+$r.Status+'_EXIT_'+$r.RootExit+'_FORCED_'+$r.TerminationRequested)
if($r.Status -cne 'PASS'){exit 20};exit 0
