# Restore archived evidence byte-for-byte; never alter a historical manifest.
param(
    [string]$OriginalPath = 'docs/evidence/p36-20261004-commands-completion-ledger.json',
    [switch]$VerifyOnly
)
$ErrorActionPreference = 'Stop'
$workspace = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..')).TrimEnd('\') + '\'
$evidenceRoot = [IO.Path]::GetFullPath((Join-Path $workspace 'docs/evidence')).TrimEnd('\') + '\'
$archiveRoot = [IO.Path]::GetFullPath((Join-Path $workspace 'docs/evidence/archives')).TrimEnd('\') + '\'
$index = Get-Content -LiteralPath (Join-Path $workspace 'docs/evidence/archive-index.json') -Raw | ConvertFrom-Json
if ($index.schema -cne 'wed-snap-evidence-archives-v1') { throw 'Unknown archive index schema' }
$candidateRecords = @($index.entries | Where-Object { $_.originalPath -ceq $OriginalPath })
if ($candidateRecords.Count -ne 1) { throw 'Expected exactly one indexed evidence path' }
$record = $candidateRecords[0]
$target = [IO.Path]::GetFullPath((Join-Path $workspace $record.originalPath))
$archive = [IO.Path]::GetFullPath((Join-Path $workspace $record.archivePath))
if (-not $target.StartsWith($evidenceRoot, [StringComparison]::OrdinalIgnoreCase) -or
    -not $archive.StartsWith($archiveRoot, [StringComparison]::OrdinalIgnoreCase) -or
    $record.format -cne 'gzip') { throw 'Archive/target outside the allowed evidence directories' }
if ((Get-FileHash -LiteralPath $archive -Algorithm SHA256).Hash -ine $record.archiveSHA256) {
    throw 'Compressed archive checksum mismatch'
}
$compressed = [IO.File]::OpenRead($archive)
$hash = [Security.Cryptography.SHA256]::Create()
try {
    $decoded = [IO.Compression.GZipStream]::new($compressed, [IO.Compression.CompressionMode]::Decompress, $true)
    try { $decodedHash = ([BitConverter]::ToString($hash.ComputeHash($decoded))).Replace('-', '').ToLowerInvariant() }
    finally { $decoded.Dispose() }
} finally { $compressed.Dispose(); $hash.Dispose() }
if ($decodedHash -cne $record.originalSHA256) { throw 'Decoded evidence checksum mismatch' }
if ($VerifyOnly) {
    Write-Output "PASS lossless archive: $OriginalPath SHA256=$decodedHash"
    exit 0
}
if (Test-Path -LiteralPath $target) {
    if ((Get-Item -LiteralPath $target).Length -ne $record.originalBytes -or
        (Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ine $record.originalSHA256) {
        throw 'Target exists with different content; refusing overwrite'
    }
    Write-Output 'PASS original evidence already exists with the expected checksum'
    exit 0
}
$temporary = $target + '.restore-' + [Guid]::NewGuid().ToString('N') + '.tmp'
if (-not $temporary.StartsWith($evidenceRoot, [StringComparison]::OrdinalIgnoreCase)) { throw 'Unsafe restore temporary path' }
$compressed = [IO.File]::OpenRead($archive)
$output = [IO.File]::Open($temporary, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
try {
    $decoded = [IO.Compression.GZipStream]::new($compressed, [IO.Compression.CompressionMode]::Decompress, $true)
    try { $decoded.CopyTo($output, 1048576) }
    finally { $decoded.Dispose() }
} finally { $compressed.Dispose(); $output.Dispose() }
# On failure preserve the temporary file for inspection; never replace another file.
if ((Get-Item -LiteralPath $temporary).Length -ne $record.originalBytes -or
    (Get-FileHash -LiteralPath $temporary -Algorithm SHA256).Hash -ine $record.originalSHA256) {
    throw "Restored evidence did not match; temporary file retained: $temporary"
}
[IO.File]::Move($temporary, $target)
Write-Output "PASS restored original evidence: $OriginalPath SHA256=$decodedHash"
