param([int]$Attempt=2)
$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
$ev="docs/evidence/tiktok-app-core-fixes-20261009/build-$Attempt"
if(Test-Path $ev){throw 'Evidence exists'};New-Item -ItemType Directory $ev|Out-Null
$parent='sha256:d4558b29dd379b16d4906fb9e618dfc4d045e3008a70e031ea3474b7b2218e4e'
$before=docker image inspect wed-snap-tiktok-app-integration:20261009 --format '{{.Id}}'
if($LASTEXITCODE -or $before -cne $parent){throw 'Wrong cached parent'}
$start=[DateTime]::UtcNow
docker build --pull=false --network=none --memory 1g -f labs/tiktok/app-core-fixes/Dockerfile -t wed-snap-tiktok-app-core-fixes:20261009 . 2>&1 | Tee-Object "$ev/build.log"
$rc=$LASTEXITCODE
$after=docker image inspect wed-snap-tiktok-app-integration:20261009 --format '{{.Id}}'
$image=docker image inspect wed-snap-tiktok-app-core-fixes:20261009 --format '{{.Id}}'
@{actualExit=$rc;utcStart=$start.ToString('o');utcEnd=[DateTime]::UtcNow.ToString('o');parentBefore=$before;parentAfter=$after;image=$image;sourceCalls=0;dependencyInstalls=0;productionBuild=$false}|ConvertTo-Json|Set-Content "$ev/receipt.json"
if($after -cne $parent){throw 'Parent changed'};exit $rc
