# Deterministic source contract, no Docker or source calls.
function Convert-TraceSnapshot($Rows){
 $normalized=@(foreach($row in $Rows){[pscustomobject][ordered]@{path=[string]$row.path;sha256=[string]$row.sha256}})|Sort-Object path
 if(@($normalized|Group-Object path|Where-Object Count -ne 1).Count){throw 'Duplicate source path'}
 return ConvertTo-Json -InputObject @($normalized) -Depth 4 -Compress
}

