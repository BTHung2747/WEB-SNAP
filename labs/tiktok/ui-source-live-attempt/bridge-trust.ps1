# Dot-sourced by Owner.psm1: public extension, not access to another module's private state.
$script:BridgeBootstraps=[Runtime.CompilerServices.ConditionalWeakTable[object,object]]::new()
$script:BridgeAuthorities=[Runtime.CompilerServices.ConditionalWeakTable[object,object]]::new()
$script:BridgeTestSeal=[object]::new()
$script:BridgeTaskMarker='source-owner-adapter-20261019'
$script:BridgeOwnerRoot=Join-Path (Get-Location).Path 'labs/tiktok/ui-source-owner-native'
$script:BridgeRoot=$PSScriptRoot
foreach($leaf in @('bridge-trust.ps1','bridge-native.ps1','bridge-runtime.ps1')){$f=Join-Path $script:BridgeRoot $leaf;$script:NativeImportPins+=@{path=$f;sha=(Get-FileHash $f).Hash.ToLowerInvariant()}}
function Bridge-Ref($Ref){
 if(!$Ref -or $Ref.sha256 -cnotmatch '^[a-f0-9]{64}$'){throw 'BRIDGE_REFERENCE'}
 $file=Resolve-WorkspaceFile $Ref.ref
 if((Get-FileHash $file).Hash.ToLowerInvariant() -cne $Ref.sha256){throw 'BRIDGE_REFERENCE_DRIFT'}
 return $file
}
function Bridge-JSON($Ref){Read-LimitedJSON (Bridge-Ref $Ref)}
function Bridge-Get($Table,$Handle){$s=$null;if($null -eq $Handle -or !$Table.TryGetValue($Handle,[ref]$s) -or $s.closed){throw 'BRIDGE_REGISTERED_HANDLE_REQUIRED'};return $s}
function Bridge-ReviewFresh($Review){$left=([DateTimeOffset]::Parse($Review.expiresAt)-[DateTimeOffset]::UtcNow).TotalSeconds;if($left -lt 341 -or $left -gt 480){throw 'BRIDGE_REVIEW_EXPIRED'}}
function Bridge-Now($Bootstrap){if($Bootstrap.managed -and $Bootstrap.ContainsKey('testClock') -and $Bootstrap.testClock){return & $Bootstrap.testClock};return [DateTimeOffset]::UtcNow}
function Bridge-Pins($Pins){
 Assert-CurrentPins $Pins
 $required=@(Get-ChildItem $script:BridgeOwnerRoot -File|ForEach-Object FullName)+@(Get-ChildItem $script:BridgeRoot -File|Where-Object Name -Like 'bridge-*.ps1'|ForEach-Object FullName)
 foreach($file in $required){$ref=[IO.Path]::GetRelativePath((Get-Location).Path,$file).Replace('\','/');if(@($Pins|Where-Object path -CEQ $ref).Count -ne 1){throw 'BRIDGE_CODE_COVERAGE'}}
}
function Bridge-Recheck($Bootstrap){
 Assert-NativeImportPins
 foreach($p in $Bootstrap.resolvedPins){if((Get-FileHash $p.path).Hash.ToLowerInvariant() -cne $p.sha256){throw 'CODE_PIN_MISMATCH'}}
 foreach($p in @($Bootstrap.review,$Bootstrap.bundleRef)){if((Get-FileHash (Join-Path $Bootstrap.cwd $p.ref)).Hash.ToLowerInvariant() -cne $p.sha256){throw 'BRIDGE_REFERENCE_DRIFT'}}
}
function Bridge-VerifyProofs($Review,$Bundle,[bool]$Managed){
 # Trust comes from a separately pinned reviewer record supplied to bootstrap,
 # never from the approval payload or from its own key/environment booleans.
 $envDoc=Bridge-JSON $Bundle.environmentProof;$env=$envDoc.Value
 if($env.schema -cne 'wed-owner-evidence-dag-v2' -or $env.mode -cne $(if($Managed){'MANAGED_ADAPTER_TEST'}else{'MEASURED_READINESS'}) -or $env.codePinsSHA256 -cne $Bundle.codePins.sha256){throw 'BRIDGE_PROOF_MODE_OR_BINDING'}
 if($Managed){
  if($env.fixture -cne 'MANAGED_SPY_NO_NATIVE_NO_SOURCE' -or $Review.kind -cne 'MANAGED_ADAPTER_TEST'){throw 'BRIDGE_TEST_PROVENANCE'}
  return @{mode='MANAGED_ADAPTER_TEST';proof=$Bundle.environmentProof;mountSourceMap=@()}
 }
 $runtime=Bridge-JSON $env.runtimeReview
 if($env.runtimeReview.sha256 -cne '499989d2d4ca9199876ef436bb31562730cab65626735f77130da365c47da038'){throw 'BRIDGE_RUNTIME_REVIEW_NOT_PINNED'}
 $historical=Bridge-Ref $env.historicalTLSReview
 if($env.historicalTLSReview.sha256 -cne '37da4eb40715b399488188aba9ecc096a2c23c4d6ac3701922dba4afb4e64fec'){throw 'BRIDGE_HISTORICAL_REVIEW_NOT_PINNED'}
 $expected=(Bridge-JSON $env.historicalSourcePins).Value
 foreach($pin in $expected|Where-Object{$_.path -clike 'apps/media/*' -or $_.path -clike 'apps/egress/*' -or $_.path -clike 'apps/api/*' -or $_.path -clike 'apps/worker/*'}){Assert-CurrentPins @($pin)}
 # Fresh proof must be reviewed under this exact code bundle; old failed batch
 # and caller PASS_OBSERVED strings cannot satisfy these structured receipts.
 $ready=(Bridge-JSON $env.readinessResult).Value.operation
 if(!$ready.readinessPASS -or !$ready.cleanupClosed -or !$ready.scopedAbsent -or !$ready.createIssued -or $ready.cid -cnotmatch '^[a-f0-9]{64}$' -or $ready.runID -cnotmatch '^[a-f0-9]{32}$' -or $ready.sourceCalls -ne 0 -or $ready.liveGrants -ne 0 -or $ready.sourceClaims -ne 0){throw 'BRIDGE_READINESS_NOT_OBSERVED'}
 $readinessPlan=(Bridge-JSON $env.readinessPlan).Value
 if($readinessPlan.runID -cne $ready.runID -or $readinessPlan.sourceGate -ne $false -or $readinessPlan.binarySHA -cne $Bundle.helper.binarySHA -or $readinessPlan.helperSHA -cne $Bundle.helper.helperSHA){throw 'BRIDGE_READINESS_CODE_BINDING'}
 Assert-CurrentPins $readinessPlan.sourcePins
 $clock=(Bridge-JSON $env.clockContent).Value.operation
 if($clock.packet.nonce -cne $ready.runID -or $clock.packet.platform -cne 'linux' -or $clock.packet.uid -ne 1000 -or $clock.packet.node -cne '22.22.3'){throw 'BRIDGE_CLOCK_BINDING'}
 $lo=[long]$clock.packet.unixMs-[long]$clock.hostAfter.unixMs;$hi=[long]$clock.packet.unixMs-[long]$clock.hostBefore.unixMs
 if($clock.hostAfter.qpc -le $clock.hostBefore.qpc -or $clock.hostAfter.frequency -ne $clock.hostBefore.frequency -or $clock.hostAfter.unixMs-$clock.hostBefore.unixMs -gt 2000 -or $lo -lt -1000 -or $hi -gt 1000 -or $lo -ne $ready.clockPair.offsetLowerMs -or $hi -ne $ready.clockPair.offsetUpperMs){throw 'BRIDGE_CLOCK_UNBOUNDED'}
 $age=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()-[long]$clock.hostAfter.unixMs
 if($age -lt 0 -or $age -gt 900000){throw 'BRIDGE_READINESS_STALE'}
 $map=(Bridge-JSON $env.mountMap).Value.operation
 if(@($map).Count -ne $ready.mappingCount){throw 'BRIDGE_MAPPING_COUNT'}
 $maps=@();foreach($row in $map){if($row.cid -cne $ready.cid -or $row.method -cne 'EXACT_CREATE_ARGV_INSPECT_TARGET_AND_CONTENT_HASH_NO_PREFIX_INFERENCE'){throw 'BRIDGE_MAPPING_PROVENANCE'};$maps+=@{hostSource=$row.windowsSource;observedSource=$row.observedEngineSource;status='PASS_OBSERVED';proof=$env.mountMap}}
 return @{mode='SOURCE_OWNER_ENVIRONMENT';mountSourceMap=$maps;proofRefs=$Bundle.environmentProof;measurementSemantics='HISTORICAL_CAPABILITY_PLUS_FRESH_READINESS_NOT_FUTURE_SOURCE_CLOSURE'}
}
function New-BridgeBootstrapCore([string]$ReviewPath,[string]$ExpectedSHA,[bool]$Managed,[scriptblock]$Spy){
 Assert-NativeImportPins
 $reviewRef=@{ref=$ReviewPath;sha256=$ExpectedSHA};$doc=Bridge-JSON $reviewRef;$r=$doc.Value
 if($r.schema -cne 'wed-reviewed-owner-bootstrap-v2' -or $r.kind -cne $(if($Managed){'MANAGED_ADAPTER_TEST'}else{'REVIEWER_GO_B'}) -or $r.reviewerThreadID -cne '01a14259-19b0-73f0-bd0c-0f5be84f6a88'){throw 'BRIDGE_REVIEW_REQUIRED'}
 Bridge-ReviewFresh $r
 if(($Managed -and !$Spy) -or (!$Managed -and $Spy)){throw 'BRIDGE_BOUNDARY_MODE'}
 $bundle=(Bridge-JSON $r.bundle).Value
 if($bundle.schema -cne 'wed-reviewed-owner-bundle-v2' -or $bundle.mode -cne $(if($Managed){'MANAGED_ADAPTER_TEST'}else{'UI_SINGLE_PHOTO_SOURCE'}) -or $bundle.endpoint -cne 'npipe:////./pipe/dockerDesktopLinuxEngine' -or $bundle.cwd -cne (Get-Location).Path){throw 'BRIDGE_BUNDLE_SCOPE'}
 $human=(Bridge-JSON $bundle.humanInstruction).Value
 if($Managed){if($human.mode -cne 'MANAGED_TEST_NOT_HUMAN_PERMISSION'){throw 'BRIDGE_TEST_HUMAN'}}else{
  if($bundle.humanInstruction.ref -cne 'docs/permissions/human-source/UI_TIKTOK_SINGLE_PHOTO_20261019.json' -or $human.directHumanReply -cne 'làm đi' -or $human.maximumSourceAdmissions -ne 1 -or $human.isRuntimeGrant -ne $false -or $human.mainActivation -or $human.galleryActivation -or $human.deployment){throw 'BRIDGE_HUMAN_SCOPE'}
  if($bundle.task.ref -cne 'docs/tasks/UI_TIKTOK_SINGLE_PHOTO_NEW_LAUNCH_20261019.md'){throw 'BRIDGE_TASK'};$null=Bridge-Ref $bundle.task
 }
 if($bundle.target.canonicalURL -cne 'https://www.tiktok.com/@adne_la.veil/photo/7678209751167110421' -or $bundle.target.expectedPostID -cne '7678209751167110421' -or $bundle.target.selectedIndex -ne 2){throw 'BRIDGE_TARGET'}
 $pins=(Bridge-JSON $bundle.codePins).Value;Bridge-Pins $pins
 if(!$Managed){
  . (Join-Path $script:BridgeOwnerRoot '../ui-source-prelaunch/wiring.ps1');$plan=Get-PrelaunchPlan
  foreach($pin in $plan.pins){$match=@($pins|Where-Object path -CEQ $pin.path);if($match.Count -ne 1 -or $match[0].sha256 -cne $pin.sha256){throw 'BRIDGE_RUNTIME_PLAN_COVERAGE'}}
 }
 $a=Get-OwnerBudget
 if($bundle.allocationSHA256 -cne $a.SHA -or $bundle.budgetSHA256 -cne (Get-FileHash (Join-Path $script:BridgeOwnerRoot '../ui-source-glue/budget-policy.json')).Hash.ToLowerInvariant()){throw 'BRIDGE_ALLOCATION'}
 foreach($kind in @('docker','node','python')){$t=$bundle.tools.$kind;if(![IO.Path]::IsPathFullyQualified($t.path) -or (Get-FileHash $t.path).Hash.ToLowerInvariant() -cne $t.sha256){throw 'BRIDGE_TOOL_PIN'}}
 if($bundle.tools.docker.path -cne 'C:\Program Files\Docker\Docker\resources\bin\docker.exe' -or $bundle.tools.docker.sha256 -cne '1aaf3dd59c24ff4c83d930bc51ecac8bf6f6f4e7a310573ee69d14ca3a7ef85c'){throw 'BRIDGE_DOCKER_PIN'}
 $helper=@{binary='D:\WED SNAP\docs\evidence\ui-source-runtime-offline-probe-20261019\backend\helper\RuntimeBoundary.dll';binarySHA='1610cb09ca52d48438bdad585adeb7dd4edda2474ec65641aa79f68e672945b1';MVID='2357bba5-a9cd-4d25-ae7c-7e002411b30c';helperSource='D:\WED SNAP\labs\tiktok\ui-source-owner-native\Win32Adapter.cs';helperSHA='5ed79b96326b56535077c6a97b7b0b30fee1031379f74dc845cfc6fcebbf7f19'}
 foreach($pair in @(@('binary','binary'),@('binarySHA','binarySHA'),@('MVID','MVID'),@('helperSource','helperSource'),@('helperSHA','helperSHA'))){if($bundle.helper.($pair[0]) -cne $helper.($pair[1])){throw 'BRIDGE_CACHED_HELPER_PIN'}}
 if((Get-FileHash $bundle.helper.binary).Hash.ToLowerInvariant() -cne $bundle.helper.binarySHA -or $bundle.helper.helperSHA -cne $script:NativeHelperSHA -or (Get-FileHash $bundle.helper.helperSource).Hash.ToLowerInvariant() -cne $script:NativeHelperSHA){throw 'BRIDGE_CACHED_HELPER_DRIFT'}
 $env=Bridge-VerifyProofs $r $bundle $Managed
 $ledger=Resolve-WorkspaceFile $bundle.ledgerRef
 $managedBases=@('docs/evidence/ui-source-live-adapter-fix-20261019/backend/unit','docs/evidence/ui-source-adapter-final-gaps-20261020/backend/unit')
 $selectedBase=if($Managed){@($managedBases|Where-Object{$bundle.evidencePrefix -ceq ($_+'/runtime-')})}else{@()}
 if($Managed -and $selectedBase.Count -ne 1){throw 'BRIDGE_EVIDENCE_NAMESPACE'}
 $prefix=if($Managed){$selectedBase[0]+'/'}else{'docs/permissions/source-claims/'}
 if(!$bundle.ledgerRef.StartsWith($prefix,[StringComparison]::Ordinal) -or !(Test-Path $ledger -PathType Container)){throw 'BRIDGE_LEDGER_NAMESPACE'}
 $canonicalPrefix=[IO.Path]::GetFullPath((Join-Path (Get-Location).Path $prefix.TrimEnd('/')))+[IO.Path]::DirectorySeparatorChar
 if(!$ledger.StartsWith($canonicalPrefix,[StringComparison]::OrdinalIgnoreCase)){throw 'BRIDGE_LEDGER_NAMESPACE'}
 if(!$Managed -and $bundle.ledgerRef -cne ('docs/permissions/source-claims/human-'+$bundle.humanInstruction.sha256)){throw 'BRIDGE_HUMAN_LEDGER'}
 $expectedPrefix=if($Managed){$selectedBase[0]+'/runtime-'}else{'docs/evidence/ui-source-live-attempt-20261019/backend/source-'}
 if($bundle.evidencePrefix -cne $expectedPrefix){throw 'BRIDGE_EVIDENCE_NAMESPACE'}
 $handle=[pscustomobject]@{kind='OPAQUE_REVIEWED_BOOTSTRAP'}
 $resolved=@(foreach($pin in $pins){@{path=[IO.Path]::GetFullPath((Join-Path (Get-Location).Path $pin.path));sha256=$pin.sha256}})
 $script:BridgeBootstraps.Add($handle,@{closed=$false;managed=$Managed;spy=$Spy;bundle=$bundle;bundleRef=$r.bundle;review=$reviewRef;environment=$env;pins=$pins;resolvedPins=$resolved;ledger=$ledger;allocation=$a.Value;cwd=(Get-Location).Path})
 return $handle
}
function New-ReviewedSourceBootstrap([string]$ReviewPath,[string]$ExpectedReviewSHA){New-BridgeBootstrapCore $ReviewPath $ExpectedReviewSHA $false $null}
function New-ManagedAdapterBootstrap([string]$ReviewPath,[string]$ExpectedReviewSHA,[scriptblock]$Spy,[scriptblock]$TraceSink=$null,[scriptblock]$TestClock=$null){$h=New-BridgeBootstrapCore $ReviewPath $ExpectedReviewSHA $true $Spy;$b=Bridge-Get $script:BridgeBootstraps $h;$b.traceSink=$TraceSink;$b.testClock=$TestClock;return $h}
function New-SourceAuthority($Bootstrap){
 $b=Bridge-Get $script:BridgeBootstraps $Bootstrap;Bridge-Recheck $b;Bridge-ReviewFresh ((Read-LimitedJSON (Join-Path $b.cwd $b.review.ref)).Value)
 $key=[Security.Cryptography.RSA]::Create(2048);$public=$key.ExportSubjectPublicKeyInfo();$kid=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($public)).ToLowerInvariant()
 $h=[pscustomobject]@{kind='OPAQUE_SCOPED_SOURCE_AUTHORITY'};$script:BridgeAuthorities.Add($h,@{closed=$false;bootstrap=$b;key=$key;kid=$kid;issued=$false;consumed=$false});return $h
}
function New-ScopedSourceApproval($Authority,[string]$RunID,[string]$ClaimID){
 $s=Bridge-Get $script:BridgeAuthorities $Authority;$b=$s.bootstrap
 if($s.issued -or $RunID -cnotmatch '^[a-f0-9]{32}$' -or $ClaimID -cnotmatch '^[a-f0-9]{32}$'){throw 'BRIDGE_ISSUANCE_DENIED'}
 Bridge-Recheck $b;Bridge-ReviewFresh ((Read-LimitedJSON (Join-Path $b.cwd $b.review.ref)).Value);$s.issued=$true
 $now=Bridge-Now $b
 $payload=[ordered]@{schema='wed-scoped-owner-approval-v2';mode=$(if($b.managed){'MANAGED_ADAPTER_TEST'}else{'UI_SINGLE_PHOTO_SOURCE'});runID=$RunID;claimID=$ClaimID;kid=$s.kid;bundleSHA=$b.bundleRef.sha256;reviewSHA=$b.review.sha256;humanSHA=$b.bundle.humanInstruction.sha256;issuedAt=$now.ToString('o');expiresAt=$now.AddSeconds(480).ToString('o')}
 $bytes=[Text.Encoding]::UTF8.GetBytes(($payload|ConvertTo-Json -Compress));$sig=$s.key.SignData($bytes,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pss)
 return @{payloadBase64=[Convert]::ToBase64String($bytes);signatureBase64=[Convert]::ToBase64String($sig)}
}
function Read-ScopedSourceApproval($Authority,$Envelope){
 $s=Bridge-Get $script:BridgeAuthorities $Authority;$b=$s.bootstrap
 if($s.consumed -or $Envelope -isnot [Collections.IDictionary] -or $Envelope.Count -ne 2 -or !$Envelope.Contains('payloadBase64') -or !$Envelope.Contains('signatureBase64')){throw 'BRIDGE_ENVELOPE_DENIED'}
 try{$raw=[Convert]::FromBase64String($Envelope.payloadBase64);$sig=[Convert]::FromBase64String($Envelope.signatureBase64)}catch{throw 'BRIDGE_SIGNATURE_ENCODING'}
 if($raw.Length -gt 16384 -or $sig.Length -gt 1024 -or !$s.key.VerifyData($raw,$sig,[Security.Cryptography.HashAlgorithmName]::SHA256,[Security.Cryptography.RSASignaturePadding]::Pss)){throw 'BRIDGE_SIGNATURE_DENIED'}
 $doc=[Text.Json.JsonDocument]::Parse([Text.Encoding]::UTF8.GetString($raw));try{$seen=[Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase);foreach($p in $doc.RootElement.EnumerateObject()){if(!$seen.Add($p.Name)){throw 'BRIDGE_DUPLICATE_SIGNED_KEY'}}}finally{$doc.Dispose()}
 $p=ConvertFrom-Json -InputObject ([Text.Encoding]::UTF8.GetString($raw));$expected=@('schema','mode','runID','claimID','kid','bundleSHA','reviewSHA','humanSHA','issuedAt','expiresAt')
 if((@($p.PSObject.Properties.Name|Sort-Object) -join '|') -cne (@($expected|Sort-Object) -join '|')){throw 'BRIDGE_SIGNED_SCHEMA'}
 $remaining=([DateTimeOffset]::Parse($p.expiresAt)-(Bridge-Now $b)).TotalSeconds
 if($p.schema -cne 'wed-scoped-owner-approval-v2' -or $p.mode -cne $(if($b.managed){'MANAGED_ADAPTER_TEST'}else{'UI_SINGLE_PHOTO_SOURCE'}) -or $p.runID -cnotmatch '^[a-f0-9]{32}$' -or $p.claimID -cnotmatch '^[a-f0-9]{32}$' -or $p.kid -cne $s.kid -or $p.bundleSHA -cne $b.bundleRef.sha256 -or $p.reviewSHA -cne $b.review.sha256 -or $p.humanSHA -cne $b.bundle.humanInstruction.sha256 -or $remaining -lt 341 -or $remaining -gt 480){throw 'BRIDGE_APPROVAL_BINDING_OR_EXPIRY'}
 Bridge-Recheck $b;Bridge-ReviewFresh ((Read-LimitedJSON (Join-Path $b.cwd $b.review.ref)).Value)
 $null=Bridge-VerifyProofs (Bridge-JSON $b.review).Value $b.bundle $b.managed
 $s.consumed=$true # Burn before durable admission; crash/failure never restores.
 $sha=[Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($raw)).ToLowerInvariant()
 $admit=Reserve-Admission $p $b.ledger $sha $false 'None' $p.humanSHA
 $start=[Diagnostics.Stopwatch]::GetTimestamp();$freq=[Diagnostics.Stopwatch]::Frequency
 $p|Add-Member NoteProperty target ($b.bundle.target|ConvertTo-Json|ConvertFrom-Json);$p|Add-Member NoteProperty evidenceRef ($b.bundle.evidencePrefix+$p.runID)
 $root=Resolve-WorkspaceFile $p.evidenceRef
 if(Test-Path $root){throw 'BRIDGE_RUNTIME_NAMESPACE_REUSE'}
 $tools=@{};foreach($kind in @('docker','node','python')){$tools[$kind]=($b.bundle.tools.$kind|ConvertTo-Json|ConvertFrom-Json)}
 $contextPins=@($b.pins|ConvertTo-Json -Depth 10|ConvertFrom-Json);$contextEnvironment=$b.environment|ConvertTo-Json -Depth 20|ConvertFrom-Json;$contextAllocation=$b.allocation|ConvertTo-Json|ConvertFrom-Json
 $ctx=[pscustomobject]@{Mode=$p.mode;Seal=$(if($b.managed){$script:BridgeTestSeal}else{$script:SourceSeal});ClaimConsumed=$true;ClaimPath=$admit.ClaimPath;ClaimSHA=$admit.ClaimSHA;RunPath=$admit.RunPath;RunSHA=$admit.RunSHA;IntentPath=$admit.IntentPath;IntentSHA=$admit.IntentSHA;HumanPath=$admit.HumanPath;HumanSHA=$admit.HumanSHA;LedgerPath=$b.ledger;ApprovalPath=$null;ApprovalSHA=$sha;EnvironmentProof=$contextEnvironment;Payload=$p;Pins=$contextPins;Tools=$tools;Allocation=$contextAllocation;StartTicks=$start;UtcStart=[DateTimeOffset]::UtcNow;WorkDeadline=$start+[long](320*$freq);CleanupDeadline=$start+[long](340*$freq);HardDeadline=$start+[long](341*$freq);StartupDeadline=$start+[long](60*$freq);NativeChildren=[Collections.Generic.List[object]]::new();NativeReceipts=[Collections.Generic.List[object]]::new();Registry=[Collections.Generic.List[object]]::new();Root=$null;ProxyStarted=$null;CleanupCallsLeft=1}
 $null=Register-NativeContext $ctx;$state=Get-NativeContext $ctx
 $state|Add-Member NoteProperty Bridge @{managed=$b.managed;spy=$b.spy;helper=$b.bundle.helper;review=$b.review;bundle=$b.bundleRef;payload=($ctx.Payload|ConvertTo-Json -Depth 20 -Compress);tools=($ctx.Tools|ConvertTo-Json -Depth 8 -Compress);pins=($ctx.Pins|ConvertTo-Json -Depth 8 -Compress);environment=($ctx.EnvironmentProof|ConvertTo-Json -Depth 20 -Compress);trace=[Collections.Generic.List[object]]::new();engine=$null;root=$root;allocation=($ctx.Allocation|ConvertTo-Json -Compress)}
 $state.Bridge.traceFailed=$false;$state.Bridge.traceSink=$(if($b.ContainsKey('traceSink')){$b.traceSink}else{$null})
 $state.Bridge.registry=$ctx.Registry;$state.Bridge.records=[Collections.Generic.List[object]]::new();$state.Bridge.startTicks=$ctx.StartTicks;$state.Bridge.utcStart=$ctx.UtcStart;$state.Bridge.deadlines=@{};foreach($key in @('WorkDeadline','CleanupDeadline','HardDeadline','StartupDeadline')){$state.Bridge.deadlines[$key]=$ctx.$key}
 $admission=@{};foreach($key in @('ClaimConsumed','ClaimPath','ClaimSHA','RunPath','RunSHA','IntentPath','IntentSHA','HumanPath','HumanSHA','LedgerPath','ApprovalSHA')){$admission[$key]=$ctx.$key};$state.Bridge.admission=($admission|ConvertTo-Json -Compress)
 $state.Bridge.publicIdentity=Get-SourceAuthorityIdentity $Authority
 return $ctx
}
function Close-SourceAuthority($Authority){$s=Bridge-Get $script:BridgeAuthorities $Authority;$s.closed=$true;$s.key.Dispose()}
function Get-SourceAuthorityIdentity($Authority){$s=Bridge-Get $script:BridgeAuthorities $Authority;return @{mode=$(if($s.bootstrap.managed){'MANAGED_ADAPTER_TEST'}else{'UI_SINGLE_PHOTO_SOURCE'});keyID=$s.kid;publicKeySPKI=[Convert]::ToBase64String($s.key.ExportSubjectPublicKeyInfo());algorithm='RSA_2048_SHA256_PSS';review=@{ref=$s.bootstrap.review.ref;sha256=$s.bootstrap.review.sha256};bundle=@{ref=$s.bootstrap.bundleRef.ref;sha256=$s.bootstrap.bundleRef.sha256};privateKey='RAM_ONLY_NEVER_EXPORTED'}}
