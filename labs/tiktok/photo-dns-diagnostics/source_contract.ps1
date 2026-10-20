function SourceSHA($path){(Get-FileHash -LiteralPath $path).Hash.ToLowerInvariant()}
function CanonicalSource($rows){ConvertTo-Json -InputObject @($rows|Sort-Object path|ForEach-Object {[pscustomobject][ordered]@{path=$_.path;sha256=$_.sha256}}) -Depth 4 -Compress}
function SourceSnapshot{
 $paths=@(rg --files labs/tiktok/photo-dns-diagnostics labs/tiktok/photo-source-trial labs/tiktok/wholephoto-registry-closure labs/tiktok/wholephoto-batch-validation labs/tiktok/wholephoto-batch labs/tiktok/wholephoto-order labs/tiktok/wholephoto-linkage labs/tiktok/wholephoto-diagnostics labs/tiktok/wholephoto-source labs/tiktok/wholephoto-connector labs/tiktok/trace-cleanup labs/tiktok/connect-closure-dns labs/tiktok/connect-poc labs/tiktok/photo-trace labs/tiktok/photo labs/tiktok/setup-trace apps/media/src/tiktok apps/media/requirements.lock apps/egress/src/egress.py)
 @($paths|ForEach-Object {[pscustomobject][ordered]@{path=$_.Replace('\','/');sha256=SourceSHA $_}}|Sort-Object path)
}
function SourceRuntimeExpected{
 $roots=@{integration='labs/tiktok/photo-dns-diagnostics';photo='labs/tiktok/photo';core='apps/media/src/tiktok';trace='labs/tiktok/setup-trace';vendor='labs/tiktok/connect-poc/vendor'}
 $rows=@(foreach($key in $roots.Keys){foreach($p in @(rg --files $roots[$key])){if($p -match '__pycache__' -or $key -eq 'core' -and $p -match 'photo_lab'){continue};[pscustomobject][ordered]@{path=$key+'/'+[IO.Path]::GetRelativePath((Resolve-Path $roots[$key]).Path,(Resolve-Path $p).Path).Replace('\','/');sha256=SourceSHA $p}}})
 @($rows|Sort-Object path)
}