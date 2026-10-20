param([ValidateRange(1,2)][int]$Attempt=1)
$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
$ev='docs/evidence/p37-renderer-20261007'
$ctx="$ev/build-context-$Attempt"
if(Test-Path -LiteralPath $ctx){throw 'Refuse reused image build evidence'}
New-Item -ItemType Directory -Path $ctx | Out-Null
$log="$ev/build.jsonl"
function InvokeDockerBuild([string]$step,[string[]]$argsDocker){
    $start=[DateTime]::UtcNow
    $out=(& docker @argsDocker 2>&1 | Out-String);$code=$LASTEXITCODE
    @{step=$step;args=$argsDocker;startUTC=$start.ToString('o');endUTC=[DateTime]::UtcNow.ToString('o');endVN=[DateTime]::UtcNow.AddHours(7).ToString('yyyy-MM-dd HH:mm:ss.fff');actualExit=$code;output=$out} | ConvertTo-Json -Depth 8 -Compress | Add-Content $log -Encoding utf8
    if($code -ne 0){throw "Docker $step exit=$code"}
    return $out.Trim()
}
$baseID='sha256:c66f52eace47d01e59a54c4b37f2d4d3db8b65326abff670b3673cb7d8900d8f'
$base=(InvokeDockerBuild 'base-before' @('image','inspect','wed-snap-media-curlcffi-lab:373-20261007') | ConvertFrom-Json)[0]
if($base.Id -cne $baseID){throw 'Base tag does not match pinned ID'}
if(InvokeDockerBuild 'running-services-before' @('ps','-q')){throw 'Do not build alongside running services; preserve their state'}
$tar="$ev/upstream/playwright-core-1.63.0.tgz"
if((Get-FileHash $tar -Algorithm SHA256).Hash.ToLower() -cne '208593d4e1bcd8f8fe5f869cad1cc332dc7f1d70dc1d58c102dc3ac36e30f26c'){throw 'Dependency tarball changed'}
Copy-Item $tar "$ctx/playwright-core-1.63.0.tgz"
Copy-Item infra/media-renderer-lab.Dockerfile "$ctx/Dockerfile"
$url='https://raw.githubusercontent.com/microsoft/playwright/v1.63.0/utils/docker/seccomp_profile.json'
Invoke-WebRequest $url -OutFile infra/renderer-seccomp-1.63.json -TimeoutSec 30
@{url=$url;sha256=(Get-FileHash infra/renderer-seccomp-1.63.json -Algorithm SHA256).Hash.ToLower();utc=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json | Set-Content "$ev/seccomp-pin.json" -Encoding utf8
$tag='wed-snap-media-renderer-lab:37-20261007'
InvokeDockerBuild 'build-renderer' @('build','--pull=false','--progress=plain','--iidfile',"$ev/image-id.txt",'-t',$tag,$ctx) | Write-Output
$new=(InvokeDockerBuild 'image-after' @('image','inspect',$tag) | ConvertFrom-Json)[0]
$after=(InvokeDockerBuild 'base-after' @('image','inspect','wed-snap-media-curlcffi-lab:373-20261007') | ConvertFrom-Json)[0]
if($after.Id -cne $baseID){throw 'Base tag changed'}
$oldLayers=@($base.RootFS.Layers);$newLayers=@($new.RootFS.Layers)
for($i=0;$i -lt $oldLayers.Count;$i++){if($oldLayers[$i] -cne $newLayers[$i]){throw 'Actual base prefix mismatch'}}
if($new.Config.User -cne '1000:1000' -or $new.Config.Labels.'com.wed-snap.playwright' -cne '1.63.0'){throw 'Image config mismatch'}
@{utc=[DateTime]::UtcNow.ToString('o');tag=$tag;actualImageID=$new.Id;baseID=$baseID;baseLayersVerified=$oldLayers.Count;
  browserRevision='1243';browserVersion='153.0.8010.12';playwright='1.63.0';browserHashInventory='/opt/renderer-browser-sha256.txt';registryDigestClaimed=$false} | ConvertTo-Json | Set-Content "$ev/image-pin.json" -Encoding utf8
Write-Output "Lab image pinned $($new.Id); base kept; dependency+browser revision fixed"
