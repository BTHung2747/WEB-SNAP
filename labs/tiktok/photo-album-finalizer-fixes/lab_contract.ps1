function SHA($p){(Get-FileHash -LiteralPath $p).Hash.ToLowerInvariant()}
function Save($p,$v){ConvertTo-Json -InputObject $v -Depth 60|Set-Content -LiteralPath $p}
function Canonical($rows){ConvertTo-Json -InputObject @($rows|Sort-Object path|ForEach-Object {[pscustomobject][ordered]@{path=$_.path;sha256=$_.sha256}}) -Depth 4 -Compress}
function SourceSnapshot{
 $paths=@(rg --files labs/tiktok/photo-album-finalizer-fixes labs/tiktok/connect-poc/vendor labs/tiktok/photo labs/tiktok/setup-trace apps/media/src/tiktok apps/media/requirements.lock apps/egress/src)
 @($paths|ForEach-Object {[pscustomobject][ordered]@{path=$_.Replace('\','/');sha256=SHA $_}}|Sort-Object path)
}
function RuntimeExpected{
 $roots=@{integration='labs/tiktok/photo-album-finalizer-fixes';photo='labs/tiktok/photo';core='apps/media/src/tiktok';trace='labs/tiktok/setup-trace';vendor='labs/tiktok/connect-poc/vendor'}
 @($(foreach($key in $roots.Keys){foreach($p in @(rg --files $roots[$key])){if($p -match '__pycache__' -or $key -eq 'core' -and $p -match 'photo_lab'){continue};[pscustomobject][ordered]@{path=$key+'/'+[IO.Path]::GetRelativePath((Resolve-Path $roots[$key]).Path,(Resolve-Path $p).Path).Replace('\','/');sha256=SHA $p}}})|Sort-Object path)
}
