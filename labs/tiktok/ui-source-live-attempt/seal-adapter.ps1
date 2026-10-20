$ErrorActionPreference='Stop'
$root='docs/evidence/ui-source-live-adapter-fix-20261019/backend'
if(Test-Path (Join-Path $root 'manifest.json')){throw 'ALREADY_SEALED'}
function WriteNew([string]$Path,$Value){$s=[IO.FileStream]::new($Path,[IO.FileMode]::CreateNew);try{$b=[Text.Encoding]::UTF8.GetBytes(($Value|ConvertTo-Json -Depth 35));$s.Write($b);$s.Flush($true)}finally{$s.Dispose()}}
function Hash([string]$Path){(Get-FileHash -LiteralPath $Path).Hash.ToLowerInvariant()}
$before=Get-Content (Join-Path $root 'before-pins.json') -Raw|ConvertFrom-Json
foreach($p in $before|Where-Object immutable){if((Hash $p.path) -cne $p.sha256){throw 'IMMUTABLE_DRIFT'}}
$oldRoot='docs/evidence/ui-source-live-attempt-20261019/backend';$oldMF=Join-Path $oldRoot 'manifest.json'
if((Hash $oldMF) -cne '80992772752eba82dc31a3326732db8b157abf7aeb5bf86ff66fcfde84cc664a'){throw 'OLD_MANIFEST_DRIFT'}
$old=Get-Content $oldMF -Raw|ConvertFrom-Json
$allowed=@($before|Where-Object{!$_.immutable}|ForEach-Object path)+@('labs/tiktok/ui-source-live-attempt/readiness.ps1')
$authorized=@();$unchanged=0
foreach($p in @($old.implementation)+@($old.dependencyPins)){
 $rel=[IO.Path]::GetRelativePath((Get-Location).Path,[IO.Path]::GetFullPath($p.path)).Replace('\','/');$h=Hash $p.path
 if($h -cne $p.sha256){if($rel -cnotin $allowed){throw 'UNAUTHORIZED_SOURCE_DRIFT'};$authorized+=@{path=$rel;beforeSHA=$p.sha256;afterSHA=$h}}else{$unchanged++}
}
foreach($p in $old.artifacts){if((Hash (Join-Path $oldRoot $p.path)) -cne $p.sha256){throw 'OLD_ARTIFACT_DRIFT'}}
$reviewMF='docs/evidence/ui-source-live-attempt-a-review-20261019/manifest.json'
if((Hash $reviewMF) -cne '169acb9cd8525fae7dce509be3f515aa01f4f349b52cf4e0f3684714d3c2b03c'){throw 'REVIEW_MANIFEST_DRIFT'}
$review=Get-Content $reviewMF -Raw|ConvertFrom-Json;foreach($p in $review.artifacts){if((Hash (Join-Path (Split-Path $reviewMF) $p.path)) -cne $p.sha256){throw 'REVIEW_ARTIFACT_DRIFT'}}
# Recover the before-readiness source mechanically; verify its sealed hash.
$text=[IO.File]::ReadAllText('labs/tiktok/ui-source-live-attempt/readiness.ps1')
$inverse=[regex]::Replace($text,'(?ms)^function Check-ReadinessCleanupMounts\([^\n]*\r?\n.*?^}\r?\n','')
$inverse=$inverse.Replace('    Check-ReadinessCleanupMounts (Read-JSON $r.RawOut) $cid','    $null=Check-ReadinessMounts $Plan (Read-JSON $r.RawOut) $cid')
$inverseFile=Join-Path $root 'before/readiness-A.ps1.txt';if(!(Test-Path $inverseFile)){[IO.File]::WriteAllText($inverseFile,$inverse,[Text.UTF8Encoding]::new($false))}
$expected=@($old.implementation|Where-Object{$_.path -clike '*/readiness.ps1'})[0].sha256
if((Hash $inverseFile) -cne $expected){throw 'READINESS_BEFORE_RECONSTRUCTION_MISMATCH'}
$final=Get-Content (Join-Path $root 'unit/public-copy-final/results.json') -Raw|ConvertFrom-Json
$cleanup=Get-Content (Join-Path $root 'readiness-cleanup-cases.json') -Raw|ConvertFrom-Json
if($final.count -ne 36 -or $final.passed -ne 36 -or $cleanup.count -ne 6 -or $cleanup.passed -ne 6){throw 'FINAL_GATES_NOT_PASS'}
$commands=@(
 @{command='test-adapter.ps1 -Trial first';outerExit=1;result='5/24';kind='HARNESS_NODE_PATH_ARRAY';EngineRun=0;Docker=0},
 @{command='test-adapter.ps1 -Trial tool-pin-fixed';outerExit=1;result='INTERRUPTED_NO_FINAL_SUMMARY';kind='OWN_MANAGED_UNIT_STOP_FOR_REDUNDANT_IO_FIX';EngineRun=0;Docker=0},
 @{command='test-adapter.ps1 -Trial context-bound';outerExit=1;result='INTERRUPTED_NO_FINAL_SUMMARY';kind='OWN_MANAGED_UNIT_STOP_BEFORE_FINAL_PROVENANCE_CHANGES';EngineRun=0;Docker=0},
 @{command='test-adapter.ps1 -Trial focused -Focus integration-pass';outerExit=0;result='1/1';kind='FOCUSED_MANAGED_INTEGRATION';EngineRun=0;Docker=0},
 @{command='test-adapter.ps1 -Trial linked-final';outerExit=1;result='33/34';kind='LOST_CID_CONTRACT_FINDING';EngineRun=0;Docker=0},
 @{command='test-cleanup-separation.ps1 then test-adapter.ps1 -Trial lost-cid-fix -Focus integration-lost-cid';outerExit=0;result='6/6 +1/1';kind='SAME_READINESS_CLEANUP_CODE_PLUS_FOCUSED_FIX';EngineRun=0;Docker=0},
 @{command='test-adapter.ps1 -Trial final-code';outerExit=0;result='35/35';kind='MANAGED_INTERMEDIATE';EngineRun=0;Docker=0},
 @{command='test-adapter.ps1 -Trial sealed-final';outerExit=0;result='35/35';kind='MANAGED_EFFECTIVE_LIMIT_CHECKS';EngineRun=0;Docker=0},
 @{command='test-adapter.ps1 -Trial public-copy-final';outerExit=0;result='36/36';kind='FINAL_MANAGED_CODE';EngineRun=0;Docker=0}
)
WriteNew (Join-Path $root 'actual-commands.json') @{commands=$commands;unitOnly=$true;sourceRequests=0;liveKeys=0;liveGrants=0;sourceClaims=0;recordedUTC=[DateTimeOffset]::UtcNow.ToString('o')}
WriteNew (Join-Path $root 'preservation.json') @{oldManifest=@{ref=$oldMF;sha256=Hash $oldMF};reviewManifest=@{ref=$reviewMF;sha256=Hash $reviewMF};oldArtifactsRehashed=$old.artifacts.Count;reviewArtifactsRehashed=$review.artifacts.Count;oldSourceAndDependencyRowsUnchanged=$unchanged;authorizedSourceDrift=$authorized;immutables=@($before|Where-Object immutable);readinessBeforeHash=$expected;goldenModified=$false;actualSourceRequests=0;sourceClaims=0}
WriteNew (Join-Path $root 'test-summary.json') @{final=@{path='unit/public-copy-final/results.json';sha256=Hash (Join-Path $root 'unit/public-copy-final/results.json');count=$final.count;passed=$final.passed;mode=$final.mode};readinessCleanup=@{path='readiness-cleanup-cases.json';sha256=Hash (Join-Path $root 'readiness-cleanup-cases.json');count=6;passed=6;mode='FAKE_EXECUTOR'};nativeOrSourceResult='NOT_RUN';historicalReadinessCause='UNKNOWN_UNCHANGED';noClaimsConsumed=$true}
WriteNew (Join-Path $root 'api-proof-map.json') @{schema='wed-owner-adapter-api-dag-v2';apis=@(@{from='reviewer out-of-band expected SHA';to='New-ReviewedSourceBootstrap';trust='HOST_ISSUER_ENTRY_NOT_SOURCE_PAYLOAD';liveGate='REVIEWER_GO_B+human+bundle+code+tools+proof DAG+expiry';observed='MANAGED_COUNTERPART_ONLY'},@{from='opaque registered bootstrap';to='New-SourceAuthority';trust='CWT+rechecked refs and current pins';observed='MANAGED_RSA_ONLY'},@{from='registered authority';to='New-ScopedSourceApproval';trust='RAM RSA/PSS+scoped original bytes';observed='MANAGED_ONLY'},@{from='signed approval';to='Read-ScopedSourceApproval';trust='registered signer+human-once lock/crash intent+registered context';observed='MANAGED_ADMISSIONS_ONLY'},@{from='registered context';to='Invoke-SourceOwner -Context';trust='CWT/seal/immutable binding/deadlines/namespace';observed='MANAGED_COORDINATOR_ONLY'},@{from='native boundary';to='cached original DLL';trust='source+binary+location+MVID+layout+assembly identity';observed='METADATA_AND_MANAGED_LAYOUT_NOT_ENGINE_RUN'},@{from='live dispatch';to='original Engine.Run';trust='exact exe/cwd/endpoint/limits+native predicate unchanged';observed='NOT_RUN'},@{from='managed dispatch';to='registered spy';trust='MANAGED_ADAPTER_TEST private seal; cannot relabel live';observed='36_CASE_GATE'},@{from='runtime guard FAIL';to='ownership-safe fullID cleanup';trust='independent type/provenance safety+perID/scopedabsence';observed='MANAGED_AND_6_READINESS_FAKE_CASES'});requiredBeforeLive=@('reviewed current code','new bounded native readiness Result and plan/code binding','fresh clock bracket+map','reviewer GO_B','frontend fresh binding/window/relay check');timeline=@{ownerSeconds=341;startup=60;publish=280;proxy=320;cleanup=20;seal=1;browserNominal=40;preOpenRemainingMs=260000;finalReserveMs=10000;windowAgeMs=1000;newMeasuredClock='NOT_RUN';providerHardCancel='UNKNOWN'};sourceWorkflowBudget='2 analyze metadata +2 fresh prepare metadata +conditional1 JPEG; retry0/redirect0';sourceFacade='IMPLEMENTED_NOT_EXECUTED';historicalCause='UNKNOWN';GO_B=$false}
$sourcePaths=@($before|Where-Object{!$_.immutable}|ForEach-Object path)+@(Get-ChildItem $PSScriptRoot -File|ForEach-Object{[IO.Path]::GetRelativePath((Get-Location).Path,$_.FullName).Replace('\','/')})
$sources=@($sourcePaths|Sort-Object -Unique|ForEach-Object{@{path=$_;sha256=Hash $_;bytes=(Get-Item $_).Length}})
$artifacts=@(Get-ChildItem $root -File -Recurse|Sort-Object FullName|ForEach-Object{@{path=[IO.Path]::GetRelativePath([IO.Path]::GetFullPath($root),$_.FullName).Replace('\','/');sha256=Hash $_.FullName;bytes=$_.Length}})
WriteNew (Join-Path $root 'manifest.json') @{schema='wed-owner-adapter-fix-manifest-v2';status='IMPLEMENTATION_CONNECTED_MANAGED_ONLY_NOT_LAUNCH_READY';implementation=$sources;artifacts=$artifacts;authorizedPriorManifestDrift=$authorized;immutable=$before|Where-Object immutable;oldEvidenceManifest=@{path=$oldMF;sha256=Hash $oldMF};reviewManifest=@{path=$reviewMF;sha256=Hash $reviewMF};liveKeys=0;liveGrants=0;sourceClaims=0;EngineRunCalls=0;DockerCalls=0;sourceRequests=0;utc=[DateTimeOffset]::UtcNow.ToString('o')}
Write-Output ('SEALED source='+$sources.Count+' artifacts='+$artifacts.Count+' sha='+(Hash (Join-Path $root 'manifest.json')))
