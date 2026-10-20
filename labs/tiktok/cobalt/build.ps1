$ErrorActionPreference='Stop';Set-Location 'D:\WED SNAP'
$ev='docs/evidence/tiktok-cobalt-20261008';$log="$ev/build.jsonl"
if(Test-Path "$ev/image-pin.json"){throw 'Refuse second successful image build'}
function D([string]$step,[string[]]$argv){
    $s=[DateTime]::UtcNow;$out=(& docker.exe @argv 2>&1|Out-String);$code=$LASTEXITCODE
    @{step=$step;argv=$argv;startUTC=$s.ToString('o');endUTC=[DateTime]::UtcNow.ToString('o');endVN=[DateTime]::UtcNow.AddHours(7).ToString('yyyy-MM-dd HH:mm:ss.fff');actualExit=$code;output=$out}|ConvertTo-Json -Depth 8 -Compress|Add-Content $log -Encoding utf8
    if($code){throw "$step exit=$code"};return $out.Trim()
}
$base=(D 'base-before' @('image','inspect','wed-snap-media-curlcffi-lab:373-20261007')|ConvertFrom-Json)[0]
if($base.Id -cne 'sha256:c66f52eace47d01e59a54c4b37f2d4d3db8b65326abff670b3673cb7d8900d8f'){throw 'Base pin mismatch'}
if(D 'running-before' @('ps','-q')){throw 'Do not build beside running services; preserve them'}
$tag='wed-snap-tiktok-cobalt-lab:20261008'
D 'build' @('build','--pull=false','--progress=plain','--iidfile',"$ev/image-id.txt",'-f','labs/tiktok/cobalt/Dockerfile','-t',$tag,'.')|Write-Output
$img=(D 'image-after' @('image','inspect',$tag)|ConvertFrom-Json)[0]
$again=(D 'base-after' @('image','inspect','wed-snap-media-curlcffi-lab:373-20261007')|ConvertFrom-Json)[0]
if($again.Id -cne $base.Id){throw 'Base changed'}
for($i=0;$i -lt $base.RootFS.Layers.Count;$i++){if($base.RootFS.Layers[$i] -cne $img.RootFS.Layers[$i]){throw 'Base prefix changed'}}
@{tag=$tag;imageID=$img.Id;baseID=$base.Id;basePrefixLayers=$base.RootFS.Layers.Count;cobaltCommit='a636575b09de1fc55d9b8cd98cac88f5f2f16b42';ytDlp='2026.08.19';lockSHA=(Get-FileHash labs/tiktok/cobalt/package-lock.json -Algorithm SHA256).Hash.ToLower();utc=[DateTime]::UtcNow.ToString('o')}|ConvertTo-Json|Set-Content "$ev/image-pin.json" -Encoding utf8
Write-Output "PIN $($img.Id)"
