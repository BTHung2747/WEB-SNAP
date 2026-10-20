param([ValidatePattern('^unit-[a-z0-9-]{1,24}$')][string]$Trial='unit-final')
. (Join-Path $PSScriptRoot 'readiness.ps1')
Import-Module (Join-Path $PSScriptRoot 'Issuer.psm1') -Force
$root=$script:LiveARoot
if(Test-Path (Join-Path $root ($Trial+'-results.json'))){throw 'UNIT_ALREADY_RUN'}
$unitRoot=Join-Path $root ('unit-ledgers/'+$Trial);$null=New-Item -ItemType Directory -Path $unitRoot
$rows=[Collections.Generic.List[object]]::new()
function Test([string]$Name,[scriptblock]$Body){try{& $Body;$rows.Add(@{name=$Name;PASS=$true})}catch{$rows.Add(@{name=$Name;PASS=$false;code='UNIT_ASSERTION_FAILED_NO_MESSAGE'})}}
function MustFail([scriptblock]$Body,[string]$Code){$caught=$null;try{& $Body|Out-Null}catch{$caught=$_.Exception.Message};if($caught -cne $Code){throw 'WRONG_REJECTION'}}
function Eq($A,$B){if($A -cne $B){throw 'ASSERTION'}}
$before=@{unixMs=100000;qpc=10;frequency=1000};$after=@{unixMs=100200;qpc=210;frequency=1000}
Test 'clock-utc-bracket-not-monotonic-domain-identity' {$r=Check-ClockPair $before $after @{unixMs=100100};Eq $r.offsetLowerMs -100;Eq $r.offsetUpperMs 100}
Test 'clock-backward' {MustFail {Check-ClockPair $after $before @{unixMs=100100}} 'CLOCK_PAIR_UNBOUNDED'}
Test 'clock-qpc-stalled' {MustFail {Check-ClockPair $before @{unixMs=100100;qpc=10;frequency=1000} @{unixMs=100100}} 'CLOCK_PAIR_UNBOUNDED'}
Test 'clock-rtt-bound' {MustFail {Check-ClockPair $before @{unixMs=102001;qpc=2200;frequency=1000} @{unixMs=101000}} 'CLOCK_PAIR_UNBOUNDED'}
Test 'clock-offset-bound' {MustFail {Check-ClockPair $before $after @{unixMs=102000}} 'CLOCK_SKEW_NOT_BOUNDED'}
Test 'clock-type-denied' {MustFail {Check-ClockPair $before $after @{unixMs='100100'}} 'CLOCK_PACKET_TYPE'}
Test 'budget-work-clamp' {Eq (Readiness-Limit 59000 $false) 1000}
Test 'budget-work-exhausted' {MustFail {Readiness-Limit 59401 $false} 'READINESS_DEADLINE'}
Test 'budget-cleanup-same-clock' {Eq (Readiness-Limit 79000 $true) 1000}
Test 'budget-cleanup-exhausted' {MustFail {Readiness-Limit 79401 $true} 'READINESS_DEADLINE'}
$n=@{Status='PASS';Created=$true;RootInOwnJob=$true;RootExit=0;TerminationRequested=$false;Timeout=$false;ByteCapExceeded=$false;FinalActive=0;PipesEOF=$true;CleanupClosed=$true}
Test 'native-root0-pass-only-with-closure' {Eq (Native-Accepted $n) $true}
foreach($field in @('TerminationRequested','Timeout','ByteCapExceeded')){Test ('native-root0-'+$field+'-fail') {$x=$n.Clone();$x[$field]=$true;Eq (Native-Accepted $x) $false}}
Test 'native-root0-residual-fail' {$x=$n.Clone();$x.FinalActive=1;Eq (Native-Accepted $x) $false}
Test 'native-root0-incomplete-fail' {$x=$n.Clone();$x.PipesEOF=$false;Eq (Native-Accepted $x) $false}
$p=@{runID=('a'*32);rows=@(@{source='D:\WED SNAP\unit-only';target='/probe/src/0000';sha256=('b'*64)})}
$cid='c'*64
$mount=@{id=$cid;mounts=@(@{type='bind';source='/observed/exact/unit';target='/probe/src/0000';rw=$false},@{type='bind';source='/observed/exact/clock';target='/probe/clock.cjs';rw=$false})}
Test 'mount-map-exact-leaf-no-prefix-inference' {$r=Check-ReadinessMounts $p $mount $cid;Eq $r.Count 2;Eq $r[0].observedEngineSource '/observed/exact/unit'}
Test 'mount-foreign-cid' {MustFail {Check-ReadinessMounts $p $mount ('d'*64)} 'MOUNT_BINDING'}
Test 'mount-writable' {$m=($mount|ConvertTo-Json -Depth 8|ConvertFrom-Json -AsHashtable);$m.mounts[0].rw=$true;MustFail {Check-ReadinessMounts $p $m $cid} 'MOUNT_UNPROVEN'}
Test 'mount-duplicate-target' {$m=($mount|ConvertTo-Json -Depth 8|ConvertFrom-Json -AsHashtable);$m.mounts[1].target=$m.mounts[0].target;MustFail {Check-ReadinessMounts $p $m $cid} 'MOUNT_UNPROVEN'}
$packet=@{mode='READINESS_ONLY_NO_SOURCE_AUTHORITY';nonce=$p.runID;node='22.22.3';platform='linux';uid=1000;unixMs=[long]100100;monotonicNs='12345678901234';files=@(@{target='/probe/src/0000';sha256=('b'*64)})}
Test 'leaf-hash-packet' {Check-ReadinessPacket $p $packet}
Test 'leaf-hash-drift' {$x=($packet|ConvertTo-Json -Depth 8|ConvertFrom-Json -AsHashtable);$x.files[0].sha256='d'*64;MustFail {Check-ReadinessPacket $p $x} 'LEAF_CONTENT_MISMATCH'}
Test 'packet-foreign-nonce' {$x=$packet.Clone();$x.nonce='d'*32;MustFail {Check-ReadinessPacket $p $x} 'CLOCK_PACKET_SCOPE'}
Test 'packet-wrong-node' {$x=$packet.Clone();$x.node='22.0.0';MustFail {Check-ReadinessPacket $p $x} 'CLOCK_PACKET_SCOPE'}
Test 'foreign-owner-denied-before-removal' {MustFail {Assert-Identity @{runID=('a'*32);task='readiness'} @{name='unit';image=('sha256:'+('e'*64))} @{id=$cid;name='/foreign';image=('sha256:'+('e'*64));run=('a'*32);task='readiness'} $cid} 'OWNERSHIP_UNPROVEN'}
$counter=0
function UnitSession([string]$Ledger=''){
 if(!$Ledger){$script:unitNumber++;$Ledger=Join-Path $unitRoot ('case-'+$script:unitNumber);$null=New-Item -ItemType Directory $Ledger}
 New-UnitAuthority ('1'*64) ('2'*64) 'UNIT_TARGET_PHOTO_INDEX_2' $Ledger
}
$script:unitNumber=0;$now=[long]1792400000000
Test 'live-default-deny-without-reviewed-owner-adapter' {MustFail {New-LiveAuthority} 'LIVE_REVIEW_AND_OWNER_ADAPTER_NOT_BOUND'}
Test 'missing-issuer-handle' {MustFail {Issue-UnitApproval $null ('a'*32) ('b'*32) $now} 'REGISTERED_ISSUER_REQUIRED'}
Test 'self-attested-handle' {MustFail {Issue-UnitApproval ([pscustomobject]@{ready=$true;sourceGate=$true}) ('a'*32) ('b'*32) $now} 'REGISTERED_ISSUER_REQUIRED'}
Test 'target-only-is-not-approval' {$s=UnitSession;try{MustFail {Consume-UnitApproval $s @{target='UNIT_TARGET_PHOTO_INDEX_2'} $now} 'ENVELOPE_SCHEMA'}finally{Close-UnitAuthority $s}}
Test 'payload-caller-anchor-denied' {$s=UnitSession;try{$e=Issue-UnitApproval $s ('a'*32) ('b'*32) $now;$e.anchor='caller';MustFail {Consume-UnitApproval $s $e $now} 'ENVELOPE_SCHEMA'}finally{Close-UnitAuthority $s}}
Test 'foreign-key-denied' {$a=UnitSession;$b=UnitSession;try{$e=Issue-UnitApproval $a ('a'*32) ('b'*32) $now;MustFail {Consume-UnitApproval $b $e $now} 'SIGNATURE_DENIED'}finally{Close-UnitAuthority $a;Close-UnitAuthority $b}}
Test 'old-expired-denied' {$s=UnitSession;try{$e=Issue-UnitApproval $s ('a'*32) ('b'*32) $now;MustFail {Consume-UnitApproval $s $e ($now+480001)} 'PAYLOAD_SCOPE_OR_EXPIRY'}finally{Close-UnitAuthority $s}}
Test 'remaining-budget-too-small-denied' {$s=UnitSession;try{$e=Issue-UnitApproval $s ('a'*32) ('b'*32) $now;MustFail {Consume-UnitApproval $s $e ($now+139001)} 'PAYLOAD_SCOPE_OR_EXPIRY'}finally{Close-UnitAuthority $s}}
Test 'unit-once-and-replay-denied' {$s=UnitSession;try{$e=Issue-UnitApproval $s ('a'*32) ('b'*32) $now;$r=Consume-UnitApproval $s $e $now;Eq $r.mode 'UNIT_ADMISSION_ONLY_NOT_SOURCE';MustFail {Consume-UnitApproval $s $e $now} 'ADMISSION_ALREADY_HELD';MustFail {Issue-UnitApproval $s ('c'*32) ('d'*32) $now} 'ISSUANCE_DENIED'}finally{Close-UnitAuthority $s}}
Test 'crash-intent-holds-admission' {$s=UnitSession;try{$dir=Join-Path $unitRoot ('case-'+$script:unitNumber);[IO.File]::WriteAllText((Join-Path $dir 'pending.json'),'UNIT_CRASH_INTENT');$e=Issue-UnitApproval $s ('a'*32) ('b'*32) $now;MustFail {Consume-UnitApproval $s $e $now} 'ADMISSION_ALREADY_HELD';Eq ([IO.File]::ReadAllText((Join-Path $dir 'pending.json'))) 'UNIT_CRASH_INTENT'}finally{Close-UnitAuthority $s}}
Test 'second-key-same-human-ledger-denied' {$s=UnitSession;$dir=Join-Path $unitRoot ('case-'+$script:unitNumber);$t=UnitSession $dir;try{$e=Issue-UnitApproval $s ('a'*32) ('b'*32) $now;$null=Consume-UnitApproval $s $e $now;$f=Issue-UnitApproval $t ('c'*32) ('d'*32) $now;MustFail {Consume-UnitApproval $t $f $now} 'ADMISSION_ALREADY_HELD'}finally{Close-UnitAuthority $s;Close-UnitAuthority $t}}
Test 'exclusive-lock-denied' {$s=UnitSession;try{$dir=Join-Path $unitRoot ('case-'+$script:unitNumber);$f=[IO.FileStream]::new((Join-Path $dir 'admission.lock'),[IO.FileMode]::OpenOrCreate,[IO.FileAccess]::ReadWrite,[IO.FileShare]::None);try{$e=Issue-UnitApproval $s ('a'*32) ('b'*32) $now;MustFail {Consume-UnitApproval $s $e $now} 'ADMISSION_LOCKED'}finally{$f.Dispose()}}finally{Close-UnitAuthority $s}}
Test 'closed-key-handle-denied' {$s=UnitSession;Close-UnitAuthority $s;MustFail {Issue-UnitApproval $s ('a'*32) ('b'*32) $now} 'REGISTERED_ISSUER_REQUIRED'}
Test 'unit-ledger-cannot-use-source-claims-root' {MustFail {New-UnitAuthority ('1'*64) ('2'*64) 'UNIT_TARGET_PHOTO_INDEX_2' (Join-Path (Get-Location).Path 'docs/permissions/source-claims')} 'UNIT_LEDGER_SCOPE'}
Test 'new-logger-overflow-fails-before-write' {MustFail {Serialize-Receipt @{unit=('x'*65536)} $null} 'OPERATION_BYTES_OVER_CAP'}
Test 'docker-override-denied' {$old=[Environment]::GetEnvironmentVariable('DOCKER_HOST');try{[Environment]::SetEnvironmentVariable('DOCKER_HOST','UNIT_ONLY_INVALID');MustFail {No-DockerOverrides} 'OVERRIDE_PRESENT'}finally{[Environment]::SetEnvironmentVariable('DOCKER_HOST',$old)}}
Test 'endpoint-exact-binding-denied' {$x=Get-Content docs/evidence/ui-source-runtime-offline-probe-20261019/backend/plan.json -Raw|ConvertFrom-Json -AsHashtable;$x.endpoint='npipe:////./pipe/unit-foreign';MustFail {New-NativeDelegate $x} 'EXECUTOR_PROVENANCE'}
$r=@{schema='wed-live-a-unit-results-v1';mode='PURE_UNIT_ONLY_NOT_NATIVE_OR_SOURCE';count=$rows.Count;passed=@($rows|Where-Object PASS).Count;failed=@($rows|Where-Object{!$_.PASS}).Count;cases=$rows.ToArray();sourceCalls=0;liveKeys=0;liveGrants=0;sourceClaims=0;utc=[DateTimeOffset]::UtcNow.ToString('o')}
Save-New (Join-Path $root ($Trial+'-results.json')) $r
Write-Output ('UNIT '+$r.passed+'/'+$r.count)
if($r.failed){exit 20}
