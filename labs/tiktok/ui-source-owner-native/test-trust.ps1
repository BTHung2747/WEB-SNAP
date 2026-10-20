param([Parameter(Mandatory)][string]$Evidence)
$ErrorActionPreference='Stop'
Import-Module (Join-Path $PSScriptRoot 'Owner.psm1') -Force -DisableNameChecking
$ev=(Resolve-Path -LiteralPath $Evidence).Path;$temp=Join-Path $ev 'OFFLINE_TEST_ONLY_SIGNATURES'
if(Test-Path $temp){throw 'REFUSE_TEST_REUSE'};New-Item -ItemType Directory -Path $temp|Out-Null
function WriteNew([string]$Path,$Value){if(Test-Path $Path){throw 'REFUSE_REWRITE'};[IO.File]::WriteAllText($Path,($Value|ConvertTo-Json -Depth 20 -Compress),[Text.UTF8Encoding]::new($false))}
function Ref([string]$Path){@{ref=[IO.Path]::GetRelativePath((Get-Location).Path,$Path).Replace('\','/');sha256=(Get-FileHash -LiteralPath $Path).Hash.ToLowerInvariant()}}
function MustReject($Action){$yes=$false;try{&$Action|Out-Null}catch{$yes=$true};if(!$yes){throw 'INVALID_APPROVAL_ACCEPTED'}}
$rsa=[Security.Cryptography.RSA]::Create();$rsa.KeySize=2048;$rows=[Collections.Generic.List[object]]::new()
try{
 $target=@{canonicalURL='https://www.tiktok.com/@offline_vector/photo/7000000000000000007';expectedPostID='7000000000000000007';selectedIndex=2}
 $anchor=Join-Path $temp 'OFFLINE_TEST_ONLY_ANCHOR.json';WriteNew $anchor @{schema='OFFLINE_TEST_ONLY_ANCHOR';keys=@(@{keyID='OFFLINE_TEST_ONLY_KEY';publicKeySPKI=[Convert]::ToBase64String($rsa.ExportSubjectPublicKeyInfo())});target=$target}
 $human=Join-Path $temp 'OFFLINE_TEST_ONLY_NOT_HUMAN.txt';[IO.File]::WriteAllText($human,'OFFLINE_TEST_ONLY_NOT_A_HUMAN_LAUNCH_INSTRUCTION')
 $pinsPath=Join-Path $temp 'OFFLINE_TEST_ONLY_PINS.json';WriteNew $pinsPath @(@{path='labs/tiktok/ui-source-owner-native/Owner.psm1';sha256=(Get-FileHash 'labs/tiktok/ui-source-owner-native/Owner.psm1').Hash.ToLowerInvariant()})
 $allocation=(Get-FileHash 'labs/tiktok/ui-source-owner-native/allocation.json').Hash.ToLowerInvariant();$budget=(Get-FileHash 'labs/tiktok/ui-source-glue/budget-policy.json').Hash.ToLowerInvariant()
 $environment=Join-Path $temp 'OFFLINE_TEST_ONLY_ENV.json';WriteNew $environment @{mode='OFFLINE_TEST_ONLY';codePinsSHA256=(Ref $pinsPath).sha256;allocationSHA256=$allocation;checks=@{node22Imports='OFFLINE_TEST_ONLY';cacheImages='OFFLINE_TEST_ONLY';publicSchema='OFFLINE_TEST_ONLY';utcClockSkew='OFFLINE_TEST_ONLY';cgroupIsolation='OFFLINE_TEST_ONLY';egressPhaseClosure='OFFLINE_TEST_ONLY'}}
 $ledger=Join-Path $temp 'OFFLINE_TEST_ONLY_LEDGER';New-Item -ItemType Directory -Path $ledger|Out-Null
 function Signed([string]$Tag,[hashtable]$Patch=@{},[switch]$Tamper){
  $body=@{schema='wed-source-owner-approval-v1';mode='OFFLINE_TEST_ONLY';state='OFFLINE_TEST_ONLY';scope='ONE_TIKTOK_PHOTO_UI_WORKFLOW';runID='OFFLINE_TEST_ONLY_'+$Tag;claimID='OFFLINE_TEST_ONLY_'+$Tag;target=$target;expiresAt=[DateTimeOffset]::UtcNow.AddSeconds(420).ToString('o');allocationSHA256=$allocation;budgetSHA256=$budget;humanInstruction=(Ref $human);task=(Ref $human);codePins=(Ref $pinsPath);environmentProof=(Ref $environment);evidenceRef='docs/evidence/OFFLINE_TEST_ONLY_NOT_SOURCE'}
  foreach($key in $Patch.Keys){$body[$key]=$Patch[$key]}
  $raw=[Text.Encoding]::UTF8.GetBytes(($body|ConvertTo-Json -Depth 20 -Compress));$sig=$rsa.SignData($raw,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pss);if($Tamper){$sig[0]=$sig[0] -bxor 1}
  $path=Join-Path $temp ('OFFLINE_TEST_ONLY_'+$Tag+'.json');WriteNew $path @{keyID='OFFLINE_TEST_ONLY_KEY';payloadBase64=[Convert]::ToBase64String($raw);signatureBase64=[Convert]::ToBase64String($sig)};return $path
 }
 $valid=Signed 'VALID';$ctx=Test-ApprovalConsumer $valid $anchor $ledger
 if($ctx.Mode -cne 'OFFLINE_TEST_ONLY' -or !$ctx.ClaimConsumed){throw 'OFFLINE_SIGNATURE_CONSUMER'}
 $hash=(Get-FileHash $ctx.ClaimPath).Hash;MustReject {Test-ApprovalConsumer $valid $anchor $ledger};if((Get-FileHash $ctx.ClaimPath).Hash -cne $hash){throw 'OFFLINE_ONCE_OVERWRITTEN'}
 $rows.Add(@{case='REAL_RSA_PSS_VERIFY_OFFLINE_ADMISSION_ONCE';status='PASS';liveAuthority=$false})
 foreach($tag in @('BAD_SIGNATURE','CONSUMED','EXPIRED','WRONG_TARGET','WRONG_BUDGET','MISSING_HUMAN')){
  $patch=@{};switch($tag){CONSUMED{$patch.state='CONSUMED'}EXPIRED{$patch.expiresAt=[DateTimeOffset]::UtcNow.AddSeconds(-1).ToString('o')}WRONG_TARGET{$patch.target=@{canonicalURL='https://www.tiktok.com/@offline_vector/photo/7000000000000000008';expectedPostID='7000000000000000008';selectedIndex=2}}WRONG_BUDGET{$patch.budgetSHA256='0'*64}MISSING_HUMAN{$patch.humanInstruction=@{ref=(Ref $human).ref;sha256='0'*64}}}
  $path=Signed $tag $patch -Tamper:($tag -ceq 'BAD_SIGNATURE');$before=@(Get-ChildItem $ledger -File).Count;MustReject {Test-ApprovalConsumer $path $anchor $ledger};if(@(Get-ChildItem $ledger -File).Count -ne $before){throw 'INVALID_CREATED_ONCE_MARKER'}
  $rows.Add(@{case=$tag;status='PASS';sourceCallbacks=0})
 }
 MustReject {Read-SourceApproval $valid};MustReject {Invoke-SourceOwner $valid};$rows.Add(@{case='OFFLINE_SIGNER_OR_CONTEXT_CANNOT_INVOKE_LIVE_ENTRY';status='PASS'})
 MustReject {Read-SourceApproval 'docs/tasks/UI_SOURCE_TARGET_20261016.json'};$rows.Add(@{case='TARGET_SELECTION_NOT_PERMISSION';status='PASS'})
 @{status='PASS_TRUSTED_CONSUMER_OFFLINE_CRYPTO_DELTA';caseCount=$rows.Count;cases=$rows.ToArray();signature='ACTUAL_DOTNET_RSA_PSS_VERIFY';privateKeyPersisted=$false;testMarkerMode='OFFLINE_TEST_ONLY_NOT_SOURCE_CLAIM';liveKeysProvisioned=0;liveApprovalsCreated=0;liveClaimsCreated=0;sourceCalls=0}|ConvertTo-Json -Depth 6|Set-Content (Join-Path $ev 'trust-tests.json') -Encoding utf8
}finally{$rsa.Dispose()}
Write-Output "PASS_TRUST_CONSUMER_CASES_$($rows.Count)"
exit 0
