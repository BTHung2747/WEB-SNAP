. (Join-Path $PSScriptRoot 'common.ps1')
$root=$script:LiveARoot
if(Test-Path (Join-Path $root 'manifest.json')){throw 'ALREADY_SEALED'}
$baseline=Check-LiveBaseline
$commandRows=@(
 @{command='test-a.ps1 (initial)';actualOuterExit=1;outcome='37/40; three harness scriptblock errors';classification='PURE_UNIT'},
 @{command='test-a.ps1 (unit-final)';actualOuterExit=0;outcome='40/40';classification='PURE_UNIT_INTERMEDIATE'},
 @{command='test-readiness-flow.ps1 then test-a.ps1 -Trial unit-sealed';actualOuterExit=0;outcome='7/7 +42/42';classification='FAKE_AND_UNIT_PRE_BATCH'},
 @{command='prepare-a.ps1';actualOuterExit=0;outcome='plan d15255bb498e407aa30edb0832ee03dac995f9f3e62c0faa4efbd9f77664bfe6';classification='NO_DAEMON'},
 @{command='run-readiness.ps1 (original entry before mandatory PlanSHA successor)';actualOuterExit=1;toolWallSeconds=2.6617929;outcome='READINESS_FAIL cleanup=True cause=READINESS_ERROR_NO_MESSAGE';classification='ONE_ACTUAL_READINESS_BATCH'},
 @{command='New-NativeDelegate then UNIT_INVALID_BEFORE_ENGINE_RUN';actualOuterExit=0;outcome='EXECUTOR_SCOPE rejected before Engine.Run';classification='OFFLINE_ARGUMENT_REJECTION_NO_DOCKER'},
 @{command='test-readiness-flow.ps1 (flow-final)';actualOuterExit=20;outcome='7/8; new harness expected3 error records but fail-fast attempted2';classification='FAKE_INTERMEDIATE'},
 @{command='test-readiness-flow.ps1 -Trial flow-sealed then test-a.ps1 -Trial unit-postattempt';actualOuterExit=0;outcome='8/8 +42/42';classification='FINAL_CODE_FAKE_AND_UNIT_ONLY'}
)
Save-New (Join-Path $root 'actual-commands.json') @{commands=$commandRows;sourceCalls=0;liveKeys=0;liveGrants=0;sourceClaims=0;history='UNCHANGED';recordedUTC=[DateTimeOffset]::UtcNow.ToString('o')}
$old=Get-Content (Join-Path $root 'readiness-plan.json') -Raw|ConvertFrom-Json
$delta=@(foreach($p in $old.sourcePins){@{path=$p.path;batchSHA=$p.sha256;finalSHA=(Get-FileHash $p.path).Hash.ToLowerInvariant();sameAsBatch=((Get-FileHash $p.path).Hash.ToLowerInvariant() -ceq $p.sha256)}})
Save-New (Join-Path $root 'provenance-dag.json') @{schema='wed-source-a-provenance-dag-v1';human=Live-Ref $script:HumanPath;task=Live-Ref $script:LiveTask;baselinePinsChecked=$baseline.pins.Count;sourceDelta=$delta;nodes=@(@{id='runtime5role';status='HISTORICAL_ACCEPTED_DIAGNOSTIC_HELPER'},@{id='egressTLS';status='HISTORICAL_CAPABILITY_120_OF_128_PINS_ONLY'},@{id='port5206';status='OBSERVED_RELEASED_SNAPSHOT'},@{id='hostLinuxClock';status='UNKNOWN_BATCH_FAILED_PRE_CREATE'},@{id='mountMap';status='NOT_RUN'},@{id='hostPythonClock';status='NOT_RUN'},@{id='liveIssuer';status='CLOSED_NOT_IMPLEMENTED'},@{id='ownerAdapter';status='NOT_IMPLEMENTED'},@{id='browserWindow';status='PROPOSED_260S_GATE_NEEDS_REVIEW'},@{id='GO_B';status='NOT_RECEIVED'});canLaunch=$false;sourceCalls=0;sourceClaims=0;liveGrants=0}
$sources=@(Get-ChildItem $PSScriptRoot -File|Sort-Object Name|ForEach-Object{@{path=[IO.Path]::GetRelativePath((Get-Location).Path,$_.FullName).Replace('\','/');sha256=(Get-FileHash $_.FullName).Hash.ToLowerInvariant();bytes=$_.Length}})
$artifacts=@(Get-ChildItem $root -File -Recurse|Sort-Object FullName|ForEach-Object{@{path=[IO.Path]::GetRelativePath($root,$_.FullName).Replace('\','/');sha256=(Get-FileHash $_.FullName).Hash.ToLowerInvariant();bytes=$_.Length}})
Save-New (Join-Path $root 'manifest.json') @{schema='wed-source-live-preparation-a-manifest-v1';status='HANDOFF_READY_FOR_REVIEW_NOT_LAUNCH_READY';implementation=$sources;artifacts=$artifacts;dependencyPins=$baseline.pins;sourceGate=$false;runtimeGrantCount=0;sourceClaimCount=0;sourceRequests=0;utc=[DateTimeOffset]::UtcNow.ToString('o')}
Write-Output ('SEALED source='+$sources.Count+' artifacts='+$artifacts.Count+' dependencies='+$baseline.pins.Count+' sha='+(Get-FileHash (Join-Path $root 'manifest.json')).Hash.ToLowerInvariant())
