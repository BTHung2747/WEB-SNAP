# AGPL-3.0 authority glue; unchanged v4 scalar/path/hash/expiry/CreateNew APIs reused.
. "$PSScriptRoot/authority_primitives.ps1"
. "$PSScriptRoot/lab_contract.ps1"
. "$PSScriptRoot/execution_namespace.ps1"
function AlbumIDs($task,$allocation){
 NewIDs $task $allocation
 if($task -ceq 'cf3808fc328743369a848f3bb5a5495e' -or $allocation -ceq 'b8f3a0d86c51490383c87fc925c876da'){throw 'OLD_ONE_PHOTO_CONSUMED'}
}
function AlbumQuota($n){
 if(-not($n -is [int] -or $n -is [long]) -or $n -lt 1 -or $n -gt 5){throw 'ALBUM_N_TYPE'}
 [ordered]@{analyze=1;metadataGET=2;imageGET=$n;metadataMaxCount=50;selectedMax=5;metadataSeconds=30;prepareSeconds=180;itemSeconds=60;itemReserveSeconds=10;metadataResponseBytes=8MB;metadataTotalBytes=16MB;imageInputBytes=20MB;imageOutputBytes=16MB;workflowInputBytes=((16+20*$n)*1MB);workflowOutputBytes=(16*$n*1MB);redirect=0;retry=0;HEAD=0;setupSeconds=10;connectSeconds=10;readSeconds=20;runtimeMiB=608;helperLimit=1;answerCap=64;rawCap=256;dnsProtocol=4;groupCap=4;socketCap=2;prefixCap=8;traceCap=256;ownerCap=32;mapCap=64;watchdogSeconds=225}
}
function AssertAlbumQuota($q,$n){$e=AlbumQuota $n;ExactKeys $q @($e.Keys);foreach($k in $e.Keys){if(-not(SourceInteger $q.$k $e[$k])){throw 'ALBUM_QUOTA_TYPED_VALUE'}}}
function AlbumSelection($s){
 ExactKeys $s @('version','mode','indices','expectedCount','snapshotSchema','snapshotKey')
 StringFields $s @('mode','snapshotSchema','snapshotKey')
 if(-not(SourceInteger $s.version 1) -or $s.mode -cne 'all' -or -not(SourceInteger $s.expectedCount 5) -or $s.snapshotSchema -cne 'tt-photo-album-v1' -or $s.snapshotKey -cnotmatch '^[a-f0-9]{64}$' -or $s.indices -isnot [array] -or $s.indices.Count -ne 5){throw 'ALBUM_SELECTION_SCHEMA'}
 for($i=0;$i -lt 5;$i++){if(-not(SourceInteger $s.indices[$i] ($i+1))){throw 'ALBUM_SELECTION_TYPED_ORDER'}}
}
function AlbumGate($path){
 RequireAlbumExecution 'offline'
 ScalarString $path;FixedPath $path (Join-Path (AlbumRoot) 'mock-sealed/gate.json');$g=SourceRead $path
 ExactKeys $g @('version','scope','status','sourceGate','sources','runtime','sourceHash','runtimeHash','trustSHA','image')
 StringFields $g @('scope','status','sourceHash','runtimeHash','trustSHA','image')
 if(-not(SourceInteger $g.version 3) -or $g.scope -cne 'OFFLINE_ALBUM_PREPARATION_FIXTURE_V1' -or $g.status -cne 'FIXTURE_ONLY_NOT_INDEPENDENT_REVIEW' -or $g.sourceGate -isnot [bool] -or $g.sourceGate -or $g.trustSHA -cne (SourceTrust) -or $g.image -cne (SourceImage)){throw 'ALBUM_FIXTURE_GATE_SCOPE'}
 if((Canonical (SourceSnapshot)) -cne (Canonical $g.sources) -or (Canonical (RuntimeExpected)) -cne (Canonical $g.runtime) -or (RowsHash $g.sources) -cne $g.sourceHash -or (RowsHash $g.runtime) -cne $g.runtimeHash){throw 'ALBUM_GATE_HASH'}
 return $g
}
function AssertAlbumMock($allocationPath,$gatePath){
 ScalarString $allocationPath;ScalarString $gatePath;$g=AlbumGate $gatePath;$a=SourceRead $allocationPath
 ExactKeys $a @('version','scope','taskID','allocationID','target','expectedID','type','selection','validatedN','sourceHash','runtimeHash','gateSHA','quota','utc','expiresUTC')
 StringFields $a @('scope','taskID','allocationID','target','expectedID','type','sourceHash','runtimeHash','gateSHA','utc','expiresUTC')
 if(-not(SourceInteger $a.version 3) -or $a.scope -cne 'OFFLINE_ALBUM_ALLOCATION_FIXTURE_V1' -or $a.target -cne (SourceTarget) -or $a.expectedID -cne '7678209751167110421' -or $a.type -cne 'photo' -or -not(SourceInteger $a.validatedN 5)){throw 'ALBUM_ALLOCATION_SCHEMA'}
 AlbumIDs $a.taskID $a.allocationID;AlbumSelection $a.selection;AssertAlbumQuota $a.quota $a.validatedN;FreshExpiry $a.utc $a.expiresUTC
 if($a.gateSHA -cne (SourceSHA $gatePath) -or $a.sourceHash -cne $g.sourceHash -or $a.runtimeHash -cne $g.runtimeHash){throw 'ALBUM_ALLOCATION_HASH'}
 $task=Join-Path (AlbumRoot) "mock-sealed/task-$($a.taskID)";FixedPath $allocationPath (Join-Path $task "$($a.allocationID)/allocation.json")
 return @{allocation=$a;gate=$g;taskRoot=$task;parent=(Get-Item $allocationPath).Directory.FullName}
}
function ConsumeAlbumMock($allocationPath,$gatePath,[scriptblock]$AfterLatch){
 $v=AssertAlbumMock $allocationPath $gatePath;$a=$v.allocation
 $latch=Join-Path $v.taskRoot 'task-latch-mock.json';$claim=Join-Path $v.parent 'claim-mock.json'
 $row=[ordered]@{version=3;scope='OFFLINE_ALBUM_ALLOCATION_FIXTURE_V1';status='CONSUMED_BEFORE_NETWORK_CAPABILITY';taskID=$a.taskID;allocationID=$a.allocationID;target=$a.target;selection=$a.selection;validatedN=$a.validatedN;gateSHA=$a.gateSHA;sourceHash=$a.sourceHash;runtimeHash=$a.runtimeHash;expiresUTC=$a.expiresUTC;quota=$a.quota;utc=[DateTime]::UtcNow.ToString('o')}
 ExclusiveReceipt $latch $row
 if($AfterLatch){& $AfterLatch}
 ExclusiveReceipt $claim $row
 return @{admission=@{version=3;scope=$row.scope;taskID=$a.taskID;allocationID=$a.allocationID;target=$a.target;expectedID=$a.expectedID;type=$a.type;selection=$a.selection;validatedN=5;sourceHash=$a.sourceHash;runtimeHash=$a.runtimeHash;gateSHA=$a.gateSHA;claimSHA=SourceSHA $claim;taskClaimSHA=SourceSHA $latch;expiresUTC=$a.expiresUTC;quota=$a.quota};claimPath=$claim;taskClaimPath=$latch;gatePath=$gatePath;consumed=$true}
}
# Live reader/validator is implemented in live_contract.ps1; mock authority never issues it.



