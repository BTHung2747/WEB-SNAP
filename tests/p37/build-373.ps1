param([string]$EvidenceDir='docs/evidence/p37-3-20261007')
$ErrorActionPreference='Stop'
$root='D:\WED SNAP'; Set-Location $root
$ev=Join-Path $root $EvidenceDir
$ctx=Join-Path $ev 'build-context'
if(Test-Path -LiteralPath $ctx){throw 'Refuse reused build evidence'}
New-Item -ItemType Directory -Path "$ctx/wheels" | Out-Null
$log=Join-Path $ev 'build.jsonl'
function Record($step,$start,$code,$output){
    $end=[DateTime]::UtcNow
    @{step=$step;start_utc=$start.ToString('o');end_utc=$end.ToString('o');end_vn=$end.AddHours(7).ToString('yyyy-MM-dd HH:mm:ss.fff');exit=$code;output=$output} | ConvertTo-Json -Depth 12 -Compress | Add-Content $log -Encoding utf8
}
function D([string]$step,[string[]]$a){
    $s=[DateTime]::UtcNow
    $o=(& docker @a 2>&1 | Out-String); $code=$LASTEXITCODE
    Record $step $s $code $o
    if($code -ne 0){throw "Docker $step exit=$code"}
    return $o.Trim()
}
$base='sha256:ecb3e7477d301d766046b92c586604a5650e22a0bac8e675b45699784f65737b'
$before=(D 'base-before' @('image','inspect','wed-snap-media:2026.08.19') | ConvertFrom-Json)[0]
if($before.Id -ne $base){throw 'Base tag mismatched'}
if((D 'running-before' @('ps','-q'))){throw 'Build requires no running services; do not stop external containers'}
$wheels=@(
    @('curl-cffi-0.16.0','curl_cffi-0.16.0-cp310-abi3-manylinux2014_x86_64.manylinux_2_17_x86_64.whl','182416f07d71a342240554fa62c22e591999b78c225b21d3fe27d9f807420dd6'),
    @('cffi-2.1.1','cffi-2.1.1-cp311-cp311-manylinux2014_x86_64.manylinux_2_17_x86_64.whl','34e261f78cb6ceaaa36f42f2613f4380d94d9c759a9c73c769ee6e0247364632'),
    @('pycparser-3.0','pycparser-3.0-py3-none-any.whl','b727414169a36b7d524c1c3e31839a521725078d7b2ff038656844266160a992')
)
$lock=@('# P37.3 Linux x86_64 CPython3.11 wheel-only lock; PyPI verified 2026-10-07')
foreach($w in $wheels){
    $s=[DateTime]::UtcNow
    $meta=Get-Content "$ev/upstream/$($w[0]).json" -Raw | ConvertFrom-Json
    $u=@($meta.urls | Where-Object {$_.filename -ceq $w[1]})
    if($u.Count -ne 1 -or $u[0].digests.sha256 -cne $w[2] -or $u[0].yanked){throw 'Official wheel metadata mismatch'}
    Invoke-WebRequest $u[0].url -OutFile "$ctx/wheels/$($w[1])" -TimeoutSec 90
    $hash=(Get-FileHash -LiteralPath "$ctx/wheels/$($w[1])" -Algorithm SHA256).Hash.ToLower()
    if($hash -cne $w[2]){throw 'Downloaded wheel hash mismatch'}
    $lock+= "$($meta.info.name)==$($meta.info.version) --hash=sha256:$hash"
    Record 'wheel-verified' $s 0 @{file=$w[1];sha256=$hash;bytes=(Get-Item "$ctx/wheels/$($w[1])").Length;url=$u[0].url;requires=$meta.info.requires_dist}
}
$lock | Set-Content "$ctx/requirements.lock" -Encoding ascii
Copy-Item infra/media-curlcffi-373.Dockerfile "$ctx/Dockerfile"
$tag='wed-snap-media-curlcffi-lab:373-20261007'
$idfile=Join-Path $ev 'image-id.txt'
D 'build-offline' @('build','--pull=false','--network=none','--progress=plain','--iidfile',$idfile,'-t',$tag,$ctx) | Write-Output
$new=(D 'new-image' @('image','inspect',$tag) | ConvertFrom-Json)[0]
$after=(D 'base-after' @('image','inspect','wed-snap-media:2026.08.19') | ConvertFrom-Json)[0]
if($after.Id -ne $base){throw 'Base changed'}
$oldLayers=@($before.RootFS.Layers); $newLayers=@($new.RootFS.Layers)
if($newLayers.Count -le $oldLayers.Count){throw 'Missing supplemental image layers'}
for($i=0;$i -lt $oldLayers.Count;$i++){if($oldLayers[$i] -cne $newLayers[$i]){throw 'Actual base layer mismatch'}}
if($new.Config.Labels.'com.wed-snap.base-id' -cne $base -or $new.Config.User -cne '1000:1000'){throw 'Image metadata mismatch'}
@{base_local_image_id=$base;image_id=$new.Id;tag=$tag;base_layer_count=$oldLayers.Count;new_layer_count=$newLayers.Count;base_layers_verified=$true;registry_digest_claimed=$false;utc=[DateTime]::UtcNow.ToString('o')} | ConvertTo-Json | Set-Content "$ev/image-pin.json" -Encoding utf8
Write-Output "PIN $($new.Id); actual base layers preserved"
