. (Join-Path $PSScriptRoot 'readiness.ps1')
$dest=Join-Path (Get-Location).Path 'docs/evidence/ui-source-live-adapter-fix-20261019/backend/readiness-cleanup-cases.json'
if(Test-Path $dest){throw 'NO_CASE_REUSE'}
$cases=[Collections.Generic.List[object]]::new()
foreach($scenario in @('missing-readonly','extra-readonly','mismatch-readonly','foreign','unknown-volume','writable-bind')){
 $fakeID='d'*64;$removed=[Collections.Generic.List[string]]::new();$exists=$false
 $p=@{runID=('a'*32);name='wed-source-'+('a'*32)+'-readiness-clock';image=('sha256:'+('e'*64));taskMarker='live-readiness-20261019';planSHA=('b'*64);rows=@(@{source='D:\UNIT\one';target='/probe/src/0000';sha256=('c'*64)});argv=@('create','UNIT_NO_NATIVE')}
 $n={param($op,$argList,$limit,$cap)
  $r=[pscustomobject]@{Status='PASS';Created=$true;RootInOwnJob=$true;RootExit=0;TerminationRequested=$false;Timeout=$false;ByteCapExceeded=$false;FinalActive=0;PipesEOF=$true;CleanupClosed=$true;RawOut='';RawErr='';ElapsedMs=1;StdoutBytes=0;StderrBytes=0;LimitMs=$limit;ByteCap=$cap}
  switch($op){
   create {$r.RawOut=$fakeID}
   owner {$r.RawOut=@{id=$fakeID;name='/'+$p.name;image=$p.image;run=$(if($scenario -ceq 'foreign'){'f'*32}else{$p.runID});task=$p.taskMarker}|ConvertTo-Json -Compress}
   guards {$r.RawOut=@{id=$fakeID;user='1000:1000';rootRO=$true;privileged=$false;capAdd=@();capDrop=@('ALL');security=@('no-new-privileges:true');memory=512MB;swap=512MB;pids=160;nanoCPU=750000000;ipc='private';cgroupns='private';network='none';portCount=0;networks=@('none');tmpfs=@{};mounts=@(@{type='bind';target='/probe/src/0000';rw=$false})}|ConvertTo-Json -Depth 8 -Compress}
   cleanup-mounts {
    $m=@(@{type='bind';source='/observed/unit';target='/probe/src/0000';rw=$false})
    if($scenario -ceq 'extra-readonly'){$m+=@{type='bind';source='/observed/extra';target='/extra';rw=$false};$m+=@{type='bind';source='/observed/more';target='/more';rw=$false}}
    if($scenario -ceq 'mismatch-readonly'){$m[0].target='/different'}
    if($scenario -ceq 'unknown-volume'){$m[0].type='volume'}
    if($scenario -ceq 'writable-bind'){$m[0].rw=$true}
    $r.RawOut=@{id=$fakeID;mounts=$m}|ConvertTo-Json -Depth 8 -Compress
   }
   remove {$removed.Add($argList[-1])}
  }
  return $r
 }
 $out=Invoke-ReadinessBatch $p $n {} {0} {}
 $safe=$scenario -cin @('missing-readonly','extra-readonly','mismatch-readonly')
 $ok=(!$out.readinessPASS -and $removed.Count -eq $(if($safe){1}else{0}) -and $out.cleanupClosed -eq $safe -and @($removed|Where-Object{$_ -cne $fakeID}).Count -eq 0)
 $cases.Add(@{name=$scenario;PASS=$ok;runtimePASS=$out.readinessPASS;cleanupClosed=$out.cleanupClosed;removed=$removed.ToArray();cause=$out.cause;mode='FAKE_EXECUTOR_NO_NATIVE'})
}
$result=@{cases=$cases.ToArray();count=$cases.Count;passed=@($cases|Where-Object PASS).Count;sourceCalls=0;nativeCalls=0}
Save-New $dest $result
Write-Output ('CLEANUP '+$result.passed+'/'+$result.count);if($result.passed -ne $result.count){exit 20}
