# Derived unchanged generic v4 authority helpers. No release/claim/gate issuer is imported.
function ScalarString {
param($value)
if($value -isnot [string]){throw 'AUTHORITY_SCALAR_STRING_REQUIRED'}
}
function StringFields {
param($row, [string[]]$fields)

 if($row -isnot [pscustomobject] -and $row -isnot [Collections.IDictionary]){throw 'AUTHORITY_OBJECT_REQUIRED'}
 foreach($name in $fields){ScalarString $row.$name}

}
function StringSchema {
param($kind, $row)

 switch($kind){
 'gate'{StringFields $row @('scope','status','image','trustSHA','sourceHash','runtimeHash','utc')}
 'proof'{StringFields $row @('role','path','sha256')}
 'row'{StringFields $row @('path','sha256')}
 'allocation'{StringFields $row @('scope','taskID','allocationID','target','expectedID','type','image','trustSHA','sourceHash','runtimeHash','gateSHA','utc','expiresUTC')}
 'authorization'{StringFields $row @('scope','status','taskID','gateSHA','sourceHash','runtimeHash','target','reviewSHA','preclaimSHA','utc','expiresUTC')}
 'review'{StringFields $row @('status','gateSHA','sourceHash','runtimeHash','utc')}
 'claim'{StringFields $row @('scope','status','taskID','allocationID','target','gateSHA','sourceHash','runtimeHash','expiresUTC','utc')}
 default{throw 'UNKNOWN_STRING_SCHEMA'}
 }

}
function SourceSHA {
param($p)
ScalarString $p;(Get-FileHash -LiteralPath $p).Hash.ToLowerInvariant()
}
function SourceRead {
param($path)

 ScalarString $path
 if(-not(Test-Path -LiteralPath $path -PathType Leaf) -or (Get-Item -LiteralPath $path).Length -gt 2MB){throw 'RECEIPT_MISSING_OR_CAP'}
 if((Get-Item -LiteralPath $path).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'RECEIPT_LINK'}
 try{
  $text=Get-Content -LiteralPath $path -Raw;$doc=[Text.Json.JsonDocument]::Parse($text)
  try{AssertJsonKeys $doc.RootElement}finally{$doc.Dispose()}
  $text|ConvertFrom-Json -DateKind String
 }catch{throw 'RECEIPT_MALFORMED'}

}
function CanonicalSource {
param($rows)
ConvertTo-Json -InputObject @($rows|Sort-Object path|ForEach-Object {[pscustomobject][ordered]@{path=$_.path;sha256=$_.sha256}}) -Depth 4 -Compress
}
function SourceInteger {
param($v, $expected)
($v -is [int] -or $v -is [long]) -and $v -eq $expected
}
function ExactKeys {
param($row, [string[]]$keys)

 if(-not $row -or @($row.psobject.Properties.Name).Count -ne $keys.Count -or (Compare-Object $keys @($row.psobject.Properties.Name) -CaseSensitive)){throw 'RECEIPT_SCHEMA'}

}
function FixedPath {
param($path, $expected)

 ScalarString $path;ScalarString $expected
 if((Resolve-Path -LiteralPath $path).Path -cne [IO.Path]::GetFullPath($expected)){throw 'FIXED_NAMESPACE'}
 # Reject symlinks/junctions through every ancestor, not only the final file.
 $node=Get-Item -LiteralPath $path
 while($node){if($node.Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'NAMESPACE_LINK'};$node=if($node -is [IO.FileInfo]){$node.Directory}else{$node.Parent}}

}
function AssertJsonKeys {
param($element)

 if($element.ValueKind -eq [Text.Json.JsonValueKind]::Object){$seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase);foreach($p in $element.EnumerateObject()){if(-not $seen.Add($p.Name)){throw 'JSON_DUPLICATE_KEY'};AssertJsonKeys $p.Value}}
 elseif($element.ValueKind -eq [Text.Json.JsonValueKind]::Array){foreach($v in $element.EnumerateArray()){AssertJsonKeys $v}}

}
function ExclusiveReceipt {
param($path, $row)

 ScalarString $path;StringSchema 'claim' $row
 # Public .NET CreateNew+FileShare.None+Flush(true); never truncate existing claim.
 $s=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
 try{$b=[Text.UTF8Encoding]::new($false).GetBytes(($row|ConvertTo-Json -Depth 8));$s.Write($b,0,$b.Length);$s.Flush($true)}finally{$s.Dispose()}

}
function RowsHash {
param($rows)

 foreach($r in $rows){ExactKeys $r @('path','sha256');StringSchema 'row' $r}
 $names=[string[]]@($rows.path);[Array]::Sort($names,[StringComparer]::Ordinal);$map=@{};$b=[Text.StringBuilder]::new()
 foreach($r in $rows){if($r.path -match '[\x00\r\n]' -or $r.sha256 -cnotmatch '^[a-f0-9]{64}$' -or $map.ContainsKey($r.path)){throw 'HASH_ROWS_SCHEMA'};$map[$r.path]=$r.sha256}
 foreach($n in $names){$null=$b.Append($n).Append([char]0).Append($map[$n]).Append("`n")}
 [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($b.ToString()))).ToLowerInvariant()

}
function FreshExpiry {
param($utc, $expires)

 ScalarString $utc;ScalarString $expires
 $a=[DateTimeOffset]::MinValue;$b=$a
 if($utc -isnot [string] -or $expires -isnot [string] -or -not $utc.EndsWith('Z') -or -not $expires.EndsWith('Z') -or -not[DateTimeOffset]::TryParse($utc,[ref]$a) -or -not[DateTimeOffset]::TryParse($expires,[ref]$b)){throw 'EXPIRY_SCHEMA'}
 $now=[DateTimeOffset]::UtcNow;if($a -gt $now -or $b -le $now -or $b -le $a -or ($b-$a).TotalSeconds -gt 600){throw 'EXPIRED_OR_INVALID_WINDOW'}

}
function NewIDs {
param($task, $allocation)

 ScalarString $task;ScalarString $allocation
 if($task -isnot [string] -or $allocation -isnot [string] -or $task -cnotmatch '^[a-f0-9]{32}$' -or $allocation -cnotmatch '^[a-f0-9]{32}$' -or $task -in @('903b9cae739f46829b8973f4d94df389','2713473edcf94a139dd91d1d82939d0a') -or $allocation -in @('827c77f493ea4c8fa112f031e1b7b2bc','a0c19e584c614c9badfa47bbc46b35b2')){throw 'NEW_TASK_ALLOCATION_REQUIRED'}

}
function AssertVersions {
param($r)

 StringFields $r @('python');StringFields $r.versions @('requests','urllib3','yt-dlp','aiohappyeyeballs')
 if($r.python -cne '3.11.2' -or $r.versions.requests -cne '2.34.2' -or $r.versions.urllib3 -cne '2.8.0' -or $r.versions.'yt-dlp' -cne '2026.8.19' -or $r.versions.aiohappyeyeballs -cne '2.7.1'){throw 'RUNTIME_PINS'}

}
function SourceTrust {
'9cc2a774b5198dcff14d9be1e66091f538975d867ce029a96bce15a55dfd730f'
}
function SourceImage {
'sha256:31742091e95df2cc62669a6c6a9e0892dc09a34341eaeefc16959dcd4dfa417e'
}
function SourceTarget {
'https://www.tiktok.com/@adne_la.veil/photo/7678209751167110421'
}
