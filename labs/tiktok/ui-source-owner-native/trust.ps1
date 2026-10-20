$script:LiveAnchorSHA='96b6671d78a1584a61085af3738dcef2963045f846366de50de4bbda0112c714'
function Assert-ControlJSONNames($Element){
 if($Element.ValueKind -eq [Text.Json.JsonValueKind]::Object){$names=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase);foreach($property in $Element.EnumerateObject()){if(!$names.Add($property.Name)){throw 'DUPLICATE_KEY'};Assert-ControlJSONNames $property.Value}}
 elseif($Element.ValueKind -eq [Text.Json.JsonValueKind]::Array){foreach($item in $Element.EnumerateArray()){Assert-ControlJSONNames $item}}
}
function Read-LimitedJSON([string]$Path,[int]$Cap=65536){
 $f=Get-Item -LiteralPath $Path -ErrorAction Stop;if($f.Attributes -band [IO.FileAttributes]::ReparsePoint -or $f.Length -gt $Cap -or $f.PSIsContainer){throw 'DOCUMENT_SIZE_OR_TYPE'}
 $bytes=[IO.File]::ReadAllBytes($f.FullName);if($bytes.Length -gt $Cap){throw 'DOCUMENT_CAP'}
 $text=[Text.Encoding]::UTF8.GetString($bytes).TrimStart([char]0xFEFF)
 $doc=[Text.Json.JsonDocument]::Parse($text)
 try{Assert-ControlJSONNames $doc.RootElement}finally{$doc.Dispose()}
 [pscustomobject]@{Value=ConvertFrom-Json -InputObject $text -Depth 30;Bytes=$bytes;SHA=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()}
}
function Assert-NoReparseAttributes([IO.FileAttributes]$Attributes){if($Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'REPARSE_REFERENCE'}}
function Resolve-WorkspaceFile([string]$Reference){
 $root=[IO.Path]::GetFullPath((Get-Location).Path);if([IO.Path]::IsPathRooted($Reference)){throw 'ABSOLUTE_REFERENCE'}
 Assert-NoReparseAttributes (Get-Item -LiteralPath $root -Force).Attributes
 $p=[IO.Path]::GetFullPath((Join-Path $root $Reference));if(!$p.StartsWith($root+[IO.Path]::DirectorySeparatorChar)){throw 'REFERENCE_ESCAPE'}
 $walk=$p;while($walk.StartsWith($root+[IO.Path]::DirectorySeparatorChar)){
  if(Test-Path -LiteralPath $walk){Assert-NoReparseAttributes (Get-Item -LiteralPath $walk -Force).Attributes}
  $walk=[IO.Path]::GetDirectoryName($walk)
 };return $p
}
function Get-OwnerBudget {
 $a=Read-LimitedJSON (Join-Path $PSScriptRoot 'allocation.json');$b=$a.Value
 if($b.ownerSeconds -ne 341 -or $b.startupSeconds+$b.browserSeconds+$b.analyzeSeconds+$b.prepareSeconds+$b.finalProofSeconds+$b.cleanupSeconds+$b.sealSeconds -ne $b.ownerSeconds -or $b.ownerSeconds -gt 480 -or $b.appBootstrapSeconds+$b.browserSeconds+$b.analyzeSeconds+$b.prepareSeconds+$b.finalProofSeconds -ne 280 -or $b.cleanupSeconds -ne 20 -or $b.controllerCleanupSeconds -gt 15){throw 'ALLOCATION_POLICY'}
 return $a
}
function Assert-CurrentPins($Pins){
 if(@($Pins).Count -lt 1){throw 'EMPTY_PINS'}
 foreach($pin in $Pins){$p=Resolve-WorkspaceFile $pin.path;if((Get-FileHash -LiteralPath $p).Hash.ToLowerInvariant() -cne $pin.sha256){throw 'CODE_PIN_MISMATCH'}}
}
function Reserve-Admission($Payload,[string]$Ledger,[string]$ApprovalSHA,[bool]$Offline,[string]$OfflineFailure='None',[string]$HumanSHA=''){
 if($OfflineFailure -cne 'None' -and (!$Offline -or $Payload.mode -cne 'OFFLINE_TEST_ONLY')){throw 'OFFLINE_FAULT_ONLY'}
 $lockPath=Resolve-WorkspaceFile ([IO.Path]::GetRelativePath((Get-Location).Path,(Join-Path $Ledger '.admission-lock')))
 # No waiting/retry: a competing owner must fail, never share an admission.
 $lock=[IO.FileStream]::new($lockPath,[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None)
 try{
  $pending=Join-Path $Ledger '.admission-pending.json'
  $claim=Join-Path $Ledger ($Payload.claimID+'.json');$run=Join-Path $Ledger ('run-'+$Payload.runID+'.json');$intent=Join-Path $Ledger ('admission-'+$Payload.runID+'.json')
  foreach($path in @($pending,$claim,$run,$intent)){Resolve-WorkspaceFile ([IO.Path]::GetRelativePath((Get-Location).Path,$path))|Out-Null}
  if(Test-Path -LiteralPath $pending){throw 'LEDGER_INCOMPLETE_ADMISSION_HOLD'}
  $human=if($HumanSHA){if($HumanSHA -cnotmatch '^[a-f0-9]{64}$'){throw 'HUMAN_ADMISSION_ID'};Join-Path $Ledger ('human-'+$HumanSHA+'.json')}else{$null}
  if((Test-Path -LiteralPath $claim) -or (Test-Path -LiteralPath $run) -or (Test-Path -LiteralPath $intent) -or ($human -and (Test-Path -LiteralPath $human))){throw 'CLAIM_OR_RUN_ALREADY_USED'}
  $value=@{mode=$Payload.mode;runID=$Payload.runID;claimID=$Payload.claimID;approvalSHA256=$ApprovalSHA;state=$(if($Offline){'OFFLINE_TEST_ONLY'}elseif($Payload.mode -ceq 'MANAGED_ADAPTER_TEST'){'MANAGED_TEST_ADMISSION_NOT_SOURCE'}else{'CONSUMED_AT_ADMISSION'});utc=[DateTimeOffset]::UtcNow.ToString('o')}
  # Durable intent is first. Any crash/error leaves it in place and holds the
  # entire ledger; no automatic deletion/recovery/reset can admit a second owner.
  Write-ExclusiveJSON $pending $value
  if($human){Write-ExclusiveJSON $human $value}
  Write-ExclusiveJSON $run $value
  if($OfflineFailure -ceq 'AfterRun'){throw 'OFFLINE_TEST_ONLY_AFTER_RUN_FAULT'}
  Write-ExclusiveJSON $claim $value
  [IO.File]::Move($pending,$intent,$false)
  return @{ClaimPath=$claim;RunPath=$run;IntentPath=$intent;ClaimSHA=(Get-FileHash $claim).Hash.ToLowerInvariant();RunSHA=(Get-FileHash $run).Hash.ToLowerInvariant();IntentSHA=(Get-FileHash $intent).Hash.ToLowerInvariant();HumanPath=$human;HumanSHA=$(if($human){(Get-FileHash $human).Hash.ToLowerInvariant()}else{$null})}
 }finally{$lock.Dispose()}
}
function Read-ApprovalCore([string]$ApprovalPath,[string]$AnchorPath,[bool]$Offline,[string]$OfflineRoot='',[string]$OfflineFailure='None'){
 $anchor=Read-LimitedJSON $AnchorPath;$a=$anchor.Value
 if(!$Offline -and $anchor.SHA -cne $script:LiveAnchorSHA){throw 'TRUST_ANCHOR_NOT_REVIEWED'}
 if($a.schema -cne $(if($Offline){'OFFLINE_TEST_ONLY_ANCHOR'}else{'wed-source-owner-trust-anchor-v1'})){throw 'TRUST_ANCHOR_MODE'}
 $envelope=Read-LimitedJSON $ApprovalPath
 if((@($envelope.Value.PSObject.Properties.Name|Sort-Object) -join '|') -cne 'keyID|payloadBase64|signatureBase64'){throw 'ENVELOPE_SCHEMA'}
 $keys=@($a.keys|Where-Object keyID -CEQ $envelope.Value.keyID);if($keys.Count -ne 1){throw 'UNTRUSTED_SIGNER'}
 $raw=[Convert]::FromBase64String($envelope.Value.payloadBase64);$sig=[Convert]::FromBase64String($envelope.Value.signatureBase64)
 if($raw.Length -gt 16384 -or $sig.Length -gt 1024){throw 'SIGNED_DOCUMENT_CAP'}
 $rsa=[Security.Cryptography.RSA]::Create()
 try{$used=0;$rsa.ImportSubjectPublicKeyInfo([Convert]::FromBase64String($keys[0].publicKeySPKI),[ref]$used);if($rsa.KeySize -lt 2048 -or !$rsa.VerifyData($raw,$sig,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pss)){throw 'BAD_SIGNATURE'}}finally{$rsa.Dispose()}
 $payloadText=[Text.Encoding]::UTF8.GetString($raw);$doc=[Text.Json.JsonDocument]::Parse($payloadText)
 try{$seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase);foreach($item in $doc.RootElement.EnumerateObject()){if(!$seen.Add($item.Name)){throw 'DUPLICATE_SIGNED_KEY'}}}finally{$doc.Dispose()}
 $p=ConvertFrom-Json -InputObject $payloadText -Depth 25
 if($p.schema -cne 'wed-source-owner-approval-v1' -or $p.scope -cne 'ONE_TIKTOK_PHOTO_UI_WORKFLOW' -or $p.mode -cne $(if($Offline){'OFFLINE_TEST_ONLY'}else{'UI_SINGLE_PHOTO_SOURCE'}) -or $p.state -cne $(if($Offline){'OFFLINE_TEST_ONLY'}else{'APPROVED_NEW'})){throw 'APPROVAL_SCOPE'}
 $idPattern=if($Offline){'^OFFLINE_TEST_ONLY_[A-Z0-9_]{1,40}$'}else{'^[a-f0-9]{32}$'}
 if($p.runID -cnotmatch $idPattern -or $p.claimID -cnotmatch $idPattern){throw 'APPROVAL_ID'}
 $expires=[DateTimeOffset]::Parse($p.expiresAt);$remaining=($expires-[DateTimeOffset]::UtcNow).TotalSeconds
 if($remaining -lt 341 -or $remaining -gt 480){throw 'APPROVAL_EXPIRY'}
 $allocation=Get-OwnerBudget;$budgetPath=Join-Path $PSScriptRoot '../ui-source-glue/budget-policy.json'
 if($p.allocationSHA256 -cne $allocation.SHA -or $p.budgetSHA256 -cne (Get-FileHash -LiteralPath $budgetPath).Hash.ToLowerInvariant()){throw 'APPROVAL_BUDGET'}
 foreach($field in @('humanInstruction','task','codePins','environmentProof')){
  $ref=$p.$field;$file=Resolve-WorkspaceFile $ref.ref
  if((Get-FileHash -LiteralPath $file).Hash.ToLowerInvariant() -cne $ref.sha256){throw 'APPROVAL_REFERENCE_HASH'}
  if($field -ceq 'humanInstruction' -and !$Offline){$humanRoot=[IO.Path]::GetFullPath((Join-Path (Get-Location).Path $a.humanEvidenceRoot));if(!$file.StartsWith($humanRoot+[IO.Path]::DirectorySeparatorChar)){throw 'HUMAN_EVIDENCE_LOCATION'}}
 }
 $pins=Get-Content -LiteralPath (Resolve-WorkspaceFile $p.codePins.ref) -Raw|ConvertFrom-Json;Assert-CurrentPins $pins
 if(!$Offline){foreach($runtimeFile in Get-ChildItem -LiteralPath $PSScriptRoot -File){$relative=[IO.Path]::GetRelativePath((Get-Location).Path,$runtimeFile.FullName).Replace('\','/');$covered=@($pins|Where-Object path -CEQ $relative);if($covered.Count -ne 1){throw 'OWNER_CODE_PIN_COVERAGE'}}}
 $env=(Read-LimitedJSON (Resolve-WorkspaceFile $p.environmentProof.ref)).Value
 if($env.mode -cne $(if($Offline){'OFFLINE_TEST_ONLY'}else{'SOURCE_OWNER_ENVIRONMENT'}) -or $env.codePinsSHA256 -cne $p.codePins.sha256 -or $env.allocationSHA256 -cne $p.allocationSHA256){throw 'ENVIRONMENT_BINDING'}
 foreach($name in @('node22Imports','cacheImages','publicSchema','utcClockSkew','cgroupIsolation','egressPhaseClosure')){if($env.checks.$name -cne $(if($Offline){'OFFLINE_TEST_ONLY'}else{'PASS_OBSERVED'})){throw 'ENVIRONMENT_NOT_OBSERVED'}}
 $tools=@{}
 if(!$Offline){foreach($kind in @('docker','node','python')){$tool=$p.tools.$kind;if(!$tool -or ![IO.Path]::IsPathRooted($tool.path) -or [IO.Path]::GetExtension($tool.path) -cne '.exe' -or (Get-FileHash -LiteralPath $tool.path).Hash.ToLowerInvariant() -cne $tool.sha256){throw 'TRUSTED_EXECUTABLE_PIN'};$tools[$kind]=$tool}}
 $target=if($Offline){$a.target}else{(Read-LimitedJSON (Resolve-WorkspaceFile 'docs/tasks/UI_SOURCE_TARGET_20261016.json')).Value}
 $url=if($Offline){$target.canonicalURL}else{$target.canonicalURL}
 if($p.target.canonicalURL -cne $url -or $p.target.expectedPostID -cne $target.expectedPostID -or $p.target.selectedIndex -ne $target.selectedIndex -or ($p.target.selectedIndex -isnot [long] -and $p.target.selectedIndex -isnot [int])){throw 'APPROVAL_TARGET'}
 $ledger=if($Offline){Resolve-WorkspaceFile ([IO.Path]::GetRelativePath((Get-Location).Path,[IO.Path]::GetFullPath($OfflineRoot)))}else{Resolve-WorkspaceFile $a.claimsRoot}
 if($Offline -and !$ledger.StartsWith([IO.Path]::GetFullPath((Join-Path (Get-Location).Path 'docs/evidence'))+[IO.Path]::DirectorySeparatorChar)){throw 'OFFLINE_LEDGER_ROOT'}
 # The source consumer never provisions trust, keys, human references or approvals.
 # Exclusive admission is consumed even if any subsequent preflight/start fails.
 if(!(Test-Path -LiteralPath $ledger -PathType Container)){throw 'CLAIM_LEDGER_NOT_PROVISIONED'}
 if(($expires-[DateTimeOffset]::UtcNow).TotalSeconds -lt 341){throw 'APPROVAL_EXPIRED_DURING_VALIDATION'}
 $admitted=Reserve-Admission $p $ledger $envelope.SHA $Offline $OfflineFailure
 $start=[Diagnostics.Stopwatch]::GetTimestamp();$freq=[Diagnostics.Stopwatch]::Frequency
 [pscustomobject]@{Mode=$p.mode;Seal=$(if($Offline){$script:OfflineSeal}else{$script:SourceSeal});ClaimConsumed=$true;ClaimPath=$admitted.ClaimPath;ClaimSHA=$admitted.ClaimSHA;RunPath=$admitted.RunPath;RunSHA=$admitted.RunSHA;IntentPath=$admitted.IntentPath;IntentSHA=$admitted.IntentSHA;LedgerPath=$ledger;ApprovalPath=[IO.Path]::GetFullPath($ApprovalPath);EnvironmentProof=$env;ApprovalSHA=$envelope.SHA;Payload=$p;Pins=$pins;Tools=$tools;Allocation=$allocation.Value;StartTicks=$start;UtcStart=[DateTimeOffset]::UtcNow;WorkDeadline=$start+[long](320*$freq);CleanupDeadline=$start+[long](340*$freq);HardDeadline=$start+[long](341*$freq);StartupDeadline=$start+[long](60*$freq);NativeChildren=[Collections.Generic.List[object]]::new();NativeReceipts=[Collections.Generic.List[object]]::new();Registry=[Collections.Generic.List[object]]::new();Root=$null;ProxyStarted=$null;CleanupCallsLeft=1}
}
function Read-SourceApproval([string]$Path){
 if([string]::IsNullOrWhiteSpace($Path)){throw 'NEW_HUMAN_APPROVAL_REQUIRED'}
 Register-NativeContext (Read-ApprovalCore $Path (Join-Path $PSScriptRoot 'trust-anchor.json') $false)
}
function Test-ApprovalConsumer([string]$Path,[string]$Anchor,[string]$Ledger,[ValidateSet('None','AfterRun')][string]$OfflineFailure='None'){Read-ApprovalCore $Path $Anchor $true $Ledger $OfflineFailure}
