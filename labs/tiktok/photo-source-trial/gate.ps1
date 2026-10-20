param([switch]$Verify)
$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
. "$PSScriptRoot/source_contract.ps1"
$ev='docs/evidence/tiktok-photo-source-trial-20261011';$script:checks=0
function Check($v,$n){$script:checks++;if(-not $v){throw "GATE_$n"}}
function J($p){SourceRead $p}
$sources=SourceSnapshot;$runtime=SourceRuntimeExpected
Check ($sources.Count -eq 316 -and $runtime.Count -eq 90) 'INVENTORY'
$suite=J "$ev/offline-suite-final.json";$proofs=@();$cases=@('normal','wrong-body','redirect','health-missing','closure-live','closure-missing','preexisting')
Check ($suite.actualExit -eq 0 -and $suite.sourceCalls -eq 0 -and $suite.cases -eq 7 -and -not(Compare-Object $cases @($suite.results.case))) 'FRESH_SUITE'
foreach($e in $suite.results){
 $d=$e.path;$c=J "$d/completion.json";$w=J "$d/worker/result.json";$v=J "$d/validation/whole-result.json"
 Check ($e.actualExit -eq 0 -and $c.actualExit -eq 0 -and $c.stage -ceq 'offline' -and $c.sourceCalls -eq 0 -and $c.ownResourcesLeft -eq 0) 'OFFLINE_NATIVE'
 foreach($p in 'source-before.json','source-after.json'){Check ((CanonicalSource (J "$d/$p")) -ceq (CanonicalSource $sources)) 'EXACT_CODE'}
 $positive=$e.case -eq 'normal';Check ($c.validatorActualExit -eq $(if($positive){0}else{20})) 'EXPECTED_NATIVE'
 if($positive){Check ($v.traceGate -and $v.operationGate -and $v.batchGate -and $v.accountingGate -and $v.technicalFileContract -and $c.proxyActualExit -eq 0 -and $c.workerActualExit -eq 0 -and $w.preparePacket.contract.fullDecode -ceq 'PASS' -and (SourceSHA "$d/worker/image.jpg") -ceq $w.preparePacket.sha256) 'FRESH_METADATA_JPEG_DECODE_SHA'}
 if($e.case -in @('closure-live','closure-missing')){Check ($v.packetFileProvisional -and $v.technicalFileContract -and -not $v.batchGate -and 'image.jpg' -in $v.ownedOutputRemoved -and -not(Test-Path "$d/worker/image.jpg")) 'CLOSURE_PRESERVED'}
 if($e.case -eq 'wrong-body'){Check ($c.workerActualExit -eq 20 -and -not $w.preparePacket -and -not(Test-Path "$d/worker/image.jpg")) 'METADATA_DENY_PREPARE'}
 if($e.case -eq 'preexisting'){$old=J "$d/worker/ownership-before.json";Check ((SourceSHA "$d/worker/image.jpg") -ceq $old.sha) 'OWNERSHIP'}
 $permission=J "$d/worker/permission-network.json";Check ($permission.privateReadDenied -and $permission.noBypass -and $permission.privateTraceUID -eq 65534 -and $permission.privateTraceMode -eq 384) 'PRIVATE_UID_NOBYPASS'
 foreach($role in 'proxy','worker'){$r=J "$d/$role/$role-runtime.json";Check ((CanonicalSource $r.sources) -ceq (CanonicalSource $runtime)) 'FULL_RUNTIME_HASH'}
 foreach($role in 'proxy','worker','validate'){
  $g=J "$d/guard-$role.json";$h=$g.HostConfig;$ram=if($role -eq 'worker'){512MB}else{96MB}
  Check ($g.Image -ceq 'sha256:31742091e95df2cc62669a6c6a9e0892dc09a34341eaeefc16959dcd4dfa417e' -and $h.Memory -eq $ram -and $h.MemorySwap -eq $ram -and $h.ReadonlyRootfs -and -not $h.Privileged -and -not $h.CapAdd -and 'ALL' -in $h.CapDrop -and 'no-new-privileges:true' -in $h.SecurityOpt -and $h.IpcMode -ceq 'private') 'ROLE_GUARDS'
  $st=J "$d/state-$role.json";Check (-not $st.Running -and -not $st.OOMKilled) 'ROLE_STOPPED'
 }
 foreach($f in Get-ChildItem $d -File -Recurse){$proofs+=@{path=[IO.Path]::GetRelativePath((Get-Location).Path,$f.FullName).Replace('\','/');sha256=SourceSHA $f.FullName}}
}
$p=J "$ev/preflight-4/preflight-result.json";$c=J "$ev/preflight-4/completion.json";$guard=J "$ev/preflight-4/guard.json"
Check ($p.status -ceq 'PASS_SOURCE_RUNNER_POLICY_OFFLINE' -and $p.actualExit -eq 0 -and $c.actualExit -eq 0 -and $p.checks.Count -eq 16 -and $p.sourceCalls -eq 0 -and -not $p.claimCreated -and -not $p.sourcePathInvoked -and $p.cookieRAMCleared -and $p.fixtureModulesLoaded.Count -eq 0 -and $p.fdBefore -eq $p.fdAfter -and $p.threadsBefore -eq $p.threadsAfter) 'SOURCE_COLD_POLICY'
Check ($guard.HostConfig.NetworkMode -ceq 'none' -and $p.trustSHA -ceq '9cc2a774b5198dcff14d9be1e66091f538975d867ce029a96bce15a55dfd730f' -and (CanonicalSource $p.reviewedRuntimeSources) -ceq (CanonicalSource $runtime)) 'SOURCE_TRUST_RUNTIME'
foreach($name in 'source-before.json','source-after.json'){Check ((CanonicalSource (J "$ev/preflight-4/$name")) -ceq (CanonicalSource $sources)) 'PREFLIGHT_EXACT'}
$claim=J "$ev/claim-tests-final/result.json";Check ($claim.status -ceq 'PASS_ALLOCATION_CLAIM_OFFLINE' -and $claim.actualExit -eq 0 -and $claim.sourceCalls -eq 0 -and $claim.realClaimsCreated -eq 0 -and $claim.defaultActualExit -eq 20 -and $claim.cases -ge 16 -and $claim.crashActualExit -eq 20 -and $claim.cancelClaimPreserved) 'CLAIM_OFFLINE'
foreach($root in "$ev/preflight-4","$ev/claim-tests-final"){foreach($f in Get-ChildItem $root -File -Recurse){$proofs+=@{path=[IO.Path]::GetRelativePath((Get-Location).Path,$f.FullName).Replace('\','/');sha256=SourceSHA $f.FullName}}}
$proofs+=@{path="$ev/offline-suite-final.json";sha256=SourceSHA "$ev/offline-suite-final.json"}
if($Verify){$g=AssertSourceGate "$ev/offline-gate.json";Check ((CanonicalSource $g.proofs) -ceq (CanonicalSource $proofs)) 'PROOFS_EXACT'}else{
 if(Test-Path "$ev/offline-gate.json"){throw 'Refuse gate reuse'}
 @{version=1;status='PASS_EXACT_SOURCE_WIRING_OFFLINE';actualExit=0;sourceCalls=0;checks=$script:checks;image='sha256:31742091e95df2cc62669a6c6a9e0892dc09a34341eaeefc16959dcd4dfa417e';sources=$sources;runtimeFiles=$runtime.Count;sourceOnlyIsolation=$true;defaultDisabled=$true;claimProbes=$true;proofs=$proofs;utc=[DateTime]::UtcNow.ToString('o');vn=[DateTimeOffset]::UtcNow.ToOffset([TimeSpan]::FromHours(7)).ToString('o')}|ConvertTo-Json -Depth 7|Set-Content "$ev/offline-gate.json"
}
Write-Output "PASS source wiring gate $script:checks / source316 runtime90 / source0";exit 0
