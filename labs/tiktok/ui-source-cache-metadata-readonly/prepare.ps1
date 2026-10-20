. (Join-Path $PSScriptRoot 'common.ps1')
if(Test-Path (Join-Path $script:Root 'prepared.json')){throw 'NO_PREPARATION_REUSE'}
New-Item -ItemType Directory -Path (Join-Path $script:Root 'helper')|Out-Null
Write-New (Join-Path $script:Root 'frozen-before.json') (Frozen)
$overrides=Assert-EmptyOverrides
. (Join-Path (Get-Location).Path 'labs/tiktok/ui-source-prelaunch/wiring.ps1')
$plan=Get-PrelaunchPlan;$specs=@(New-Specs $plan.resources.roles)
if($specs.Count -ne 7){throw 'EXACT_QUERY_BUDGET'}
$source=(Resolve-Path 'labs/tiktok/ui-source-owner-native/Win32Adapter.cs').Path
if((Get-FileHash $source).Hash.ToLowerInvariant() -cne $script:HelperSHA -or ('WedOwnerWin32.Engine' -as [type])){throw 'HELPER_PIN_OR_PRELOADED_TYPE'}
$dll=Join-Path $script:Root 'helper/CacheReadonlyBoundary.dll';$watch=[Diagnostics.Stopwatch]::StartNew()
Add-Type -Path $source -OutputAssembly $dll
if(!('WedOwnerWin32.Engine' -as [type])){Add-Type -Path $dll}
$type='WedOwnerWin32.Engine' -as [type];if($type.Assembly.Location -cne $dll){throw 'ASSEMBLY_LOCATION'}
$probe=Get-Content 'docs/evidence/ui-source-local-access-probe-20261019/reviewer/provenance.json' -Raw|ConvertFrom-Json
$docker=$probe.dockerExe;if(!$docker){$docker=(Get-Content 'docs/evidence/ui-source-environment-readonly-20261019/backend/inventory-1/docker-version.json' -Raw|ConvertFrom-Json).executable.path}
if((Get-FileHash $docker).Hash.ToLowerInvariant() -cne $script:DockerSHA -or $probe.dockerExeSHA -cne $script:DockerSHA){throw 'DOCKER_PIN'}
$pins=ScriptPins
$data=@{schema='wed-cache-metadata-readonly-plan-v1';root=$script:Root;endpoint=$script:Endpoint;docker=$docker;dockerSHA=$script:DockerSHA;helperSource=$source;helperSourceSHA=$script:HelperSHA;binary=$dll;binarySHA=(Get-FileHash $dll).Hash.ToLowerInvariant();MVID=$type.Module.ModuleVersionId.ToString();layout=$type::Layout();compileMs=$watch.ElapsedMilliseconds;compilerHardCancel='NOT_CLAIMED';specs=$specs;roles=$plan.resources.roles|Select-Object role,image,memoryMiB,pids,cpu;sourcePins=$pins;overrides=$overrides;planSource=@(foreach($f in @('labs/tiktok/ui-source-prelaunch/wiring.ps1','labs/tiktok/ui-source-readiness/plan.ps1','labs/tiktok/ui-source-glue/wiring.ps1')){@{path=$f;sha256=(Get-FileHash $f).Hash.ToLowerInvariant()}});queryLimit=7;watchdogMs=15000;combinedByteCap=65536;sourceGate=$false;probeReference='docs/evidence/ui-source-local-access-probe-20261019/reviewer/ASSESSMENT.md';utc=[DateTimeOffset]::UtcNow.ToString('o')}
Write-New (Join-Path $script:Root 'prepared.json') $data
Write-Output 'PREPARED_ZERO_DAEMON_QUERIES';exit 0
