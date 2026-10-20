# Preparatory authority core. UNIT_VECTOR is a distinct protocol, never accepted
# by the old source owner or by the closed live entry below. No private export.
Set-StrictMode -Version Latest
$ErrorActionPreference='Stop'
$script:Sessions=[Runtime.CompilerServices.ConditionalWeakTable[object,object]]::new()
function Get-Authority($Handle){
 $state=$null
 if($null -eq $Handle -or !$script:Sessions.TryGetValue($Handle,[ref]$state) -or $state.closed){throw 'REGISTERED_ISSUER_REQUIRED'}
 return $state
}
function New-UnitAuthority([string]$BundleSHA,[string]$HumanSHA,[string]$Target,[string]$Ledger){
 if($BundleSHA -cnotmatch '^[a-f0-9]{64}$' -or $HumanSHA -cnotmatch '^[a-f0-9]{64}$' -or $Target -cne 'UNIT_TARGET_PHOTO_INDEX_2'){throw 'UNIT_SCOPE'}
 # Unit roots cannot overlap production/source authority directories.
 $base=[IO.Path]::GetFullPath((Join-Path (Get-Location).Path 'docs/evidence/ui-source-live-attempt-20261019/backend/unit-ledgers'))+[IO.Path]::DirectorySeparatorChar
 $dir=[IO.Path]::GetFullPath($Ledger)
 if(!$dir.StartsWith($base,[StringComparison]::OrdinalIgnoreCase) -or ![IO.Directory]::Exists($dir)){throw 'UNIT_LEDGER_SCOPE'}
 $key=[Security.Cryptography.RSA]::Create(2048);$handle=[pscustomobject]@{kind='OPAQUE_UNIT_VECTOR_HANDLE_NOT_SOURCE_AUTHORITY'}
 $public=$key.ExportSubjectPublicKeyInfo();$kid=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($public)).ToLowerInvariant()
 $script:Sessions.Add($handle,@{key=$key;public=$public;kid=$kid;bundle=$BundleSHA;human=$HumanSHA;target=$Target;ledger=$dir;closed=$false;issued=$false})
 return $handle
}
function Issue-UnitApproval($Handle,[string]$Run,[string]$Claim,[long]$NowMs){
 $s=Get-Authority $Handle
 if($s.issued -or $Run -cnotmatch '^[a-f0-9]{32}$' -or $Claim -cnotmatch '^[a-f0-9]{32}$' -or $NowMs -lt 0){throw 'ISSUANCE_DENIED'}
 # Burn in RAM before signing; errors never make the issuer reusable.
 $s.issued=$true
 $p=[ordered]@{schema='wed-unit-authority-vector-v1';mode='UNIT_VECTOR_NOT_SOURCE';runID=$Run;claimID=$Claim;humanSHA=$s.human;bundleSHA=$s.bundle;target=$s.target;issuedMs=$NowMs;expiresMs=$NowMs+480000;ownerSeconds=341;kid=$s.kid}
 $bytes=[Text.Encoding]::UTF8.GetBytes(($p|ConvertTo-Json -Compress))
 $signature=$s.key.SignData($bytes,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pss)
 return @{payload=[Convert]::ToBase64String($bytes);signature=[Convert]::ToBase64String($signature)}
}
function Consume-UnitApproval($Handle,$Envelope,[long]$NowMs){
 $s=Get-Authority $Handle
 if($Envelope -isnot [Collections.IDictionary] -or $Envelope.Count -ne 2 -or !$Envelope.Contains('payload') -or !$Envelope.Contains('signature')){throw 'ENVELOPE_SCHEMA'}
 try{$bytes=[Convert]::FromBase64String($Envelope.payload);$sig=[Convert]::FromBase64String($Envelope.signature)}catch{throw 'ENVELOPE_ENCODING'}
 if($bytes.Length -gt 16384 -or $sig.Length -gt 1024 -or !$s.key.VerifyData($bytes,$sig,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pss)){throw 'SIGNATURE_DENIED'}
 # Signature covers original bytes. Duplicate keys are still rejected explicitly.
 $doc=[Text.Json.JsonDocument]::Parse([Text.Encoding]::UTF8.GetString($bytes))
 try{$seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal);foreach($p in $doc.RootElement.EnumerateObject()){if(!$seen.Add($p.Name)){throw 'PAYLOAD_SCHEMA'}}}finally{$doc.Dispose()}
 $p=ConvertFrom-Json -InputObject ([Text.Encoding]::UTF8.GetString($bytes)) -AsHashtable
 $keys=@('schema','mode','runID','claimID','humanSHA','bundleSHA','target','issuedMs','expiresMs','ownerSeconds','kid')
 if($p.Count -ne $keys.Count -or @($keys|Where-Object{!$p.Contains($_)}).Count){throw 'PAYLOAD_SCHEMA'}
 if($p.schema -cne 'wed-unit-authority-vector-v1' -or $p.mode -cne 'UNIT_VECTOR_NOT_SOURCE' -or $p.humanSHA -cne $s.human -or $p.bundleSHA -cne $s.bundle -or $p.target -cne $s.target -or $p.kid -cne $s.kid -or $p.runID -cnotmatch '^[a-f0-9]{32}$' -or $p.claimID -cnotmatch '^[a-f0-9]{32}$' -or $p.ownerSeconds -ne 341 -or $p.issuedMs -isnot [long] -and $p.issuedMs -isnot [int] -or $p.expiresMs -isnot [long] -and $p.expiresMs -isnot [int] -or $NowMs -lt $p.issuedMs -or $p.expiresMs-$p.issuedMs -ne 480000 -or $p.expiresMs-$NowMs -lt 341000){throw 'PAYLOAD_SCOPE_OR_EXPIRY'}
 # Exclusive lock, then durable crash intent, then immutable human/run/claim
 # markers. Any partial failure holds the human admission, never rolls it back.
 $lock=$null
 try{
  try{$lock=[IO.FileStream]::new((Join-Path $s.ledger 'admission.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)}catch{throw 'ADMISSION_LOCKED'}
  foreach($name in @('pending.json','admission.json',('human-'+$s.human),('run-'+$p.runID),('claim-'+$p.claimID))){if([IO.File]::Exists((Join-Path $s.ledger $name))){throw 'ADMISSION_ALREADY_HELD'}}
  $intent=[Text.Encoding]::UTF8.GetBytes(($p|ConvertTo-Json -Compress));$f=[IO.FileStream]::new((Join-Path $s.ledger 'pending.json'),[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
  try{$f.Write($intent,0,$intent.Length);$f.Flush($true)}finally{$f.Dispose()}
  foreach($name in @(('human-'+$s.human),('run-'+$p.runID),('claim-'+$p.claimID))){$f=[IO.FileStream]::new((Join-Path $s.ledger $name),[IO.FileMode]::CreateNew);try{$f.Flush($true)}finally{$f.Dispose()}}
  [IO.File]::Move((Join-Path $s.ledger 'pending.json'),(Join-Path $s.ledger 'admission.json'),$false)
 }finally{if($lock){$lock.Dispose()}}
 return @{mode='UNIT_ADMISSION_ONLY_NOT_SOURCE';consumed=$true;runID=$p.runID;claimID=$p.claimID;kid=$s.kid}
}
function Get-UnitPublicIdentity($Handle){$s=Get-Authority $Handle;return @{mode='UNIT_PUBLIC_IDENTITY_NOT_SOURCE_TRUST';kid=$s.kid;SPKI=[Convert]::ToBase64String($s.public)}}
function Close-UnitAuthority($Handle){$s=Get-Authority $Handle;$s.closed=$true;$s.key.Dispose()}
function New-LiveAuthority {
 # No caller-supplied anchor, payload field, boolean, or unit handle can open
 # this entry. A reviewed owner-context adapter and review-bound bootstrap are
 # not implemented yet. Deliberately no key/grant/claim allocation here.
 throw 'LIVE_REVIEW_AND_OWNER_ADAPTER_NOT_BOUND'
}
Export-ModuleMember -Function New-UnitAuthority,Issue-UnitApproval,Consume-UnitApproval,Get-UnitPublicIdentity,Close-UnitAuthority,New-LiveAuthority
