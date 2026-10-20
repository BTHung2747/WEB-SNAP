# Validate untrusted values before PowerShell collection operators or binding casts.
function ScalarString($value){if($value -isnot [string]){throw 'AUTHORITY_SCALAR_STRING_REQUIRED'}}
function StringFields($row,[string[]]$fields){
 if($row -isnot [pscustomobject] -and $row -isnot [Collections.IDictionary]){throw 'AUTHORITY_OBJECT_REQUIRED'}
 foreach($name in $fields){ScalarString $row.$name}
}
function StringSchema($kind,$row){
 switch($kind){
 'gate'{StringFields $row @('scope','status','image','trustSHA','sourceHash','runtimeHash','utc')}
 'proof'{StringFields $row @('role','path','sha256')}
 'row'{StringFields $row @('path','sha256')}
 'allocation'{StringFields $row @('scope','taskID','allocationID','target','expectedID','type','image','trustSHA','sourceHash','runtimeHash','gateSHA','utc','expiresUTC')}
 'authorization'{StringFields $row @('scope','status','taskID','gateSHA','sourceHash','runtimeHash','target','reviewSHA','preclaimSHA','utc','expiresUTC')}
 'review'{StringFields $row @('status','gateSHA','sourceHash','runtimeHash','utc')}
 'claim'{StringFields $row @('scope','status','taskID','allocationID','target','gateSHA','sourceHash','runtimeHash','expiresUTC','utc')}
 default{throw 'UNKNOWN_STRING_SCHEMA'}
 }
}

