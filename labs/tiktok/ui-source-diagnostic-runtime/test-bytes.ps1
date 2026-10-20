param([Parameter(Mandatory)][ValidatePattern('^[a-z0-9-]{1,40}$')][string]$Namespace)
. (Join-Path $PSScriptRoot 'wiring.ps1')
$root=Join-Path (Get-Location).Path ('docs/evidence/ui-source-diagnostic-runtime-20261019/backend/'+$Namespace)
if(Test-Path $root){throw 'FRESH_TEST_NAMESPACE'};New-Item -ItemType Directory -Path $root|Out-Null
Save-New (Join-Path $root 'source-pins.json') @(Get-ChildItem $PSScriptRoot -File|Sort-Object Name|ForEach-Object{@{path=$_.FullName;sha256=(Get-FileHash $_.FullName).Hash.ToLowerInvariant()}})
$rows=[Collections.Generic.List[object]]::new()
function Check([bool]$OK,[string]$Code,$Proof=$null){if(!$OK){throw ('ASSERT_'+$Code)};$rows.Add(@{case=$Code;status='PASS_PURE_DISK_NOT_NATIVE';proof=$Proof})}
function Readback([string]$Path,$Proof){
 $b=[IO.File]::ReadAllBytes($Path);$d=[Text.Json.JsonDocument]::Parse($script:StrictUTF8.GetString($b))
 try{$db=$script:StrictUTF8.GetByteCount($d.RootElement.GetProperty('diagnostics').GetRawText())}finally{$d.Dispose()}
 Check ($b.Length -eq $Proof.operationBytes -and $db -eq $Proof.diagnosticBytes -and $b.Length -le 65536 -and $db -le 16384 -and (Get-FileHash $Path).Hash.ToLowerInvariant() -ceq $Proof.sha256 -and $b[0] -eq 123 -and $b[-1] -eq 125) ('READBACK_'+[IO.Path]::GetFileNameWithoutExtension($Path)) @{fileBytes=$b.Length;diagnosticBytes=$db;sha256=$Proof.sha256}
}
try{
 foreach($size in @(16383,16384,16385)){
  $empty=ConvertTo-Json -InputObject @{pad=''} -Compress;$baseBytes=$script:StrictUTF8.GetByteCount($empty);$diag=@{pad=('a'*($size-$baseBytes))};$path=Join-Path $root ('diagnostic-'+$size+'.json');$denied=$false
  try{$proof=Write-CappedReceipt $path @{fixture='SYNTHETIC_BOUNDARY'} $diag}catch{$denied=$_.Exception.Message -ceq 'DIAGNOSTIC_BYTES_OVER_CAP'}
  if($size -le 16384){Check (!$denied) ('DIAGNOSTIC_ACCEPT_'+$size);Readback $path $proof}else{Check ($denied -and !(Test-Path $path)) 'DIAGNOSTIC_CAP_PLUS_ONE_NO_FILE'}
 }
 foreach($size in @(65535,65536,65537)){
  $base=Serialize-Receipt @{pad=''} $null;$op=@{pad=('a'*($size-$base.operationBytes))};$path=Join-Path $root ('operation-'+$size+'.json');$denied=$false
  try{$proof=Write-CappedReceipt $path $op $null}catch{$denied=$_.Exception.Message -ceq 'OPERATION_BYTES_OVER_CAP'}
  if($size -le 65536){Check (!$denied) ('OPERATION_ACCEPT_'+$size);Readback $path $proof}else{Check ($denied -and !(Test-Path $path)) 'OPERATION_CAP_PLUS_ONE_NO_FILE'}
 }
 $counter=Get-Content docs/evidence/ui-source-job-residual-diagnostic-review-20261019/serialization-counterexample.json -Raw|ConvertFrom-Json -AsHashtable -Depth 64
 $op=@{fixture='REVIEWER_3_BY_16';events=@(1..64|ForEach-Object{@{Code='SYNTHETIC_EVENT';Ms=[double]::MaxValue;Active=[uint32]::MaxValue}})}
 $proof=Write-CappedReceipt (Join-Path $root 'reviewer-3x16-events64.json') $op $counter.diagnostics
 Readback (Join-Path $root 'reviewer-3x16-events64.json') $proof
 Check ($proof.diagnosticBytes -le 16384) 'REVIEWER_COUNTEREXAMPLE_BOUNDED' $proof
 foreach($d in @($null,@{},@{Complete=$false;Code='SYNTHETIC_ERROR';Value=[long]::MinValue},@{fixture="SYNTHETIC_Nguyễn_ảnh_😀_`"_slash\_`n_end"})){
  $path=Join-Path $root ('shape-'+$rows.Count+'.json');$proof=Write-CappedReceipt $path @{events=@()} $d;Readback $path $proof
 }
 $dest=Join-Path $root 'no-overwrite.json';$proof=Write-CappedReceipt $dest @{fixture='ORIGINAL'} @{};$before=(Get-FileHash $dest).Hash;$denied=$false
 try{$null=Write-CappedReceipt $dest @{fixture='NEW'} @{} }catch{$denied=$_.Exception.Message -ceq 'NO_OVERWRITE'}
 Check ($denied -and (Get-FileHash $dest).Hash -ceq $before) 'STRICT_NO_OVERWRITE'
 $partial=Join-Path $root 'partial-write.json';$failed=$false
 try{$null=Write-CappedReceipt $partial @{fixture='PARTIAL_FAULT'} @{} {param($s,$b) $s.Write($b,0,1);throw 'SYNTHETIC_SINK_FAULT'}}catch{$failed=$_.Exception.Message -ceq 'ATOMIC_WRITE_FAILED_NO_MESSAGE'}
 Check ($failed -and !(Test-Path $partial) -and @(Get-ChildItem $root -Filter '*.stage' -Force).Count -eq 0) 'PARTIAL_STAGE_CLEANED_NO_INVALID_FINAL'
 $deep=@{};$v=$deep;foreach($i in 1..40){$v.next=@{};$v=$v.next};$failed=$false;$path=Join-Path $root 'depth-fail.json'
 try{$null=Write-CappedReceipt $path @{} $deep}catch{$failed=$_.Exception.Message -ceq 'SERIALIZATION_FAILED_NO_MESSAGE'}
 Check ($failed -and !(Test-Path $path)) 'DEPTH_SERIALIZATION_FAIL_NO_FILE'
 $pipe=New-LoggedPipeline $root {throw 'NO_NATIVE_EXPECTED'}
 $failed=$false;try{& $pipe.sink 'synthetic-overcap' @{pad=('x'*70000)}}catch{$failed=$true}
 $marker=Get-Content (Join-Path $root 'core-synthetic-overcap-incomplete.json') -Raw|ConvertFrom-Json
 Check ($failed -and $pipe.state.failed -and !$marker.operation.complete -and !$marker.diagnostics.Complete -and !(Test-Path (Join-Path $root 'core-synthetic-overcap.json'))) 'INCOMPLETE_MARKER_NOT_SUCCESS'
 $parse=@();foreach($file in Get-ChildItem $PSScriptRoot -Filter '*.ps1'){$t=$null;$e=$null;$null=[Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$t,[ref]$e);$parse+=@($e)};Check ($parse.Count -eq 0) 'PS_PARSE'
 Save-New (Join-Path $root 'result.json') @{status='PASS_PURE_BYTES_DISK';caseCount=$rows.Count;cases=$rows.ToArray();nativeCalls=0;daemonCalls=0;utc=[DateTimeOffset]::UtcNow.ToString('o')}
 Write-Output ('PURE_BYTE_CHECKS_PASS_'+$rows.Count)
}catch{Save-New (Join-Path $root 'failure.json') @{completed=$rows.Count;code=$(if($_.Exception.Message -match '^ASSERT_[A-Z0-9_-]+$'){$_.Exception.Message}else{'PURE_TEST_ERROR_NO_MESSAGE'});nativeCalls=0};throw}
