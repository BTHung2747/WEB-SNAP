param([switch]$Verify,[switch]$TestCanonical,[switch]$TestRuntime)
$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
$ev='docs/evidence/tiktok-wholephoto-source-20261010';$lab='labs/tiktok/wholephoto-source';$script:checks=0
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
 $files=@(rg --files labs/tiktok/wholephoto-source labs/tiktok/wholephoto-connector labs/tiktok/trace-cleanup labs/tiktok/connect-closure-dns labs/tiktok/connect-poc labs/tiktok/photo-trace labs/tiktok/photo labs/tiktok/setup-trace apps/media/src/tiktok apps/media/requirements.lock apps/egress/src/egress.py)
 $rows=@(foreach($p in $files){[pscustomobject]@{path=$p.Replace('\','/');sha256=SHA $p}});@($rows|Sort-Object path)
}
$cases=@('normal','candidate-latency','image-dns-failure','image-tcp-failure','image-cert-failure','image-tls-stall','image-html','wrong-body','redirect','dns-private','health-missing','health-incomplete','trace-cap','trace-open','trace-write','helper-crash','helper-cap','helper-late','helper-answer-cap','handoff-fail','owner-abort','final-close-fail','summary-missing','postfile-diagnostic','preexisting','parent-nonzero','parent-expiry','guards','ssrf-literal','ssrf-host','cancel','proxy-parent-block')
$current=Snapshot;$snapshot=$current|ConvertTo-Json -Depth 4 -Compress
$proofs=@();$roots=@{integration=$lab;photo='labs/tiktok/photo';core='apps/media/src/tiktok';trace='labs/tiktok/setup-trace';vendor='labs/tiktok/connect-poc/vendor'}
function RuntimeCheck($path){
 $r=ReadJson $path
 Check ($r.python -ceq '3.11.2' -and $r.versions.requests -ceq '2.34.2' -and $r.versions.urllib3 -ceq '2.8.0' -and $r.versions.aiohappyeyeballs -ceq '2.7.1' -and $r.versions.'yt-dlp' -ceq '2026.8.19') 'PIN'
 $expected=@(foreach($key in $roots.Keys){foreach($p in @(rg --files $roots[$key])){
  if($p -match '(__pycache__|node_modules)' -or ($key -eq 'core' -and $p -match 'photo_lab')){continue}
  [pscustomobject]@{path=$key+'/'+[IO.Path]::GetRelativePath((Resolve-Path $roots[$key]).Path,(Resolve-Path $p).Path).Replace('\','/');sha256=SHA $p}
 }})|Sort-Object path
 Check ((CanonicalProofs $expected) -ceq (CanonicalProofs $r.sources)) 'FULL_RUNTIME_INVENTORY'
}
if($TestRuntime){RuntimeCheck "$ev/source-policy-5/policy-result.json";Write-Output 'PASS entire72 runtime inventory / source0';exit 0}
$suite=ReadJson "$ev/release-suite-result.json";Check ($suite.actualExit -eq 0 -and $suite.sourceCalls -eq 0 -and $suite.results.Count -eq 32 -and -not(Compare-Object $cases @($suite.results.case))) 'WHOLE_SUITE'
foreach($entry in $suite.results){
 $dir=$entry.path;$c=ReadJson "$dir/completion.json";$r=ReadJson "$dir/validation/whole-result.json";$success=$entry.case -in @('normal','candidate-latency')
 Check ($entry.actualExit -eq 0 -and $c.actualExit -eq 0 -and $c.stage -ceq 'offline' -and $c.ownResourcesLeft -eq 0 -and $c.sourceCalls -eq 0) 'COMPLETION'
 foreach($name in 'source-before.json','source-after.json'){Check (((ReadJson "$dir/$name")|ConvertTo-Json -Depth 4 -Compress) -ceq $snapshot) 'WHOLE_CODE_HASH'}
 RuntimeCheck "$dir/proxy/proxy-runtime.json";RuntimeCheck "$dir/worker/worker-runtime.json"
 $p=ReadJson "$dir/worker/permission-network.json";Check ($p.privateReadDenied -and $p.noBypass -and $p.privateTraceUID -eq 65534 -and $p.privateTraceMode -eq 384) 'PRIVACY_NOBYPASS'
 Check (($c.validatorActualExit -eq 0) -eq $success -and ($r.status -ceq 'PASS_WHOLEPHOTO_OFFLINE') -eq $success) 'EXPECTED_NATIVE'
 if($success){Check ($c.workerActualExit -eq 0 -and $c.proxyActualExit -eq 0 -and $r.parentActualExit -eq 0 -and $r.workerActualExit -eq 0 -and $r.traceGate -and $r.technicalFileContract) 'POSITIVE_ROLES_FILE'}
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
 foreach($file in Get-ChildItem -LiteralPath $dir -File -Recurse){$proofs+=@{path=[IO.Path]::GetRelativePath((Get-Location).Path,$file.FullName).Replace('\','/');sha256=SHA $file.FullName}}
}
$policy=ReadJson "$ev/source-policy-5/policy-result.json";RuntimeCheck "$ev/source-policy-5/policy-result.json"
Check ($policy.status -ceq 'PASS_SOURCE_POLICY_OFFLINE' -and $policy.sourceCalls -eq 0 -and $policy.fixtureModulesLoaded.Count -eq 0 -and $policy.uid -eq 65534) 'SOURCE_BRANCH_OFFLINE_POLICY'
Check (@(Lines "$ev/source-policy-5/native.jsonl"|Where-Object {$_.step -eq 'run' -and $_.actualExit -eq 0}).Count -eq 1) 'POLICY_NATIVE'
foreach($file in Get-ChildItem -LiteralPath "$ev/source-policy-5" -File -Recurse){$proofs+=@{path=[IO.Path]::GetRelativePath((Get-Location).Path,$file.FullName).Replace('\','/');sha256=SHA $file.FullName}}
$proofs+=@{path="$ev/release-suite-result.json";sha256=SHA "$ev/release-suite-result.json"}
if($Verify){
 $receipt=ReadJson "$ev/offline-gate.json";Check ($receipt.status -ceq 'PASS_EXACT_WHOLE_OFFLINE_GATE' -and $receipt.actualExit -eq 0 -and $receipt.cases -eq 32 -and $receipt.image -ceq 'sha256:31742091e95df2cc62669a6c6a9e0892dc09a34341eaeefc16959dcd4dfa417e' -and $receipt.snapshotJSON -ceq $snapshot) 'EXACT_HASH_GATE'
 Check ((CanonicalProofs $receipt.proofs) -ceq (CanonicalProofs $proofs)) 'EXACT_PROOFS_GATE'
}else{
 if(Test-Path "$ev/offline-gate.json"){throw 'Refuse gate reuse'}
 @{status='PASS_EXACT_WHOLE_OFFLINE_GATE';actualExit=0;checks=$script:checks;cases=32;sourceCalls=0;snapshotJSON=$snapshot;sourceFiles=$current.Count;proofs=$proofs;image='sha256:31742091e95df2cc62669a6c6a9e0892dc09a34341eaeefc16959dcd4dfa417e';utc=[DateTime]::UtcNow.ToString('o')}|ConvertTo-Json -Depth 6|Set-Content "$ev/offline-gate.json"
}
Write-Output "PASS exact gate $script:checks checks / source=$($current.Count) / 32 cases";exit 0
