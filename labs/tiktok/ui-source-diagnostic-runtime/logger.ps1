$ErrorActionPreference='Stop'
$script:StrictUTF8=[Text.UTF8Encoding]::new($false,$true)
function Serialize-Receipt($Operation,$Diagnostic){
 try{
  $dj=ConvertTo-Json -InputObject $Diagnostic -Depth 32 -Compress -EscapeHandling Default -WarningAction Stop
  $db=$script:StrictUTF8.GetBytes($dj)
  if($db.Length -gt 16384){throw 'DIAGNOSTIC_BYTES_OVER_CAP'}
  $oj=ConvertTo-Json -InputObject $Operation -Depth 32 -Compress -EscapeHandling Default -WarningAction Stop
  $doc=[Text.Json.JsonDocument]::Parse([string]$oj);$mem=[IO.MemoryStream]::new();$writer=$null
  try{
   $options=[Text.Json.JsonWriterOptions]::new();$options.Indented=$false;$options.SkipValidation=$false;$options.MaxDepth=64
   $writer=[Text.Json.Utf8JsonWriter]::new([IO.Stream]$mem,$options)
   $writer.WriteStartObject();$writer.WritePropertyName('operation');$doc.RootElement.WriteTo($writer)
   $writer.WritePropertyName('diagnostics');$writer.WriteRawValue([string]$dj,$false);$writer.WriteEndObject();$writer.Flush()
   $bytes=$mem.ToArray()
  }finally{if($writer){$writer.Dispose()};$mem.Dispose();$doc.Dispose()}
  if($bytes.Length -gt 65536){throw 'OPERATION_BYTES_OVER_CAP'}
  # Check the actual nested raw span before opening any file. No reserialization
  # or newline/indent/encoding pass exists after this buffer is measured.
  $actual=[Text.Json.JsonDocument]::Parse($script:StrictUTF8.GetString($bytes))
  try{$span=$script:StrictUTF8.GetBytes($actual.RootElement.GetProperty('diagnostics').GetRawText())}finally{$actual.Dispose()}
  if($span.Length -ne $db.Length -or [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($span)) -cne [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($db))){throw 'DIAGNOSTIC_SPAN_CHANGED'}
  return @{bytes=$bytes;diagnosticBytes=$span.Length;operationBytes=$bytes.Length;sha256=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()}
 }catch{
  if($_.Exception.Message -cin @('DIAGNOSTIC_BYTES_OVER_CAP','OPERATION_BYTES_OVER_CAP','DIAGNOSTIC_SPAN_CHANGED')){throw $_.Exception.Message}
  throw 'SERIALIZATION_FAILED_NO_MESSAGE'
 }
}
function Write-ExactBytes([string]$Path,[byte[]]$Bytes,[scriptblock]$IOHook=$null){
 if($Bytes.Length -gt 65536){throw 'OPERATION_BYTES_OVER_CAP'}
 $full=[IO.Path]::GetFullPath($Path);$dir=[IO.Path]::GetDirectoryName($full)
 if([IO.File]::Exists($full)){throw 'NO_OVERWRITE'}
 $stage=Join-Path $dir ('.'+[IO.Path]::GetFileName($full)+'.'+[Guid]::NewGuid().ToString('N')+'.stage')
 $owned=$false;$stream=$null
 try{
  $stream=[IO.FileStream]::new($stage,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None);$owned=$true
  if($IOHook){& $IOHook $stream $Bytes}
  $stream.Write($Bytes,0,$Bytes.Length);$stream.Flush($true);$stream.Dispose();$stream=$null
  if((Get-FileHash $stage).Hash -cne [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($Bytes))){throw 'STAGED_BYTES_MISMATCH'}
  [IO.File]::Move($stage,$full,$false);$owned=$false
 }catch{
  if($_.Exception.Message -cin @('NO_OVERWRITE','STAGED_BYTES_MISMATCH')){throw $_.Exception.Message}
  throw 'ATOMIC_WRITE_FAILED_NO_MESSAGE'
 }finally{
  if($stream){$stream.Dispose()}
  # Only this CreateNew sibling stage is owned; never delete destination.
  if($owned -and [IO.Path]::GetDirectoryName($stage) -ceq $dir){[IO.File]::Delete($stage)}
 }
}
function Write-CappedReceipt([string]$Path,$Operation,$Diagnostic,[scriptblock]$IOHook=$null){
 $s=Serialize-Receipt $Operation $Diagnostic
 Write-ExactBytes $Path $s.bytes $IOHook
 return @{operationBytes=$s.operationBytes;diagnosticBytes=$s.diagnosticBytes;sha256=$s.sha256}
}
function Logger-Code($ErrorRecord){
 if($ErrorRecord.Exception.Message -cin @('DIAGNOSTIC_BYTES_OVER_CAP','OPERATION_BYTES_OVER_CAP','DIAGNOSTIC_SPAN_CHANGED','SERIALIZATION_FAILED_NO_MESSAGE','NO_OVERWRITE','STAGED_BYTES_MISMATCH','ATOMIC_WRITE_FAILED_NO_MESSAGE')){return $ErrorRecord.Exception.Message}
 return 'LOGGER_FAILED_NO_MESSAGE'
}
