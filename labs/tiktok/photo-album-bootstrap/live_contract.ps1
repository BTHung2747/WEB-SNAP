# AGPL-3.0 album binding reader/validator/consumer. v4 authority primitives reused.
. "$PSScriptRoot/album_authority.ps1"
function SameValue($a,$b){
 if($null -eq $a -or $null -eq $b){return $null -eq $a -and $null -eq $b}
 if($a -is [bool] -or $b -is [bool]){return $a -is [bool] -and $b -is [bool] -and $a -ceq $b}
 if(($a -is [int] -or $a -is [long]) -and ($b -is [int] -or $b -is [long])){return $a -eq $b}
 if($a.GetType() -ne $b.GetType()){return $false}
 if($a -is [array]){if($a.Count -ne $b.Count){return $false};for($i=0;$i -lt $a.Count;$i++){if(-not(SameValue $a[$i] $b[$i])){return $false}};return $true}
 if($a -is [pscustomobject]){$ak=@($a.psobject.Properties.Name|Sort-Object);$bk=@($b.psobject.Properties.Name|Sort-Object);if(($ak -join ',') -cne ($bk -join ',')){return $false};foreach($k in $ak){if(-not(SameValue $a.$k $b.$k)){return $false}};return $true}
 return $a -ceq $b
}
function HashFields($row,[string[]]$fields){foreach($k in $fields){ScalarString $row.$k;if($row.$k -cnotmatch '^[a-f0-9]{64}$'){throw 'LIVE_HASH_SCHEMA'}}}
function BundleRow($dir,$name){$p=Join-Path $dir $name;FixedPath $p $p;return SourceRead $p}
function ColdGuardStrings($value,[string[]]$expected){
 # Actual JSON value stays untyped: never coerce/wrap a scalar into an array.
 if($value -isnot [array] -or $value.Count -ne $expected.Count){throw 'COLD_GUARD_COLLECTION_SCHEMA'}
 for($i=0;$i -lt $value.Count;$i++){if($value[$i] -isnot [string] -or $value[$i] -cne $expected[$i]){throw 'COLD_GUARD_COLLECTION_SCHEMA'}}
}
function ColdGuardCollections($h){
 if($h -isnot [pscustomobject]){throw 'COLD_GUARD_COLLECTION_SCHEMA'}
 foreach($key in 'CapDrop','SecurityOpt','CapAdd','ExtraHosts'){if($key -cnotin @($h.psobject.Properties.Name)){throw 'COLD_GUARD_COLLECTION_SCHEMA'}}
 # Frozen measured cold profile: one ALL and one NNP, implicit default seccomp.
 ColdGuardStrings $h.CapDrop @('ALL');ColdGuardStrings $h.SecurityOpt @('no-new-privileges:true')
 foreach($key in 'CapAdd','ExtraHosts'){
  $v=$h.$key
  if($v -is [array]){if($v.Count -ne 0){throw 'COLD_GUARD_COLLECTION_SCHEMA'}}
  elseif($null -ne $v){throw 'COLD_GUARD_COLLECTION_SCHEMA'}
 }
}
function ReleaseShape($r){
 ExactKeys $r @('version','scope','status','sourceGate','preparationSHA','reviewSHA','freshColdSHA','sourceHash','runtimeHash','target','expectedID','type','selection','validatedN','quota','image','trustSHA','taskID','allocationID','utc','expiresUTC')
 StringFields $r @('scope','status','target','expectedID','type','image','trustSHA','taskID','allocationID','utc','expiresUTC')
 HashFields $r @('preparationSHA','reviewSHA','freshColdSHA','sourceHash','runtimeHash','trustSHA')
 AlbumIDs $r.taskID $r.allocationID;FreshExpiry $r.utc $r.expiresUTC;AlbumSelection $r.selection;AssertAlbumQuota $r.quota 5
 if(-not(SourceInteger $r.version 4) -or -not(SourceInteger $r.validatedN 5) -or $r.target -cne (SourceTarget) -or $r.expectedID -cne '7678209751167110421' -or $r.type -cne 'photo' -or $r.image -cne (SourceImage) -or $r.trustSHA -cne (SourceTrust)){throw 'LIVE_RELEASE_FIELDS'}
}
function AssertLiveBundle($dir,[switch]$Harness){
 ScalarString $dir;$full=(Resolve-Path $dir).Path;$root=AlbumRoot
 if($Harness){if(-not $full.StartsWith((Join-Path $root 'harness')+[IO.Path]::DirectorySeparatorChar,[StringComparison]::Ordinal)){throw 'HARNESS_NAMESPACE'}}
 elseif($full -cne (Join-Path $root 'release')){throw 'LIVE_NAMESPACE'}
 $r=BundleRow $full 'release.json';ReleaseShape $r
 if($Harness){if($r.scope -cne 'OFFLINE_LIVE_CONTRACT_HARNESS_V1' -or $r.status -cne 'FIXTURE_RELEASE_ONLY' -or $r.sourceGate -isnot [bool] -or $r.sourceGate){throw 'FIXTURE_NOT_LIVE'}}
 elseif($r.scope -cne 'ALBUM_SOURCE_RELEASE_V1' -or $r.status -cne 'REVIEWED_BOUND_RELEASE' -or $r.sourceGate -isnot [bool] -or -not $r.sourceGate){throw 'LIVE_RELEASE_NOT_ENABLED'}
 $prep=BundleRow $full 'preparation.json'
 ExactKeys $prep @('version','scope','sourceGate','sources','runtime','sourceHash','runtimeHash','image','trustSHA','selection','quota')
 if(-not(SourceInteger $prep.version 4) -or $prep.scope -cne 'ALBUM_BRIDGE_OFFLINE_PREPARATION_V1' -or $prep.sourceGate -isnot [bool] -or $prep.sourceGate){throw 'PREPARATION_SCOPE'}
 if($r.preparationSHA -cne (SourceSHA (Join-Path $full 'preparation.json')) -or $r.sourceHash -cne (RowsHash (SourceSnapshot)) -or $r.runtimeHash -cne (RowsHash (RuntimeExpected -Source)) -or (Canonical $prep.sources) -cne (Canonical (SourceSnapshot)) -or (Canonical $prep.runtime) -cne (Canonical (RuntimeExpected -Source))){throw 'LIVE_EXACT_CODE_RUNTIME'}
 foreach($k in 'sourceHash','runtimeHash','image','trustSHA','selection','quota'){if(-not(SameValue $prep.$k $r.$k)){throw 'LIVE_PREP_BINDING'}}
 $review=BundleRow $full 'review.json'
 ExactKeys $review @('version','scope','status','sourceGate','sourceCalls','actualExit','preparationSHA','sourceHash','runtimeHash','selection','quota','utc')
 if(-not(SourceInteger $review.version 4) -or -not(SourceInteger $review.sourceCalls 0) -or -not(SourceInteger $review.actualExit 0) -or $review.sourceGate -isnot [bool] -or $review.sourceGate -or $review.scope -cne $(if($Harness){'OFFLINE_REVIEW_FIXTURE_ONLY'}else{'ALBUM_BRIDGE_INDEPENDENT_REVIEW_V1'}) -or $review.status -cne $(if($Harness){'FIXTURE_REVIEW_ONLY'}else{'PASS_INDEPENDENT_ALBUM_BRIDGE_REVIEW'})){throw 'INDEPENDENT_REVIEW_REQUIRED'}
 foreach($k in 'preparationSHA','sourceHash','runtimeHash','selection','quota'){if(-not(SameValue $review.$k $r.$k)){throw 'REVIEW_BINDING'}}
 if($r.reviewSHA -cne (SourceSHA (Join-Path $full 'review.json'))){throw 'REVIEW_HASH'}
 $cold=BundleRow $full 'cold.json'
 ExactKeys $cold @('version','scope','status','sourceCalls','actualExit','sources','versions','python','trustSHA','fixtureModules','network','sourceMainInvoked','utc','guardSHA','completionSHA')
 HashFields $cold @('guardSHA','completionSHA')
 if($cold.guardSHA -cne (SourceSHA (Join-Path $full 'cold-guard.json')) -or $cold.completionSHA -cne (SourceSHA (Join-Path $full 'cold-completion.json'))){throw 'COLD_PROOF_LINK'}
 if(-not(SourceInteger $cold.version 4) -or -not(SourceInteger $cold.sourceCalls 0) -or -not(SourceInteger $cold.actualExit 0) -or $cold.scope -cne $(if($Harness){'OFFLINE_COLD_FIXTURE_ONLY'}else{'ALBUM_SOURCE_COLD_ATTESTATION_V1'}) -or $cold.status -cne $(if($Harness){'FIXTURE_COLD_ONLY'}else{'PASS_SOURCE_ONLY_COLD_NETWORK_NONE'}) -or $cold.network -cne 'none' -or $cold.sourceMainInvoked -isnot [bool] -or $cold.sourceMainInvoked -or $cold.fixtureModules -isnot [array] -or $cold.fixtureModules.Count -or $cold.trustSHA -cne (SourceTrust) -or (Canonical $cold.sources) -cne (Canonical (RuntimeExpected -Source))){throw 'FRESH_COLD_REQUIRED'}
 AssertVersions $cold;FreshExpiry $cold.utc $r.expiresUTC
 if($r.freshColdSHA -cne (SourceSHA (Join-Path $full 'cold.json'))){throw 'COLD_HASH'}
 $cg=BundleRow $full 'cold-guard.json';$cc=BundleRow $full 'cold-completion.json';$h=$cg.HostConfig
 ColdGuardCollections $h
 if($cg.Image -cne (SourceImage) -or $cg.Config.User -cne '65534:65534' -or $h.NetworkMode -cne 'none' -or $h.ExtraHosts -or -not(SourceInteger $h.Memory 96MB) -or -not(SourceInteger $h.MemorySwap 96MB) -or -not(SourceInteger $h.NanoCpus 250000000) -or $h.ReadonlyRootfs -isnot [bool] -or -not $h.ReadonlyRootfs -or $h.Privileged -isnot [bool] -or $h.Privileged -or $h.CapAdd -or 'ALL' -notin $h.CapDrop -or 'no-new-privileges:true' -notin $h.SecurityOpt -or $h.IpcMode -cne 'private' -or -not(SourceInteger $h.PidsLimit 64) -or -not(SourceInteger $cc.actualExit 0) -or -not(SourceInteger $cc.sourceCalls 0) -or -not(SourceInteger $cc.ownResourcesLeft 0)){throw 'COLD_NATIVE_GUARD'}
 if(-not $Harness){. "$PSScriptRoot/bootstrap_contract.ps1";AssertBootstrapProof $full $r.preparationSHA $r.reviewSHA}
 $auth=BundleRow $full 'authorization.json'
 ExactKeys $auth @('version','scope','status','releaseSHA','reviewSHA','taskID','allocationID','target','selection','quota','utc','expiresUTC')
 StringFields $auth @('scope','status','releaseSHA','reviewSHA','taskID','allocationID','target','utc','expiresUTC')
 if(-not(SourceInteger $auth.version 4) -or $auth.scope -cne $(if($Harness){'OFFLINE_HUMAN_TASK_FIXTURE_ONLY'}else{'ALBUM_SOURCE_HUMAN_TASK_V1'}) -or $auth.status -cne $(if($Harness){'FIXTURE_TASK_ONLY'}else{'HUMAN_AUTHORIZED'}) -or $auth.releaseSHA -cne (SourceSHA (Join-Path $full 'release.json'))){throw 'HUMAN_TASK_REQUIRED'}
 foreach($k in 'reviewSHA','taskID','allocationID','target','selection','quota','expiresUTC'){if(-not(SameValue $auth.$k $r.$k)){throw 'HUMAN_TASK_BINDING'}};FreshExpiry $auth.utc $auth.expiresUTC
 $allocation=BundleRow $full 'allocation.json'
 ExactKeys $allocation @('version','scope','releaseSHA','authorizationSHA','taskID','allocationID','target','expectedID','type','selection','validatedN','quota','utc','expiresUTC')
 if(-not(SourceInteger $allocation.version 4) -or $allocation.scope -cne $(if($Harness){'OFFLINE_ALLOCATION_BRIDGE_FIXTURE_ONLY'}else{'ALBUM_SOURCE_ALLOCATION_V1'}) -or $allocation.releaseSHA -cne (SourceSHA (Join-Path $full 'release.json')) -or $allocation.authorizationSHA -cne (SourceSHA (Join-Path $full 'authorization.json'))){throw 'ALLOCATION_BINDING'}
 foreach($k in 'taskID','allocationID','target','expectedID','type','selection','validatedN','quota','expiresUTC'){if(-not(SameValue $allocation.$k $r.$k)){throw 'ALLOCATION_BINDING'}};FreshExpiry $allocation.utc $allocation.expiresUTC
 return @{gate=$r;allocation=$allocation;directory=$full;releaseSHA=SourceSHA (Join-Path $full 'release.json');authorizationSHA=SourceSHA (Join-Path $full 'authorization.json');harness=[bool]$Harness}
}
function ConsumeLiveBundle($dir,[switch]$Harness,[scriptblock]$AfterLatch){
 if($AfterLatch -and -not $Harness){throw 'HARNESS_CALLBACK_ONLY'}
 $v=AssertLiveBundle $dir -Harness:$Harness;$r=$v.gate
 $claim=[ordered]@{version=4;scope=$(if($Harness){'OFFLINE_LIVE_CLAIM_FIXTURE_ONLY'}else{'ALBUM_SOURCE_ALLOCATION_V1'});status='CONSUMED_BEFORE_NETWORK_CAPABILITY';releaseSHA=$v.releaseSHA;authorizationSHA=$v.authorizationSHA;taskID=$r.taskID;allocationID=$r.allocationID;target=$r.target;selection=$r.selection;validatedN=5;quota=$r.quota;sourceHash=$r.sourceHash;runtimeHash=$r.runtimeHash;expiresUTC=$r.expiresUTC;utc=[DateTime]::UtcNow.ToString('o');gateSHA=$v.releaseSHA}
 $taskRoot=if($Harness){Join-Path $v.directory 'consumed'}else{Join-Path (AlbumRoot) "source-task/task-$($r.taskID)"}
 if(-not(Test-Path $taskRoot)){New-Item -ItemType Directory $taskRoot|Out-Null}
 # Reuse the v4 ancestor/reparse guard on the newly derived write namespace,
 # not only on release readers. A preexisting junction must never own a latch.
 FixedPath $taskRoot $taskRoot
 $latch=Join-Path $taskRoot 'task-latch.json';$cp=Join-Path $taskRoot "claim-$($r.allocationID).json";ExclusiveReceipt $latch $claim;if($AfterLatch){& $AfterLatch};ExclusiveReceipt $cp $claim
 $admission=@{version=4;scope=$claim.scope;taskID=$r.taskID;allocationID=$r.allocationID;target=$r.target;expectedID=$r.expectedID;type=$r.type;selection=$r.selection;validatedN=5;sourceHash=$r.sourceHash;runtimeHash=$r.runtimeHash;gateSHA=$v.releaseSHA;claimSHA=SourceSHA $cp;taskClaimSHA=SourceSHA $latch;expiresUTC=$r.expiresUTC;quota=$r.quota;authorizationSHA=$v.authorizationSHA}
 return @{gate=$r;admission=$admission;directory=$v.directory;claimPath=$cp;taskClaimPath=$latch;gatePath=Join-Path $v.directory 'release.json';consumed=$true;harness=[bool]$Harness;parent=$taskRoot}
}
function AssertAlbumSourceRelease($path){ScalarString $path;FixedPath $path (Join-Path (AlbumRoot) 'release/release.json');return AssertLiveBundle (Split-Path $path)}
