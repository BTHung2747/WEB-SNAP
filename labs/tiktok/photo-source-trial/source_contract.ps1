# Source allocation/claim glue only; no network/library transport implementation.
function SourceSHA($path){(Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant()}
function SourceRead($path){
 if(-not(Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Item -LiteralPath $path).Length -gt 2MB){throw 'SOURCE_RECEIPT_MISSING_OR_CAP'}
 try{Get-Content -LiteralPath $path -Raw|ConvertFrom-Json}catch{throw 'SOURCE_RECEIPT_MALFORMED'}
}
function CanonicalSource($rows){ConvertTo-Json -InputObject @($rows|Sort-Object path|ForEach-Object {[pscustomobject][ordered]@{path=$_.path;sha256=$_.sha256}}) -Depth 4 -Compress}
function SourceSnapshot{
 $paths=@(rg --files labs/tiktok/photo-source-trial labs/tiktok/wholephoto-registry-closure labs/tiktok/wholephoto-batch-validation labs/tiktok/wholephoto-batch labs/tiktok/wholephoto-order labs/tiktok/wholephoto-linkage labs/tiktok/wholephoto-diagnostics labs/tiktok/wholephoto-source labs/tiktok/wholephoto-connector labs/tiktok/trace-cleanup labs/tiktok/connect-closure-dns labs/tiktok/connect-poc labs/tiktok/photo-trace labs/tiktok/photo labs/tiktok/setup-trace apps/media/src/tiktok apps/media/requirements.lock apps/egress/src/egress.py)
 @($paths|ForEach-Object {[pscustomobject][ordered]@{path=$_.Replace('\','/');sha256=SourceSHA $_}}|Sort-Object path)
}
function SourceQuota{[ordered]@{analyze=1;metadataGET=2;imageGET=1;selectedIndex=1;metadataSeconds=30;prepareSeconds=60;metadataResponseBytes=8MB;metadataTotalBytes=16MB;imageInputBytes=20MB;imageOutputBytes=16MB;workflowBytes=36MB;redirect=0;retry=0;HEAD=0;setupSeconds=10;reserveSeconds=1;connectSeconds=10;readSeconds=20;runtimeMiB=608;helperLimit=1;answerCap=64;groupCap=4;socketCap=2;prefixCap=8;traceCap=256;ownerCap=32;mapCap=64}}
function SourceQuotaJSON($value){ConvertTo-Json -InputObject $value -Depth 4 -Compress}
function SourceRuntimeExpected{
 $roots=@{integration='labs/tiktok/photo-source-trial';photo='labs/tiktok/photo';core='apps/media/src/tiktok';trace='labs/tiktok/setup-trace';vendor='labs/tiktok/connect-poc/vendor'}
 $rows=@(foreach($key in $roots.Keys){foreach($p in @(rg --files $roots[$key])){if($p -match '__pycache__' -or $key -eq 'core' -and $p -match 'photo_lab'){continue};[pscustomobject][ordered]@{path=$key+'/'+[IO.Path]::GetRelativePath((Resolve-Path $roots[$key]).Path,(Resolve-Path $p).Path).Replace('\','/');sha256=SourceSHA $p}}})
 @($rows|Sort-Object path)
}
function SourceInteger($value,$expected){($value -is [long] -or $value -is [int]) -and $value -eq $expected}
function AssertSourceGate($gatePath){
 $g=SourceRead $gatePath
 if(-not(SourceInteger $g.version 1) -or $g.status -cne 'PASS_EXACT_SOURCE_WIRING_OFFLINE' -or -not(SourceInteger $g.actualExit 0) -or -not(SourceInteger $g.sourceCalls 0) -or $g.image -cne 'sha256:31742091e95df2cc62669a6c6a9e0892dc09a34341eaeefc16959dcd4dfa417e' -or $g.sourceOnlyIsolation -isnot [bool] -or $g.sourceOnlyIsolation -ne $true -or $g.defaultDisabled -isnot [bool] -or $g.defaultDisabled -ne $true -or $g.claimProbes -isnot [bool] -or $g.claimProbes -ne $true -or -not(SourceInteger $g.runtimeFiles 90)){throw 'SOURCE_GATE_FIELDS'}
 if((CanonicalSource $g.sources) -cne (CanonicalSource (SourceSnapshot))){throw 'SOURCE_GATE_CODE_DRIFT'}
 if(-not $g.proofs -or @($g.proofs|Group-Object path|Where-Object Count -ne 1).Count){throw 'SOURCE_GATE_PROOFS'}
 foreach($p in $g.proofs){if($p.path -isnot [string] -or -not $p.path.StartsWith('docs/evidence/tiktok-photo-source-trial-20261011/',[StringComparison]::Ordinal) -or $p.sha256 -cnotmatch '^[a-f0-9]{64}$' -or (SourceSHA $p.path) -cne $p.sha256){throw 'SOURCE_GATE_PROOF_DRIFT'}}
 return $g
}
function AssertSourceAllocation($allocationPath,$gatePath,[switch]$Fixture){
 $root=[IO.Path]::GetFullPath('D:\WED SNAP\docs\evidence\tiktok-photo-source-trial-20261011')
 $ap=(Resolve-Path -LiteralPath $allocationPath).Path;$gp=(Resolve-Path -LiteralPath $gatePath).Path
 if(-not $ap.StartsWith($root+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'SOURCE_NAMESPACE'}
 if(-not $Fixture -and ($gp -cne (Join-Path $root 'offline-gate.json') -or (Get-Item -LiteralPath $allocationPath).Directory.Name -cnotmatch '^source-[a-f0-9]{32}$')){throw 'SOURCE_NAMESPACE'}
 $a=SourceRead $allocationPath;$g=AssertSourceGate $gatePath
 $expectedKeys=@('version','allocationID','task','scope','target','expectedID','type','image','gateSHA','quota','utc')
 if(@($a.psobject.Properties.Name).Count -ne $expectedKeys.Count -or (Compare-Object $expectedKeys @($a.psobject.Properties.Name))){throw 'SOURCE_ALLOCATION_SCHEMA'}
 if(-not(SourceInteger $a.version 1) -or $a.allocationID -cnotmatch '^[a-f0-9]{32}$' -or $a.task -cne 'HUMAN_SOURCE_PHOTO_TASK_20261011' -or $a.scope -cne $(if($Fixture){'OFFLINE_CLAIM_FIXTURE'}else{'ONE_PHOTO_SOURCE_ALLOCATION'}) -or $a.target -cne 'https://www.tiktok.com/@adne_la.veil/photo/7678209751167110421' -or $a.expectedID -cne '7678209751167110421' -or $a.type -cne 'photo' -or $a.image -cne $g.image -or $a.gateSHA -cne (SourceSHA $gatePath)){throw 'SOURCE_ALLOCATION_VALUES'}
 # Fixed typed integer quota; JSON property order is intentionally not relied on.
 $quota=SourceQuota
 if(@($a.quota.psobject.Properties.Name).Count -ne $quota.Count){throw 'SOURCE_ALLOCATION_QUOTA'}
 foreach($key in $quota.Keys){$v=$a.quota.$key;if($v -isnot [long] -and $v -isnot [int] -or $v -ne $quota[$key]){throw 'SOURCE_ALLOCATION_QUOTA'}}
 $stamp=[DateTimeOffset]::MinValue;if(-not [DateTimeOffset]::TryParse($a.utc,[ref]$stamp)){throw 'SOURCE_ALLOCATION_UTC'}
 if(-not $Fixture -and (Get-Item -LiteralPath $allocationPath).Directory.Name -cne ('source-'+$a.allocationID)){throw 'SOURCE_ALLOCATION_NAMESPACE_ID'}
 return $a
}
function ClaimSourceAllocation($allocationPath,$gatePath,[switch]$Fixture){
 $a=AssertSourceAllocation $allocationPath $gatePath -Fixture:$Fixture
 $parent=(Get-Item -LiteralPath $allocationPath).Directory.FullName
 $taskClaimPath=if($Fixture){Join-Path $parent 'task-claim-fixture.json'}else{'D:\WED SNAP\docs\evidence\tiktok-photo-source-trial-20261011\source-task-claim.json'}
 # A task latch prevents a second allocation namespace from expanding quota.
 # Crash between the two CreateNew operations consumes the task; never rollback.
 try{$latch=[IO.File]::Open($taskClaimPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)}catch{throw 'SOURCE_TASK_ALREADY_CONSUMED_OR_IO'}
 try{$bytes=[Text.UTF8Encoding]::new($false).GetBytes((@{task=$a.task;allocationID=$a.allocationID;scope=$a.scope;status='CONSUMED_BEFORE_NETWORK_CAPABILITY';utc=[DateTime]::UtcNow.ToString('o')}|ConvertTo-Json));$latch.Write($bytes,0,$bytes.Length);$latch.Flush($true)}finally{$latch.Dispose()}
 # Caller supplies fresh task-owned namespace; no configurable claim output path.
 $claimPath=Join-Path $parent $(if($Fixture){'claim-fixture.json'}else{'source-claim.json'})
 try{$stream=[IO.File]::Open($claimPath,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)}catch{throw 'SOURCE_CLAIM_ALREADY_EXISTS_OR_IO'}
 try{
  $json=@{version=1;allocationID=$a.allocationID;scope=$a.scope;target=$a.target;expectedID=$a.expectedID;quota=$a.quota;gateSHA=$a.gateSHA;allocationSHA=SourceSHA $allocationPath;status='CONSUMED_BEFORE_NETWORK_CAPABILITY';utc=[DateTime]::UtcNow.ToString('o')}|ConvertTo-Json -Depth 6
  $bytes=[Text.UTF8Encoding]::new($false).GetBytes($json);$stream.Write($bytes,0,$bytes.Length);$stream.Flush($true)
 }finally{$stream.Dispose()}
 return [pscustomobject]@{allocation=$a;claimPath=$claimPath;claimSHA=SourceSHA $claimPath;taskClaimPath=$taskClaimPath;taskClaimSHA=SourceSHA $taskClaimPath;gateSHA=$a.gateSHA;allocationSHA=SourceSHA $allocationPath}
}