function SourceSHA($p){ScalarString $p;(Get-FileHash -LiteralPath $p).Hash.ToLowerInvariant()}
function SourceRead($p){Get-Content -LiteralPath $p -Raw|ConvertFrom-Json -DateKind String}
function CanonicalSource($rows){ConvertTo-Json -InputObject @($rows|Sort-Object path|ForEach-Object {[pscustomobject][ordered]@{path=$_.path;sha256=$_.sha256}}) -Depth 4 -Compress}
function SourceSnapshot{
 $paths=@(rg --files labs/tiktok/photo-source-trial-v4-live labs/tiktok/connect-poc/vendor labs/tiktok/photo labs/tiktok/setup-trace apps/media/src/tiktok apps/media/requirements.lock apps/egress/src)
 @($paths|ForEach-Object {[pscustomobject][ordered]@{path=$_.Replace('\','/');sha256=SourceSHA $_}}|Sort-Object path)
}
function SourceRuntimeExpected{
 $roots=@{integration='labs/tiktok/photo-source-trial-v4-live';photo='labs/tiktok/photo';core='apps/media/src/tiktok';trace='labs/tiktok/setup-trace';vendor='labs/tiktok/connect-poc/vendor'}
 @($(foreach($key in $roots.Keys){foreach($p in @(rg --files $roots[$key])){if($p -match '__pycache__' -or $key -eq 'core' -and $p -match 'photo_lab'){continue};[pscustomobject][ordered]@{path=$key+'/'+[IO.Path]::GetRelativePath((Resolve-Path $roots[$key]).Path,(Resolve-Path $p).Path).Replace('\','/');sha256=SourceSHA $p}}})|Sort-Object path)
}

function SourceQuota{[ordered]@{analyze=1;metadataGET=2;imageGET=1;selectedIndex=1;metadataSeconds=30;prepareSeconds=60;metadataResponseBytes=8MB;metadataTotalBytes=16MB;imageInputBytes=20MB;imageOutputBytes=16MB;workflowBytes=36MB;redirect=0;retry=0;HEAD=0;setupSeconds=10;reserveSeconds=1;connectSeconds=10;readSeconds=20;runtimeMiB=608;helperLimit=1;answerCap=64;rawCap=256;dnsProtocol=4;groupCap=4;socketCap=2;prefixCap=8;traceCap=256;ownerCap=32;mapCap=64}}
# Glue appended to successor only. No HTTP/DNS/egress calls.
function SourceRoot{[IO.Path]::GetFullPath('D:\WED SNAP\docs\evidence\tiktok-photo-source-trial-v4-live-20261013')}
function SourceImage{'sha256:31742091e95df2cc62669a6c6a9e0892dc09a34341eaeefc16959dcd4dfa417e'}
function SourceTrust{'9cc2a774b5198dcff14d9be1e66091f538975d867ce029a96bce15a55dfd730f'}
function SourceTarget{'https://www.tiktok.com/@adne_la.veil/photo/7678209751167110421'}
function SourceInteger($v,$expected){($v -is [int] -or $v -is [long]) -and $v -eq $expected}
function SourceRead($path){
 ScalarString $path
 if(-not(Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Item -LiteralPath $path).Length -gt 2MB){throw 'RECEIPT_MISSING_OR_CAP'}
 if((Get-Item -LiteralPath $path).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'RECEIPT_LINK'}
 try{
  $text=Get-Content -LiteralPath $path -Raw;$doc=[Text.Json.JsonDocument]::Parse($text)
  try{AssertJsonKeys $doc.RootElement}finally{$doc.Dispose()}
  $text|ConvertFrom-Json -DateKind String
 }catch{throw 'RECEIPT_MALFORMED'}
}
function ExactKeys($row,[string[]]$keys){
 if(-not $row -or @($row.psobject.Properties.Name).Count -ne $keys.Count -or (Compare-Object $keys @($row.psobject.Properties.Name) -CaseSensitive)){throw 'RECEIPT_SCHEMA'}
}
function FixedQuota($row){
 $expected=SourceQuota;ExactKeys $row @($expected.Keys)
 foreach($k in $expected.Keys){if(-not(SourceInteger $row.$k $expected[$k])){throw 'QUOTA_TYPED_VALUE'}}
}
function FixedPath($path,$expected){
 ScalarString $path;ScalarString $expected
 if((Resolve-Path -LiteralPath $path).Path -cne [IO.Path]::GetFullPath($expected)){throw 'FIXED_NAMESPACE'}
 # Reject symlinks/junctions through every ancestor, not only the final file.
 $node=Get-Item -LiteralPath $path
 while($node){if($node.Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'NAMESPACE_LINK'};$node=if($node -is [IO.FileInfo]){$node.Directory}else{$node.Parent}}
}
function SourceProofRoles{@('cold-v4','authority-v4','whole-v4')}
function SourceEvidence($proofs){
 foreach($p in $proofs){StringSchema 'proof' $p}
 $paths=@(foreach($p in $proofs){Get-ChildItem -LiteralPath (Split-Path $p.path) -Recurse -File|ForEach-Object {[IO.Path]::GetRelativePath((Get-Location).Path,$_.FullName).Replace('\','/')}})
 $paths+=@('freeze.ps1','cold-probe.py','run-cold.ps1','contract-tests.ps1','build-gate.ps1','make-offline-gate.ps1','fixture-authority.ps1')|ForEach-Object {'docs/evidence/tiktok-photo-source-trial-v4-live-20261013/'+$_}
 $paths+=@(Get-ChildItem -LiteralPath (Join-Path (SourceRoot) 'mock') -Recurse -File|ForEach-Object {[IO.Path]::GetRelativePath((Get-Location).Path,$_.FullName).Replace('\','/')})
 @($paths|Sort-Object -Unique|ForEach-Object {[pscustomobject][ordered]@{path=$_;sha256=SourceSHA $_}})
}
function AssertVersions($r){
 StringFields $r @('python');StringFields $r.versions @('requests','urllib3','yt-dlp','aiohappyeyeballs')
 if($r.python -cne '3.11.2' -or $r.versions.requests -cne '2.34.2' -or $r.versions.urllib3 -cne '2.8.0' -or $r.versions.'yt-dlp' -cne '2026.8.19' -or $r.versions.aiohappyeyeballs -cne '2.7.1'){throw 'RUNTIME_PINS'}
}
function ExclusiveReceipt($path,$row){
 ScalarString $path;StringSchema 'claim' $row
 # Public .NET CreateNew+FileShare.None+Flush(true); never truncate existing claim.
 $s=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
 try{$b=[Text.UTF8Encoding]::new($false).GetBytes(($row|ConvertTo-Json -Depth 8));$s.Write($b,0,$b.Length);$s.Flush($true)}finally{$s.Dispose()}
}
# AGPL-3.0 owned authority integration. Existing quotas/path guard/CreateNew API reused.
function AssertJsonKeys($element){
 if($element.ValueKind -eq [Text.Json.JsonValueKind]::Object){$seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase);foreach($p in $element.EnumerateObject()){if(-not $seen.Add($p.Name)){throw 'JSON_DUPLICATE_KEY'};AssertJsonKeys $p.Value}}
 elseif($element.ValueKind -eq [Text.Json.JsonValueKind]::Array){foreach($v in $element.EnumerateArray()){AssertJsonKeys $v}}
}
function RowsHash($rows){
 foreach($r in $rows){ExactKeys $r @('path','sha256');StringSchema 'row' $r}
 $names=[string[]]@($rows.path);[Array]::Sort($names,[StringComparer]::Ordinal);$map=@{};$b=[Text.StringBuilder]::new()
 foreach($r in $rows){if($r.path -match '[\x00\r\n]' -or $r.sha256 -cnotmatch '^[a-f0-9]{64}$' -or $map.ContainsKey($r.path)){throw 'HASH_ROWS_SCHEMA'};$map[$r.path]=$r.sha256}
 foreach($n in $names){$null=$b.Append($n).Append([char]0).Append($map[$n]).Append("`n")}
 [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($b.ToString()))).ToLowerInvariant()
}
function FreshExpiry($utc,$expires){
 ScalarString $utc;ScalarString $expires
 $a=[DateTimeOffset]::MinValue;$b=$a
 if($utc -isnot [string] -or $expires -isnot [string] -or -not $utc.EndsWith('Z') -or -not $expires.EndsWith('Z') -or -not[DateTimeOffset]::TryParse($utc,[ref]$a) -or -not[DateTimeOffset]::TryParse($expires,[ref]$b)){throw 'EXPIRY_SCHEMA'}
 $now=[DateTimeOffset]::UtcNow;if($a -gt $now -or $b -le $now -or $b -le $a -or ($b-$a).TotalSeconds -gt 600){throw 'EXPIRED_OR_INVALID_WINDOW'}
}
function NewIDs($task,$allocation){
 ScalarString $task;ScalarString $allocation
 if($task -isnot [string] -or $allocation -isnot [string] -or $task -cnotmatch '^[a-f0-9]{32}$' -or $allocation -cnotmatch '^[a-f0-9]{32}$' -or $task -in @('903b9cae739f46829b8973f4d94df389','2713473edcf94a139dd91d1d82939d0a') -or $allocation -in @('827c77f493ea4c8fa112f031e1b7b2bc','a0c19e584c614c9badfa47bbc46b35b2')){throw 'NEW_TASK_ALLOCATION_REQUIRED'}
}
function AssertSourceGate($gatePath,[switch]$Mock){
 ScalarString $gatePath
 if(-not $Mock){FixedPath $gatePath (Join-Path (SourceRoot) 'source-gate.json')}else{
  $full=(Resolve-Path -LiteralPath $gatePath).Path;$prefix=Join-Path (SourceRoot) 'mock/gates'
  if(-not $full.StartsWith($prefix+[IO.Path]::DirectorySeparatorChar,[StringComparison]::Ordinal)){throw 'MOCK_GATE_NAMESPACE'};FixedPath $gatePath $full
 }
 $g=SourceRead $gatePath
 StringSchema 'gate' $g
 foreach($p in $g.proofs){StringSchema 'proof' $p};foreach($f in $g.evidence){StringSchema 'row' $f}
 $null=RowsHash $g.sources;$null=RowsHash $g.runtime
 ExactKeys $g @('version','scope','status','actualExit','sourceCalls','sourceGate','image','trustSHA','dnsProtocol','sources','runtime','sourceHash','runtimeHash','quota','proofs','evidence','defaultDisabled','sourceOnlyIsolation','utc')
 if(-not(SourceInteger $g.version 2) -or -not(SourceInteger $g.dnsProtocol 4) -or -not(SourceInteger $g.actualExit 0) -or -not(SourceInteger $g.sourceCalls 0) -or $g.sourceGate -isnot [bool] -or $g.defaultDisabled -isnot [bool] -or -not $g.defaultDisabled -or $g.sourceOnlyIsolation -isnot [bool] -or -not $g.sourceOnlyIsolation -or $g.image -cne (SourceImage) -or $g.trustSHA -cne (SourceTrust)){throw 'V4_GATE_FIELDS'}
 if($Mock){if($g.scope -cne 'OFFLINE_SOURCE_TRIAL_V4_FIXTURE_ONLY' -or $g.status -cne 'PASS_OFFLINE_AUTHORITY_FIXTURE' -or $g.sourceGate){throw 'FIXTURE_GATE_SCOPE'}}
 elseif($g.scope -cne 'ONE_PHOTO_SOURCE_TRIAL_V4' -or $g.status -cne 'PASS_REVIEWED_SOURCE_TRIAL_V4_GATE' -or -not $g.sourceGate){throw 'REAL_SOURCE_GATE_NOT_RELEASED'}
 FixedQuota $g.quota
 if((CanonicalSource $g.sources) -cne (CanonicalSource (SourceSnapshot)) -or (CanonicalSource $g.runtime) -cne (CanonicalSource (SourceRuntimeExpected)) -or $g.sourceHash -cne (RowsHash $g.sources) -or $g.runtimeHash -cne (RowsHash $g.runtime)){throw 'V4_GATE_EXACT_CODE_RUNTIME'}
 $roles=SourceProofRoles
 if($g.proofs.Count -ne 3 -or (Compare-Object $roles @($g.proofs.role)) -or @($g.proofs|Group-Object role|Where-Object Count -ne 1).Count -or @($g.proofs|Group-Object path|Where-Object Count -ne 1).Count){throw 'V4_GATE_PROOF_ROLES'}
 foreach($p in $g.proofs){
  ExactKeys $p @('role','path','sha256');FixedPath $p.path (Join-Path 'D:\WED SNAP' $p.path)
  if(-not $p.path.StartsWith('docs/evidence/tiktok-photo-source-trial-v4-live-20261013/',[StringComparison]::Ordinal) -or $p.path.Contains('..') -or (SourceSHA $p.path) -cne $p.sha256){throw 'V4_PROOF_PATH_HASH'}
  $r=SourceRead $p.path
  if($r.PSObject.Properties.Name -contains 'scope'){ScalarString $r.scope}
  if(-not $Mock){if($p.role -ceq 'cold-v4'){StringFields $r @('status','trustSHA');$null=RowsHash $r.sources}elseif($p.role -ceq 'authority-v4'){StringFields $r @('status')}else{StringFields $r @('stage')}}
  if($Mock){if($r.scope -cne 'OFFLINE_PROOF_FIXTURE_ONLY'){throw 'FIXTURE_PROOF_SCOPE'};continue}
  if($r.scope -ceq 'OFFLINE_PROOF_FIXTURE_ONLY' -or -not(SourceInteger $r.actualExit 0) -or -not(SourceInteger $r.sourceCalls 0)){throw 'LIVE_PROOF_NOT_OFFLINE_ATTESTATION'}
  if($p.role -ceq 'cold-v4'){if($r.status -cne 'PASS_COLD_V4_SOURCE_POLICY_NETWORK_NONE' -or $r.trustSHA -cne (SourceTrust) -or (CanonicalSource $r.sources) -cne (CanonicalSource $g.runtime)){throw 'COLD_V4_PROOF'};AssertVersions $r}
  elseif($p.role -ceq 'authority-v4'){if($r.status -cne 'PASS_V4_AUTHORITY_CONTRACT_OFFLINE'){throw 'AUTHORITY_PROOF'}}
  elseif($r.stage -cne 'offline' -or -not(SourceInteger $r.workerActualExit 0) -or -not(SourceInteger $r.proxyActualExit 0) -or -not(SourceInteger $r.validatorActualExit 0) -or -not(SourceInteger $r.ownResourcesLeft 0)){throw 'WHOLE_V4_PROOF'}
 }
 if(-not $Mock){if(-not $g.evidence -or (CanonicalSource $g.evidence) -cne (CanonicalSource (SourceEvidence $g.proofs))){throw 'EVIDENCE_REQUIRED'};foreach($f in $g.evidence){FixedPath $f.path (Join-Path 'D:\WED SNAP' $f.path);if((SourceSHA $f.path) -cne $f.sha256){throw 'EVIDENCE_DRIFT'}}}
 return $g
}
function AssertSourceAuthorization($gatePath){
 ScalarString $gatePath
 $root=SourceRoot;$g=AssertSourceGate $gatePath
 $authPath=Join-Path $root 'human-source-authorization.json';$reviewPath=Join-Path $root 'independent-review.json'
 FixedPath $authPath $authPath;FixedPath $reviewPath $reviewPath;$a=SourceRead $authPath;$r=SourceRead $reviewPath
 StringSchema 'authorization' $a;StringSchema 'review' $r
 ExactKeys $a @('version','scope','status','taskID','gateSHA','sourceHash','runtimeHash','target','quota','reviewSHA','preclaimSHA','utc','expiresUTC')
 ExactKeys $r @('version','status','actualExit','sourceCalls','gateSHA','sourceHash','runtimeHash','utc')
 if(-not(SourceInteger $a.version 2) -or $a.scope -cne 'ONE_PHOTO_SOURCE_TRIAL_V4' -or $a.status -cne 'HUMAN_AUTHORIZED' -or $a.target -cne (SourceTarget) -or $a.gateSHA -cne (SourceSHA $gatePath) -or $a.sourceHash -cne $g.sourceHash -or $a.runtimeHash -cne $g.runtimeHash -or $a.reviewSHA -cne (SourceSHA $reviewPath)){throw 'HUMAN_V4_AUTH_REQUIRED'}
 FreshExpiry $a.utc $a.expiresUTC;FixedQuota $a.quota
 if(-not(SourceInteger $r.version 2) -or $r.status -cne 'PASS_INDEPENDENT_SOURCE_TRIAL_V4_PREPARATION_REVIEW' -or -not(SourceInteger $r.actualExit 0) -or -not(SourceInteger $r.sourceCalls 0) -or $r.gateSHA -cne $a.gateSHA -or $r.sourceHash -cne $g.sourceHash -or $r.runtimeHash -cne $g.runtimeHash){throw 'INDEPENDENT_V4_REVIEW_REQUIRED'}
 $cold=SourceRead (Join-Path $root 'preclaim/cold-result.json');$completion=SourceRead (Join-Path $root 'preclaim/completion.json');$guard=SourceRead (Join-Path $root 'preclaim/guard.json')
 StringFields $cold @('status','trustSHA');$null=RowsHash $cold.sources
 if($a.preclaimSHA -cne (SourceSHA (Join-Path $root 'preclaim/cold-result.json')) -or $cold.status -cne 'PASS_COLD_V4_SOURCE_POLICY_NETWORK_NONE' -or $cold.trustSHA -cne (SourceTrust) -or (CanonicalSource $cold.sources) -cne (CanonicalSource (SourceRuntimeExpected)) -or -not(SourceInteger $completion.actualExit 0) -or -not(SourceInteger $completion.sourceCalls 0) -or -not(SourceInteger $completion.ownResourcesLeft 0)){throw 'PRECLAIM_V4_ATTESTATION'}
 AssertVersions $cold
 StringFields $guard @('Image');StringFields $guard.Config @('User');StringFields $guard.HostConfig @('NetworkMode','IpcMode');foreach($v in $guard.HostConfig.CapDrop){ScalarString $v};foreach($v in $guard.HostConfig.SecurityOpt){ScalarString $v}
 $h=$guard.HostConfig;if($guard.Image -cne (SourceImage) -or $h.NetworkMode -cne 'none' -or $h.Memory -ne 96MB -or $h.MemorySwap -ne 96MB -or $h.NanoCpus -ne 250000000 -or $guard.Config.User -cne '65534:65534' -or -not $h.ReadonlyRootfs -or $h.Privileged -or $h.CapAdd -or 'ALL' -notin $h.CapDrop -or 'no-new-privileges:true' -notin $h.SecurityOpt -or $h.IpcMode -cne 'private' -or $h.PidsLimit -ne 64){throw 'PRECLAIM_V4_GUARD'}
 return $a
}
function AssertSourceAllocation($allocationPath,$gatePath,[switch]$Mock){
 ScalarString $allocationPath;ScalarString $gatePath
 $g=AssertSourceGate $gatePath -Mock:$Mock;$a=SourceRead $allocationPath
 StringSchema 'allocation' $a
 ExactKeys $a @('version','scope','taskID','allocationID','target','expectedID','type','selectedIndex','image','trustSHA','dnsProtocol','sourceHash','runtimeHash','gateSHA','quota','utc','expiresUTC')
 if(-not(SourceInteger $a.version 2) -or -not(SourceInteger $a.dnsProtocol 4) -or $a.scope -cne $(if($Mock){'OFFLINE_CLAIM_FIXTURE_V4'}else{'ONE_PHOTO_SOURCE_ALLOCATION_V4'}) -or $a.target -cne (SourceTarget) -or $a.expectedID -cne '7678209751167110421' -or $a.type -cne 'photo' -or -not(SourceInteger $a.selectedIndex 1) -or $a.image -cne $g.image -or $a.trustSHA -cne $g.trustSHA -or $a.sourceHash -cne $g.sourceHash -or $a.runtimeHash -cne $g.runtimeHash -or $a.gateSHA -cne (SourceSHA $gatePath)){throw 'V4_ALLOCATION_FIELDS'}
 NewIDs $a.taskID $a.allocationID;FreshExpiry $a.utc $a.expiresUTC;FixedQuota $a.quota
 $taskRoot=Join-Path (SourceRoot) $(if($Mock){"mock/task-$($a.taskID)"}else{"source-task/task-$($a.taskID)"})
 FixedPath $allocationPath (Join-Path $taskRoot "$($a.allocationID)/allocation.json")
 if(-not $Mock){$auth=AssertSourceAuthorization $gatePath;if($auth.taskID -cne $a.taskID -or $a.expiresUTC -cne $auth.expiresUTC){throw 'AUTH_TASK_EXPIRY_MISMATCH'}}
 return @{allocation=$a;gate=$g;taskRoot=$taskRoot;parent=(Get-Item $allocationPath).Directory.FullName}
}
function ClaimSourceAllocation($allocationPath,$gatePath,[switch]$Mock,[scriptblock]$AfterLatch){
 if($AfterLatch -and -not $Mock){throw 'FIXTURE_CALLBACK_ONLY'}
 $v=AssertSourceAllocation $allocationPath $gatePath -Mock:$Mock;$a=$v.allocation
 $latch=Join-Path $v.taskRoot $(if($Mock){'task-latch-mock.json'}else{'task-latch.json'});$claim=Join-Path $v.parent $(if($Mock){'claim-mock.json'}else{'source-claim.json'})
 $row=[ordered]@{version=2;scope=$a.scope;status='CONSUMED_BEFORE_NETWORK_CAPABILITY';taskID=$a.taskID;allocationID=$a.allocationID;target=$a.target;selectedIndex=$a.selectedIndex;dnsProtocol=4;gateSHA=$a.gateSHA;sourceHash=$a.sourceHash;runtimeHash=$a.runtimeHash;expiresUTC=$a.expiresUTC;utc=[DateTime]::UtcNow.ToString('o')}
 ExclusiveReceipt $latch $row
 if($AfterLatch){& $AfterLatch}
 ExclusiveReceipt $claim $row
 return @{allocation=$a;gate=$v.gate;claimPath=$claim;claimSHA=SourceSHA $claim;taskClaimPath=$latch;taskClaimSHA=SourceSHA $latch;gateSHA=$a.gateSHA;allocationSHA=SourceSHA $allocationPath}
}
function AdmissionControl($release){
 StringFields $release @('claimSHA','taskClaimSHA','gateSHA','allocationSHA');StringSchema 'allocation' $release.allocation
 $a=$release.allocation
 @{version=2;scope='ONE_PHOTO_SOURCE_ALLOCATION_V4';taskID=$a.taskID;allocationID=$a.allocationID;target=$a.target;selectedIndex=1;dnsProtocol=4;sourceHash=$a.sourceHash;runtimeHash=$a.runtimeHash;gateSHA=$a.gateSHA;claimSHA=$release.claimSHA;taskClaimSHA=$release.taskClaimSHA;expiresUTC=$a.expiresUTC;quota=SourceQuota}
}
