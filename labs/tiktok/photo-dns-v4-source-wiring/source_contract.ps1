function SourceSHA($p){(Get-FileHash -LiteralPath $p).Hash.ToLowerInvariant()}
function SourceRead($p){Get-Content -LiteralPath $p -Raw|ConvertFrom-Json -DateKind String}
function CanonicalSource($rows){ConvertTo-Json -InputObject @($rows|Sort-Object path|ForEach-Object {[pscustomobject][ordered]@{path=$_.path;sha256=$_.sha256}}) -Depth 4 -Compress}
function SourceSnapshot{
 $paths=@(rg --files labs/tiktok/photo-dns-v4-source-wiring labs/tiktok/connect-poc/vendor labs/tiktok/photo labs/tiktok/setup-trace apps/media/src/tiktok apps/media/requirements.lock apps/egress/src)
 @($paths|ForEach-Object {[pscustomobject][ordered]@{path=$_.Replace('\','/');sha256=SourceSHA $_}}|Sort-Object path)
}
function SourceRuntimeExpected{
 $roots=@{integration='labs/tiktok/photo-dns-v4-source-wiring';photo='labs/tiktok/photo';core='apps/media/src/tiktok';trace='labs/tiktok/setup-trace';vendor='labs/tiktok/connect-poc/vendor'}
 @($(foreach($key in $roots.Keys){foreach($p in @(rg --files $roots[$key])){if($p -match '__pycache__' -or $key -eq 'core' -and $p -match 'photo_lab'){continue};[pscustomobject][ordered]@{path=$key+'/'+[IO.Path]::GetRelativePath((Resolve-Path $roots[$key]).Path,(Resolve-Path $p).Path).Replace('\','/');sha256=SourceSHA $p}}})|Sort-Object path)
}

function SourceQuota{[ordered]@{analyze=1;metadataGET=2;imageGET=1;selectedIndex=1;metadataSeconds=30;prepareSeconds=60;metadataResponseBytes=8MB;metadataTotalBytes=16MB;imageInputBytes=20MB;imageOutputBytes=16MB;workflowBytes=36MB;redirect=0;retry=0;HEAD=0;setupSeconds=10;reserveSeconds=1;connectSeconds=10;readSeconds=20;runtimeMiB=608;helperLimit=1;answerCap=64;groupCap=4;socketCap=2;prefixCap=8;traceCap=256;ownerCap=32;mapCap=64}}
# Glue appended to successor only. No HTTP/DNS/egress calls.
function SourceRoot{[IO.Path]::GetFullPath('D:\WED SNAP\docs\evidence\tiktok-photo-dns-v4-source-wiring-20261013')}
function SourceImage{'sha256:31742091e95df2cc62669a6c6a9e0892dc09a34341eaeefc16959dcd4dfa417e'}
function SourceTrust{'9cc2a774b5198dcff14d9be1e66091f538975d867ce029a96bce15a55dfd730f'}
function SourceTarget{'https://www.tiktok.com/@adne_la.veil/photo/7678209751167110421'}
function SourceInteger($v,$expected){($v -is [int] -or $v -is [long]) -and $v -eq $expected}
function SourceRead($path){
 if(-not(Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Item -LiteralPath $path).Length -gt 2MB){throw 'RECEIPT_MISSING_OR_CAP'}
 if((Get-Item -LiteralPath $path).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'RECEIPT_LINK'}
 try{Get-Content -LiteralPath $path -Raw|ConvertFrom-Json -DateKind String}catch{throw 'RECEIPT_MALFORMED'}
}
function ExactKeys($row,[string[]]$keys){
 if(-not $row -or @($row.psobject.Properties.Name).Count -ne $keys.Count -or (Compare-Object $keys @($row.psobject.Properties.Name))){throw 'RECEIPT_SCHEMA'}
}
function FixedQuota($row){
 $expected=SourceQuota;ExactKeys $row @($expected.Keys)
 foreach($k in $expected.Keys){if(-not(SourceInteger $row.$k $expected[$k])){throw 'QUOTA_TYPED_VALUE'}}
}
function FixedPath($path,$expected){
 if((Resolve-Path -LiteralPath $path).Path -cne [IO.Path]::GetFullPath($expected)){throw 'FIXED_NAMESPACE'}
 # Reject symlinks/junctions through every ancestor, not only the final file.
 $node=Get-Item -LiteralPath $path
 while($node){if($node.Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'NAMESPACE_LINK'};$node=if($node -is [IO.FileInfo]){$node.Directory}else{$node.Parent}}
}
function SourceProofRoles{@('cold','contract','normal')}
function SourceEvidence($proofs){
 $paths=@(foreach($p in $proofs){Get-ChildItem -LiteralPath (Split-Path $p.path) -Recurse -File|ForEach-Object {[IO.Path]::GetRelativePath((Get-Location).Path,$_.FullName).Replace('\','/')}})
 $paths+=@('freeze.ps1','cold-probe.py','probe.py','run-narrow.ps1','run-contract.ps1','build-gate.ps1')|ForEach-Object {'docs/evidence/tiktok-photo-dns-v4-source-wiring-20261013/'+$_}
 @($paths|Sort-Object -Unique|ForEach-Object {[pscustomobject][ordered]@{path=$_;sha256=SourceSHA $_}})
}
function AssertSourceGate($gatePath,[switch]$Mock){
 if(-not $Mock){FixedPath $gatePath (Join-Path (SourceRoot) 'offline-gate.json')}
 $g=SourceRead $gatePath
 ExactKeys $g @('version','status','actualExit','sourceCalls','image','trustSHA','sources','runtime','sourceHash','quota','proofs','evidence','defaultDisabled','sourceOnlyIsolation','utc')
 if(-not(SourceInteger $g.version 1) -or -not(SourceInteger $g.actualExit 0) -or -not(SourceInteger $g.sourceCalls 0) -or $g.status -cne 'PASS_EXACT_DNS_SOURCE_WIRING_OFFLINE' -or $g.image -cne (SourceImage) -or $g.trustSHA -cne (SourceTrust) -or $g.defaultDisabled -isnot [bool] -or -not $g.defaultDisabled -or $g.sourceOnlyIsolation -isnot [bool] -or -not $g.sourceOnlyIsolation){throw 'GATE_FIELDS'}
 FixedQuota $g.quota
 if((CanonicalSource $g.sources) -cne (CanonicalSource (SourceSnapshot)) -or (CanonicalSource $g.runtime) -cne (CanonicalSource (SourceRuntimeExpected))){throw 'GATE_EXACT_CODE_RUNTIME'}
 $bytes=[Text.Encoding]::UTF8.GetBytes((CanonicalSource $g.sources));$hash=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
 if($g.sourceHash -cne $hash){throw 'GATE_CODE_HASH'}
 $roles=SourceProofRoles
 if($g.proofs.Count -ne $roles.Count -or (Compare-Object $roles @($g.proofs.role)) -or @($g.proofs|Group-Object role|Where-Object Count -ne 1).Count -or @($g.proofs|Group-Object path|Where-Object Count -ne 1).Count){throw 'GATE_PROOF_ROLES'}
 foreach($p in $g.proofs){
  ExactKeys $p @('role','path','sha256')
  if($p.path -isnot [string] -or -not $p.path.StartsWith('docs/evidence/tiktok-photo-dns-v4-source-wiring-20261013/',[StringComparison]::Ordinal) -or $p.path.Contains('..') -or $p.sha256 -cnotmatch '^[a-f0-9]{64}$'){throw 'GATE_PROOF_PATH'}
  FixedPath $p.path (Join-Path 'D:\WED SNAP' $p.path)
  if((SourceSHA $p.path) -cne $p.sha256){throw 'GATE_PROOF_DRIFT'}
  $r=SourceRead $p.path
  if($r.scope -ceq 'OFFLINE_PROOF_FIXTURE_ONLY'){if(-not $Mock){throw 'MOCK_PROOF_IS_NOT_SOURCE_GATE'};continue}
  if(-not(SourceInteger $r.actualExit 0) -or -not(SourceInteger $r.sourceCalls 0)){throw 'GATE_PROOF_EXIT_OR_SCOPE'}
  if($p.role -ceq 'cold'){
   if($r.status -cne 'PASS_COLD_SOURCE_POLICY_NETWORK_NONE' -or $r.trustSHA -cne (SourceTrust) -or (CanonicalSource $r.sources) -cne (CanonicalSource $g.runtime)){throw 'COLD_RUNTIME_TRUST'}
   AssertVersions $r
  }elseif($p.role -ceq 'contract'){
   if($r.status -cne 'PASS_SOURCE_AUTHORITY_CONTRACT_OFFLINE'){throw 'CONTRACT_PROOF'}
  }elseif($r.stage -cne 'offline' -or -not(SourceInteger $r.workerActualExit 0) -or -not(SourceInteger $r.proxyActualExit 0) -or -not(SourceInteger $r.validatorActualExit 0) -or -not(SourceInteger $r.ownResourcesLeft 0)){throw 'NORMAL_WHOLE_NATIVE'}
 }
 if(-not $Mock){
  if(-not $g.evidence -or (CanonicalSource $g.evidence) -cne (CanonicalSource (SourceEvidence $g.proofs))){throw 'GATE_RAW_EVIDENCE_DRIFT'}
  foreach($f in $g.evidence){if((SourceSHA $f.path) -cne $f.sha256){throw 'GATE_RAW_EVIDENCE_DRIFT'}}
 }
 return $g
}
function AssertVersions($r){
 if($r.python -cne '3.11.2' -or $r.versions.requests -cne '2.34.2' -or $r.versions.urllib3 -cne '2.8.0' -or $r.versions.'yt-dlp' -cne '2026.8.19' -or $r.versions.aiohappyeyeballs -cne '2.7.1'){throw 'RUNTIME_PINS'}
}
function AssertPreclaim($expectedSHA){
 $root=SourceRoot;$r=SourceRead "$root/preclaim/cold-result.json";$c=SourceRead "$root/preclaim/completion.json";$g=SourceRead "$root/preclaim/guard.json";$h=$g.HostConfig
 if($expectedSHA -cne (SourceSHA "$root/preclaim/cold-result.json") -or $r.status -cne 'PASS_COLD_SOURCE_POLICY_NETWORK_NONE' -or $r.trustSHA -cne (SourceTrust) -or (CanonicalSource $r.sources) -cne (CanonicalSource (SourceRuntimeExpected)) -or -not(SourceInteger $r.actualExit 0) -or -not(SourceInteger $c.actualExit 0) -or -not(SourceInteger $c.sourceCalls 0) -or -not(SourceInteger $c.ownResourcesLeft 0)){throw 'PRECLAIM_ATTESTATION'}
 AssertVersions $r
 if($g.Image -cne (SourceImage) -or $g.Config.User -cne '65534:65534' -or $h.NetworkMode -cne 'none' -or $h.Memory -ne 96MB -or $h.MemorySwap -ne 96MB -or $h.NanoCpus -ne 250000000 -or $h.PidsLimit -ne 64 -or $h.IpcMode -cne 'private' -or -not $h.ReadonlyRootfs -or $h.Privileged -or $h.CapAdd -or 'ALL' -notin $h.CapDrop -or 'no-new-privileges:true' -notin $h.SecurityOpt){throw 'PRECLAIM_GUARD'}
}

function AssertSourceAuthorization($gatePath){
 $root=SourceRoot;$a=SourceRead (Join-Path $root 'human-source-authorization.json');$review=SourceRead (Join-Path $root 'independent-review.json')
 ExactKeys $a @('version','status','scope','taskID','gateSHA','target','quota','reviewSHA','preclaimSHA','utc')
 ExactKeys $review @('version','status','actualExit','gateSHA','sourceHash','sourceCalls','utc')
 $g=AssertSourceGate $gatePath
 if(-not(SourceInteger $a.version 1) -or $a.status -cne 'HUMAN_AUTHORIZED' -or $a.scope -cne 'ONE_PHOTO_SOURCE_TRIAL' -or $a.taskID -cnotmatch '^[a-f0-9]{32}$' -or $a.target -cne (SourceTarget) -or $a.gateSHA -cne (SourceSHA $gatePath) -or $a.reviewSHA -cne (SourceSHA (Join-Path $root 'independent-review.json'))){throw 'HUMAN_SOURCE_AUTH_REQUIRED'}
 FixedQuota $a.quota
 AssertPreclaim $a.preclaimSHA
 if(-not(SourceInteger $review.version 1) -or -not(SourceInteger $review.actualExit 0) -or -not(SourceInteger $review.sourceCalls 0) -or $review.status -cne 'PASS_INDEPENDENT_SOURCE_WIRING_AUDIT' -or $review.gateSHA -cne $a.gateSHA -or $review.sourceHash -cne $g.sourceHash){throw 'INDEPENDENT_REVIEW_REQUIRED'}
 foreach($stamp in @($a.utc,$review.utc)){$time=[DateTimeOffset]::MinValue;if($stamp -isnot [string] -or -not [DateTimeOffset]::TryParse($stamp,[ref]$time)){throw 'AUTH_UTC'}}
 return $a
}
function AssertSourceAllocation($allocationPath,$gatePath,[switch]$Mock){
 $g=AssertSourceGate $gatePath -Mock:$Mock;$a=SourceRead $allocationPath
 ExactKeys $a @('version','scope','taskID','allocationID','target','expectedID','type','selectedIndex','image','trustSHA','sourceHash','gateSHA','quota','utc')
 if(-not(SourceInteger $a.version 1) -or $a.scope -cne $(if($Mock){'OFFLINE_CLAIM_FIXTURE'}else{'ONE_PHOTO_SOURCE_ALLOCATION'}) -or $a.taskID -cnotmatch '^[a-f0-9]{32}$' -or $a.allocationID -cnotmatch '^[a-f0-9]{32}$' -or $a.target -cne (SourceTarget) -or $a.expectedID -cne '7678209751167110421' -or $a.type -cne 'photo' -or -not(SourceInteger $a.selectedIndex 1) -or $a.image -cne $g.image -or $a.trustSHA -cne $g.trustSHA -or $a.sourceHash -cne $g.sourceHash -or $a.gateSHA -cne (SourceSHA $gatePath)){throw 'ALLOCATION_FIELDS'}
 FixedQuota $a.quota
 $time=[DateTimeOffset]::MinValue;if($a.utc -isnot [string] -or -not[DateTimeOffset]::TryParse($a.utc,[ref]$time)){throw 'ALLOCATION_UTC'}
 $root=SourceRoot
 if($Mock){$prefix=Join-Path $root 'mock';$full=(Resolve-Path -LiteralPath $allocationPath).Path;if(-not $full.StartsWith($prefix+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'MOCK_NAMESPACE'}}
 else{$auth=AssertSourceAuthorization $gatePath;if($auth.taskID -cne $a.taskID){throw 'TASK_MISMATCH'}}
 $parent=(Get-Item -LiteralPath $allocationPath).Directory.FullName
 if($Mock){$taskRoot=Split-Path $parent;if((Split-Path $taskRoot -Leaf) -cne ('task-'+$a.taskID)){throw 'MOCK_TASK_MISMATCH'}}else{$taskRoot=Join-Path $root 'source-task'}
 FixedPath $allocationPath (Join-Path $taskRoot "$($a.allocationID)/allocation.json")
 return @{allocation=$a;taskRoot=$taskRoot;parent=$parent;gate=$g}
}
function ExclusiveReceipt($path,$row){
 # Public .NET CreateNew+FileShare.None+Flush(true); never truncate existing claim.
 $s=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
 try{$b=[Text.UTF8Encoding]::new($false).GetBytes(($row|ConvertTo-Json -Depth 8));$s.Write($b,0,$b.Length);$s.Flush($true)}finally{$s.Dispose()}
}
function ClaimSourceAllocation($allocationPath,$gatePath,[switch]$Mock,[scriptblock]$AfterLatch){
 if($AfterLatch -and -not $Mock){throw 'TEST_CALLBACK_DENIED'}
 $v=AssertSourceAllocation $allocationPath $gatePath -Mock:$Mock;$a=$v.allocation
 $latch=Join-Path $v.taskRoot $(if($Mock){'task-latch-mock.json'}else{'task-latch.json'})
 $claim=Join-Path $v.parent $(if($Mock){'claim-mock.json'}else{'source-claim.json'})
 ExclusiveReceipt $latch @{taskID=$a.taskID;allocationID=$a.allocationID;scope=$a.scope;status='CONSUMED_BEFORE_NETWORK_CAPABILITY';gateSHA=$a.gateSHA;utc=[DateTime]::UtcNow.ToString('o')}
 if($AfterLatch){& $AfterLatch} # Offline fault injection only. Consumed latch is never undone.
 ExclusiveReceipt $claim @{taskID=$a.taskID;allocationID=$a.allocationID;scope=$a.scope;status='CONSUMED_BEFORE_NETWORK_CAPABILITY';gateSHA=$a.gateSHA;allocationSHA=SourceSHA $allocationPath;utc=[DateTime]::UtcNow.ToString('o')}
 return @{allocation=$a;claimPath=$claim;claimSHA=SourceSHA $claim;taskClaimPath=$latch;taskClaimSHA=SourceSHA $latch;gateSHA=$a.gateSHA;allocationSHA=SourceSHA $allocationPath}
}
