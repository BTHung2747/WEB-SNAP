param([ValidatePattern('^[a-z0-9-]{1,24}$')][string]$Trial='first',[string]$Focus='*',[ValidateSet('docs/evidence/ui-source-live-adapter-fix-20261019/backend','docs/evidence/ui-source-adapter-final-gaps-20261020/backend')][string]$EvidenceBase='docs/evidence/ui-source-live-adapter-fix-20261019/backend',[switch]$FunctionsOnly)
$ErrorActionPreference='Stop'
$evidence=$EvidenceBase
$unit=Join-Path $evidence ('unit/'+$Trial)
if(Test-Path $unit){throw 'NO_UNIT_REUSE'};New-Item -ItemType Directory $unit -ErrorAction Stop|Out-Null
Import-Module ./labs/tiktok/ui-source-owner-native/Owner.psm1 -Force -DisableNameChecking
$old=Get-Content docs/evidence/ui-source-runtime-offline-probe-20261019/backend/plan.json -Raw|ConvertFrom-Json
$helper=@{};foreach($k in @('binary','binarySHA','MVID','helperSource','helperSHA')){$helper[$k]=$old.$k}
$all=@(Get-ChildItem labs/tiktok/ui-source-owner-native -File)+@(Get-ChildItem $PSScriptRoot -Filter 'bridge-*.ps1' -File)
$pins=@($all|ForEach-Object{@{path=[IO.Path]::GetRelativePath((Get-Location).Path,$_.FullName).Replace('\','/');sha256=(Get-FileHash $_.FullName).Hash.ToLowerInvariant()}})
$script:nodePath=@(Get-Command node -CommandType Application)[0].Source
function Ref([string]$Path){@{ref=$Path.Replace('\','/');sha256=(Get-FileHash $Path).Hash.ToLowerInvariant()}}
function Put([string]$Path,$Value){$s=[IO.FileStream]::new($Path,[IO.FileMode]::CreateNew);try{$bytes=[Text.Encoding]::UTF8.GetBytes(($Value|ConvertTo-Json -Depth 25 -Compress));$s.Write($bytes);$s.Flush($true)}finally{$s.Dispose()}}
function Assert($V){if(!$V){throw 'UNIT_ASSERTION'}}
function Reject([scriptblock]$Body,[string]$Code){$caught=$null;try{& $Body|Out-Null}catch{$caught=$_.Exception.Message};Assert ($caught -ceq $Code)}
$rows=[Collections.Generic.List[object]]::new();$index=0
function Case([string]$Name,[scriptblock]$Body){if($Name -notlike $Focus){return};$w=[Diagnostics.Stopwatch]::StartNew();try{& $Body;$rows.Add(@{name=$Name;PASS=$true;elapsedMs=$w.ElapsedMilliseconds})}catch{$rows.Add(@{name=$Name;PASS=$false;type=$_.Exception.GetType().Name;code=$(if($_.Exception.Message -cmatch '^(BRIDGE_[A-Z_]+|UNIT_ASSERTION|CLAIM_OR_RUN_ALREADY_USED|REGISTERED_NATIVE_CONTEXT_REQUIRED)$'){$_.Exception.Message}else{'UNIT_ERROR_NO_MESSAGE'});line=$_.InvocationInfo.ScriptLineNumber;elapsedMs=$w.ElapsedMilliseconds})};Write-Output ('CASE '+$Name+' '+$rows[-1].PASS)}
function Fixture([string]$Scenario='pass'){
 $nodePath=$script:nodePath
 $script:index++;$dir=Join-Path $unit ('case-'+$script:index);New-Item -ItemType Directory $dir|Out-Null
 $ledger=Join-Path $dir 'ledger';New-Item -ItemType Directory $ledger|Out-Null
 Put (Join-Path $dir 'pins.json') $pins
 Put (Join-Path $dir 'human.json') @{mode='MANAGED_TEST_NOT_HUMAN_PERMISSION'}
 $pinRef=Ref (Join-Path $dir 'pins.json')
 Put (Join-Path $dir 'environment.json') @{schema='wed-owner-evidence-dag-v2';mode='MANAGED_ADAPTER_TEST';fixture='MANAGED_SPY_NO_NATIVE_NO_SOURCE';codePinsSHA256=$pinRef.sha256}
 $run=[Guid]::NewGuid().ToString('N');$clock=@{now=[DateTimeOffset]::UtcNow}
 $state=@{scenario=$Scenario;exists=$false;calls=[Collections.Generic.List[object]]::new();removes=[Collections.Generic.List[string]]::new();run=$run;cid=('c'*64);root=[IO.Path]::GetFullPath(($evidence+'/unit/runtime-'+$run))}
 $spy={param($exe,[string[]]$argList,$cwd,$limit,$cap)
  if($argList.Count -lt 3 -or $argList[0] -cne '--host' -or $argList[1] -cne 'npipe:////./pipe/dockerDesktopLinuxEngine'){throw 'UNIT_ENDPOINT'}
  $a=$argList[2..($argList.Count-1)];$state.calls.Add(@{command=$a[0];argvCount=$argList.Count;limitMs=$limit;cap=$cap;cwd=$cwd;endpoint='EXACT_LOCAL_PIPE';managed=$true})
  $r=[pscustomobject]@{Status='PASS';Created=$true;RootExit=0;RootPID=10001;RootCreationFileTime=1;RootInOwnJob=$true;JobHandleNonInherited=$true;LimitsVerified=$true;TerminationRequested=$false;Timeout=$false;ByteCapExceeded=$false;PipesEOF=$true;CleanupClosed=$true;TreeClosed=$true;FinalActive=0;LiveHandles=0;LiveBuffers=0;CloseErrors=0;BackgroundReaders=0;BeforeRootRelease=0;AfterRootRelease=0;RawOut='';RawErr='UNIT_SIGNED_URL_SECRET_DO_NOT_LOG';StdoutBytes=0;StderrBytes=0;RetainedBytes=0;Phase='MANAGED_SPY';Win32Error=0;HostInJob=$false;LimitFlagsActual=8192;MemoryLimitBytes=0;ActiveLimitActual=0;PeakJobMemory=0}
  switch($a[0]){
   ps {if($state.exists){$r.RawOut=$state.cid}}
   network {$r.RawOut=''}
   create {
    $state.exists=$true;$r.RawOut=$state.cid
    if($state.scenario -ceq 'forced-create'){$r.Status='FAIL';$r.TerminationRequested=$true}
    if($state.scenario -ceq 'lost-cid'){$r.RawOut=''}
    if($state.scenario -ceq 'throw-create'){throw [InvalidOperationException]::new('UNIT_URL_TOKEN_MUST_NOT_LOG')}
    if($state.scenario -ceq 'bad-projection'){$r.PSObject.Properties.Remove('PipesEOF')}
    if($state.scenario -ceq 'failed-create'){$state.exists=$false;$r.RawOut='';$r.Status='FAIL';$r.RootExit=20}
   }
   inspect {
    if(!$state.exists){$r.RootExit=1;$r.Status='FAIL';break}
    $mounts=@(@{Type='bind';Source='D:\UNIT\one';Destination='/unit/one';RW=$false},@{Type='bind';Source='D:\UNIT\two';Destination='/unit/two';RW=$false})
    if($state.scenario -ceq 'missing-leaf'){$mounts=@($mounts[0])}
    if($state.scenario -ceq 'extra-leaf'){$mounts+=@{Type='bind';Source='D:\UNIT\extra';Destination='/extra';RW=$false}}
    if($state.scenario -ceq 'wrong-leaf'){$mounts[0].Destination='/wrong'}
    if($state.scenario -ceq 'writable'){$mounts[0].RW=$true}
    if($state.scenario -ceq 'own-control-writable'){$mounts[0].RW=$true;$mounts[0].Source=Join-Path $state.root 'control'}
    if($state.scenario -ceq 'volume'){$mounts[0].Type='volume'}
    $g=@{Id=$state.cid;Name='/wed-source-'+$state.run+'-app';Image='sha256:d4558b29dd379b16d4906fb9e618dfc4d045e3008a70e031ea3474b7b2218e4e';Config=@{Labels=@{'com.wed-snap.run'=$(if($state.scenario -ceq 'foreign'){'f'*32}else{$state.run});'com.wed-snap.task'='source-owner-adapter-20261019'}};Mounts=$mounts}
    if($state.scenario -ceq 'foreign-image'){$g.Image='sha256:'+('f'*64)}
    $r.RawOut=ConvertTo-Json -InputObject @($g) -Depth 10 -Compress
   }
   rm {$state.removes.Add($a[-1]);$state.exists=$false}
  }
  $r|Add-Member NoteProperty LimitMs $limit;$r|Add-Member NoteProperty ByteCap $cap;$r|Add-Member NoteProperty ElapsedMs 1
  return $r
 }.GetNewClosure()
 $bundle=@{schema='wed-reviewed-owner-bundle-v2';mode='MANAGED_ADAPTER_TEST';endpoint='npipe:////./pipe/dockerDesktopLinuxEngine';cwd=(Get-Location).Path;target=@{canonicalURL='https://www.tiktok.com/@adne_la.veil/photo/7678209751167110421';expectedPostID='7678209751167110421';selectedIndex=2};humanInstruction=Ref (Join-Path $dir 'human.json');codePins=$pinRef;environmentProof=Ref (Join-Path $dir 'environment.json');allocationSHA256=(Get-FileHash labs/tiktok/ui-source-owner-native/allocation.json).Hash.ToLowerInvariant();budgetSHA256=(Get-FileHash labs/tiktok/ui-source-glue/budget-policy.json).Hash.ToLowerInvariant();helper=$helper;ledgerRef=$ledger.Replace('\','/');evidencePrefix=($evidence+'/unit/runtime-');tools=@{docker=@{path=$old.docker;sha256=$old.dockerSHA};node=@{path=$nodePath;sha256=(Get-FileHash $nodePath).Hash.ToLowerInvariant()};python=@{path='C:\Users\LENOVO\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe';sha256=(Get-FileHash 'C:\Users\LENOVO\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe').Hash.ToLowerInvariant()}}}
 Put (Join-Path $dir 'bundle.json') $bundle
 $review=@{schema='wed-reviewed-owner-bootstrap-v2';kind='MANAGED_ADAPTER_TEST';reviewerThreadID='01a14259-19b0-73f0-bd0c-0f5be84f6a88';expiresAt=[DateTimeOffset]::UtcNow.AddSeconds(480).ToString('o');bundle=Ref (Join-Path $dir 'bundle.json')}
 Put (Join-Path $dir 'review.json') $review
 return @{dir=$dir;review=Ref (Join-Path $dir 'review.json');state=$state;spy=$spy;bundle=$bundle;clock=$clock;run=$run;claim=[Guid]::NewGuid().ToString('N')}
}
function Bootstrap($F,[scriptblock]$Sink=$null){$holder=$F.clock;$clockFn={$holder.now}.GetNewClosure();New-ManagedAdapterBootstrap $F.review.ref $F.review.sha256 $F.spy $Sink $clockFn}
function Context($F,[scriptblock]$Sink=$null){$watch=[Diagnostics.Stopwatch]::StartNew();$b=Bootstrap $F $Sink;$s1=$watch.ElapsedMilliseconds;$a=New-SourceAuthority $b;$s2=$watch.ElapsedMilliseconds;try{$e=New-ScopedSourceApproval $a $F.run $F.claim;$s3=$watch.ElapsedMilliseconds;$c=Read-ScopedSourceApproval $a $e;$F.profile=@{bootstrapMs=$s1;authorityMs=$s2-$s1;issueMs=$s3-$s2;admitMs=$watch.ElapsedMilliseconds-$s3};return @{context=$c;authority=$a;bootstrap=$b;envelope=$e}}catch{Close-SourceAuthority $a;throw}}
if($FunctionsOnly){return}
foreach($scenario in @('pass','missing-leaf','extra-leaf','wrong-leaf','writable','own-control-writable','volume','foreign','foreign-image','forced-create','lost-cid','throw-create','bad-projection','failed-create')){
 Case ('integration-'+$scenario) {
  $fixture=Fixture $scenario;$created=Context $fixture
  try{$out=Invoke-SourceOwner -Context $created.context
   $removeExpected=$scenario -cin @('pass','missing-leaf','extra-leaf','wrong-leaf','own-control-writable','forced-create','lost-cid','throw-create','bad-projection')
   Assert ($fixture.state.removes.Count -eq $(if($removeExpected){1}else{0}))
   Assert (@($fixture.state.removes|Where-Object{$_ -cne $fixture.state.cid}).Count -eq 0)
   Assert ($out.mode -ceq 'MANAGED_ADAPTER_TEST_NO_NATIVE_OR_SOURCE')
   foreach($receipt in $created.context.NativeReceipts){Assert ($receipt.effectiveNativeLimitMs -ge 401 -and $receipt.effectiveNativeLimitMs -le $receipt.waitLimitMs);Assert ($receipt.executionSliceMs -eq $receipt.effectiveNativeLimitMs-400)}
   Assert ($out.executionPASS -eq ($scenario -ceq 'pass'))
   if($scenario -cin @('pass','missing-leaf','extra-leaf','wrong-leaf','own-control-writable','forced-create','lost-cid')){Assert $out.cleanup.closed}
   if($scenario -cin @('foreign','foreign-image','volume','writable','throw-create','bad-projection','failed-create')){Assert (!$out.cleanup.closed)}
   Assert (($out.trace|ConvertTo-Json -Depth 20 -Compress) -cnotmatch 'UNIT_SIGNED_URL_SECRET|UNIT_URL_TOKEN')
   Put (Join-Path $fixture.dir 'result.json') @{mode=$out.mode;executionPASS=$out.executionPASS;cleanup=$out.cleanup;registry=$out.registry;traceIncomplete=$out.trace.incomplete;traceRows=$out.trace.rows.Count;removeCount=$fixture.state.removes.Count;calls=$fixture.state.calls.ToArray();factoryProfile=$fixture.profile}
  }finally{Close-SourceAuthority $created.authority}
 }
}
Case 'sink-failure-still-cleans-known-cid' {$f=Fixture;$c=Context $f {param($row)if($row.stage -ceq 'CREATED_CID'){throw 'UNIT_SINK_SECRET'}};try{$o=Invoke-SourceOwner -Context $c.context;Assert (!$o.executionPASS);Assert $o.cleanup.closed;Assert $o.trace.incomplete;Assert ($f.state.removes.Count -eq 1)}finally{Close-SourceAuthority $c.authority}}
Case 'default-owner-deny' {Reject {Invoke-SourceOwner} 'NEW_HUMAN_APPROVAL_REQUIRED'}
Case 'target-only-context-deny' {Reject {Invoke-SourceOwner -Context ([pscustomobject]@{target='only';Mode='UI_SINGLE_PHOTO_SOURCE'})} 'REGISTERED_NATIVE_CONTEXT_REQUIRED'}
Case 'caller-boolean-not-bootstrap' {Reject {New-SourceAuthority ([pscustomobject]@{approved=$true})} 'BRIDGE_REGISTERED_HANDLE_REQUIRED'}
Case 'public-identity-does-not-alias-trusted-bootstrap-refs' {$f=Fixture;$b=Bootstrap $f;$a=New-SourceAuthority $b;try{$identity=Get-SourceAuthorityIdentity $a;$identity.review.ref='UNIT_FOREIGN_REF';$identity.bundle.sha256='f'*64;$again=Get-SourceAuthorityIdentity $a;Assert ($again.review.ref -ceq $f.review.ref);Assert ($again.bundle.sha256 -ceq (Ref (Join-Path $f.dir 'bundle.json')).sha256);$e=New-ScopedSourceApproval $a $f.run $f.claim;$ctx=Read-ScopedSourceApproval $a $e;Assert ($ctx.Mode -ceq 'MANAGED_ADAPTER_TEST');Assert ($f.state.calls.Count -eq 0)}finally{Close-SourceAuthority $a}}
Case 'test-review-not-live-bootstrap' {$f=Fixture;Reject {New-ReviewedSourceBootstrap $f.review.ref $f.review.sha256} 'BRIDGE_REVIEW_REQUIRED';Assert ($f.state.calls.Count -eq 0)}
Case 'tampered-reference-denied-before-key' {$f=Fixture;Reject {New-ManagedAdapterBootstrap $f.review.ref ('f'*64) $f.spy} 'BRIDGE_REFERENCE_DRIFT';Assert ($f.state.calls.Count -eq 0)}
Case 'replay-and-fresh-key-human-once' {$f=Fixture;$c=Context $f;try{Reject {Read-ScopedSourceApproval $c.authority $c.envelope} 'BRIDGE_ENVELOPE_DENIED';$a=New-SourceAuthority $c.bootstrap;try{$e=New-ScopedSourceApproval $a ([Guid]::NewGuid().ToString('N')) ([Guid]::NewGuid().ToString('N'));Reject {Read-ScopedSourceApproval $a $e} 'CLAIM_OR_RUN_ALREADY_USED'}finally{Close-SourceAuthority $a};Assert ($f.state.calls.Count -eq 0)}finally{Close-SourceAuthority $c.authority}}
Case 'foreign-signature-denied' {$f=Fixture;$g=Fixture;$a=New-SourceAuthority (Bootstrap $f);$b=New-SourceAuthority (Bootstrap $g);try{$e=New-ScopedSourceApproval $a $f.run $f.claim;Reject {Read-ScopedSourceApproval $b $e} 'BRIDGE_SIGNATURE_DENIED'}finally{Close-SourceAuthority $a;Close-SourceAuthority $b}}
Case 'approval-expiry-clamped-before-admission' {$f=Fixture;$a=New-SourceAuthority (Bootstrap $f);try{$e=New-ScopedSourceApproval $a $f.run $f.claim;$f.clock.now=$f.clock.now.AddSeconds(140);Reject {Read-ScopedSourceApproval $a $e} 'BRIDGE_APPROVAL_BINDING_OR_EXPIRY';Assert (!(Test-Path (Join-Path $f.bundle.ledgerRef '.admission-pending.json')))}finally{Close-SourceAuthority $a}}
Case 'payload-mutation-denied' {$f=Fixture;$c=Context $f;try{$c.context.Payload.target.selectedIndex=1;Reject {Invoke-SourceOwner -Context $c.context} 'BRIDGE_CONTEXT_MUTATED';Assert ($f.state.calls.Count -eq 0)}finally{Close-SourceAuthority $c.authority}}
Case 'wrong-cwd-denied-before-method' {$f=Fixture;$c=Context $f;$cwd=(Get-Location).Path;try{Set-Location $f.dir;Reject {Invoke-SourceOwner -Context $c.context} 'BRIDGE_CWD_CHANGED';Assert ($f.state.calls.Count -eq 0)}finally{Set-Location $cwd;Close-SourceAuthority $c.authority}}
Case 'endpoint-override-rejected-in-real-wrapper-before-method' {$f=Fixture;$c=Context $f;try{Reject {Test-ManagedSourceDispatch $c.context @('--host','npipe:////./pipe/foreign','ps')} 'BRIDGE_ENDPOINT_OVERRIDE';Assert ($f.state.calls.Count -eq 0);$trace=Get-SourceAdapterTrace $c.context;Assert (@($trace.rows|Where-Object stage -EQ 'WRAPPER_ERROR').Count -eq 1)}finally{Close-SourceAuthority $c.authority}}
Case 'deadline-cannot-reset' {$f=Fixture;$c=Context $f;try{$c.context.WorkDeadline+=[Diagnostics.Stopwatch]::Frequency;Reject {Invoke-SourceOwner -Context $c.context} 'BRIDGE_CLOCK_OR_DEADLINE_MUTATED';Assert ($f.state.calls.Count -eq 0)}finally{Close-SourceAuthority $c.authority}}
Case 'admission-paths-cannot-be-replaced' {$f=Fixture;$c=Context $f;try{$c.context.ClaimPath=Join-Path $f.dir 'foreign-claim';Reject {Invoke-SourceOwner -Context $c.context} 'BRIDGE_ADMISSION_MUTATED';Assert ($f.state.calls.Count -eq 0)}finally{Close-SourceAuthority $c.authority}}
Case 'registry-entries-cannot-be-injected' {$f=Fixture;$c=Context $f;try{$c.context.Registry.Add([pscustomobject]@{Name='foreign'});Reject {Invoke-SourceOwner -Context $c.context} 'BRIDGE_REGISTRY_MUTATED';Assert ($f.state.calls.Count -eq 0)}finally{Close-SourceAuthority $c.authority}}
function AlterFixture($F,[string]$Field,$Value){$F.bundle[$Field]=$Value;Put (Join-Path $F.dir 'altered-bundle.json') $F.bundle;$review=Get-Content $F.review.ref -Raw|ConvertFrom-Json;$review.bundle=Ref (Join-Path $F.dir 'altered-bundle.json');Put (Join-Path $F.dir 'altered-review.json') $review;$F.review=Ref (Join-Path $F.dir 'altered-review.json')}
Case 'wrong-endpoint-bundle-denied-before-key' {$f=Fixture;AlterFixture $f endpoint 'npipe:////./pipe/foreign';Reject {Bootstrap $f} 'BRIDGE_BUNDLE_SCOPE';Assert ($f.state.calls.Count -eq 0)}
Case 'managed-ledger-cannot-traverse-outside-unit' {$f=Fixture;AlterFixture $f ledgerRef 'docs/evidence/ui-source-live-adapter-fix-20261019/backend/unit/../../../../';Reject {Bootstrap $f} 'BRIDGE_LEDGER_NAMESPACE'}
Case 'wrong-target-bundle-denied-before-key' {$f=Fixture;AlterFixture $f target @{canonicalURL='https://www.tiktok.com/@adne_la.veil/photo/7678209751167110421';expectedPostID='7678209751167110421';selectedIndex=1};Reject {Bootstrap $f} 'BRIDGE_TARGET'}
Case 'scalar-environment-not-proof' {$f=Fixture;Put (Join-Path $f.dir 'scalar-env.json') @{schema='wed-owner-evidence-dag-v2';mode='MANAGED_ADAPTER_TEST';codePinsSHA256=$f.bundle.codePins.sha256;checks='PASS_OBSERVED'};AlterFixture $f environmentProof (Ref (Join-Path $f.dir 'scalar-env.json'));Reject {Bootstrap $f} 'BRIDGE_TEST_PROVENANCE'}
Case 'crash-intent-holds-admission' {$f=Fixture;Put (Join-Path $f.bundle.ledgerRef '.admission-pending.json') @{mode='MANAGED_TEST_CRASH_INTENT'};$a=New-SourceAuthority (Bootstrap $f);try{$e=New-ScopedSourceApproval $a $f.run $f.claim;Reject {Read-ScopedSourceApproval $a $e} 'LEDGER_INCOMPLETE_ADMISSION_HOLD';Assert ($f.state.calls.Count -eq 0)}finally{Close-SourceAuthority $a}}
Case 'window-owner-clock-freshness-and-binding' {$f=Fixture;$c=Context $f;try{$null=Initialize-ManagedAdapterHarness $c.context;$nonce=[Guid]::NewGuid().ToString('N');$r=Test-ManagedWindowService $c.context $nonce;$sample=$r.sample;Assert ($sample.clockDomain -ceq 'WINDOWS_QPC');Assert ($sample.preOpenMinimumMs -eq 260000);Assert ([long]$sample.effectiveObservationCutoffQPC -eq $c.context.WorkDeadline-10*[Diagnostics.Stopwatch]::Frequency);$sha=(Ref (Join-Path $c.context.Control 'browser-contract.json')).sha256;Reject {Read-OwnerWindowResponse $c.context.Control ('f'*32) $sha} 'BRIDGE_WINDOW_PRIVATE_PROOF';Assert ($r.ageAtReadMs -le 1000);Assert ($r.privateProofSHA256 -cmatch '^[a-f0-9]{64}$')}finally{Close-SourceAuthority $c.authority}}
$summary=@{schema='wed-owner-adapter-managed-results-v2';mode='MANAGED_SPY_NO_NATIVE_NO_SOURCE';count=$rows.Count;passed=@($rows|Where-Object PASS).Count;cases=$rows.ToArray();liveKeys=0;liveGrants=0;sourceClaims=0;EngineRunCalls=0;DockerCalls=0;utc=[DateTimeOffset]::UtcNow.ToString('o')}
Put (Join-Path $unit 'results.json') $summary
Write-Output ('ADAPTER '+$summary.passed+'/'+$summary.count)
if($summary.passed -ne $summary.count){exit 20}
