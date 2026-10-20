param([ValidatePattern('^flow-[a-z0-9-]{1,24}$')][string]$Trial='flow-final')
. (Join-Path $PSScriptRoot 'readiness.ps1')
$root=$script:LiveARoot
if(Test-Path (Join-Path $root ($Trial+'-results.json'))){throw 'FLOW_ALREADY_RUN'}
$cases=[Collections.Generic.List[object]]::new()
foreach($scenario in @('pass','root0-forced-before-create','create-log-fail','create-root0-forced-with-cid','foreign-owner','clock-content-wrong','sink-always-fails','wrapper-throws')){
 $seen=[Collections.Generic.List[string]]::new();$removed=[Collections.Generic.List[string]]::new();$created=$false;$fakeCID='c'*64;$fakeNow=0
 $p=@{runID=('a'*32);name='wed-source-'+('a'*32)+'-readiness-clock';image='sha256:'+('e'*64);taskMarker='live-readiness-20261019';planSHA=('d'*64);rows=@(@{source='D:\WED SNAP\unit-only';target='/probe/src/0000';sha256=('b'*64)});argv=@('create','UNIT_ONLY_NO_NATIVE')}
 $native={param($op,$argv,$limit,$cap)
  $seen.Add($op)
  if($scenario -ceq 'wrapper-throws'){throw [InvalidOperationException]::new('UNIT_SECRET_URL_MUST_NOT_BE_LOGGED')}
  $r=[pscustomobject]@{Status='PASS';Created=$true;RootInOwnJob=$true;RootExit=0;TerminationRequested=$false;Timeout=$false;ByteCapExceeded=$false;FinalActive=0;PipesEOF=$true;CleanupClosed=$true;RawOut='';RawErr='';LimitMs=$limit;ByteCap=$cap;StdoutBytes=0;StderrBytes=0;ElapsedMs=2}
  switch($op){
   collision {if($scenario -ceq 'root0-forced-before-create'){$r.Status='FAIL';$r.TerminationRequested=$true}}
   create {$r.RawOut=$fakeCID;if($scenario -ceq 'create-root0-forced-with-cid'){$r.Status='FAIL';$r.TerminationRequested=$true}}
   owner {$r.RawOut=@{id=$fakeCID;name='/'+$p.name;image=$p.image;run=$(if($scenario -ceq 'foreign-owner'){'f'*32}else{$p.runID});task=$p.taskMarker}|ConvertTo-Json -Compress}
   guards {$r.RawOut=@{id=$fakeCID;user='1000:1000';rootRO=$true;privileged=$false;capAdd=@();capDrop=@('ALL');security=@('no-new-privileges:true');memory=512MB;swap=512MB;pids=160;nanoCPU=750000000;ipc='private';cgroupns='private';network='none';portCount=0;networks=@('none');tmpfs=$null;mounts=@(@{type='bind';target='/probe/src/0000';rw=$false},@{type='bind';target='/probe/clock.cjs';rw=$false})}|ConvertTo-Json -Depth 8 -Compress}
   {$_ -cin @('mounts','cleanup-mounts')} {$r.RawOut=@{id=$fakeCID;mounts=@(@{type='bind';source='/observed/exact/unit';target='/probe/src/0000';rw=$false},@{type='bind';source='/observed/exact/clock';target='/probe/clock.cjs';rw=$false})}|ConvertTo-Json -Depth 8 -Compress}
   clock-start {$r.RawOut=@{mode='READINESS_ONLY_NO_SOURCE_AUTHORITY';nonce=$p.runID;node='22.22.3';platform='linux';uid=1000;unixMs=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds();monotonicNs='12345678901234';files=@(@{target='/probe/src/0000';sha256=$(if($scenario -ceq 'clock-content-wrong'){'f'*64}else{'b'*64})})}|ConvertTo-Json -Depth 8 -Compress}
   state {$r.RawOut=@{id=$fakeCID;running=$false;status='exited';exit=0;oom=$false;errorPresent=$false}|ConvertTo-Json -Compress}
   remove {$removed.Add([string]$argv[-1])}
  }
  return $r
 }
 $sink={param($name,$value) if($scenario -ceq 'sink-always-fails' -or ($scenario -ceq 'create-log-fail' -and $name -ceq 'created')){throw 'UNIT_INJECTED_SINK_FAILURE'}}
 $result=Invoke-ReadinessBatch $p $native $sink {0} {}
 $expectedPass=$scenario -ceq 'pass';$expectedRemoved=$scenario -cin @('pass','create-log-fail','create-root0-forced-with-cid','clock-content-wrong')
 $ok=$result.readinessPASS -eq $expectedPass -and ($removed.Count -eq $(if($expectedRemoved){1}else{0})) -and @($removed|Where-Object{$_ -cne $fakeCID}).Count -eq 0
 if($scenario -ceq 'root0-forced-before-create' -and $seen.Contains('create')){$ok=$false}
 if($scenario -ceq 'foreign-owner' -and $result.cleanupClosed){$ok=$false}
 if($scenario -ceq 'create-log-fail' -and $result.logComplete){$ok=$false}
 if($scenario -ceq 'wrapper-throws' -and ($result.cause -cne 'NATIVE_WRAPPER_EXCEPTION' -or @($result.nativeCalls|Where-Object resultObserved -EQ $false).Count -ne 2)){$ok=$false}
 $cases.Add(@{name=$scenario;PASS=$ok;completion=$result.readinessPASS;cause=$result.cause;cleanupClosed=$result.cleanupClosed;removed=$removed.ToArray();calls=$seen.ToArray();fake=$true})
}
$out=@{mode='FAKE_EXECUTOR_ONLY_NO_NATIVE';cases=$cases.ToArray();count=$cases.Count;passed=@($cases|Where-Object PASS).Count;sourceCalls=0;liveGrants=0;sourceClaims=0}
Save-New (Join-Path $root ($Trial+'-results.json')) $out
Write-Output ('FLOW '+$out.passed+'/'+$out.count);if($out.passed -ne $out.count){exit 20}
