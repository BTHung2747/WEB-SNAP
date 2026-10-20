param([switch]$Verify,[switch]$TestCanonical,[switch]$TestRuntime)
$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
$ev='docs/evidence/tiktok-registry-closure-20261011';$lab='labs/tiktok/wholephoto-registry-closure';$script:checks=0
function Check($v,$code){$script:checks++;if(-not $v){throw "GATE_$code"}}
function SHA($p){(Get-FileHash -LiteralPath $p).Hash.ToLowerInvariant()}
function ReadJson($p){Get-Content -LiteralPath $p -Raw|ConvertFrom-Json}
function Lines($p){if(Test-Path $p){@(Get-Content -LiteralPath $p|Where-Object {$_}|ForEach-Object {$_|ConvertFrom-Json})}else{@()}}
function CanonicalProofs($rows){
 $ordered=@($rows|Sort-Object path|ForEach-Object {[pscustomobject][ordered]@{path=$_.path;sha256=$_.sha256}})
 ConvertTo-Json -InputObject $ordered -Depth 4 -Compress
}
if($TestCanonical){
 $a=@([pscustomobject][ordered]@{path='X';sha256='Y'});$b=@([pscustomobject][ordered]@{sha256='Y';path='X'})
 Check ((CanonicalProofs $a) -ceq (CanonicalProofs $b)) 'CANONICAL_KEY_ORDER'
 $bad=@([pscustomobject]@{path='X';sha256='Z'})
 Check ((CanonicalProofs $a) -cne (CanonicalProofs $bad)) 'HASH_MUTATION_REJECT'
 $bad=@([pscustomobject]@{path='Z';sha256='Y'})
 Check ((CanonicalProofs $a) -cne (CanonicalProofs $bad)) 'PATH_MUTATION_REJECT'
 Check ((CanonicalProofs $a) -cne (CanonicalProofs @())) 'MISSING_PROOF_REJECT'
 Write-Output "PASS canonical gate4 / no source";exit 0
}
function Snapshot{
 $files=@(rg --files labs/tiktok/wholephoto-registry-closure labs/tiktok/wholephoto-batch-validation labs/tiktok/wholephoto-batch labs/tiktok/wholephoto-order labs/tiktok/wholephoto-linkage labs/tiktok/wholephoto-diagnostics labs/tiktok/wholephoto-source labs/tiktok/wholephoto-connector labs/tiktok/trace-cleanup labs/tiktok/connect-closure-dns labs/tiktok/connect-poc labs/tiktok/photo-trace labs/tiktok/photo labs/tiktok/setup-trace apps/media/src/tiktok apps/media/requirements.lock apps/egress/src/egress.py)
 $rows=@(foreach($p in $files){[pscustomobject]@{path=$p.Replace('\','/');sha256=SHA $p}});@($rows|Sort-Object path)
}
$cases=@('normal','candidate-latency','image-dns-failure','image-tcp-failure','image-cert-failure','image-tls-stall','image-html','wrong-body','redirect','dns-private','health-missing','health-incomplete','trace-cap','trace-open','trace-write','helper-crash','helper-cap','helper-late','helper-answer-cap','handoff-fail','owner-abort','final-close-fail','summary-missing','postfile-diagnostic','preexisting','parent-nonzero','parent-expiry','guards','ssrf-literal','ssrf-host','cancel','proxy-parent-block','observer-disjoint','observer-extra','observer-extra-preexisting','observer-order-send','observer-order-header','observer-order-header-preexisting','observer-order-setup','observer-order-reopen','batch-stall-third','batch-fast7','batch-fast45','batch-fast64','batch-admission-postfile','batch-admission-preexisting','batch-phase-missing','batch-epoch-postfile','batchval-groups0','batchval-records-empty','batchval-owner-disjoint','batchval-registry-disjoint','batchval-duplicate-owner','batchval-missing-operation','batchval-record-mismatch','batchval-preexisting','closure-idempotent','closure-live','closure-missing','closure-terminal','closure-error','closure-owner','closure-before-winner','closure-before-handoff','closure-late','closure-extra','closure-preexisting')
$current=Snapshot;$snapshot=$current|ConvertTo-Json -Depth 4 -Compress
$proofs=@();$roots=@{integration=$lab;photo='labs/tiktok/photo';core='apps/media/src/tiktok';trace='labs/tiktok/setup-trace';vendor='labs/tiktok/connect-poc/vendor'}
function RuntimeCheck($path){
 $r=ReadJson $path;if($r.runtime){$r=$r.runtime}
 Check ($r.python -ceq '3.11.2' -and $r.versions.requests -ceq '2.34.2' -and $r.versions.urllib3 -ceq '2.8.0' -and $r.versions.aiohappyeyeballs -ceq '2.7.1' -and $r.versions.'yt-dlp' -ceq '2026.8.19') 'PIN'
 $expected=@(foreach($key in $roots.Keys){foreach($p in @(rg --files $roots[$key])){
  if($p -match '(__pycache__|node_modules)' -or ($key -eq 'core' -and $p -match 'photo_lab')){continue}
  [pscustomobject]@{path=$key+'/'+[IO.Path]::GetRelativePath((Resolve-Path $roots[$key]).Path,(Resolve-Path $p).Path).Replace('\','/');sha256=SHA $p}
 }})|Sort-Object path
 Check ((CanonicalProofs $expected) -ceq (CanonicalProofs $r.sources)) 'FULL_RUNTIME_INVENTORY'
}
if($TestRuntime){RuntimeCheck "$ev/source-policy-1/policy-result.json";Write-Output 'PASS entire88 runtime inventory / source0';exit 0}
$suite=ReadJson "$ev/suite-result.json";Check ($suite.actualExit -eq 0 -and $suite.sourceCalls -eq 0 -and $suite.results.Count -eq 67 -and -not(Compare-Object $cases @($suite.results.case))) 'WHOLE_SUITE'
foreach($entry in $suite.results){
 $dir=$entry.path;$c=ReadJson "$dir/completion.json";$r=ReadJson "$dir/validation/whole-result.json";$success=$entry.case -in @('normal','candidate-latency','batch-stall-third','batch-fast7','closure-idempotent')
 Check ($entry.actualExit -eq 0 -and $c.actualExit -eq 0 -and $c.stage -ceq 'offline' -and $c.ownResourcesLeft -eq 0 -and $c.sourceCalls -eq 0) 'COMPLETION'
 foreach($name in 'source-before.json','source-after.json'){Check (((ReadJson "$dir/$name")|ConvertTo-Json -Depth 4 -Compress) -ceq $snapshot) 'WHOLE_CODE_HASH'}
 RuntimeCheck "$dir/proxy/proxy-runtime.json";RuntimeCheck "$dir/worker/worker-runtime.json"
 $p=ReadJson "$dir/worker/permission-network.json";Check ($p.privateReadDenied -and $p.noBypass -and $p.privateTraceUID -eq 65534 -and $p.privateTraceMode -eq 384) 'PRIVACY_NOBYPASS'
 Check (($c.validatorActualExit -eq 0) -eq $success -and ($r.status -ceq 'PASS_WHOLEPHOTO_OFFLINE') -eq $success) 'EXPECTED_NATIVE'
 if($success){Check ($r.operationGate -and $r.batchGate -and $r.accountingVersion -eq 3 -and $r.accountingGate -and $r.requestAccounting.exact -and $c.workerActualExit -eq 0 -and $c.proxyActualExit -eq 0 -and $r.parentActualExit -eq 0 -and $r.workerActualExit -eq 0 -and $r.traceGate -and $r.technicalFileContract) 'POSITIVE_ROLES_FILE'}
 $native=@(Lines "$dir/native.jsonl")
 Check (@($native|Where-Object {$_.step -eq 'remove' -and $_.actualExit -eq 0}).Count -eq 3 -and @($native|Where-Object {$_.step -eq 'network-remove' -and $_.actualExit -eq 0}).Count -eq 2) 'OWN_CLEANUP'
 foreach($n in $native|Where-Object step -eq 'network-inspect'){Check (@($n.stdout|ConvertFrom-Json)[0].Internal) 'OFFLINE_INTERNAL'}
 foreach($role in 'proxy','worker','validate'){
  $g=ReadJson "$dir/guard-$role.json";$h=$g.HostConfig;$ram=if($role -eq 'worker'){512MB}else{96MB};$uid=if($role -eq 'worker'){'1000:1000'}else{'65534:65534'}
  Check ($g.Image -ceq 'sha256:31742091e95df2cc62669a6c6a9e0892dc09a34341eaeefc16959dcd4dfa417e' -and $h.Memory -eq $ram -and $h.MemorySwap -eq $ram -and $h.ReadonlyRootfs -and -not $h.Privileged -and 'ALL' -in $h.CapDrop -and 'no-new-privileges:true' -in $h.SecurityOpt -and $h.IpcMode -ceq 'private' -and $g.Config.User -ceq $uid) 'ROLE_GUARD'
  $s=ReadJson "$dir/state-$role.json";Check (-not $s.Running -and -not $s.OOMKilled) 'ROLE_STOPPED'
 }
 if($entry.case -in @('final-close-fail','summary-missing','postfile-diagnostic')){Check ($r.packetFileProvisional -and $r.actualExit -eq 20 -and 'image.jpg' -in $r.ownedOutputRemoved -and -not(Test-Path "$dir/worker/image.jpg")) 'POSTFILE_REJECT'}
 if($entry.case -eq 'preexisting'){$prior=ReadJson "$dir/worker/ownership-before.json";Check ((SHA "$dir/worker/image.jpg") -ceq $prior.sha) 'PREEXISTING'}
 if($entry.case -in @('parent-expiry','parent-nonzero')){Check (-not(Test-Path "$dir/worker/image.jpg.part")) 'PARTIAL_CLEANUP'}
 if($entry.case -in @('observer-disjoint','observer-extra','observer-extra-preexisting','observer-order-send','observer-order-header','observer-order-header-preexisting','observer-order-setup','observer-order-reopen')){
  Check ($r.packetFileProvisional -and $r.technicalFileContract -and -not $r.accountingGate -and $r.actualExit -eq 20 -and $c.workerActualExit -eq 0 -and $c.proxyActualExit -eq 0 -and 'image.jpg' -in $r.ownedOutputRemoved -and -not(Test-Path "$dir/worker/image.jpg")) 'ACTUAL_PROVISIONAL_LINKAGE_REJECT'
  if($entry.case -in @('observer-extra-preexisting','observer-order-header-preexisting')){$prior=ReadJson "$dir/worker/ownership-before.json";Check ((SHA "$dir/worker/keep.bin") -ceq $prior.unrelatedSHA) 'UNRELATED_PREEXISTING'}
  if($entry.case -like 'observer-order-*'){
   Check ($r.requestAccounting.linkageCoverage.status -ceq 'PARTIAL' -and @($r.requestAccounting.linkageCoverage.reasonCodes|Where-Object {$_ -like 'ORDER_*'}).Count -gt 0 -and $r.requestAccounting.budgetWithinCaps -and $r.requestAccounting.requestSendBegin.metadata -ceq 'UNKNOWN' -and -not(Test-Path "$dir/worker/image.jpg.part")) 'ORDER_REASON_BUDGET_CLEANUP'
   $injection=ReadJson "$dir/worker/observer-injection.json";Check ($injection.packetUnchanged -and $injection.orderOnlyFixture -and $injection.terminalSequencePreserved) 'ORDER_ONLY_INJECTION'
  }
 }
 foreach($file in Get-ChildItem -LiteralPath $dir -File -Recurse){$proofs+=@{path=[IO.Path]::GetRelativePath((Get-Location).Path,$file.FullName).Replace('\','/');sha256=SHA $file.FullName}}
}
$probe=ReadJson "$ev/probe-1/probe-result.json"
Check ($probe.accountingCases -eq 71 -and $probe.indexCases -eq 7 -and $probe.batchCases -eq 4 -and $probe.runtime.sources.Count -eq 88) 'NARROW82_COVERAGE'
foreach($test in $probe.accounting|Where-Object scope -eq 'ACCOUNTING_ORDER_GATE'){
 Check ($test.accountingGateActualExit -eq $(if($test.accepted){0}else{20}) -and $test.receipt.exact -eq $test.accepted -and $test.packetUnchanged -and $test.observerUnchanged -and $test.sourceCalls -eq 0) 'ORDER_NATIVE_IDENTITY'
 if(-not $test.accepted){Check ($test.expectedReason -in $test.receipt.linkageCoverage.reasonCodes -and $test.receipt.linkageCoverage.status -ceq 'PARTIAL' -and $test.receipt.requestSendBegin.metadata -ceq 'UNKNOWN' -and $test.receipt.budgetWithinCaps) 'ORDER_CONTRADICTION_REJECT'}
}
Check ($probe.status -ceq 'PASS_DIAGNOSTIC_PROBES' -and $probe.actualExit -eq 0 -and $probe.sourceCalls -eq 0 -and $probe.fdBefore -eq $probe.fdAfter -and $probe.threadsBefore -eq $probe.threadsAfter) 'NARROW_PROBES'
Check ((CanonicalProofs $probe.runtime.sources) -ceq (CanonicalProofs (ReadJson "$ev/source-policy-1/policy-result.json").sources)) 'PROBE_SAME_RUNTIME'
foreach($f in Get-ChildItem "$ev/probe-1" -File -Recurse){$proofs+=@{path=[IO.Path]::GetRelativePath((Get-Location).Path,$f.FullName).Replace('\','/');sha256=SHA $f.FullName}}
$policy=ReadJson "$ev/source-policy-1/policy-result.json";RuntimeCheck "$ev/source-policy-1/policy-result.json"
Check ($policy.status -ceq 'PASS_SOURCE_POLICY_OFFLINE' -and $policy.sourceCalls -eq 0 -and $policy.fixtureModulesLoaded.Count -eq 0 -and $policy.uid -eq 65534) 'SOURCE_BRANCH_OFFLINE_POLICY'
Check (@(Lines "$ev/source-policy-1/native.jsonl"|Where-Object {$_.step -eq 'run' -and $_.actualExit -eq 0}).Count -eq 1) 'POLICY_NATIVE'
foreach($file in Get-ChildItem -LiteralPath "$ev/source-policy-1" -File -Recurse){$proofs+=@{path=[IO.Path]::GetRelativePath((Get-Location).Path,$file.FullName).Replace('\','/');sha256=SHA $file.FullName}}
$policy=ReadJson "$ev/policy-1/probe-result.json"
Check ($probe.unchangedContracts -eq 78 -and $probe.derivedBatchCases -eq 4 -and $policy.status -ceq 'PASS_BATCH_POLICY_OFFLINE' -and $policy.newCases -eq 55) '78_DERIVED4_NEW55'
RuntimeCheck "$ev/policy-1/probe-result.json" # runtime wrapper handled below
foreach($test in $probe.batches){
 $valid=$test.case -ne 'many45_trace_cap'
 Check ($test.connectorGateActualExit -eq $(if($valid){0}else{20}) -and $test.diagnosticGateActualExit -eq 0 -and $test.socketsLeft -eq 0 -and $test.pending -eq 0 -and $test.groups -le 4) 'DERIVED_MAPPING_NATIVE'
 if(-not $valid){Check (($test.attemptedNumericIndices -join ',') -ceq '1,2,3,4,5,6,7,8' -and $test.suffixUnknown -eq 37 -and $test.status -ceq 'TRACE_ADMISSION_LIMIT') 'BOUNDED45_NOT_UNREACHABLE'}
}
foreach($f in Get-ChildItem "$ev/policy-1" -File -Recurse){$proofs+=@{path=[IO.Path]::GetRelativePath((Get-Location).Path,$f.FullName).Replace('\','/');sha256=SHA $f.FullName}}
$validation=ReadJson "$ev/validation-1/probe-result.json"
Check ($validation.status -ceq 'PASS_BATCH_RECEIPT_TRACE_PROBES' -and $validation.newCases -eq 55 -and $validation.fdBefore -eq $validation.fdAfter) 'VALIDATION55_NATIVE'
RuntimeCheck "$ev/validation-1/probe-result.json"
foreach($test in $validation.cases){Check ($test.nativeExit -eq $(if($test.case -eq 'fresh_control'){0}else{20}) -and $test.validation.accepted -eq ($test.case -eq 'fresh_control') -and $test.receiptUnchanged -and $test.traceUnchanged) 'VALIDATION_NATIVE_CONFLICTS'}
foreach($file in Get-ChildItem "$ev/validation-1" -File -Recurse){$proofs+=@{path=[IO.Path]::GetRelativePath((Get-Location).Path,$file.FullName).Replace('\','/');sha256=SHA $file.FullName}}
$closure=ReadJson "$ev/closure-1/probe-result.json"
Check ($closure.status -ceq 'PASS_REGISTRY_CLOSURE_OFFLINE' -and $closure.newCases -eq 55 -and $closure.validationCases -eq 47 -and $closure.physicalCases -eq 8 -and $closure.fdBefore -eq $closure.fdAfter -and $closure.threadsBefore -eq $closure.threadsAfter) 'CLOSURE55'
RuntimeCheck "$ev/closure-1/probe-result.json"
foreach($c in $closure.cases){Check ($c.nativeExit -eq $(if($c.case -in @('fresh_single_close','fresh_real_idempotent_close')){0}else{20}) -and $c.inputUnchanged -and $c.validation.accepted -eq ($c.nativeExit -eq 0)) 'CLOSURE_NATIVE_0_20'}
foreach($c in $closure.physical){Check ($c.physicalSocketsLeft -eq 0 -and $c.pending -eq 0 -and $c.FD_before -eq $c.FD_after -and $c.diagnosticNativeExit -eq $(if($c.case -in @('once','twice')){0}else{20})) 'CLOSURE_PHYSICAL_INCOMPLETE'}
foreach($f in Get-ChildItem "$ev/closure-1" -File -Recurse){$proofs+=@{path=[IO.Path]::GetRelativePath((Get-Location).Path,$f.FullName).Replace('\','/');sha256=SHA $f.FullName}}
$proofs+=@{path="$ev/suite-result.json";sha256=SHA "$ev/suite-result.json"}
if($Verify){
 $receipt=ReadJson "$ev/offline-gate.json";Check ($receipt.status -ceq 'PASS_EXACT_WHOLE_OFFLINE_GATE' -and $receipt.actualExit -eq 0 -and $receipt.cases -eq 67 -and $receipt.image -ceq 'sha256:31742091e95df2cc62669a6c6a9e0892dc09a34341eaeefc16959dcd4dfa417e' -and $receipt.snapshotJSON -ceq $snapshot) 'EXACT_HASH_GATE'
 Check ((CanonicalProofs $receipt.proofs) -ceq (CanonicalProofs $proofs)) 'EXACT_PROOFS_GATE'
}else{
 if(Test-Path "$ev/offline-gate.json"){throw 'Refuse gate reuse'}
 @{status='PASS_EXACT_WHOLE_OFFLINE_GATE';actualExit=0;checks=$script:checks;cases=67;sourceCalls=0;snapshotJSON=$snapshot;sourceFiles=$current.Count;proofs=$proofs;image='sha256:31742091e95df2cc62669a6c6a9e0892dc09a34341eaeefc16959dcd4dfa417e';utc=[DateTime]::UtcNow.ToString('o')}|ConvertTo-Json -Depth 6|Set-Content "$ev/offline-gate.json"
}
Write-Output "PASS exact gate $script:checks checks / source=$($current.Count) / 67 cases";exit 0