# WED SNAP lab glue, AGPL-3.0; Get-FileHash, not a custom hashing implementation.
function CobaltHostHashes {
    $base='labs/tiktok/cobalt'
    $paths=@(@(Get-ChildItem "$base/src" -Recurse -File|ForEach-Object {$_.FullName.Substring($root.Length+1).Replace('\','/')})+
        @('run.ps1','hash_gate.ps1','redact.ps1','test_gate.ps1','compose.yaml','Dockerfile','package.json','package-lock.json'|ForEach-Object {"$base/$_"})|Sort-Object)
    return @(foreach($f in $paths){[ordered]@{path=$f;bytes=(Get-Item -LiteralPath $f).Length;sha256=(Get-FileHash -LiteralPath $f -Algorithm SHA256).Hash.ToLower()}})
}
function Assert-CobaltHashGate($receipt,$current,$image) {
    if($receipt.schema -ne 1 -or $receipt.actualExit -ne 0 -or $receipt.ownResourcesLeft -ne 0 -or $receipt.imageID -cne $image){throw 'OFFLINE_RECEIPT_REQUIRED'}
    $expected=ConvertTo-Json -InputObject @($receipt.hostHashes) -Depth 5 -Compress
    $actual=ConvertTo-Json -InputObject @($current) -Depth 5 -Compress
    if($expected -cne $actual){throw 'OFFLINE_SOURCE_OR_LOCK_HASH_MISMATCH'}
}
